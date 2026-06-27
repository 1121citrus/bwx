#!/usr/bin/env bats
# Functional tests for bwx secret query subcommands.
# Exercises the actual business logic against the mock bws.

load helpers

setup()    { bwx_test_setup; }
teardown() { bwx_test_teardown; }

# -- secret get value --

@test "secret get value returns value by key name" {
    run "${BWX}" secret get value secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_1" ]]
}

@test "secret get value returns value by UUID" {
    run "${BWX}" secret get value aaaa-bbbb-cccc-dddd
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_1" ]]
}

@test "secret get value with explicit project" {
    run "${BWX}" secret get value secret_key_2 other-project
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_2" ]]
}

@test "secret get value with --refresh flag" {
    run "${BWX}" secret get --refresh value secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_1" ]]
}

@test "secret get value fails for unknown secret" {
    run "${BWX}" secret get value nonexistent_secret
    [[ "${status}" -ne 0 ]]
}

@test "secret get --help mentions log-level" {
    run "${BWX}" secret get --help
    [[ "${output}" == *"--log-level"* ]]
}

# -- secret get note --

@test "secret get note returns note by key name" {
    run "${BWX}" secret get note secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "note 1" ]]
}

@test "secret get note returns structured note" {
    run "${BWX}" secret get note secret_key_3
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"file: test-secret-1"* ]]
    [[ "${output}" == *"release-tag: test-tag-1"* ]]
}

@test "secret get note with --refresh flag" {
    run "${BWX}" secret get --refresh note secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "note 1" ]]
}

# -- secret get id --

@test "secret get id returns UUID by key name" {
    run "${BWX}" secret get id secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "aaaa-bbbb-cccc-dddd" ]]
}

@test "secret get id returns UUID for second secret" {
    run "${BWX}" secret get id secret_key_2
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "eeee-ffff-gggg-hhhh" ]]
}

@test "secret get id fails for unknown secret" {
    run "${BWX}" secret get id nonexistent_secret
    [[ "${status}" -ne 0 ]]
}

# -- secret get key --

@test "secret get key returns key by name" {
    run "${BWX}" secret get key secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_key_1" ]]
}

@test "secret get key returns key by UUID" {
    run "${BWX}" secret get key aaaa-bbbb-cccc-dddd
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_key_1" ]]
}

# -- secret get name --

@test "secret get name returns name by key" {
    run "${BWX}" secret get name secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"secret_key_1"* ]]
}

# -- secret get filename --

@test "secret get filename returns file property from note" {
    run "${BWX}" secret get filename secret_key_3
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "test-secret-1" ]]
}

@test "secret get filename returns empty for secret without file property" {
    run "${BWX}" secret get filename secret_key_1
    # No file: property → empty output; status may be non-zero from grep
    [[ -z "${output}" ]] || [[ "${output}" != *"file:"* ]]
}

# -- secret get tags --

@test "secret get tags returns release tags" {
    run "${BWX}" secret get tags secret_key_3
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-tag-1"* ]]
}

@test "secret get tags returns multiple tags" {
    run "${BWX}" secret get tags secret_key_6
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"tag-a"* ]]
    [[ "${output}" == *"tag-b"* ]]
}

@test "secret get tags strips comments and whitespace" {
    run "${BWX}" secret get tags secret_key_tags_edge
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"tag-c"* ]]
    [[ "${output}" == *"tag-d"* ]]
}

@test "secret get provider returns provider line with comments and spaces" {
    run "${BWX}" secret get provider secret_key_provider_edge
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "tailscale-manual" ]]
}

@test "secret get tags returns empty for untagged secret" {
    run "${BWX}" secret get tags secret_key_7
    # No tags → empty output; status may be 0 or non-zero
    [[ -z "${output}" ]] || [[ "${output}" != *"release-tag"* ]]
}

# -- secret show --

@test "secret show returns full details" {
    run "${BWX}" secret show secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"secret_key_1"* ]]
    [[ "${output}" == *"secret_value_1"* ]]
}

# -- secret ls --

@test "secret ls returns summary listing" {
    run "${BWX}" secret ls
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"secret_key_1"* ]]
}

@test "secret ls --help shows usage" {
    run "${BWX}" secret ls --help
    [[ "${output}" == *"Usage:"* ]]
}

@test "secret ls --refresh succeeds" {
    run "${BWX}" secret ls --refresh
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"secret_key_1"* ]]
}

@test "secret ls --log-level debug succeeds" {
    run "${BWX}" secret ls --log-level debug
    [[ "${status}" -eq 0 ]]
}
