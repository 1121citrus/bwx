#!/usr/bin/env bats
# Functional tests for bwx project query subcommands.

load helpers

setup()    { bwx_test_setup; }
teardown() { bwx_test_teardown; }

# -- project list --

@test "project list returns projects" {
    run "${BWX}" project list
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

@test "project list with --refresh" {
    run "${BWX}" project list --refresh
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

# -- project show --

@test "project show returns project details" {
    run "${BWX}" project show test-project
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

@test "project show by UUID" {
    run "${BWX}" project show 11111111-1111-1111-1111-111111111111
    [[ "${status}" -eq 0 ]]
}

# -- project id --

@test "project id returns UUID" {
    run "${BWX}" project id test-project
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "11111111-1111-1111-1111-111111111111" ]]
}

@test "project id for other-project" {
    run "${BWX}" project id other-project
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "22222222-2222-2222-2222-222222222222" ]]
}

@test "project id fails for unknown project" {
    run "${BWX}" project id nonexistent-project
    [[ "${status}" -ne 0 ]]
}

# -- project name --

@test "project name returns name by UUID" {
    run "${BWX}" project name 11111111-1111-1111-1111-111111111111
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

# -- project ls --

@test "project ls returns summary" {
    run "${BWX}" project ls
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

# -- project default --

@test "project default name returns BWX_DEFAULT_PROJECT" {
    run "${BWX}" project default name
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "test-project" ]]
}

@test "project default name --help shows usage" {
    run "${BWX}" project default name --help
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"BWX_DEFAULT_PROJECT"* ]]
}

@test "project default name --log-level debug succeeds" {
    run "${BWX}" project default name --log-level debug
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "test-project" ]]
}

@test "project default name rejects unknown option" {
    run "${BWX}" project default name --bogus
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Unknown option"* ]]
}

@test "project default name rejects extra arguments" {
    run "${BWX}" project default name extra-arg
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Too many arguments"* ]]
}

@test "project default id returns UUID of default project" {
    run "${BWX}" project default id
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "11111111-1111-1111-1111-111111111111" ]]
}

@test "project default id --help shows usage" {
    run "${BWX}" project default id --help
    [[ "${output}" == *"Usage:"* ]]
}

@test "project default id --refresh re-fetches UUID" {
    run "${BWX}" project default id --refresh
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "11111111-1111-1111-1111-111111111111" ]]
}

# -- project list option parsing --

@test "project list --help shows usage" {
    run "${BWX}" project list --help
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"--export"* ]]
}

@test "project list --names returns project names" {
    run "${BWX}" project list --names
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

# -- project name option parsing --

@test "project name --help shows usage" {
    run "${BWX}" project name --help
    [[ "${output}" == *"Usage:"* ]]
}

@test "project name with no arg uses default" {
    run "${BWX}" project name
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

@test "project name fails for unknown UUID" {
    run "${BWX}" project name 99999999-9999-9999-9999-999999999999
    [[ "${status}" -ne 0 ]]
}

# -- project ls option parsing --

@test "project ls --help shows usage" {
    run "${BWX}" project ls --help
    [[ "${output}" == *"Usage:"* ]]
}

@test "project ls --refresh succeeds" {
    run "${BWX}" project ls --refresh
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-project"* ]]
}

@test "project ls rejects extra arguments" {
    run "${BWX}" project ls extra-arg
    [[ "${status}" -ne 0 ]]
}
