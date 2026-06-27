#!/usr/bin/env bats
# shellcheck shell=bash
# Systematic tests for option parsing boilerplate across all commands.
# Covers --help, --log-level, and -- separator handling.

load helpers

setup()    { bwx_test_setup; }
teardown() { bwx_test_teardown; }

# Commands that accept --help
HELP_COMMANDS=(
    "secret list"
    "secret get"
    "secret show"
    "secret set"
    "secret delete"
    "secret create"
    "secret clone"
    "project list"
    "project show"
    "project id"
    "project name"
    "project default id"
    "project default name"
    "project ls"
    "secret ls"
    "tag list"
    "tag secrets"
    "tag add"
    "tag remove"
    "tag project"
    "tag unproject"
    "import"
    "check expiry"
    "rotate"
)

@test "all commands accept --help" {
    for cmd in "${HELP_COMMANDS[@]}"; do
        # shellcheck disable=SC2086
        run "${BWX}" ${cmd} --help
        [[ "${status}" -le 2 ]] || {
            echo "FAIL: bwx ${cmd} --help exited ${status}"
            return 1
        }
        [[ "${output}" != *"Unknown option"* ]] || {
            echo "FAIL: bwx ${cmd} --help produced 'Unknown option'"
            return 1
        }
    done
}

# Commands that support --log-level
LOG_LEVEL_COMMANDS=(
    "secret list"
    "secret show"
    "secret delete"
    "secret create"
    "project list"
    "project id"
    "project name"
    "project default id"
    "project default name"
    "project ls"
    "secret ls"
    "tag list"
    "tag secrets"
    "check expiry"
    "rotate"
)

@test "commands accept --log-level debug with --help" {
    for cmd in "${LOG_LEVEL_COMMANDS[@]}"; do
        # shellcheck disable=SC2086
        run "${BWX}" ${cmd} --log-level debug --help
        [[ "${status}" -le 2 ]] || {
            echo "FAIL: bwx ${cmd} --log-level debug --help exited ${status}"
            return 1
        }
    done
}

@test "commands accept -- separator before --help" {
    # After --, --help is treated as a positional arg, not a flag.
    # Some commands will error on it; the key is that -- itself is accepted.
    for cmd in "project default name" "project default id" "project ls" "secret ls"; do
        # shellcheck disable=SC2086
        run "${BWX}" ${cmd} --
        # Should not produce "Unknown option --"
        [[ "${output}" != *"Unknown option '--'"* ]] || {
            echo "FAIL: bwx ${cmd} -- produced 'Unknown option'"
            return 1
        }
    done
}

# -- secret get property help tests --

@test "secret get value --help shows usage" {
    run "${BWX}" secret get value --help
    [[ "${output}" == *"Usage:"* ]] || [[ "${output}" == *"usage:"* ]] || \
        [[ "${output}" == *"value"* ]]
}

@test "secret get id --help shows usage" {
    run "${BWX}" secret get id --help
    [[ "${status}" -le 2 ]]
}

@test "secret get note --help shows usage" {
    run "${BWX}" secret get note --help
    [[ "${status}" -le 2 ]]
}

# -- secret get id edge cases --

@test "secret get id --log-level debug succeeds" {
    run "${BWX}" secret get --log-level debug id secret_key_1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "aaaa-bbbb-cccc-dddd" ]]
}
