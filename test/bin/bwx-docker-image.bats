#!/usr/bin/env bats
# Validate the published bwx runtime image.

bats_require_minimum_version 1.5.0

IMAGE="${IMAGE:-1121citrus/bwx:latest}"

setup() {
    command -v docker >/dev/null 2>&1 || skip "Docker CLI is unavailable"
    docker info >/dev/null 2>&1 || skip "Docker daemon is unavailable"
}

@test "image: includes all runtime dependencies" {
    run docker run --rm --entrypoint bash "${IMAGE}" -ec '
        for tool in bash bws jq curl openssl aws; do
            command -v "${tool}" >/dev/null
        done
    '
    [[ "${status}" -eq 0 ]]
}

@test "image: bwx reports its source version" {
    local source_version
    source_version="$(<"${BATS_TEST_DIRNAME}/../../version.txt")"
    run docker run --rm "${IMAGE}" --version
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "${source_version}" ]]
}

@test "image: bws is executable" {
    run docker run --rm --entrypoint bws "${IMAGE}" --version
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == bws\ * ]]
}

@test "image: default user is not root" {
    run docker run --rm --entrypoint id "${IMAGE}" -u
    [[ "${status}" -eq 0 ]]
    [[ "${output}" -ne 0 ]]
}

@test "image: does not include the Docker CLI" {
    run docker run --rm --entrypoint bash "${IMAGE}" -c \
        'command -v docker'
    [[ "${status}" -ne 0 ]]
}
