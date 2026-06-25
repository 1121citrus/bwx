#!/usr/bin/env bats
# Tests for miscellaneous bwx behaviors: version, raw, log-level.

BWX_ROOT="$(realpath "$(dirname "${BATS_TEST_FILENAME}")/../..")"
BWX="${BWX_ROOT}/bin/bwx"

# -- version --

@test "version reads from version.txt" {
    local expected
    expected="$(<"${BWX_ROOT}/version.txt")"
    run "${BWX}" --version
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "${expected}" ]]
}

@test "version matches semver format" {
    run "${BWX}" --version
    [[ "${output}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "help banner includes version from version.txt" {
    local expected
    expected="$(<"${BWX_ROOT}/version.txt")"
    run "${BWX}" --help
    [[ "${output}" == *"${expected}"* ]]
}

# -- raw pass-through --

@test "raw subcommand is recognized" {
    # raw delegates to bws which won't be available in test,
    # but the dispatch should reach bws (not exit with unknown command)
    run "${BWX}" raw --help
    # Either bws prints help (status 0/2) or bws not found (127)
    # but NOT bwx's "unknown command" (status 2 with "unknown" in output)
    if [[ "${status}" -eq 2 ]]; then
        [[ "${output}" != *"unknown command"* ]]
    fi
}

# -- log-level flag --

@test "secret value accepts --log-level flag" {
    run "${BWX}" secret value --log-level debug --help
    # Should not reject --log-level as unknown
    [[ "${output}" != *"Unknown option: --log-level"* ]]
}

@test "project list accepts --log-level flag" {
    run "${BWX}" project list --log-level trace --help
    [[ "${output}" != *"Unknown option: --log-level"* ]]
}

# -- no-args behavior --

@test "no arguments shows help with usage" {
    run "${BWX}"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"secret"* ]]
    [[ "${output}" == *"project"* ]]
    [[ "${output}" == *"tag"* ]]
}

@test "help and -h produce identical output" {
    run "${BWX}" --help
    local help_output="${output}"
    run "${BWX}" -h
    [[ "${output}" == "${help_output}" ]]
}

# -- source guard --

# -- double-dash handling --

@test "-- before family is consumed" {
    run "${BWX}" -- --help
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Usage:"* ]]
}

@test "-- between family and command is consumed" {
    run "${BWX}" secret -- get --help
    [[ "${output}" == *"bwx secret get"* ]]
}

@test "-- between command and subcommand is consumed" {
    run "${BWX}" secret -- set --help
    [[ "${output}" == *"bwx secret set"* ]]
}

@test "multiple -- between subcommand words are consumed" {
    run "${BWX}" -- secret -- get --help
    [[ "${output}" == *"bwx secret get"* ]]
}

# -- source guard --

@test "bwx refuses to be sourced" {
    run bash -c "source '${BWX}'"
    [[ "${status}" -ne 0 ]]
}
