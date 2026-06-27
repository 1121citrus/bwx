#!/usr/bin/env bats
# shellcheck shell=bash
# Tests for include/provider-config: scrubbing, credential resolution,
# and typed config parsing.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ── bwx-scrub-config-value ────────────────────────────────────────

@test "scrub: passes clean string" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-scrub-config-value "hello-world_123" "test"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "hello-world_123" ]]
}

@test "scrub: passes URL" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-scrub-config-value "http://grafana:3000/api" "test"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "http://grafana:3000/api" ]]
}

@test "scrub: rejects dollar sign" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-scrub-config-value "hello\$(world)" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

@test "scrub: rejects backtick" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-scrub-config-value "hello\`world\`" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

@test "scrub: rejects backslash" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-scrub-config-value "hello\\nworld" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

@test "scrub: rejects newline" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-scrub-config-value "line1
line2" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"newline"* ]]
}

# ── bwx-resolve-credential ────────────────────────────────────────

@test "resolve: reads file via ./ path" {
    echo "file-secret-value" > "${TEST_TMPDIR}/cred"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "'"${TEST_TMPDIR}/cred"'" "test"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"file-secret-value"* ]]
}

@test "resolve: reads file via absolute path" {
    echo "abs-secret" > "${TEST_TMPDIR}/abscred"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "'"${TEST_TMPDIR}/abscred"'" "test"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"abs-secret"* ]]
}

@test "resolve: reads env var via @env:" {
    run bash -c '
        export MY_TEST_CRED="env-secret-value"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "@env:MY_TEST_CRED" "test"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "env-secret-value" ]]
}

@test "resolve: env var not set returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "@env:NONEXISTENT_VAR_XYZ" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"env var not set"* ]]
}

@test "resolve: rejects invalid env var name" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "@env:invalid-name" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"invalid env var name"* ]]
}

@test "resolve: file not found returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "/nonexistent/file" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"file not found"* ]]
}

@test "resolve: literal value passes through scrub" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "plain-literal" "test"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "plain-literal" ]]
}

@test "resolve: empty reference returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"empty reference"* ]]
}

@test "resolve: rejects project:secret with shell chars in project" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-resolve-credential "\$(evil):secret" "test"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

# ── bwx-provider-config ───────────────────────────────────────────

@test "config: string type extracts field" {
    local note="my-field: hello-world"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "my-field" "'"${note}"'" "default" "string"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "hello-world" ]]
}

@test "config: string type uses default when absent" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "missing-field" "" "fallback" "string"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "fallback" ]]
}

@test "config: required field missing returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "missing-field" "" "" "string"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"required field missing"* ]]
}

@test "config: integer type accepts valid number" {
    local note="port: 8080"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "port" "'"${note}"'" "3000" "integer"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "8080" ]]
}

@test "config: integer type rejects non-numeric" {
    local note="port: abc"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "port" "'"${note}"'" "3000" "integer"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"expected integer"* ]]
    [[ "${output}" == *"3000"* ]]
}

@test "config: integer range rejects out-of-bounds" {
    local note="length: 4"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "length" "'"${note}"'" "32" "integer:8:256"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"outside range"* ]]
    [[ "${output}" == *"32"* ]]
}

@test "config: integer range accepts in-bounds" {
    local note="length: 64"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "length" "'"${note}"'" "32" "integer:8:256"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "64" ]]
}

@test "config: enum type accepts valid value" {
    local note="charset: alphanumeric"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "charset" "'"${note}"'" "full" "enum:alphanumeric|full"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "alphanumeric" ]]
}

@test "config: enum type rejects invalid value with default" {
    local note="charset: hex"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "charset" "'"${note}"'" "full" "enum:alphanumeric|full"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"expected one of"* ]]
    [[ "${output}" == *"full"* ]]
}

@test "config: string type rejects shell metacharacters" {
    printf '%s\n' 'my-field: hello$(evil)' > "${TEST_TMPDIR}/note"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        note=$(<"'"${TEST_TMPDIR}/note"'")
        bwx-provider-config "my-field" "${note}" "safe" "string"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

@test "config: credential type resolves file path" {
    echo "resolved-secret" > "${TEST_TMPDIR}/mycred"
    local note="cred-field: ${TEST_TMPDIR}/mycred"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "cred-field" "'"${note}"'" "" "credential"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"resolved-secret"* ]]
}

@test "config: credential type resolves env var" {
    run bash -c '
        export TEST_CRED_VAL="from-env"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        bwx-provider-config "cred-field" "cred-field: @env:TEST_CRED_VAL" "" "credential"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "from-env" ]]
}

# ── credential-via-stdin security checks ──────────────────────────

@test "security: bitwarden-api-key passes token via stdin not args" {
    grep -q -- '--header @-' "${BWX_ROOT}/lib/providers/bitwarden-api-key"
    local inline_auth
    inline_auth=$(grep -c 'header "Authorization: Bearer' \
        "${BWX_ROOT}/lib/providers/bitwarden-api-key" || true)
    [[ "${inline_auth}" -eq 0 ]]
}

@test "security: docker-registry passes JWT via stdin not args" {
    grep -q -- '--header @-' "${BWX_ROOT}/lib/providers/docker-registry"
    local inline_auth
    inline_auth=$(grep -c 'header "Authorization: Bearer' \
        "${BWX_ROOT}/lib/providers/docker-registry" || true)
    [[ "${inline_auth}" -eq 0 ]]
}

@test "security: grafana-service-account passes auth via stdin not --user" {
    grep -q -- '--header @-' \
        "${BWX_ROOT}/lib/providers/grafana-service-account"
    local user_flag
    user_flag=$(grep -c -- '--user' \
        "${BWX_ROOT}/lib/providers/grafana-service-account" || true)
    [[ "${user_flag}" -eq 0 ]]
}

@test "security: no provider passes credentials via --user flag" {
    local count
    count=$(grep -rl -- '--user' "${BWX_ROOT}/lib/providers/" | wc -l)
    [[ "${count}" -eq 0 ]]
}
