#!/usr/bin/env bats
# shellcheck shell=bash
# Unit tests for include/bwx-cache.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export BWX_CACHE_DIR="${TEST_TMPDIR}/cache"
    source "${BWX_ROOT}/include/logging"
    source "${BWX_ROOT}/include/bwx-cache"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ── bwx-cache-dir ───────────────────────────────────────────────────

@test "cache-dir returns BWX_CACHE_DIR when set" {
    local result
    result=$(bwx-cache-dir)
    [[ "${result}" == "${TEST_TMPDIR}/cache" ]]
    [[ -d "${result}" ]]
}

@test "cache-dir creates directory if missing" {
    rm -rf "${BWX_CACHE_DIR}"
    local result
    result=$(bwx-cache-dir)
    [[ -d "${result}" ]]
}

@test "cache-dir returns 1 in mock mode without BWX_CACHE_DIR" {
    unset BWX_CACHE_DIR
    export CITRUS_ENABLE_MOCK_COMMANDS=true
    run bwx-cache-dir
    [[ "${status}" -eq 1 ]]
}

@test "cache-dir sets directory permissions to 700" {
    bwx-cache-dir >/dev/null
    local perms
    perms=$(stat -c '%a' "${BWX_CACHE_DIR}" 2>/dev/null || \
            stat -f '%Lp' "${BWX_CACHE_DIR}" 2>/dev/null)
    [[ "${perms}" == "700" ]]
}

# ── bwx-cache-hash ──────────────────────────────────────────────────

@test "cache-hash produces consistent output" {
    local h1 h2
    h1=$(bwx-cache-hash "test-key")
    h2=$(bwx-cache-hash "test-key")
    [[ "${h1}" == "${h2}" ]]
    [[ -n "${h1}" ]]
}

@test "cache-hash differs for different inputs" {
    local h1 h2
    h1=$(bwx-cache-hash "key-a")
    h2=$(bwx-cache-hash "key-b")
    [[ "${h1}" != "${h2}" ]]
}

# ── bwx-cache-file ──────────────────────────────────────────────────

@test "cache-file returns path under cache dir" {
    local result
    result=$(bwx-cache-file "ns" "key" "json")
    [[ "${result}" == "${BWX_CACHE_DIR}/"* ]]
    [[ "${result}" == *.json ]]
}

@test "cache-file uses default extension json" {
    local result
    result=$(bwx-cache-file "ns" "key")
    [[ "${result}" == *.json ]]
}

# ── bwx-cache-write and bwx-cache-read ──────────────────────────────

@test "cache-write and cache-read round-trip" {
    local f
    f=$(bwx-cache-file "test" "round-trip")
    bwx-cache-write "${f}" "hello-world"
    local content
    content=$(cat "${f}")
    [[ "${content}" == "hello-world" ]]
}

@test "cache-write creates non-world-readable file" {
    local f
    f=$(bwx-cache-file "test" "perms")
    bwx-cache-write "${f}" "secret-data"
    local perms
    perms=$(stat -c '%a' "${f}" 2>/dev/null || \
            stat -f '%Lp' "${f}" 2>/dev/null)
    [[ "${perms}" == "600" ]]
}

@test "cache-read returns content when fresh" {
    local f
    f=$(bwx-cache-file "test" "fresh-read")
    bwx-cache-write "${f}" "fresh-content"
    local result
    result=$(bwx-cache-read "${f}" 300)
    [[ "${result}" == "fresh-content" ]]
}

@test "cache-read fails for stale file" {
    local f
    f=$(bwx-cache-file "test" "stale-read")
    bwx-cache-write "${f}" "stale-content"
    # Touch file to make it appear old
    touch -t 200001010000.00 "${f}"
    run bwx-cache-read "${f}" 300
    [[ "${status}" -ne 0 ]]
}

# ── bwx-cache-is-fresh ──────────────────────────────────────────────

@test "cache-is-fresh returns 0 for recent file" {
    local f
    f=$(bwx-cache-file "test" "fresh")
    bwx-cache-write "${f}" "data"
    bwx-cache-is-fresh "${f}" 300
}

@test "cache-is-fresh returns 1 for old file" {
    local f
    f=$(bwx-cache-file "test" "old")
    bwx-cache-write "${f}" "data"
    touch -t 200001010000.00 "${f}"
    run bwx-cache-is-fresh "${f}" 300
    [[ "${status}" -ne 0 ]]
}

@test "cache-is-fresh returns 1 for missing file" {
    run bwx-cache-is-fresh "/nonexistent/file" 300
    [[ "${status}" -ne 0 ]]
}

@test "cache-is-fresh returns 1 for zero TTL" {
    local f
    f=$(bwx-cache-file "test" "zero-ttl")
    bwx-cache-write "${f}" "data"
    run bwx-cache-is-fresh "${f}" 0
    [[ "${status}" -ne 0 ]]
}

# ── bwx-cache-delete ────────────────────────────────────────────────

@test "cache-delete removes file" {
    local f
    f=$(bwx-cache-file "test" "delete-me")
    bwx-cache-write "${f}" "data"
    [[ -f "${f}" ]]
    bwx-cache-delete "${f}"
    [[ ! -f "${f}" ]]
}

@test "cache-delete is safe for nonexistent file" {
    bwx-cache-delete "/nonexistent/file"
}
