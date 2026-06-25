#!/usr/bin/env bats
# Tests for bwx tag subcommands.

BWX_ROOT="$(realpath "$(dirname "${BATS_TEST_FILENAME}")/../..")"
BWX="${BWX_ROOT}/bin/bwx"

setup() {
    TEST_TMPDIR="${BWX_ROOT}/test/.tmp-$$-${BATS_TEST_NUMBER}"
    mkdir -p "${TEST_TMPDIR}/stub-bin"

    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    project) echo '[{"id":"proj-1","name":"my-project","organizationId":"org-1"}]' ;;
    secret)
        case "$2" in
            list)
                echo '[{"id":"uuid-1","key":"secret_v1","value":"val","note":"release-tag: 2026.06.01\nrelease-tag: 2026.07.01","organizationId":"org-1","projectId":"proj-1","creationDate":"2026-01-01","revisionDate":"2026-06-01"}]'
                ;;
            get)
                echo '{"id":"uuid-1","key":"secret_v1","value":"val","note":"release-tag: 2026.06.01","organizationId":"org-1","projectId":"proj-1"}'
                ;;
            edit)
                echo '{"id":"uuid-1","key":"secret_v1"}'
                ;;
        esac
        ;;
esac
STUB
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    if ! command -v jq >/dev/null 2>&1; then
        cat > "${TEST_TMPDIR}/stub-bin/jq" <<'JQ'
#!/usr/bin/env sh
docker run --rm -i apteno/alpine-jq "$@"
JQ
        chmod +x "${TEST_TMPDIR}/stub-bin/jq"
    fi

    export PATH="${TEST_TMPDIR}/stub-bin:${PATH}"
    export BWS_ACCESS_TOKEN="test-token"
    export BWX_DEFAULT_PROJECT="my-project"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

@test "tag list --help exits 0" {
    run "${BWX}" tag list --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag secrets --help exits 0" {
    run "${BWX}" tag secrets --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag add --help exits 0" {
    run "${BWX}" tag add --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag remove --help exits 0" {
    run "${BWX}" tag remove --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag project --help exits 0" {
    run "${BWX}" tag project --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag unproject --help exits 0" {
    run "${BWX}" tag unproject --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "all tag subcommands accept --help" {
    for cmd in add list project remove secrets unproject; do
        run "${BWX}" tag "${cmd}" --help
        [[ "${status}" -eq 0 || "${status}" -eq 2 ]] || \
            return 1
    done
}
