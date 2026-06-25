#!/usr/bin/env bats
# Core tests for the bwx dispatch layer.

BWX_ROOT="$(realpath "$(dirname "${BATS_TEST_FILENAME}")/../..")"
BWX="${BWX_ROOT}/bin/bwx"

@test "help flag exits 0" {
    run "${BWX}" --help
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Bitwarden Secrets Manager"* ]]
}

@test "h flag exits 0" {
    run "${BWX}" -h
    [[ "${status}" -eq 0 ]]
}

@test "no arguments shows help" {
    run "${BWX}"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Usage:"* ]]
}

@test "version flag shows version" {
    run "${BWX}" --version
    [[ "${status}" -eq 0 ]]
    [[ "${output}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "unknown top-level command shows families" {
    run "${BWX}" bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"unknown command: bogus"* ]]
    [[ "${output}" == *"completion"* ]]
    [[ "${output}" == *"secret"* ]]
    [[ "${output}" == *"project"* ]]
    [[ "${output}" == *"tag"* ]]
}

@test "unknown secret subcommand shows secret commands" {
    run "${BWX}" secret bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"unknown command: bogus"* ]]
    [[ "${output}" == *"get"* ]]
    [[ "${output}" == *"set"* ]]
    [[ "${output}" == *"list"* ]]
    [[ "${output}" == *"show"* ]]
}

@test "unknown project subcommand shows project commands" {
    run "${BWX}" project bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"default"* ]]
    [[ "${output}" == *"list"* ]]
}

@test "unknown tag subcommand shows tag commands" {
    run "${BWX}" tag bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"add"* ]]
    [[ "${output}" == *"remove"* ]]
}

@test "secret set with unknown property exits non-zero" {
    run "${BWX}" secret set bogus my-secret my-value
    [[ "${status}" -ne 0 ]]
}

@test "unknown project default subcommand shows default commands" {
    run "${BWX}" project default bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"project default"* ]]
    [[ "${output}" == *"id"* ]]
    [[ "${output}" == *"name"* ]]
}

@test "unknown project default subcommand exits 2" {
    run "${BWX}" project default bogus
    [[ "${status}" -eq 2 ]]
}

@test "completion bash outputs a complete function" {
    run "${BWX}" completion bash
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"_bwx_completions"* ]]
    [[ "${output}" == *"complete -F"* ]]
}

@test "completion bash includes all top-level families" {
    run "${BWX}" completion bash
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"completion"* ]]
    [[ "${output}" == *"project"* ]]
    [[ "${output}" == *"raw"* ]]
    [[ "${output}" == *"secret"* ]]
    [[ "${output}" == *"tag"* ]]
}

@test "completion bash includes secret subcommands" {
    run "${BWX}" completion bash
    [[ "${output}" == *"get"* ]]
    [[ "${output}" == *"create"* ]]
    [[ "${output}" == *"list"* ]]
    [[ "${output}" == *"set"* ]]
    [[ "${output}" == *"delete"* ]]
}

@test "completion bash includes project subcommands" {
    run "${BWX}" completion bash
    [[ "${output}" == *"default"* ]]
    [[ "${output}" == *"show"* ]]
}

@test "completion bash includes tag subcommands" {
    run "${BWX}" completion bash
    [[ "${output}" == *"add"* ]]
    [[ "${output}" == *"remove"* ]]
    [[ "${output}" == *"unproject"* ]]
}

@test "completion bash includes secret get and set" {
    run "${BWX}" completion bash
    [[ "${output}" == *"get"* ]]
    [[ "${output}" == *"set"* ]]
}

@test "completion bash includes nested project default subcommands" {
    run "${BWX}" completion bash
    # project default has id and name
    [[ "${output}" == *'"default"'* ]]
    [[ "${output}" == *"id"* ]]
    [[ "${output}" == *"name"* ]]
}

@test "completion zsh outputs compdef" {
    run "${BWX}" completion zsh
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"compdef"* ]]
}

@test "completion zsh includes families" {
    run "${BWX}" completion zsh
    [[ "${output}" == *"secret"* ]]
    [[ "${output}" == *"project"* ]]
    [[ "${output}" == *"tag"* ]]
}

@test "completion unknown shell exits 2" {
    run "${BWX}" completion fish
    [[ "${status}" -eq 2 ]]
}

@test "bwx cannot be sourced" {
    run bash -c "source '${BWX}'"
    [[ "${status}" -ne 0 ]]
}

@test "all secret subcommands are recognized" {
    for cmd in clone create delete get list ls set show; do
        run "${BWX}" secret "${cmd}" --help
        [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 2 ]]
    done
}

@test "all project subcommands are recognized" {
    for cmd in id list ls name show; do
        run "${BWX}" project "${cmd}" --help
        [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 2 ]]
    done
}

@test "project default subcommands are recognized" {
    for cmd in id name; do
        run "${BWX}" project default "${cmd}" --help
        [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 2 ]]
    done
}

@test "all tag subcommands are recognized" {
    for cmd in add list project remove secrets unproject; do
        run "${BWX}" tag "${cmd}" --help
        [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 2 ]]
    done
}
