#!/usr/bin/env bats
# Tests for lifecycle subcommands: import, check expiry, rotate.

BWX_ROOT="$(realpath "$(dirname "${BATS_TEST_FILENAME}")/../..")"
BWX="${BWX_ROOT}/bin/bwx"

# -- import --

@test "import --help shows usage" {
    run "${BWX}" import --help
    [[ "${output}" == *"bwx import"* ]]
    [[ "${output}" == *"TAG"* ]]
    [[ "${output}" == *"OUTPUT_DIR"* ]]
}

@test "import requires TAG and OUTPUT_DIR" {
    run "${BWX}" import
    [[ "${status}" -ne 0 ]]
}

@test "import is in the dispatch table" {
    run "${BWX}" bogus-import
    [[ "${output}" == *"import"* ]]
}

# -- check expiry --

@test "check expiry --help shows usage" {
    run "${BWX}" check expiry --help
    [[ "${output}" == *"bwx check expiry"* ]]
    [[ "${output}" == *"--exit-on-expiring"* ]]
    [[ "${output}" == *"--warn-days"* ]]
}

@test "check expiry is in the dispatch table" {
    run "${BWX}" check bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"expiry"* ]]
}

# -- rotate --

@test "rotate --help shows usage" {
    run "${BWX}" rotate --help
    [[ "${output}" == *"bwx rotate"* ]]
    [[ "${output}" == *"--all"* ]]
    [[ "${output}" == *"provider"* ]]
}

@test "rotate --help lists built-in providers" {
    run "${BWX}" rotate --help
    [[ "${output}" == *"tailscale-oauth"* ]]
    [[ "${output}" == *"tailscale-manual"* ]]
    [[ "${output}" == *"github-pat"* ]]
    [[ "${output}" == *"prompt"* ]]
}

@test "rotate requires SECRET or --all" {
    run "${BWX}" rotate
    [[ "${status}" -ne 0 ]]
}

@test "rotate is in the dispatch table" {
    run "${BWX}" bogus-rotate
    [[ "${output}" == *"rotate"* ]]
}

# -- completion includes new families --

@test "completion bash includes import" {
    run "${BWX}" completion bash
    [[ "${output}" == *"import"* ]]
}

@test "completion bash includes check" {
    run "${BWX}" completion bash
    [[ "${output}" == *"check"* ]]
}

@test "completion bash includes rotate" {
    run "${BWX}" completion bash
    [[ "${output}" == *"rotate"* ]]
}

@test "completion bash includes check expiry as nested subcommand" {
    run "${BWX}" completion bash
    [[ "${output}" == *"expiry"* ]]
}

# -- help text includes new commands --

@test "top-level help shows import" {
    run "${BWX}" --help
    [[ "${output}" == *"import"* ]]
    [[ "${output}" == *"Export secrets by release tag"* ]]
}

@test "top-level help shows check" {
    run "${BWX}" --help
    [[ "${output}" == *"check"* ]]
    [[ "${output}" == *"expiry"* ]]
}

@test "top-level help shows rotate" {
    run "${BWX}" --help
    [[ "${output}" == *"rotate"* ]]
    [[ "${output}" == *"provider"* ]]
}

# -- no bws- leakage in new commands --

@test "import help has no bws- prefix" {
    run "${BWX}" import --help
    [[ "${output}" != *"bws-"* ]]
}

@test "check expiry help has no bws- prefix" {
    run "${BWX}" check expiry --help
    [[ "${output}" != *"bws-"* ]]
}

@test "rotate help has no bws- prefix" {
    run "${BWX}" rotate --help
    [[ "${output}" != *"bws-"* ]]
}
