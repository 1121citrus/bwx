#!/usr/bin/env bats
# Regression tests for the 2026-06-26 bwx remediation plan.
# Each test references the phase/item it validates.

load helpers

setup() {
    bwx_test_setup
    export MOCK_BWS_CALL_LOG="${TEST_TMPDIR}/bws-calls.log"
}

teardown() { bwx_test_teardown; }

# =========================================================================
# Phase 1A: DEBUG xtrace does not leak secret values
# =========================================================================

@test "1A: DEBUG=1 secret set value does not leak value to stderr" {
    run env DEBUG=1 "${BWX}" secret set value secret_key_1 "SUPER_SECRET_VALUE_1A"
    # The value must not appear anywhere in combined output
    [[ "${output}" != *"SUPER_SECRET_VALUE_1A"* ]]
}

@test "1A: DEBUG=1 secret create does not leak value to stderr" {
    run env DEBUG=1 "${BWX}" secret create new_key_1a "SUPER_SECRET_CREATE_1A"
    [[ "${output}" != *"SUPER_SECRET_CREATE_1A"* ]]
}

# =========================================================================
# Phase 1B: import rejects path traversal in secret keys
# =========================================================================

@test "1B: import writes raw files by UUID not key" {
    # Use the default mock which has secret_key_3 with release-tag: test-tag-1
    local outdir="${TEST_TMPDIR}/import-output"
    run "${BWX}" import test-tag-1 "${outdir}"
    [[ "${status}" -eq 0 ]]
    # .raw directory should contain a MANIFEST file
    [[ -f "${outdir}/.raw/MANIFEST" ]]
    # .raw files should be named by UUID (iiii-jjjj-kkkk-llll) not key
    [[ -f "${outdir}/.raw/iiii-jjjj-kkkk-llll" ]]
    # key-named file should NOT exist
    [[ ! -f "${outdir}/.raw/secret_key_3" ]]
}

# =========================================================================
# Phase 2A: rotate --all selects from explicit project
# =========================================================================

@test "2A: rotate --all --dry-run forwards project to candidate fetch" {
    # Replace mock to track which project secret list is called with
    rm -f "${TEST_TMPDIR}/stub-bin/bws"
    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'MOCK'
#!/usr/bin/env bash
if [[ -n "${MOCK_BWS_CALL_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "${MOCK_BWS_CALL_LOG}"
fi
if [[ "$1" == "project" && "$2" == "list" ]]; then
    echo '[{"id":"11111111-1111-1111-1111-111111111111","name":"test-project","organizationId":"org-1","createdAt":"2023-01-01T00:00:00Z","updatedAt":"2023-01-01T00:00:00Z"},{"id":"22222222-2222-2222-2222-222222222222","name":"other-project","organizationId":"org-1","createdAt":"2023-01-01T00:00:00Z","updatedAt":"2023-01-01T00:00:00Z"}]'
    exit 0
fi
if [[ "$1" == "secret" && "$2" == "list" ]]; then
    pid="${3:-default}"
    if [[ "${pid}" == "22222222-2222-2222-2222-222222222222" ]]; then
        cat <<'JSON'
[{"id":"other-uuid","organizationId":"org-1","projectId":"22222222-2222-2222-2222-222222222222","key":"other_expiring_v1","value":"val","note":"expires: 2000-01-01\nprovider: prompt","creationDate":"2023-01-01T00:00:00Z","revisionDate":"2023-01-01T00:00:00Z"}]
JSON
    else
        cat <<'JSON'
[{"id":"default-uuid","organizationId":"org-1","projectId":"11111111-1111-1111-1111-111111111111","key":"default_expiring_v1","value":"val","note":"expires: 2000-01-01\nprovider: prompt","creationDate":"2023-01-01T00:00:00Z","revisionDate":"2023-01-01T00:00:00Z"}]
JSON
    fi
    exit 0
fi
echo "Mock bws: Unknown command $*" >&2
exit 1
MOCK
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    run "${BWX}" rotate --all --dry-run other-project
    [[ "${status}" -eq 0 ]]
    # Should rotate other_expiring_v1, NOT default_expiring_v1
    [[ "${output}" == *"other_expiring_v1"* ]]
    [[ "${output}" != *"default_expiring_v1"* ]]
}

# =========================================================================
# Phase 2B: rotate --all fails closed on candidate fetch error
# =========================================================================

@test "2B: rotate --all fails when secret list fetch fails" {
    rm -f "${TEST_TMPDIR}/stub-bin/bws"
    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "project" && "$2" == "list" ]]; then
    echo '[{"id":"11111111-1111-1111-1111-111111111111","name":"test-project","organizationId":"org-1","createdAt":"2023-01-01T00:00:00Z","updatedAt":"2023-01-01T00:00:00Z"}]'
    exit 0
fi
if [[ "$1" == "secret" && "$2" == "list" ]]; then
    echo "ERROR: API failure" >&2
    exit 1
fi
echo "Mock bws: Unknown command $*" >&2
exit 1
MOCK
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    run "${BWX}" rotate --all --dry-run
    [[ "${status}" -ne 0 ]]
    [[ "${output}" != *"All rotations complete"* ]]
}

# =========================================================================
# Phase 2C: native bws takes precedence over Docker wrapper
# =========================================================================

@test "2C: lib/bwx skips Docker wrapper when native bws exists" {
    # The native-bws guard in lib/bwx checks command -v bws.
    # In test mode, CITRUS_ENABLE_MOCK_COMMANDS=true takes priority,
    # so verify the guard is present in the source.
    local guard_present
    guard_present=$(grep -c 'command -v bws' "${BWX_ROOT}/lib/bwx")
    [[ "${guard_present}" -ge 1 ]]
    # Also verify it comes after the mock guard but before bws() definition
    local mock_line guard_line bws_line
    mock_line=$(grep -n 'CITRUS_ENABLE_MOCK_COMMANDS' "${BWX_ROOT}/lib/bwx" | head -1 | cut -d: -f1)
    guard_line=$(grep -n 'command -v bws' "${BWX_ROOT}/lib/bwx" | head -1 | cut -d: -f1)
    bws_line=$(grep -n '^bws()' "${BWX_ROOT}/lib/bwx" | head -1 | cut -d: -f1)
    [[ "${mock_line}" -lt "${guard_line}" ]]
    [[ "${guard_line}" -lt "${bws_line}" ]]
}

# =========================================================================
# Phase 3A: optional metadata getters return zero for absent fields
# =========================================================================

@test "3A: secret get filename returns 0 for secret without file property" {
    run "${BWX}" secret get filename secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ -z "${output}" ]]
}

@test "3A: secret get expires returns 0 for secret without expires property" {
    run "${BWX}" secret get expires secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ -z "${output}" ]]
}

@test "3A: secret get provider returns 0 for secret without provider property" {
    run "${BWX}" secret get provider secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ -z "${output}" ]]
}

@test "3A: secret get tags returns 0 for untagged secret" {
    run "${BWX}" secret get tags secret_key_7
    [[ "${status}" -eq 0 ]]
    [[ -z "${output}" ]]
}

# =========================================================================
# Phase 3B: centralized note parser unit tests
# =========================================================================

@test "3B: note-parser get-field extracts single-value field" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'file: myfile.txt\nexpires: 2026-12-31\nprovider: github-pat'
    local result
    result="$(bwx-note-get-field file "${note}")"
    [[ "${result}" == "myfile.txt" ]]
}

@test "3B: note-parser get-field returns empty for absent field" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'file: myfile.txt\nexpires: 2026-12-31'
    local result
    result="$(bwx-note-get-field provider "${note}")"
    [[ -z "${result}" ]]
}

@test "3B: note-parser get-field strips inline comments" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'provider :   tailscale-manual   # inline comment'
    local result
    result="$(bwx-note-get-field provider "${note}")"
    [[ "${result}" == "tailscale-manual" ]]
}

@test "3B: note-parser get-multi-field extracts all values" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'release-tag: v1.0\nfile: test\nrelease-tag: v2.0'
    local result
    result="$(bwx-note-get-multi-field release-tag "${note}")"
    [[ "${result}" == *"v1.0"* ]]
    [[ "${result}" == *"v2.0"* ]]
}

@test "3B: note-parser get-multi-field returns empty for absent field" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'file: test\nexpires: 2026-12-31'
    local result
    result="$(bwx-note-get-multi-field release-tag "${note}")"
    [[ -z "${result}" ]]
}

@test "3B: note-parser validate-path rejects traversal" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_path "../../escape"
    [[ "${status}" -ne 0 ]]
}

@test "3B: note-parser validate-path rejects slash" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_path "foo/bar"
    [[ "${status}" -ne 0 ]]
}

@test "3B: note-parser validate-path rejects leading dash" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_path "-flaglike"
    [[ "${status}" -ne 0 ]]
}

@test "3B: note-parser validate-path accepts safe name" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_path "my-secret-file.txt"
    [[ "${status}" -eq 0 ]]
}

@test "3B: note-parser validate-date accepts YYYY-MM-DD" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_date "2026-12-31"
    [[ "${status}" -eq 0 ]]
}

@test "3B: note-parser validate-date rejects invalid format" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_date "not-a-date"
    [[ "${status}" -ne 0 ]]
}

@test "3B: note-parser validate-identifier accepts valid" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_identifier "github-pat"
    [[ "${status}" -eq 0 ]]
}

@test "3B: note-parser validate-identifier rejects spaces" {
    source "${BWX_ROOT}/include/note-parser"
    run _bwx_note_validate_identifier "has spaces"
    [[ "${status}" -ne 0 ]]
}

@test "3B: note-parser set-field replaces existing field" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'file: old.txt\nexpires: 2026-01-01'
    local result
    result="$(bwx-note-set-field expires "2027-06-15" "${note}")"
    [[ "${result}" == *"expires: 2027-06-15"* ]]
    [[ "${result}" != *"2026-01-01"* ]]
    # file: should be preserved
    [[ "${result}" == *"file: old.txt"* ]]
}

@test "3B: note-parser set-field appends absent field" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'file: old.txt'
    local result
    result="$(bwx-note-set-field expires "2027-06-15" "${note}")"
    [[ "${result}" == *"file: old.txt"* ]]
    [[ "${result}" == *"expires: 2027-06-15"* ]]
}

@test "3B: note-parser set-field rejects invalid path value" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'file: old.txt'
    run bwx-note-set-field file "../../escape" "${note}"
    [[ "${status}" -ne 0 ]]
}

@test "3B: note-parser remove-field removes all instances" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'release-tag: v1\nfile: test\nrelease-tag: v2'
    local result
    result="$(bwx-note-remove-field release-tag "" "${note}")"
    [[ "${result}" != *"release-tag"* ]]
    [[ "${result}" == *"file: test"* ]]
}

@test "3B: note-parser remove-field removes specific value" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'release-tag: v1\nrelease-tag: v2\nrelease-tag: v3'
    local result
    result="$(bwx-note-remove-field release-tag "v2" "${note}")"
    [[ "${result}" == *"v1"* ]]
    [[ "${result}" != *"v2"* ]]
    [[ "${result}" == *"v3"* ]]
}

@test "3B: note-parser preserves unknown fields through mutations" {
    source "${BWX_ROOT}/include/note-parser"
    local note=$'file: test\nowner: ops-team\nenv: production\nexpires: 2026-01-01'
    local result
    result="$(bwx-note-remove-field expires "" "${note}")"
    # Unknown fields preserved
    [[ "${result}" == *"owner: ops-team"* ]]
    [[ "${result}" == *"env: production"* ]]
    [[ "${result}" == *"file: test"* ]]
    # expires removed
    [[ "${result}" != *"expires:"* ]]
}

# =========================================================================
# Phase 3C: rotation preserves unknown metadata fields
# =========================================================================

@test "3C: rotation note rebuild preserves unknown fields" {
    # Verify the rotation code uses bwx-note-remove-field (preserve strategy)
    # not the old extract-and-reconstruct approach
    local srcfile="${BWX_ROOT}/lib/bwx-rotate"
    # Should contain the new preserve-and-replace approach
    grep -q 'bwx-note-remove-field' "${srcfile}"
    # Should NOT contain the old narrow field extraction
    run grep -c 'file_field.*grep.*file.*head' "${srcfile}"
    [[ "${output}" == "0" ]]
}

# =========================================================================
# Phase 3D: provider expiry validation
# =========================================================================

@test "3D: rotation validates PROVIDER_EXPIRES is numeric" {
    grep -q 'PROVIDER_EXPIRES.*\^.0-9' "${BWX_ROOT}/lib/bwx-rotate"
}

@test "3D: rotation validates PROVIDER_EXPIRES is non-zero" {
    grep -q 'PROVIDER_EXPIRES.*-gt 0' "${BWX_ROOT}/lib/bwx-rotate"
}

@test "3D: prompt provider validates expiry input" {
    grep -q '\^.0-9' "${BWX_ROOT}/lib/providers/prompt"
}

@test "3D: github-pat provider validates expiry input" {
    grep -q '\^.0-9' "${BWX_ROOT}/lib/providers/github-pat"
}

# =========================================================================
# Phase 3E: create --description option
# =========================================================================

@test "3E: secret create --description sets note field" {
    run "${BWX}" secret create --description "my desc" new_key_3e "some_value"
    [[ "${status}" -eq 0 ]]
    # The bws call log should show --note with "note: my desc"
    local log_content
    log_content="$(<"${MOCK_BWS_CALL_LOG}")"
    [[ "${log_content}" == *"note: my desc"* ]]
}

@test "3E: secret create --note still works as alias" {
    run "${BWX}" secret create --note "my note" new_key_3e_alias "some_value"
    [[ "${status}" -eq 0 ]]
    local log_content
    log_content="$(<"${MOCK_BWS_CALL_LOG}")"
    [[ "${log_content}" == *"note: my note"* ]]
}

@test "3E: secret create -d short flag works" {
    run "${BWX}" secret create -d "short desc" new_key_3e_short "some_value"
    [[ "${status}" -eq 0 ]]
}

@test "3E: secret create help shows --description" {
    run "${BWX}" secret create --help
    [[ "${output}" == *"--description"* ]]
}

# =========================================================================
# Phase 3F: check expiry accepts project argument
# =========================================================================

@test "3F: check expiry --help mentions PROJECT argument" {
    run "${BWX}" check expiry --help
    [[ "${output}" == *"PROJECT"* ]]
}

@test "3F: check expiry with project argument runs successfully" {
    run "${BWX}" check expiry test-project
    [[ "${status}" -eq 0 ]]
}

# =========================================================================
# Phase 4A: ShellCheck covers all shell files
# =========================================================================

@test "4A: build lint discovers shell files in include/, lib/, and bin/" {
    grep -q 'find bin/ include/ lib/' "${BWX_ROOT}/build"
}

@test "4A: build lint includes extensionless files (covers note-parser, providers)" {
    grep -q '! -name "\*\.\*"' "${BWX_ROOT}/build"
}

# =========================================================================
# Phase 4C: no contradictory license notices remain
# =========================================================================

@test "4C: no 'may not be copied' notices in lib/" {
    run grep -rl "may not be copied" "${BWX_ROOT}/lib/"
    [[ "${status}" -ne 0 ]]
}

@test "4C: no 'may not be copied' notices in include/" {
    run grep -rl "may not be copied" "${BWX_ROOT}/include/"
    [[ "${status}" -ne 0 ]]
}

# =========================================================================
# Phase 5B: cache path uses public namespace
# =========================================================================

@test "5B: cache default path uses bwx namespace not 1121-citrus" {
    run grep '1121-citrus' "${BWX_ROOT}/include/bwx-cache"
    [[ "${status}" -ne 0 ]]
}

# =========================================================================
# Phase 5C: SECURITY.md matches runtime cache default
# =========================================================================

@test "5C: SECURITY.md cache path matches bwx-cache default" {
    # Both should reference the bwx namespace
    grep -q 'XDG_CACHE_HOME.*bwx' "${BWX_ROOT}/SECURITY.md"
    grep -q 'XDG_CACHE_HOME.*bwx' "${BWX_ROOT}/include/bwx-cache"
}

@test "5C: public docs use bwx cache namespace" {
    grep -q 'XDG_CACHE_HOME.*bwx' "${BWX_ROOT}/doc/usage.md"
    grep -q 'XDG_CACHE_HOME.*bwx' "${BWX_ROOT}/man/man1/bwx.1"
    run grep -R '1121-citrus/bws' \
        "${BWX_ROOT}/doc" "${BWX_ROOT}/man/man1"
    [[ "${status}" -ne 0 ]]
}

@test "5C: import raw archive contract is documented" {
    grep -q 'raw secret JSON' "${BWX_ROOT}/doc/usage.md"
    grep -q 'MANIFEST' "${BWX_ROOT}/doc/usage.md"
    grep -q 'UUID' "${BWX_ROOT}/doc/usage.md"
}

@test "5C: extension docs do not teach xtrace debug pattern" {
    run grep -E 'set -o (verbose|xtrace)|set -x' \
        "${BWX_ROOT}/doc/extending.md"
    [[ "${status}" -ne 0 ]]
    grep -q 'LOG_LEVEL=debug' "${BWX_ROOT}/doc/extending.md"
}

@test "5C: Homebrew formula has no placeholder release checksum" {
    local formula="${BWX_ROOT}/install/homebrew/Formula/bwx.rb"
    run grep -q 'sha256 "0000000000000000000000000000000000000000000000000000000000000000"' \
        "${formula}"
    [[ "${status}" -ne 0 ]]
    grep -q 'head "https://github.com/1121citrus/bwx.git"' "${formula}"
    grep -q -- '--HEAD' "${BWX_ROOT}/doc/usage.md"
}

@test "5C: Homebrew formula carries tagged release archive checksum" {
    local formula="${BWX_ROOT}/install/homebrew/Formula/bwx.rb"
    grep -q 'url "https://github.com/1121citrus/bwx/archive/refs/tags/v1.0.0.tar.gz"' \
        "${formula}"
    grep -Eq 'sha256 "[0-9a-f]{64}"' "${formula}"
}

@test "5C: Homebrew test does not compare CLI version to HEAD version" {
    local formula="${BWX_ROOT}/install/homebrew/Formula/bwx.rb"
    run grep -q 'version.to_s' "${formula}"
    [[ "${status}" -ne 0 ]]
    grep -q 'assert_match.*\\d+\\.\\d+\\.\\d+' "${formula}"
}

@test "5C: tag commands use centralized note parser" {
    local command_file
    for command_file in \
        "${BWX_ROOT}/lib/bwx-release-tags" \
        "${BWX_ROOT}/lib/bwx-release-tag-secrets" \
        "${BWX_ROOT}/lib/bwx-tag-project" \
        "${BWX_ROOT}/lib/bwx-untag-project"; do
        grep -q 'include/note-parser' "${command_file}"
        run grep -E 'startswith\("release-tag: ?"\)|contains\("release-tag:"\)' \
            "${command_file}"
        [[ "${status}" -ne 0 ]]
    done
}

# =========================================================================
# Phase 5D: CHANGELOG has no private repo references
# =========================================================================

@test "5D: CHANGELOG does not reference private repo" {
    run grep -i '1121-citrus' "${BWX_ROOT}/CHANGELOG.md"
    [[ "${status}" -ne 0 ]]
    run grep -i 'private repo' "${BWX_ROOT}/CHANGELOG.md"
    [[ "${status}" -ne 0 ]]
}

# =========================================================================
# Phase 6A: bwx-secret-clone follows standard module pattern
# =========================================================================

@test "6A: bwx-secret-clone has strict mode at function entry" {
    grep -q 'set -o errexit' "${BWX_ROOT}/lib/bwx-secret-clone"
}

@test "6A: bwx-secret-clone has no duplicate usage function" {
    run grep -c '^usage()' "${BWX_ROOT}/lib/bwx-secret-clone"
    # grep -c returns 1 when no match; output is "0"
    [[ "${output}" == "0" ]] || [[ "${status}" -ne 0 ]]
}

@test "6A: bwx-secret-clone has standard docstring comment" {
    grep -q '# Clone a secret' "${BWX_ROOT}/lib/bwx-secret-clone"
}
