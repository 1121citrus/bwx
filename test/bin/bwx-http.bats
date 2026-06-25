#!/usr/bin/env bats
# Tests for the HTTP client resolution chain (include/http).
#
# Verifies the fallback order: curl → wget → fetch → docker.
# Each test masks tools via PATH manipulation and checks which
# backend is resolved.

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    source "${BWX_ROOT}/include/http"
    # Reset resolution state before each test
    _HTTP_BACKEND=""

    TEST_TMPDIR="${BWX_ROOT}/test/.tmp-$$-${BATS_TEST_NUMBER}"
    mkdir -p "${TEST_TMPDIR}/empty-bin"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# Create a fake executable that always succeeds
_make_fake() {
    local dir="${1}" name="${2}"
    printf '#!/bin/sh\nexit 0\n' > "${dir}/${name}"
    chmod +x "${dir}/${name}"
}

# -- Resolution order tests --

@test "resolves curl when curl is available" {
    _HTTP_BACKEND=""
    _http_resolve
    # curl is available in the BATS Alpine container via apk or
    # on the host; if neither, this test is skipped
    if command -v curl >/dev/null 2>&1; then
        [[ "${_HTTP_BACKEND}" == "curl" ]]
    else
        skip "curl not available natively"
    fi
}

@test "resolves wget when curl is masked" {
    _HTTP_BACKEND=""
    # Create a PATH with only wget, no curl
    local fake="${TEST_TMPDIR}/wget-only"
    mkdir -p "${fake}"
    _make_fake "${fake}" "wget"

    PATH="${fake}" _http_resolve
    [[ "${_HTTP_BACKEND}" == "wget" ]]
}

@test "resolves fetch when curl and wget are masked" {
    _HTTP_BACKEND=""
    local fake="${TEST_TMPDIR}/fetch-only"
    mkdir -p "${fake}"
    _make_fake "${fake}" "fetch"

    PATH="${fake}" _http_resolve
    [[ "${_HTTP_BACKEND}" == "fetch" ]]
}

@test "resolves docker when curl wget and fetch are all masked" {
    _HTTP_BACKEND=""
    local fake="${TEST_TMPDIR}/docker-only"
    mkdir -p "${fake}"
    _make_fake "${fake}" "docker"

    PATH="${fake}" _http_resolve
    [[ "${_HTTP_BACKEND}" == "docker" ]]
}

@test "fails when no HTTP client is available" {
    _HTTP_BACKEND=""
    run bash -c "
        source '${BWX_ROOT}/include/http'
        _HTTP_BACKEND=''
        PATH='${TEST_TMPDIR}/empty-bin' _http_resolve
    "
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"No HTTP client available"* ]]
}

# -- HTTP_BACKEND override --

@test "HTTP_BACKEND env var overrides auto-detection" {
    _HTTP_BACKEND=""
    HTTP_BACKEND=wget _http_resolve
    [[ "${_HTTP_BACKEND}" == "wget" ]]
}

@test "HTTP_BACKEND=docker forces docker backend" {
    _HTTP_BACKEND=""
    HTTP_BACKEND=docker _http_resolve
    [[ "${_HTTP_BACKEND}" == "docker" ]]
}

# -- Resolution caching --

@test "resolution is cached across calls" {
    _HTTP_BACKEND=""
    HTTP_BACKEND=wget _http_resolve
    [[ "${_HTTP_BACKEND}" == "wget" ]]

    # Second call should keep wget even without the env var
    unset HTTP_BACKEND
    _http_resolve
    [[ "${_HTTP_BACKEND}" == "wget" ]]
}

@test "http_backend reports the resolved backend" {
    _HTTP_BACKEND=""
    HTTP_BACKEND=fetch _http_resolve
    result="$(http_backend)"
    [[ "${result}" == "fetch" ]]
}

# -- http_get dispatches to the correct backend --

@test "http_get with curl backend calls curl" {
    _HTTP_BACKEND="curl"
    if ! command -v curl >/dev/null 2>&1; then
        skip "curl not available"
    fi
    # Use a URL that returns a known string
    run http_get "https://httpbin.org/robots.txt"
    if [[ "${status}" -eq 0 ]]; then
        [[ "${output}" == *"User-agent"* ]]
    else
        skip "network unavailable"
    fi
}

@test "http_get with wget backend calls wget" {
    _HTTP_BACKEND="wget"
    if ! command -v wget >/dev/null 2>&1; then
        skip "wget not available"
    fi
    run http_get "https://httpbin.org/robots.txt"
    if [[ "${status}" -eq 0 ]]; then
        [[ "${output}" == *"User-agent"* ]]
    else
        skip "network unavailable"
    fi
}

# -- http_download --

@test "http_download writes to the specified file" {
    _HTTP_BACKEND=""
    _http_resolve || skip "no HTTP client available"
    local dest="${TEST_TMPDIR}/downloaded.txt"
    run http_download "https://httpbin.org/robots.txt" "${dest}"
    if [[ "${status}" -eq 0 ]]; then
        [[ -f "${dest}" ]]
        grep -q "User-agent" "${dest}"
    else
        skip "network unavailable"
    fi
}

@test "http_download requires URL argument" {
    _HTTP_BACKEND="curl"
    run http_download
    [[ "${status}" -ne 0 ]]
}

@test "http_get requires URL argument" {
    _HTTP_BACKEND="curl"
    run http_get
    [[ "${status}" -ne 0 ]]
}
