#!/usr/bin/env bats
# Tests for bwx secret subcommands.
# Uses a bws stub to avoid requiring a live BWS account.

BWX_ROOT="$(realpath "$(dirname "${BATS_TEST_FILENAME}")/../..")"
BWX="${BWX_ROOT}/bin/bwx"

setup() {
    TEST_TMPDIR="${BWX_ROOT}/test/.tmp-$$-${BATS_TEST_NUMBER}"
    mkdir -p "${TEST_TMPDIR}/stub-bin"

    export CITRUS_ENABLE_MOCK_COMMANDS=true

    # Create a bws stub that returns mock JSON
    cat > "${TEST_TMPDIR}/stub-bin/bws" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    secret)
        case "$2" in
            list)
                cat <<'JSON'
[
  {"id":"uuid-1","key":"app_password_v1","value":"s3cret","note":"file: app-password\nnote: test secret\nexpires: 2026-12-31\nrelease-tag: 2026.06.01","organizationId":"org-1","projectId":"proj-1","creationDate":"2026-01-01","revisionDate":"2026-06-01"},
  {"id":"uuid-2","key":"api_token_v2","value":"tok123","note":"file: api-token\nrelease-tag: 2026.06.01\nrelease-tag: 2026.07.01","organizationId":"org-1","projectId":"proj-1","creationDate":"2026-02-01","revisionDate":"2026-06-15"}
]
JSON
                ;;
            get)
                cat <<'JSON'
{"id":"uuid-1","key":"app_password_v1","value":"s3cret","note":"file: app-password\nnote: test secret\nexpires: 2026-12-31\nrelease-tag: 2026.06.01","organizationId":"org-1","projectId":"proj-1","creationDate":"2026-01-01","revisionDate":"2026-06-01"}
JSON
                ;;
            create)
                cat <<'JSON'
{"id":"uuid-new","key":"new_secret_v1","value":"newval","note":"","organizationId":"org-1","projectId":"proj-1","creationDate":"2026-06-24","revisionDate":"2026-06-24"}
JSON
                ;;
            edit)
                echo '{"id":"uuid-1","key":"app_password_v1","value":"updated"}'
                ;;
        esac
        ;;
    project)
        case "$2" in
            list)
                cat <<'JSON'
[{"id":"proj-1","name":"my-project","organizationId":"org-1","creationDate":"2026-01-01","revisionDate":"2026-06-01"}]
JSON
                ;;
            get)
                echo '{"id":"proj-1","name":"my-project","organizationId":"org-1"}'
                ;;
        esac
        ;;
esac
STUB
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    # Also stub jq if not available
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

# -- secret list --

@test "secret list returns secrets" {
    jq --version >/dev/null 2>&1 || skip "jq not available (native or Docker)"
    run "${BWX}" secret list
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
    [[ "${output}" == *"app_password_v1"* ]]
}

# -- secret show --

@test "secret show requires a secret argument" {
    run "${BWX}" secret show
    [[ "${status}" -ne 0 ]]
}

@test "secret show --help exits 0" {
    run "${BWX}" secret show --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret value --

@test "secret value --help exits 0" {
    run "${BWX}" secret value --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret note --

@test "secret note --help exits 0" {
    run "${BWX}" secret note --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret filename --

@test "secret filename --help exits 0" {
    run "${BWX}" secret filename --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret id --

@test "secret id --help exits 0" {
    run "${BWX}" secret id --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret key --

@test "secret key --help exits 0" {
    run "${BWX}" secret key --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret create --

@test "secret create --help exits 0" {
    run "${BWX}" secret create --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret clone --

@test "secret clone --help exits 0" {
    run "${BWX}" secret clone --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- secret set --

@test "secret set value --help exits 0" {
    run "${BWX}" secret set value --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "secret set note --help exits 0" {
    run "${BWX}" secret set note --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "secret set key --help exits 0" {
    run "${BWX}" secret set key --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "secret set filename --help exits 0" {
    run "${BWX}" secret set filename --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

# -- help for every secret subcommand --

@test "all secret subcommands accept --help" {
    for cmd in clone create filename id key list ls name note show tags value; do
        run "${BWX}" secret "${cmd}" --help
        [[ "${status}" -eq 0 || "${status}" -eq 2 ]] || \
            return 1
    done
}

@test "all secret set subcommands accept --help" {
    for cmd in filename key note value; do
        run "${BWX}" secret set "${cmd}" --help
        [[ "${status}" -eq 0 || "${status}" -eq 2 ]] || \
            return 1
    done
}
