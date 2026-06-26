#!/usr/bin/env bats
# Regression tests for defects found in the Opus 4.8 deep review
# (dev/doc/secrets/20260625-claude-opus-4-8-bwx-deep-review.md).

load helpers

setup() {
    bwx_test_setup
    export MOCK_BWS_CALL_LOG="${TEST_TMPDIR}/bws-calls.log"
}

teardown() { bwx_test_teardown; }

# -- Finding 1: rotate --all PROJECT ignores the project argument --

@test "rotate --all passes project to rotate_one (dry-run)" {
    run "${BWX}" rotate --all --dry-run other-project
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Rotating"* ]]
}

# -- Finding 3: sort -u scrambles note line order --

@test "tag add preserves note line order" {
    run "${BWX}" tag add secret_key_3 "new-tag-xyz"
    [[ "${status}" -eq 0 ]]
    # The mock call log captures what was passed to bws secret edit --note
    # secret_key_3 note: "file: test-secret-1\nnote: ...\nrelease-tag: test-tag-1"
    # After adding new-tag-xyz, file: must still come before note: and release-tag:
    local log_content
    log_content="$(<"${MOCK_BWS_CALL_LOG}")"
    [[ "${log_content}" == *"--note"* ]]
    # Verify line order is preserved: file: before note: before release-tag:
    local file_line note_line tag_line
    file_line=$(grep -n 'file:' "${MOCK_BWS_CALL_LOG}" | head -1 | cut -d: -f1)
    note_line=$(grep -n 'note:' "${MOCK_BWS_CALL_LOG}" | grep -v 'secret edit' | head -1 | cut -d: -f1)
    tag_line=$(grep -n 'release-tag:' "${MOCK_BWS_CALL_LOG}" | head -1 | cut -d: -f1)
    [[ "${file_line}" -lt "${note_line}" ]]
    [[ "${note_line}" -lt "${tag_line}" ]]
}

@test "tag remove preserves note line order" {
    run "${BWX}" tag remove secret_key_6 "tag-b"
    [[ "${status}" -eq 0 ]]
    # secret_key_6 note: "release-tag: tag-b\nnote: multi-tag secret\nrelease-tag: tag-a"
    # After removing tag-b, remaining lines keep original order
    local log_content
    log_content="$(<"${MOCK_BWS_CALL_LOG}")"
    # tag-b should be gone
    [[ "${log_content}" != *"release-tag: tag-b"* ]]
    # remaining content should still be present
    [[ "${log_content}" == *"multi-tag secret"* ]]
    [[ "${log_content}" == *"tag-a"* ]]
    # note: line must appear before release-tag: tag-a (order preserved)
    local note_line tag_line
    note_line=$(grep -n 'multi-tag secret' "${MOCK_BWS_CALL_LOG}" | head -1 | cut -d: -f1)
    tag_line=$(grep -n 'release-tag: tag-a' "${MOCK_BWS_CALL_LOG}" | head -1 | cut -d: -f1)
    [[ "${note_line}" -lt "${tag_line}" ]]
}

# -- Finding 4: echo -e corrupts notes containing backslash sequences --

@test "tag add does not interpret backslash sequences in notes" {
    # Replace the symlink with a custom mock (rm first to avoid
    # overwriting the shared fixture through the symlink)
    rm -f "${TEST_TMPDIR}/stub-bin/bws"
    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'MOCK'
#!/usr/bin/env bash
if [[ -n "${MOCK_BWS_CALL_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "${MOCK_BWS_CALL_LOG}"
fi
if [[ "$1" == "secret" && "$2" == "list" ]]; then
    cat <<'JSON'
[
  {
    "id": "backslash-test-uuid",
    "organizationId": "org-1",
    "projectId": "11111111-1111-1111-1111-111111111111",
    "key": "backslash_secret_v1",
    "value": "val",
    "note": "file: bs-file\nnote: has \\t tabs and \\n newlines literally",
    "creationDate": "2023-01-01T00:00:00Z",
    "revisionDate": "2023-01-01T00:00:00Z"
  }
]
JSON
    exit 0
fi
if [[ "$1" == "project" && "$2" == "list" ]]; then
    echo '[{"id":"11111111-1111-1111-1111-111111111111","name":"test-project","organizationId":"org-1","createdAt":"2023-01-01T00:00:00Z","updatedAt":"2023-01-01T00:00:00Z"}]'
    exit 0
fi
if [[ "$1" == "secret" && "$2" == "edit" ]]; then
    echo "{\"id\":\"$3\",\"key\":\"edited\"}"
    exit 0
fi
echo "Mock bws: Unknown command $*" >&2
exit 1
MOCK
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    run "${BWX}" tag add backslash_secret_v1 "new-tag"
    [[ "${status}" -eq 0 ]]
    # The logged bws call should preserve literal backslash sequences
    # (echo -e would have turned \\t into a real tab and \\n into a newline)
    local log_content
    log_content="$(<"${MOCK_BWS_CALL_LOG}")"
    [[ "${log_content}" == *'\t'* ]]
    [[ "${log_content}" == *'\n'* ]]
}

# -- Finding 2: bulk tag/untag failure counter unreachable --

@test "tag unproject continues after individual secret failures" {
    # Replace the symlink with a custom mock (rm first to avoid
    # overwriting the shared fixture through the symlink)
    rm -f "${TEST_TMPDIR}/stub-bin/bws"
    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'MOCK'
#!/usr/bin/env bash
if [[ -n "${MOCK_BWS_CALL_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "${MOCK_BWS_CALL_LOG}"
fi
if [[ "$1" == "secret" && "$2" == "list" ]]; then
    cat <<JSON
[
  {
    "id": "fail-uuid-1",
    "organizationId": "org-1",
    "projectId": "${3:-11111111-1111-1111-1111-111111111111}",
    "key": "fail_secret_v1",
    "value": "val1",
    "note": "release-tag: remove-me",
    "creationDate": "2023-01-01T00:00:00Z",
    "revisionDate": "2023-01-01T00:00:00Z"
  },
  {
    "id": "pass-uuid-2",
    "organizationId": "org-1",
    "projectId": "${3:-11111111-1111-1111-1111-111111111111}",
    "key": "pass_secret_v1",
    "value": "val2",
    "note": "release-tag: remove-me",
    "creationDate": "2023-01-01T00:00:00Z",
    "revisionDate": "2023-01-01T00:00:00Z"
  }
]
JSON
    exit 0
fi
if [[ "$1" == "project" && "$2" == "list" ]]; then
    echo '[{"id":"11111111-1111-1111-1111-111111111111","name":"test-project","organizationId":"org-1","createdAt":"2023-01-01T00:00:00Z","updatedAt":"2023-01-01T00:00:00Z"}]'
    exit 0
fi
if [[ "$1" == "secret" && "$2" == "edit" ]]; then
    # Fail on the first secret, succeed on the second
    if [[ "$3" == "fail-uuid-1" ]]; then
        echo "Error: simulated failure" >&2
        exit 1
    fi
    echo "{\"id\":\"$3\",\"key\":\"edited\"}"
    exit 0
fi
echo "Mock bws: Unknown command $*" >&2
exit 1
MOCK
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    run "${BWX}" tag unproject remove-me
    # Should return non-zero because of the failure, but should NOT crash.
    # Before the fix, error() would exit the process on the first failure.
    [[ "${status}" -ne 0 ]]
    # Both secrets should have been attempted (not just the first one)
    local edit_count
    edit_count=$(grep -c 'secret edit' "${MOCK_BWS_CALL_LOG}" || echo 0)
    [[ "${edit_count}" -ge 2 ]]
}

# -- Finding 6: set filename sed injection --

@test "set filename handles ampersand in value" {
    run "${BWX}" secret set filename secret_key_3 "file&name"
    [[ "${status}" -eq 0 ]]
    local note_content
    note_content="$(grep -- '--note' "${MOCK_BWS_CALL_LOG}" | head -1)"
    [[ "${note_content}" == *"file&name"* ]]
}

@test "set filename handles pipe in value" {
    run "${BWX}" secret set filename secret_key_3 "file|name"
    [[ "${status}" -eq 0 ]]
    local note_content
    note_content="$(grep -- '--note' "${MOCK_BWS_CALL_LOG}" | head -1)"
    [[ "${note_content}" == *"file|name"* ]]
}

@test "set filename handles backslash in value" {
    run "${BWX}" secret set filename secret_key_3 'file\\name'
    [[ "${status}" -eq 0 ]]
}

# -- Finding 7: clone --help rejected as unknown option --

@test "secret clone --help shows usage instead of error" {
    run "${BWX}" secret clone --help
    [[ "${output}" == *"Usage"* ]]
    [[ "${output}" != *"Unknown option"* ]]
}

@test "secret clone -h shows usage" {
    run "${BWX}" secret clone -h
    [[ "${output}" == *"Usage"* ]]
    [[ "${output}" != *"Unknown option"* ]]
}

# -- Finding 8: project-name cache uses literal backslash-t --

@test "project name cache returns correct name on second call" {
    # First call populates the cache
    run "${BWX}" project name 11111111-1111-1111-1111-111111111111
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]

    # Second call should use the cache and still return the correct name
    run "${BWX}" project name 11111111-1111-1111-1111-111111111111
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

# -- Finding 10: stray :: syntax --

@test "untag-project trace line does not produce syntax errors" {
    # bwx-untag-project line 194 had || :: which is a syntax anomaly
    # Verify static analysis: no '|| ::' (stray colon) in the source
    local srcfile="${BWX_ROOT}/lib/bwx-untag-project"
    run grep -c '|| ::$' "${srcfile}"
    [[ "${output}" == "0" ]]
}
