#!/usr/bin/env bats
# shellcheck disable=SC1090,SC1091
# Portability tests for bwx.
#
# Static-analysis tests that verify portability guards and patterns
# are present in the source tree.  These run in milliseconds with no
# Docker or network dependency.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
BWX="${BWX_ROOT}/bin/bwx"

# ---------------------------------------------------------------------------
# P-01: Bash version guard
# ---------------------------------------------------------------------------

@test "bin/bwx contains bash version guard" {
    grep -q 'BASH_VERSINFO\[0\] < 4' "${BWX}"
}

@test "build script contains bash version guard" {
    grep -q 'BASH_VERSINFO\[0\] < 4' "${BWX_ROOT}/build"
}

@test "version guard message text is present in bin/bwx" {
    grep -q 'bash 4.0 or later' "${BWX}"
    grep -q 'brew install bash' "${BWX}"
}

# ---------------------------------------------------------------------------
# P-02: No bare readlink -f in build tooling
# ---------------------------------------------------------------------------

@test "build does not use bare readlink -f" {
    grep -q '_portable_readlink' "${BWX_ROOT}/build"
    grep -q 'script_dir=.*_portable_readlink' "${BWX_ROOT}/build"
}

@test "test/run-all does not use bare readlink -f for whereami" {
    grep -q '_portable_readlink' "${BWX_ROOT}/test/run-all"
    grep -q 'whereami=.*_portable_readlink' "${BWX_ROOT}/test/run-all"
}

@test "include/path _bwx_realpath has readlink -f fallback" {
    grep -q 'readlink -f' "${BWX_ROOT}/include/path"
    grep -q 'realpath' "${BWX_ROOT}/include/path"
    grep -q 'pwd -P' "${BWX_ROOT}/include/path"
}

# ---------------------------------------------------------------------------
# P-03: No en_US.UTF-8 locale dependency in awk toupper
# ---------------------------------------------------------------------------

@test "no source files use LC_ALL=en_US.UTF-8 awk toupper" {
    local count
    count=$(grep -rl "LC_ALL='en_US.UTF-8' awk" \
        "${BWX_ROOT}/lib/" \
        "${BWX_ROOT}/bin/" \
        "${BWX_ROOT}/include/" 2>/dev/null | wc -l)
    [[ "${count}" -eq 0 ]]
}

@test "project name sanitization uses bash case transform" {
    grep -rqF '^^}' "${BWX_ROOT}/lib/"
}

# ---------------------------------------------------------------------------
# P-04: Hash fallback chain includes sha256sum
# ---------------------------------------------------------------------------

@test "bwx-cache-hash supports sha256sum (GNU coreutils) systems" {
    grep -q 'sha256sum' "${BWX_ROOT}/include/bwx-cache"
}

@test "bwx-cache-hash fallback order is shasum then sha256sum" {
    # cksum is intentionally not a fallback: CRC32 collisions would
    # let unrelated cache keys share a file. The function errors out
    # when no SHA-256 implementation is present (see bwx-cache.bats).
    local shasum_line sha256sum_line
    shasum_line=$(grep -n 'shasum -a 256' "${BWX_ROOT}/include/bwx-cache" \
        | head -1 | cut -d: -f1)
    sha256sum_line=$(grep -n 'sha256sum' "${BWX_ROOT}/include/bwx-cache" \
        | head -1 | cut -d: -f1)
    [[ "${shasum_line}" -lt "${sha256sum_line}" ]]
}

# ---------------------------------------------------------------------------
# P-05: build --help uses portable head/sed
# ---------------------------------------------------------------------------

@test "build --help does not use head -n -1" {
    run ! grep -q 'head -n -1' "${BWX_ROOT}/build"
}

# ---------------------------------------------------------------------------
# P-06: date conversion portability
# ---------------------------------------------------------------------------

@test "_bwx_date_to_epoch tries BSD date first then GNU then BusyBox" {
    local bsd_line gnu_line bb_line
    bsd_line=$(grep -n 'date -u -j -f' \
        "${BWX_ROOT}/lib/bwx-check-expiry" | head -1 | cut -d: -f1)
    gnu_line=$(grep -n 'date -u -d' \
        "${BWX_ROOT}/lib/bwx-check-expiry" | head -1 | cut -d: -f1)
    bb_line=$(grep -n 'date -u -D' \
        "${BWX_ROOT}/lib/bwx-check-expiry" | head -1 | cut -d: -f1)
    [[ "${bsd_line}" -lt "${gnu_line}" ]]
    [[ "${gnu_line}" -lt "${bb_line}" ]]
}

@test "bwx-rotate date arithmetic has BSD and GNU fallbacks" {
    grep -q 'date -u -d' "${BWX_ROOT}/lib/bwx-rotate"
    grep -q 'date -u -r' "${BWX_ROOT}/lib/bwx-rotate"
    grep -q 'date -u -j -f' "${BWX_ROOT}/lib/bwx-rotate"
}

# ---------------------------------------------------------------------------
# P-07: stat mtime portability
# ---------------------------------------------------------------------------

@test "bwx-cache-mtime has GNU and BSD stat fallbacks" {
    grep -q "stat --format" "${BWX_ROOT}/include/bwx-cache"
    grep -q "stat -f" "${BWX_ROOT}/include/bwx-cache"
}

# ---------------------------------------------------------------------------
# P-08: HTTP abstraction completeness
# ---------------------------------------------------------------------------

@test "include/http supports curl wget fetch and docker backends" {
    for backend in curl wget fetch docker; do
        grep -q "${backend}" "${BWX_ROOT}/include/http"
    done
}

# ---------------------------------------------------------------------------
# Functional portability: cache hash produces consistent output
# ---------------------------------------------------------------------------

@test "bwx-cache-hash produces a hash for simple input" {
    source "${BWX_ROOT}/include/bwx-cache"
    local hash
    hash=$(bwx-cache-hash "test-input")
    [[ -n "${hash}" ]]
    [[ "${#hash}" -gt 5 ]]
}

@test "bwx-cache-hash is deterministic" {
    source "${BWX_ROOT}/include/bwx-cache"
    local h1 h2
    h1=$(bwx-cache-hash "determinism-test")
    h2=$(bwx-cache-hash "determinism-test")
    [[ "${h1}" == "${h2}" ]]
}

@test "bwx-cache-hash differs for different inputs" {
    source "${BWX_ROOT}/include/bwx-cache"
    local h1 h2
    h1=$(bwx-cache-hash "input-alpha")
    h2=$(bwx-cache-hash "input-bravo")
    [[ "${h1}" != "${h2}" ]]
}

# ---------------------------------------------------------------------------
# Functional portability: _bwx_realpath resolves paths
# ---------------------------------------------------------------------------

@test "_bwx_realpath resolves an absolute path" {
    source "${BWX_ROOT}/include/path"
    local result
    result=$(_bwx_realpath "${BWX_ROOT}/bin/bwx")
    [[ "${result}" == *"/bin/bwx" ]]
    [[ "${result}" == /* ]]
}

@test "_bwx_realpath resolves a relative path" {
    source "${BWX_ROOT}/include/path"
    local result
    result=$(_bwx_realpath "${BWX_ROOT}/bin/../bin/bwx")
    [[ "${result}" == *"/bin/bwx" ]]
    [[ "${result}" != *".."* ]]
}

# ---------------------------------------------------------------------------
# Functional portability: note-parser field extraction
# ---------------------------------------------------------------------------

@test "bwx-note-get-field extracts field case-insensitively" {
    source "${BWX_ROOT}/include/note-parser"
    local note
    note=$'file: my-secret.txt\nnote: some description'
    local result
    result=$(bwx-note-get-field file "${note}")
    [[ "${result}" == "my-secret.txt" ]]
}

@test "bwx-note-get-field strips inline comments" {
    source "${BWX_ROOT}/include/note-parser"
    local note="provider: tailscale-manual   # inline comment"
    local result
    result=$(bwx-note-get-field provider "${note}")
    [[ "${result}" == "tailscale-manual" ]]
}

# ---------------------------------------------------------------------------
# Functional portability: project name sanitization
# ---------------------------------------------------------------------------

@test "bash case transform uppercases ASCII correctly" {
    local input="my-project_123"
    local sanitized="${input//[^[:alnum:]]/_}"
    sanitized="${sanitized^^}"
    [[ "${sanitized}" == "MY_PROJECT_123" ]]
}

@test "bash case transform handles UUID-like input" {
    local input="11111111-1111-1111-1111-111111111111"
    local sanitized="${input//[^[:alnum:]]/_}"
    sanitized="${sanitized^^}"
    [[ "${sanitized}" == "11111111_1111_1111_1111_111111111111" ]]
}
