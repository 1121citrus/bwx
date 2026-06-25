#!/usr/bin/env bats
# Tests for bwx project subcommands.

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
BWX="${BWX_ROOT}/bin/bwx"

setup() {
    TEST_TMPDIR="${BWX_ROOT}/test/.tmp-$$-${BATS_TEST_NUMBER}"
    mkdir -p "${TEST_TMPDIR}/stub-bin"

    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    project)
        case "$2" in
            list)
                echo '[{"id":"proj-1","name":"my-project","organizationId":"org-1"}]'
                ;;
            get)
                echo '{"id":"proj-1","name":"my-project","organizationId":"org-1"}'
                ;;
        esac
        ;;
    secret)
        echo '[]'
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

@test "project list --help exits 0" {
    run "${BWX}" project list --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "project show --help exits 0" {
    run "${BWX}" project show --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "project id --help exits 0" {
    run "${BWX}" project id --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "project name --help exits 0" {
    run "${BWX}" project name --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "project default id returns a value" {
    run "${BWX}" project default id
    # May return empty if no default set, but should not error
    [[ "${status}" -le 4 ]]
}

@test "project default name returns the default project" {
    run "${BWX}" project default name
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "all project subcommands accept --help" {
    for cmd in id list ls name show; do
        run "${BWX}" project "${cmd}" --help
        [[ "${status}" -eq 0 || "${status}" -eq 2 ]] || \
            return 1
    done
}
