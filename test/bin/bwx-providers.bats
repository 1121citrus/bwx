#!/usr/bin/env bats
# shellcheck shell=bash
# Tests for lib/providers/* rotation provider functions.
# Each test spawns a subprocess that opens the input file on fd 9 and
# exports BWX_TTY_FD=9 so the provider reads from the file, not /dev/tty.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ── prompt provider ─────────────────────────────────────────────────

@test "prompt: accepts value with default expiry" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "my-secret-value" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/prompt"
        bwx-provider-prompt "test-secret"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=my-secret-value"* ]]
    [[ "${output}" == *"EXPIRES=90"* ]]
    [[ "${output}" == *"NOTE="* ]]
}

@test "prompt: accepts value with custom expiry" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "my-secret-value" "30" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/prompt"
        bwx-provider-prompt "test-secret"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"EXPIRES=30"* ]]
}

@test "prompt: empty value returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/prompt"
        bwx-provider-prompt "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"No value provided"* ]]
}

@test "prompt: non-numeric expiry returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "my-value" "abc" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/prompt"
        bwx-provider-prompt "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"positive integer"* ]]
}

@test "prompt: zero expiry returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "my-value" "0" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/prompt"
        bwx-provider-prompt "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"positive integer"* ]]
}

# ── tailscale-manual provider ───────────────────────────────────────

@test "tailscale-manual: accepts valid tskey-auth key" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "tskey-auth-abc123" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-manual"
        bwx-provider-tailscale-manual "test-secret"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=tskey-auth-abc123"* ]]
    [[ "${output}" == *"EXPIRES=90"* ]]
    [[ "${output}" == *"Untagged reusable key"* ]]
}

@test "tailscale-manual: empty key returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-manual"
        bwx-provider-tailscale-manual "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"No key provided"* ]]
}

@test "tailscale-manual: invalid prefix returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "tskey-reusable-abc123" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-manual"
        bwx-provider-tailscale-manual "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"tskey-auth-"* ]]
}

# ── github-pat provider ─────────────────────────────────────────────

@test "github-pat: accepts ghp_ token with default expiry" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "ghp_abc123" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/github-pat"
        bwx-provider-github-pat "test-secret"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=ghp_abc123"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"NOTE=note: GitHub PAT"* ]]
}

@test "github-pat: accepts github_pat_ token" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "github_pat_xyz789" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/github-pat"
        bwx-provider-github-pat "test-secret"
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=github_pat_xyz789"* ]]
}

@test "github-pat: unrecognized prefix warns but succeeds" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "custom_token_123" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/github-pat"
        bwx-provider-github-pat "test-secret"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=custom_token_123"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
}

@test "github-pat: custom expiry" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "ghp_abc123" "30" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/github-pat"
        bwx-provider-github-pat "test-secret"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"EXPIRES=30"* ]]
}

@test "github-pat: empty token returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/github-pat"
        bwx-provider-github-pat "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"No token provided"* ]]
}

@test "github-pat: non-numeric expiry returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "ghp_abc123" "xyz" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/github-pat"
        bwx-provider-github-pat "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"positive integer"* ]]
}

@test "github-pat: zero expiry returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "ghp_abc123" "0" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/github-pat"
        bwx-provider-github-pat "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"positive integer"* ]]
}

# ── tailscale-oauth provider ────────────────────────────────────────

@test "tailscale-oauth: missing credential files returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-oauth"
        bwx-provider-tailscale-oauth "test-secret" "/nonexistent/dir"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"credentials not found"* ]]
}

@test "tailscale-oauth: missing client_secret_file only returns 1" {
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-oauth"
        bwx-provider-tailscale-oauth "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"credentials not found"* ]]
}

@test "tailscale-oauth: oauth token request failure returns 1" {
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    echo "client-secret" > "${TEST_TMPDIR}/tailscale-oauth-client-secret"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-oauth"
        curl() { return 1; }
        bwx-provider-tailscale-oauth "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"token request failed"* ]]
}

@test "tailscale-oauth: key creation failure returns 1" {
    jq --version >/dev/null 2>&1 || skip "jq required for oauth provider"
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    echo "client-secret" > "${TEST_TMPDIR}/tailscale-oauth-client-secret"
    local call_log="${TEST_TMPDIR}/curl-calls"
    echo "0" > "${call_log}"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-oauth"
        call_log="'"${call_log}"'"
        curl() {
            local count
            count=$(<"${call_log}")
            count=$((count + 1))
            echo "${count}" > "${call_log}"
            if [[ "${count}" -eq 1 ]]; then
                echo "{\"access_token\":\"test-oauth-token\"}"
                return 0
            fi
            return 1
        }
        bwx-provider-tailscale-oauth "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"key creation failed"* ]]
}

@test "tailscale-oauth: successful key creation sets globals" {
    jq --version >/dev/null 2>&1 || skip "jq required for oauth provider"
    echo "client-id" > "${TEST_TMPDIR}/tailscale-oauth-client-id"
    echo "client-secret" > "${TEST_TMPDIR}/tailscale-oauth-client-secret"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/lib/providers/tailscale-oauth"
        curl() {
            case "$*" in
                *oauth/token*)
                    echo "{\"access_token\":\"test-oauth-token\"}"
                    ;;
                *keys*)
                    echo "{\"key\":\"tskey-auth-stubbed-key\"}"
                    ;;
            esac
            return 0
        }
        bwx-provider-tailscale-oauth "test-secret" "'"${TEST_TMPDIR}"'"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=tskey-auth-stubbed-key"* ]]
    [[ "${output}" == *"EXPIRES=90"* ]]
    [[ "${output}" == *"Tagged reusable key"* ]]
}
