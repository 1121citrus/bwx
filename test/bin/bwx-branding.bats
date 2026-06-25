#!/usr/bin/env bats
# Verify that all user-visible output uses bwx naming, not bws-.

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
BWX="${BWX_ROOT}/bin/bwx"

# Every subcommand's --help must show "bwx" in the Usage line,
# never "bws-".

@test "secret list help says bwx not bws" {
    run "${BWX}" secret list --help
    [[ "${output}" == *"bwx"* ]]
    [[ "${output}" != *"bws-"* ]]
}

@test "secret show help says bwx not bws" {
    run "${BWX}" secret show --help
    [[ "${output}" != *"bws-"* ]]
}

@test "secret get value help says bwx not bws" {
    run "${BWX}" secret get --help
    [[ "${output}" != *"bws-"* ]]
}

@test "secret set value help says bwx not bws" {
    run "${BWX}" secret set value --help
    [[ "${output}" != *"bws-"* ]]
}

@test "project list help says bwx not bws" {
    run "${BWX}" project list --help
    [[ "${output}" != *"bws-"* ]]
}

@test "project default id help says bwx not bws" {
    run "${BWX}" project default id --help
    [[ "${output}" != *"bws-"* ]]
}

@test "tag add help says bwx not bws" {
    run "${BWX}" tag add --help
    [[ "${output}" != *"bws-"* ]]
}

@test "tag project help says bwx not bws" {
    run "${BWX}" tag project --help
    [[ "${output}" != *"bws-"* ]]
}

@test "top-level help says bwx not bws" {
    run "${BWX}" --help
    [[ "${output}" == *"bwx"* ]]
    [[ "${output}" != *"bws-"* ]]
}

# Verify all 28 subcommand help outputs in a loop
@test "no subcommand help contains bws- prefix" {
    local cmds=(
        "secret list" "secret show" "secret get value" "secret get note"
        "secret get id" "secret get key" "secret get name" "secret get filename"
        "secret get tags" "secret ls" "secret create" "secret clone"
        "secret set value" "secret set note" "secret set key"
        "secret set filename"
        "project list" "project show" "project id" "project name"
        "project ls" "project default id" "project default name"
        "tag list" "tag secrets" "tag add" "tag remove"
        "tag project" "tag unproject"
    )
    for cmd in "${cmds[@]}"; do
        # shellcheck disable=SC2086
        run "${BWX}" ${cmd} --help
        if [[ "${output}" == *"bws-"* ]]; then
            echo "FAIL: bwx ${cmd} --help contains bws-" >&2
            return 1
        fi
    done
}
