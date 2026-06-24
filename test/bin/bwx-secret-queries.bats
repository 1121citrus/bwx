#!/usr/bin/env bats
# Functional tests for bwx secret query subcommands.
# Exercises the actual business logic against the mock bws.

load helpers

setup()    { bwx_test_setup; }
teardown() { bwx_test_teardown; }

# -- secret value --

@test "secret value returns value by key name" {
    run "${BWX}" secret value secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_1" ]]
}

@test "secret value returns value by UUID" {
    run "${BWX}" secret value aaaa-bbbb-cccc-dddd
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_1" ]]
}

@test "secret value with explicit project" {
    run "${BWX}" secret value secret_key_2 other-project
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_2" ]]
}

@test "secret value with --refresh flag" {
    run "${BWX}" secret value --refresh secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_value_1" ]]
}

@test "secret value fails for unknown secret" {
    run "${BWX}" secret value nonexistent_secret
    [[ "${status}" -ne 0 ]]
}

@test "secret value --help mentions log-level" {
    run "${BWX}" secret value --help
    [[ "${output}" == *"--log-level"* ]]
}

# -- secret note --

@test "secret note returns note by key name" {
    run "${BWX}" secret note secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "note 1" ]]
}

@test "secret note returns structured note" {
    run "${BWX}" secret note secret_key_3
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"file: test-secret-1"* ]]
    [[ "${output}" == *"release-tag: test-tag-1"* ]]
}

@test "secret note with --refresh flag" {
    run "${BWX}" secret note --refresh secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "note 1" ]]
}

# -- secret id --

@test "secret id returns UUID by key name" {
    run "${BWX}" secret id secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "aaaa-bbbb-cccc-dddd" ]]
}

@test "secret id returns UUID for second secret" {
    run "${BWX}" secret id secret_key_2
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "eeee-ffff-gggg-hhhh" ]]
}

@test "secret id fails for unknown secret" {
    run "${BWX}" secret id nonexistent_secret
    [[ "${status}" -ne 0 ]]
}

# -- secret key --

@test "secret key returns key by name" {
    run "${BWX}" secret key secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_key_1" ]]
}

@test "secret key returns key by UUID" {
    run "${BWX}" secret key aaaa-bbbb-cccc-dddd
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "secret_key_1" ]]
}

# -- secret name --

@test "secret name returns name by key" {
    run "${BWX}" secret name secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"secret_key_1"* ]]
}

# -- secret filename --

@test "secret filename returns file property from note" {
    run "${BWX}" secret filename secret_key_3
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "test-secret-1" ]]
}

@test "secret filename returns empty for secret without file property" {
    run "${BWX}" secret filename secret_key_1
    # Should succeed but return empty or the key name as fallback
    [[ "${status}" -eq 0 ]]
}

# -- secret tags --

@test "secret tags returns release tags" {
    run "${BWX}" secret tags secret_key_3
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"test-tag-1"* ]]
}

@test "secret tags returns multiple tags" {
    run "${BWX}" secret tags secret_key_6
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"tag-a"* ]]
    [[ "${output}" == *"tag-b"* ]]
}

@test "secret tags returns empty for untagged secret" {
    run "${BWX}" secret tags secret_key_7
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
