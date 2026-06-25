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

@test "project default id returns UUID of default project" {
    run "${BWX}" project default id
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "11111111-1111-1111-1111-111111111111" ]]
}
