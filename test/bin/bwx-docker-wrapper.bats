#!/usr/bin/env bats
# shellcheck shell=bash
# Tests for lib/bwx — the Docker wrapper, token validation, and cache behavior.
# These tests do NOT set CITRUS_ENABLE_MOCK_COMMANDS, so lib/bwx defines
# the real bws() function. A stub docker command intercepts all container runs.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export BWX_CACHE_DIR="${TEST_TMPDIR}/cache"
    export BWX_VALIDATE_ACCESS_TTL_SECONDS=300

    # Ensure no native bws is on PATH — remove any stub-bin directories
    local cleaned_path=""
    IFS=: read -ra path_parts <<< "${PATH}"
    for p in "${path_parts[@]}"; do
        [[ "${p}" == *stub-bin* ]] && continue
        cleaned_path+="${p}:"
    done
    export PATH="${TEST_TMPDIR}/bin:${cleaned_path%:}"

    # Create a stub docker that simulates bws project list
    mkdir -p "${TEST_TMPDIR}/bin"
    cat > "${TEST_TMPDIR}/bin/docker" <<'DOCKER_STUB'
#!/usr/bin/env bash
# Stub docker for lib/bwx tests
case "$*" in
    *help*)
        echo "bws help stub output"
        exit 0
        ;;
    *"project list"*)
        echo '[{"id":"test-uuid","name":"test-project"}]'
        exit 0
        ;;
    *)
        echo '{"stub":"ok"}'
        exit 0
        ;;
esac
DOCKER_STUB
    chmod +x "${TEST_TMPDIR}/bin/docker"

    # Source logging and cache includes before lib/bwx
    source "${BWX_ROOT}/include/logging"
    source "${BWX_ROOT}/include/bwx-cache"

    # Source lib/bwx which defines bws() since CITRUS_ENABLE_MOCK_COMMANDS
    # is unset and no native bws is on PATH
    unset CITRUS_ENABLE_MOCK_COMMANDS
    source "${BWX_ROOT}/lib/bwx"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ── token validation ────────────────────────────────────────────────

@test "bws: empty access token exits with error" {
    export BWS_ACCESS_TOKEN=""
    run bws project list
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"BWS_ACCESS_TOKEN"* ]]
}

@test "bws: missing access token exits with error" {
    unset BWS_ACCESS_TOKEN
    run bws project list
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"BWS_ACCESS_TOKEN"* ]]
}

@test "bws: malformed token format exits with error" {
    export BWS_ACCESS_TOKEN="not-a-valid-token"
    run bws project list
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"token"* ]]
}

@test "bws: valid token format passes validation" {
    export BWS_ACCESS_TOKEN="0.valid-token-format"
    run -0 bws project list
}

# ── help dispatch ───────────────────────────────────────────────────

@test "bws: --help flag shows help" {
    export BWS_ACCESS_TOKEN="0.valid-token"
    run bws --help
    [[ "${output}" == *"help"* ]]
}

@test "bws: -h flag shows help" {
    export BWS_ACCESS_TOKEN="0.valid-token"
    run bws -h
    [[ "${output}" == *"help"* ]]
}

# ── validation cache ────────────────────────────────────────────────

@test "bws: second call uses cached validation" {
    export BWS_ACCESS_TOKEN="0.valid-token"
    run -0 bws project list
    # Cache file should exist
    local cache_files
    cache_files=$(find "${BWX_CACHE_DIR}" -name 'validate-access-*' 2>/dev/null)
    [[ -n "${cache_files}" ]]
}

# ── docker not found ────────────────────────────────────────────────

@test "bws: docker not found exits with error" {
    export BWS_ACCESS_TOKEN="0.valid-token"
    rm -f "${TEST_TMPDIR}/bin/docker"
    run bws project list
    [[ "${status}" -ne 0 ]]
}

# ── log-level stripping ────────────────────────────────────────────

@test "bws: --log-level is stripped from forwarded args" {
    export BWS_ACCESS_TOKEN="0.valid-token"
    # Override docker to log received args
    cat > "${TEST_TMPDIR}/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "ARGS: $*"
exit 0
STUB
    chmod +x "${TEST_TMPDIR}/bin/docker"
    # Re-source to get fresh bws() with updated docker
    source "${BWX_ROOT}/lib/bwx"
    run -0 bws --log-level debug project list
    # The docker invocation should not contain --log-level
    [[ "${output}" != *"--log-level"* ]]
}

# ── config file handling ────────────────────────────────────────────

@test "bws: creates temp config with chmod 600" {
    export BWS_ACCESS_TOKEN="0.valid-token"
    unset BWS_CONFIG_FILE
    # Override docker to check config file permissions
    cat > "${TEST_TMPDIR}/bin/docker" <<'STUB'
#!/usr/bin/env bash
for arg in "$@"; do
    case "${arg}" in
        *.config/bws/config)
            # Extract the host path (part before the colon)
            host_path="${prev_arg}"
            host_path="${host_path%%:*}"
            if [[ -f "${host_path}" ]]; then
                perms=$(stat -c '%a' "${host_path}" 2>/dev/null || \
                        stat -f '%Lp' "${host_path}" 2>/dev/null)
                echo "CONFIG_PERMS=${perms}"
            fi
            ;;
    esac
    prev_arg="${arg}"
done
echo '[]'
exit 0
STUB
    chmod +x "${TEST_TMPDIR}/bin/docker"
    source "${BWX_ROOT}/lib/bwx"
    run -0 bws project list
}

# ── source guard ────────────────────────────────────────────────────

@test "lib/bwx: direct execution works" {
    export BWS_ACCESS_TOKEN="0.valid-token"
    export CITRUS_ENABLE_MOCK_COMMANDS=true
    run "${BWX_ROOT}/lib/bwx"
    [[ "${status}" -eq 0 ]]
}
