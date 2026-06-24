#!/usr/bin/env bats
# Functional tests for bwx tag subcommands.

load helpers

setup()    { bwx_test_setup; }
teardown() { bwx_test_teardown; }

# -- tag list --

@test "tag list returns tags across all secrets" {
    run "${BWX}" tag list
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-tag-1"* ]]
}

@test "tag list includes multi-value tags" {
    run "${BWX}" tag list
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"tag-a"* ]]
    [[ "${output}" == *"tag-b"* ]]
}

@test "tag list with --refresh" {
    run "${BWX}" tag list --refresh
    [[ "${status}" -eq 0 ]]
}

# -- tag secrets --

@test "tag secrets returns secrets with the specified tag" {
    run "${BWX}" tag secrets test-tag-1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"secret_key_3"* ]]
}

@test "tag secrets for tag-a includes secret_key_6" {
    run "${BWX}" tag secrets tag-a
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"secret_key_6"* ]]
}

@test "tag secrets for nonexistent tag returns empty" {
    run "${BWX}" tag secrets no-such-tag
    [[ "${status}" -eq 0 ]]
}

# -- tag add --

@test "tag add --help exits cleanly" {
    run "${BWX}" tag add --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag add requires arguments" {
    run "${BWX}" tag add
    [[ "${status}" -ne 0 ]]
}

# -- tag remove --

@test "tag remove --help exits cleanly" {
    run "${BWX}" tag remove --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag remove requires arguments" {
    run "${BWX}" tag remove
    [[ "${status}" -ne 0 ]]
}

# -- tag project --

@test "tag project --help exits cleanly" {
    run "${BWX}" tag project --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag project requires a tag argument" {
    run "${BWX}" tag project
    [[ "${status}" -ne 0 ]]
}

# -- tag unproject --

@test "tag unproject --help exits cleanly" {
    run "${BWX}" tag unproject --help
    [[ "${status}" -eq 0 || "${status}" -eq 2 ]]
}

@test "tag unproject requires a tag argument" {
    run "${BWX}" tag unproject
    [[ "${status}" -ne 0 ]]
}
