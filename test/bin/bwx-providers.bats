#!/usr/bin/env bats
# shellcheck shell=bash
# Tests for lib/providers/* rotation provider functions.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    source "${BWX_ROOT}/include/logging"
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    exec 9<&- 2>/dev/null || true
    rm -rf "${TEST_TMPDIR}"
    unset -f curl 2>/dev/null || true
}

# Write lines to a temp file and open it on fd 9 for provider reads.
# Usage: _feed "line1" "line2" ...
_feed() {
    local f="${TEST_TMPDIR}/tty-input"
    printf '%s\n' "$@" > "${f}"
    exec 9< "${f}"
    export BWX_TTY_FD=9
}

# ── prompt provider ─────────────────────────────────────────────────

@test "prompt: accepts value with default expiry" {
    source "${BWX_ROOT}/lib/providers/prompt"
    _feed "my-secret-value" ""
    bwx-provider-prompt "test-secret"
    [[ "${PROVIDER_VALUE}" == "my-secret-value" ]]
    [[ "${PROVIDER_EXPIRES}" == "90" ]]
    [[ "${PROVIDER_NOTE}" == "" ]]
}

@test "prompt: accepts value with custom expiry" {
    source "${BWX_ROOT}/lib/providers/prompt"
    _feed "my-secret-value" "30"
    bwx-provider-prompt "test-secret"
    [[ "${PROVIDER_VALUE}" == "my-secret-value" ]]
    [[ "${PROVIDER_EXPIRES}" == "30" ]]
}

@test "prompt: empty value returns 1" {
    source "${BWX_ROOT}/lib/providers/prompt"
    _feed "" ""
    run -1 bwx-provider-prompt "test-secret"
    [[ "${output}" == *"No value provided"* ]]
}

@test "prompt: non-numeric expiry returns 1" {
    source "${BWX_ROOT}/lib/providers/prompt"
    _feed "my-value" "abc"
    run -1 bwx-provider-prompt "test-secret"
    [[ "${output}" == *"positive integer"* ]]
}

@test "prompt: zero expiry returns 1" {
    source "${BWX_ROOT}/lib/providers/prompt"
    _feed "my-value" "0"
    run -1 bwx-provider-prompt "test-secret"
    [[ "${output}" == *"positive integer"* ]]
}

# ── tailscale-manual provider ───────────────────────────────────────

@test "tailscale-manual: accepts valid tskey-auth key" {
    source "${BWX_ROOT}/lib/providers/tailscale-manual"
    _feed "tskey-auth-abc123"
    bwx-provider-tailscale-manual "test-secret"
    [[ "${PROVIDER_VALUE}" == "tskey-auth-abc123" ]]
    [[ "${PROVIDER_EXPIRES}" == "90" ]]
    [[ "${PROVIDER_NOTE}" == *"Untagged reusable key"* ]]
}

@test "tailscale-manual: empty key returns 1" {
    source "${BWX_ROOT}/lib/providers/tailscale-manual"
    _feed ""
    run -1 bwx-provider-tailscale-manual "test-secret"
    [[ "${output}" == *"No key provided"* ]]
}

@test "tailscale-manual: invalid prefix returns 1" {
    source "${BWX_ROOT}/lib/providers/tailscale-manual"
    _feed "tskey-reusable-abc123"
    run -1 bwx-provider-tailscale-manual "test-secret"
    [[ "${output}" == *"tskey-auth-"* ]]
}

# ── github-pat provider ─────────────────────────────────────────────

@test "github-pat: accepts ghp_ token with default expiry" {
    source "${BWX_ROOT}/lib/providers/github-pat"
    _feed "ghp_abc123" ""
    bwx-provider-github-pat "test-secret"
    [[ "${PROVIDER_VALUE}" == "ghp_abc123" ]]
    [[ "${PROVIDER_EXPIRES}" == "365" ]]
    [[ "${PROVIDER_NOTE}" == "note: GitHub PAT" ]]
}

@test "github-pat: accepts github_pat_ token" {
    source "${BWX_ROOT}/lib/providers/github-pat"
    _feed "github_pat_xyz789" ""
    bwx-provider-github-pat "test-secret"
    [[ "${PROVIDER_VALUE}" == "github_pat_xyz789" ]]
}

@test "github-pat: unrecognized prefix warns but succeeds" {
    source "${BWX_ROOT}/lib/providers/github-pat"
    _feed "custom_token_123" ""
    bwx-provider-github-pat "test-secret"
    [[ "${PROVIDER_VALUE}" == "custom_token_123" ]]
    [[ "${PROVIDER_EXPIRES}" == "365" ]]
}

@test "github-pat: custom expiry" {
    source "${BWX_ROOT}/lib/providers/github-pat"
    _feed "ghp_abc123" "30"
    bwx-provider-github-pat "test-secret"
    [[ "${PROVIDER_EXPIRES}" == "30" ]]
}

@test "github-pat: empty token returns 1" {
    source "${BWX_ROOT}/lib/providers/github-pat"
    _feed "" ""
    run -1 bwx-provider-github-pat "test-secret"
    [[ "${output}" == *"No token provided"* ]]
}

@test "github-pat: non-numeric expiry returns 1" {
    source "${BWX_ROOT}/lib/providers/github-pat"
    _feed "ghp_abc123" "xyz"
    run -1 bwx-provider-github-pat "test-secret"
    [[ "${output}" == *"positive integer"* ]]
}

@test "github-pat: zero expiry returns 1" {
    source "${BWX_ROOT}/lib/providers/github-pat"
    _feed "ghp_abc123" "0"
    run -1 bwx-provider-github-pat "test-secret"
    [[ "${output}" == *"positive integer"* ]]
}

# ── tailscale-oauth provider ────────────────────────────────────────

@test "tailscale-oauth: missing credential files returns 1" {
    source "${BWX_ROOT}/lib/providers/tailscale-oauth"
    run -1 bwx-provider-tailscale-oauth "test-secret" "/nonexistent/dir"
    [[ "${output}" == *"credentials not found"* ]]
}

@test "tailscale-oauth: missing client_secret_file only returns 1" {
    source "${BWX_ROOT}/lib/providers/tailscale-oauth"
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    run -1 bwx-provider-tailscale-oauth "test-secret" "${TEST_TMPDIR}"
    [[ "${output}" == *"credentials not found"* ]]
}

@test "tailscale-oauth: oauth token request failure returns 1" {
    source "${BWX_ROOT}/lib/providers/tailscale-oauth"
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    echo "client-secret" > "${TEST_TMPDIR}/tailscale-oauth-client-secret"
    curl() { return 1; }
    export -f curl
    run -1 bwx-provider-tailscale-oauth "test-secret" "${TEST_TMPDIR}"
    [[ "${output}" == *"token request failed"* ]]
}

@test "tailscale-oauth: key creation failure returns 1" {
    jq --version >/dev/null 2>&1 || skip "jq required for oauth provider"
    source "${BWX_ROOT}/lib/providers/tailscale-oauth"
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    echo "client-secret" > "${TEST_TMPDIR}/tailscale-oauth-client-secret"
    local call_log="${TEST_TMPDIR}/curl-calls"
    echo "0" > "${call_log}"
    curl() {
        local count
        count=$(<"${call_log}")
        count=$((count + 1))
        echo "${count}" > "${call_log}"
        if [[ "${count}" -eq 1 ]]; then
            echo '{"access_token":"test-oauth-token"}'
            return 0
        fi
        return 1
    }
    export -f curl
    export call_log
    run -1 bwx-provider-tailscale-oauth "test-secret" "${TEST_TMPDIR}"
    [[ "${output}" == *"key creation failed"* ]]
}

@test "tailscale-oauth: successful key creation sets globals" {
    jq --version >/dev/null 2>&1 || skip "jq required for oauth provider"
    source "${BWX_ROOT}/lib/providers/tailscale-oauth"
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    echo "client-secret" > "${TEST_TMPDIR}/tailscale-oauth-client-secret"
    curl() {
        case "$*" in
            *oauth/token*)
                echo '{"access_token":"test-oauth-token"}'
                ;;
            *keys*)
                echo '{"key":"tskey-auth-stubbed-key"}'
                ;;
        esac
        return 0
    }
    export -f curl
    bwx-provider-tailscale-oauth "test-secret" "${TEST_TMPDIR}"
    [[ "${PROVIDER_VALUE}" == "tskey-auth-stubbed-key" ]]
    [[ "${PROVIDER_EXPIRES}" == "90" ]]
    [[ "${PROVIDER_NOTE}" == *"Tagged reusable key"* ]]
}
