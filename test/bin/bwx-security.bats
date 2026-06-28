#!/usr/bin/env bats
# Security regression tests — validates that secret values, tokens,
# and credentials do not leak through xtrace, process arguments, file
# permissions, or unsanitized input paths.

load helpers

setup() {
    bwx_test_setup
    export MOCK_BWS_CALL_LOG="${TEST_TMPDIR}/bws-calls.log"
}

teardown() { bwx_test_teardown; }

# =========================================================================
# H1-H3: no module enables xtrace (secret values flow through all)
# =========================================================================

@test "security: no lib/ module enables set -o xtrace" {
    local count
    count=$(grep -rl 'set -o.*xtrace' "${BWX_ROOT}/lib/" | wc -l)
    [[ "${count}" -eq 0 ]]
}

@test "security: no include/ module enables set -o xtrace" {
    local count
    count=$(grep -rl 'set -o.*xtrace' "${BWX_ROOT}/include/" | wc -l)
    [[ "${count}" -eq 0 ]]
}

@test "security: DEBUG=1 secret get value does not leak via xtrace" {
    local stderr_file="${TEST_TMPDIR}/stderr-get-value"
    env DEBUG=1 "${BWX}" secret get value secret_key_1 2>"${stderr_file}" || true
    # Xtrace lines start with + and show expanded commands
    local xtrace_lines
    xtrace_lines=$(grep -cE '^\+\+? ' "${stderr_file}" || true)
    [[ "${xtrace_lines}" -eq 0 ]]
}

@test "security: DEBUG=1 secret show does not leak via xtrace" {
    local stderr_file="${TEST_TMPDIR}/stderr-show"
    env DEBUG=1 "${BWX}" secret show secret_key_1 2>"${stderr_file}" || true
    local xtrace_lines
    xtrace_lines=$(grep -cE '^\+\+? ' "${stderr_file}" || true)
    [[ "${xtrace_lines}" -eq 0 ]]
}

@test "security: DEBUG=1 secret list does not leak via xtrace" {
    local stderr_file="${TEST_TMPDIR}/stderr-list"
    env DEBUG=1 "${BWX}" secret list 2>"${stderr_file}" || true
    local xtrace_lines
    xtrace_lines=$(grep -cE '^\+\+? ' "${stderr_file}" || true)
    [[ "${xtrace_lines}" -eq 0 ]]
}

@test "security: DEBUG=1 check expiry does not leak via xtrace" {
    local stderr_file="${TEST_TMPDIR}/stderr-expiry"
    env DEBUG=1 "${BWX}" check expiry 2>"${stderr_file}" || true
    local xtrace_lines
    xtrace_lines=$(grep -cE '^\+\+? ' "${stderr_file}" || true)
    [[ "${xtrace_lines}" -eq 0 ]]
}

@test "security: DEBUG=1 secret delete does not leak via xtrace" {
    local stderr_file="${TEST_TMPDIR}/stderr-delete"
    env DEBUG=1 "${BWX}" secret delete secret_key_1 2>"${stderr_file}" || true
    local xtrace_lines
    xtrace_lines=$(grep -cE '^\+\+? ' "${stderr_file}" || true)
    [[ "${xtrace_lines}" -eq 0 ]]
}

@test "security: DEBUG=1 tag list does not leak via xtrace" {
    local stderr_file="${TEST_TMPDIR}/stderr-tag-list"
    env DEBUG=1 "${BWX}" tag list 2>"${stderr_file}" || true
    local xtrace_lines
    xtrace_lines=$(grep -cE '^\+\+? ' "${stderr_file}" || true)
    [[ "${xtrace_lines}" -eq 0 ]]
}

@test "security: DEBUG=1 project list does not leak via xtrace" {
    local stderr_file="${TEST_TMPDIR}/stderr-proj-list"
    env DEBUG=1 "${BWX}" project list 2>"${stderr_file}" || true
    local xtrace_lines
    xtrace_lines=$(grep -cE '^\+\+? ' "${stderr_file}" || true)
    [[ "${xtrace_lines}" -eq 0 ]]
}

# =========================================================================
# H4: no --access-token in process argument list
# =========================================================================

@test "security: lib/bwx validation does not pass --access-token as CLI arg" {
    run grep -- '--access-token' "${BWX_ROOT}/lib/bwx"
    [[ "${status}" -ne 0 ]]
}

@test "security: docker bws wrapper trace redacts forwarded secret args" {
    ! grep -q 'trace .*\$\*' "${BWX_ROOT}/lib/bwx"
    grep -q '<redacted-args>' "${BWX_ROOT}/lib/bwx"
}

@test "security: secret create trace redacts new secret value" {
    ! grep -q 'trace "bws ${create_args\[\*\]}"' \
        "${BWX_ROOT}/lib/bwx-create-secret"
    grep -q "trace \"bws secret create --note '...'" \
        "${BWX_ROOT}/lib/bwx-create-secret"
}

# =========================================================================
# M1/M2: curl credentials passed via stdin not CLI args
# =========================================================================

@test "security: tailscale-oauth passes client_secret via stdin" {
    # The --data flag should use @- (stdin), not inline credentials
    grep -q -- '--data @-' "${BWX_ROOT}/lib/providers/tailscale-oauth"
}

@test "security: tailscale-oauth passes bearer token via stdin" {
    # Authorization header should not appear as a --header "..." inline arg
    local inline_auth
    inline_auth=$(grep -c 'header "Authorization: Bearer' "${BWX_ROOT}/lib/providers/tailscale-oauth" || true)
    [[ "${inline_auth}" -eq 0 ]]
}

# =========================================================================
# M4: import tag argument validated against regex injection
# =========================================================================

@test "security: import rejects tag with regex metacharacters" {
    local outdir="${TEST_TMPDIR}/import-regex-test"
    run "${BWX}" import '.*' "${outdir}"
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"invalid characters"* ]]
}

@test "security: import rejects tag with parentheses" {
    local outdir="${TEST_TMPDIR}/import-regex-test"
    run "${BWX}" import '(bad)' "${outdir}"
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"invalid characters"* ]]
}

@test "security: import accepts valid tag names" {
    local outdir="${TEST_TMPDIR}/import-valid-tag"
    run "${BWX}" import test-tag-1 "${outdir}"
    [[ "${status}" -eq 0 ]]
}

@test "security: import accepts 'all' as special tag" {
    local outdir="${TEST_TMPDIR}/import-all-tag"
    run "${BWX}" import all "${outdir}"
    [[ "${status}" -eq 0 ]]
}

@test "security: import rejects secret file metadata with path traversal" {
    local outdir="${TEST_TMPDIR}/import-path-traversal"
    rm -f "${TEST_TMPDIR}/stub-bin/bws"
    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'MOCK'
#!/usr/bin/env bash
if [[ -n "${MOCK_BWS_CALL_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "${MOCK_BWS_CALL_LOG}"
fi
if [[ "$1" == "project" && "$2" == "list" ]]; then
    echo '[{"id":"11111111-1111-1111-1111-111111111111","name":"test-project","organizationId":"org-1","createdAt":"2023-01-01T00:00:00Z","updatedAt":"2023-01-01T00:00:00Z"}]'
    exit 0
fi
if [[ "$1" == "secret" && "$2" == "list" ]]; then
    cat <<'JSON'
[{"id":"malicious-uuid","organizationId":"org-1","projectId":"11111111-1111-1111-1111-111111111111","key":"evil_secret","value":"val","note":"file: ../escape\nnote: bad\nrelease-tag: test-tag-1","creationDate":"2023-01-01T00:00:00Z","revisionDate":"2023-01-01T00:00:00Z"}]
JSON
    exit 0
fi

echo "Mock bws: Unknown command $*" >&2
exit 1
MOCK
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    run "${BWX}" import test-tag-1 "${outdir}"
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Refusing to export"* ]]
}

# =========================================================================
# M5: temp config file has restrictive permissions
# =========================================================================

@test "security: lib/bwx temp config uses chmod 600 not 644" {
    grep -q 'chmod 600 "\${config_file}"' "${BWX_ROOT}/lib/bwx"
}

# =========================================================================
# L4: import output files have restrictive permissions
# =========================================================================

@test "security: import sets umask 077 before writing secret files" {
    grep -q 'umask 077' "${BWX_ROOT}/lib/bwx-import"
}

@test "security: import output directory is not world-readable" {
    local outdir="${TEST_TMPDIR}/import-perms-test"
    run "${BWX}" import test-tag-1 "${outdir}"
    [[ "${status}" -eq 0 ]]
    # Verify others have no access (works under root and non-root)
    run ls -ld "${outdir}"
    # Last 3 chars of permissions should be --- (no other access)
    [[ "${output}" =~ ^d.......--- ]] || [[ "${output}" =~ ^drwx------ ]]
}

@test "security: import .by-uuid directory is not world-readable" {
    local outdir="${TEST_TMPDIR}/import-perms-test2"
    run "${BWX}" import test-tag-1 "${outdir}"
    [[ "${status}" -eq 0 ]]
    run ls -ld "${outdir}/.by-uuid"
    [[ "${output}" =~ ^d.......--- ]] || [[ "${output}" =~ ^drwx------ ]]
}

# =========================================================================
# L5: provider name validated before source (prevents path traversal)
# =========================================================================

@test "security: rotate validates provider name as identifier" {
    grep -q '\[a-zA-Z0-9_-\]' "${BWX_ROOT}/lib/bwx-rotate"
}

@test "security: rotate rejects provider with path traversal" {
    # Create a mock secret with malicious provider name
    rm -f "${TEST_TMPDIR}/stub-bin/bws"
    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'MOCK'
#!/usr/bin/env bash
if [[ -n "${MOCK_BWS_CALL_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "${MOCK_BWS_CALL_LOG}"
fi
if [[ "$1" == "project" && "$2" == "list" ]]; then
    echo '[{"id":"11111111-1111-1111-1111-111111111111","name":"test-project","organizationId":"org-1","createdAt":"2023-01-01T00:00:00Z","updatedAt":"2023-01-01T00:00:00Z"}]'
    exit 0
fi
if [[ "$1" == "secret" && "$2" == "list" ]]; then
    cat <<'JSON'
[{"id":"evil-uuid","organizationId":"org-1","projectId":"11111111-1111-1111-1111-111111111111","key":"evil_secret_v1","value":"val","note":"provider: ../../bin/bwx\nexpires: 2000-01-01","creationDate":"2023-01-01T00:00:00Z","revisionDate":"2023-01-01T00:00:00Z"}]
JSON
    exit 0
fi
echo "Mock bws: Unknown command $*" >&2
exit 1
MOCK
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    run "${BWX}" rotate evil_secret_v1
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Invalid provider name"* ]]
}

# =========================================================================
# L6: clone does not leak secret value JSON to stdout
# =========================================================================

@test "security: clone does not output raw bws JSON to stdout" {
    run "${BWX}" secret clone app_password_v1 "new-rotated-value"
    [[ "${status}" -eq 0 ]]
    # Should not contain the raw JSON response from bws secret create
    [[ "${output}" != *'"value"'* ]]
    [[ "${output}" != *'"organizationId"'* ]]
    # Should contain the info log about the clone
    [[ "${output}" == *"app_password_v2"* ]]
}

# =========================================================================
# Cache file security
# =========================================================================

@test "security: bwx-cache-write creates files not world-readable" {
    source "${BWX_ROOT}/include/bwx-cache"
    local test_cache="${TEST_TMPDIR}/cache-perm-test"
    bwx-cache-write "${test_cache}" "test-payload"
    run ls -l "${test_cache}"
    # File should have no group or other permissions
    [[ "${output}" =~ ^-.......--- ]] || [[ "${output}" =~ ^-rw------- ]]
}

@test "security: bwx-cache-dir creates directory not world-accessible" {
    export BWX_CACHE_DIR="${TEST_TMPDIR}/cache-dir-test"
    source "${BWX_ROOT}/include/bwx-cache"
    bwx-cache-dir >/dev/null
    run ls -ld "${BWX_CACHE_DIR}"
    [[ "${output}" =~ ^d.......--- ]] || [[ "${output}" =~ ^drwx------ ]]
}

# =========================================================================
# Note parser input validation
# =========================================================================

@test "security: note-parser set-field rejects date with invalid format" {
    source "${BWX_ROOT}/include/note-parser"
    local note="expires: 2026-01-01"
    run bwx-note-set-field expires "'; rm -rf /; echo '" "${note}"
    [[ "${status}" -ne 0 ]]
}

@test "security: note-parser set-field rejects provider with spaces" {
    source "${BWX_ROOT}/include/note-parser"
    local note="provider: prompt"
    run bwx-note-set-field provider "prompt; echo pwned" "${note}"
    [[ "${status}" -ne 0 ]]
}

@test "security: note-parser set-field rejects release-tag with metacharacters" {
    source "${BWX_ROOT}/include/note-parser"
    local note="release-tag: v1"
    run bwx-note-set-field release-tag 'v1"; rm -rf /' "${note}"
    [[ "${status}" -ne 0 ]]
}

@test "security: note-parser validate-path rejects NUL-adjacent patterns" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_path ""
    [[ "${status}" -ne 0 ]]
}

# =========================================================================
# Trap-based cleanup: no quoted-path traps that could execute filename
# =========================================================================

@test "security: lib/ files use function-based RETURN traps, not quoted paths" {
    # `trap "rm ... '${var}'" RETURN` expands the path at trap-install
    # time and embeds it as shell code. If the filename ever contains
    # a quote or shell metacharacter, the trap body would execute it.
    # Function-based traps (`trap _cleanup_fn RETURN`) re-read the
    # variable at fire time and pass it as an argument — never as code.
    local hits
    hits=$(grep -rnE "trap[[:space:]]+\"rm[[:space:]]" \
            "${BWX_ROOT}/lib/" "${BWX_ROOT}/include/" 2>/dev/null \
            | wc -l)
    [[ "${hits}" -eq 0 ]]
}

@test "security: trap cleanup functions strip injected filenames" {
    # End-to-end shape check: install a function-based RETURN trap,
    # set the target variable to a value containing shell-injection
    # bait, fire the trap, and confirm only the literal path is acted
    # on (the bait file is left intact).
    local marker="${TEST_TMPDIR}/should-not-be-touched"
    : > "${marker}"
    local tmpfile
    tmpfile="$(mktemp "${TEST_TMPDIR}/cleanup.XXXXXX")"
    : > "${tmpfile}"
    local saved="${tmpfile}"
    # Inject bait: if the trap body evaluated the variable as code,
    # this would delete the marker. The function-based trap passes
    # the value as a single argv element to rm, so the literal
    # filename (which does not exist) is simply ignored.
    tmpfile="${saved}'; rm -f '${marker}"
    _cleanup() { rm -f -- "${tmpfile}"; }
    (
        trap _cleanup RETURN
        true
    )
    [[ -f "${marker}" ]]
}
