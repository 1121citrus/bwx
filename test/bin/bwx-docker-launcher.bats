#!/usr/bin/env bats
# Tests for the standalone Docker launcher without invoking Docker.

bats_require_minimum_version 1.5.0

WRAPPER="${BATS_TEST_DIRNAME}/../../install/bwx"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export HOME="${TEST_TMPDIR}/home"
    export XDG_CONFIG_HOME="${HOME}/config"
    export XDG_CACHE_HOME="${HOME}/cache"
    export DOCKER_STUB_LOG="${TEST_TMPDIR}/docker-args"
    mkdir -p "${HOME}" "${TEST_TMPDIR}/bin"
    cat > "${TEST_TMPDIR}/bin/docker" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" > "${DOCKER_STUB_LOG}"
STUB
    chmod +x "${TEST_TMPDIR}/bin/docker"
    export PATH="${TEST_TMPDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

@test "launcher passes image and bwx arguments to Docker" {
    run env BWX_DOCKER_IMAGE=example/bwx:test \
        "${WRAPPER}" --version
    [[ "${status}" -eq 0 ]]
    grep -Fxq 'example/bwx:test' "${DOCKER_STUB_LOG}"
    grep -Fxq -- '--version' "${DOCKER_STUB_LOG}"
}

@test "launcher mounts the working directory as the container workdir" {
    run "${WRAPPER}" config list
    [[ "${status}" -eq 0 ]]
    grep -Fxq -- '--workdir' "${DOCKER_STUB_LOG}"
    grep -Fxq -- "$(pwd -P)" "${DOCKER_STUB_LOG}"
    grep -Fxq -- "${PWD}:${PWD}" "${DOCKER_STUB_LOG}"
}

@test "launcher mounts bwx config and cache without mounting all of HOME" {
    run "${WRAPPER}" config list
    [[ "${status}" -eq 0 ]]
    grep -Fxq -- "${XDG_CONFIG_HOME}/bwx:${XDG_CONFIG_HOME}/bwx" \
        "${DOCKER_STUB_LOG}"
    grep -Fxq -- "${XDG_CACHE_HOME}/bwx:${XDG_CACHE_HOME}/bwx" \
        "${DOCKER_STUB_LOG}"
    ! grep -Fxq -- "${HOME}:${HOME}" "${DOCKER_STUB_LOG}"
}

@test "launcher forwards credentials by variable name, not value" {
    run env BWS_ACCESS_TOKEN=test-token-value \
        "${WRAPPER}" secret list
    [[ "${status}" -eq 0 ]]
    grep -Fxq BWS_ACCESS_TOKEN "${DOCKER_STUB_LOG}"
    [[ "${output}" != *test-token-value* ]]
    [[ "$(<"${DOCKER_STUB_LOG}")" != *test-token-value* ]]
}

@test "launcher accepts a custom environment file" {
    local env_file="${TEST_TMPDIR}/provider.env"
    touch "${env_file}"
    run env BWX_DOCKER_ENV_FILE="${env_file}" \
        "${WRAPPER}" provider info
    [[ "${status}" -eq 0 ]]
    grep -Fxq -- '--env-file' "${DOCKER_STUB_LOG}"
    grep -Fxq -- "${env_file}" "${DOCKER_STUB_LOG}"
}

@test "launcher fails clearly when Docker is unavailable" {
    mkdir -p "${TEST_TMPDIR}/empty-path"
    run -127 env PATH="${TEST_TMPDIR}/empty-path" \
        "${BASH}" "${WRAPPER}" --version
    [[ "${output}" == *"Docker is required"* ]]
}

@test "launcher does not mount the Docker socket or enable privileged mode" {
    run "${WRAPPER}" --version
    [[ "${status}" -eq 0 ]]
    [[ "$(<"${DOCKER_STUB_LOG}")" != *"/var/run/docker.sock"* ]]
    [[ "$(<"${DOCKER_STUB_LOG}")" != *"--privileged"* ]]
}
