#!/usr/bin/env bats
# Functional tests for bwx mutation subcommands (set, clone, create,
# tag add/remove, tag project/unproject).

load helpers

setup()    { bwx_test_setup; }
teardown() { bwx_test_teardown; }

# -- secret set value --

@test "secret set value updates a secret" {
    run "${BWX}" secret set value secret_key_1 "new_value"
    [[ "${status}" -eq 0 ]]
}

@test "secret set value requires secret and value args" {
    run "${BWX}" secret set value
    [[ "${status}" -ne 0 ]]
}

@test "secret set value requires value arg" {
    run "${BWX}" secret set value secret_key_1
    [[ "${status}" -ne 0 ]]
}

# -- secret set note --

@test "secret set note updates a note" {
    run "${BWX}" secret set note secret_key_1 "new note text"
    [[ "${status}" -eq 0 ]]
}

@test "secret set note requires secret and note args" {
    run "${BWX}" secret set note
    [[ "${status}" -ne 0 ]]
}

# -- secret set key --

@test "secret set key updates a key name" {
    run "${BWX}" secret set key secret_key_1 "renamed_key"
    [[ "${status}" -eq 0 ]]
}

@test "secret set key requires secret and key args" {
    run "${BWX}" secret set key
    [[ "${status}" -ne 0 ]]
}

# -- secret set filename --

@test "secret set filename updates the file property" {
    run "${BWX}" secret set filename secret_key_3 "new-filename"
    [[ "${status}" -eq 0 ]]
}

@test "secret set filename requires secret and filename args" {
    run "${BWX}" secret set filename
    [[ "${status}" -ne 0 ]]
}

# -- secret delete --

@test "secret delete deletes a secret by name" {
    run "${BWX}" secret delete secret_key_1
    [[ "${status}" -eq 0 ]]
}

@test "secret delete deletes a secret by UUID" {
    run "${BWX}" secret delete aaaa-bbbb-cccc-dddd
    [[ "${status}" -eq 0 ]]
}

@test "secret delete requires a secret argument" {
    run "${BWX}" secret delete
    [[ "${status}" -ne 0 ]]
}

@test "secret delete fails for unknown secret" {
    run "${BWX}" secret delete nonexistent_secret
    [[ "${status}" -ne 0 ]]
}

@test "secret delete --help shows usage" {
    run "${BWX}" secret delete --help
    [[ "${output}" == *"bwx secret delete"* ]]
    [[ "${output}" != *"bws-"* ]]
}

# -- secret create --

@test "secret create creates a new secret" {
    run "${BWX}" secret create new_test_key "test_value"
    [[ "${status}" -eq 0 ]]
}

@test "secret create with --note" {
    run "${BWX}" secret create --note "file: test\nrelease-tag: v1" \
        new_key_with_note "val"
    [[ "${status}" -eq 0 ]]
}

@test "secret create requires key and value" {
    run "${BWX}" secret create
    [[ "${status}" -ne 0 ]]
}

# -- secret clone --

@test "secret clone clones a versioned secret" {
    run "${BWX}" secret clone app_password_v1 "rotated-value"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"app_password_v2"* ]]
}

@test "secret clone rejects non-versioned secret names" {
    run "${BWX}" secret clone secret_key_1
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"_vN"* ]]
}

@test "secret clone requires a secret name" {
    run "${BWX}" secret clone
    [[ "${status}" -ne 0 ]]
}

# -- tag add --

@test "tag add adds a release tag" {
    run "${BWX}" tag add secret_key_1 "2026.06.24.01"
    [[ "${status}" -eq 0 ]]
}

@test "tag add requires secret and tag" {
    run "${BWX}" tag add secret_key_1
    [[ "${status}" -ne 0 ]]
}

# -- tag remove --

@test "tag remove removes a release tag" {
    run "${BWX}" tag remove secret_key_3 "test-tag-1"
    [[ "${status}" -eq 0 ]]
}

@test "tag remove requires secret and tag" {
    run "${BWX}" tag remove secret_key_3
    [[ "${status}" -ne 0 ]]
}

# -- tag project --

@test "tag project tags all secrets" {
    run "${BWX}" tag project "2026.06.24.01"
    [[ "${status}" -eq 0 ]]
}

@test "tag project requires a tag" {
    run "${BWX}" tag project
    [[ "${status}" -ne 0 ]]
}

# -- tag unproject --

@test "tag unproject untags all secrets" {
    run "${BWX}" tag unproject "test-tag-1"
    [[ "${status}" -eq 0 ]]
}

@test "tag unproject requires a tag" {
    run "${BWX}" tag unproject
    [[ "${status}" -ne 0 ]]
}
