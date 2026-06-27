#!/usr/bin/env bats
# Docker-based cross-environment portability tests for bwx.
#
# Spins up real containers to validate bwx behavior across different
# Linux distributions and tool chains.  Each test is self-contained:
# it mounts the bwx source tree read-only and runs commands inside
# the container.
#
# Requirements:
#   - Docker daemon running
#   - Network access for image pulls (first run only)
#
# These tests are slower than unit tests (~5-15s each) but catch
# real-world portability regressions that static analysis misses.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    if ! docker info >/dev/null 2>&1; then
        skip "Docker not available"
    fi
}

# ---------------------------------------------------------------------------
# Helper: run a command inside a container with bwx mounted
# ---------------------------------------------------------------------------

_docker_run() {
    local image="$1"; shift
    docker run --rm \
        -v "${BWX_ROOT}:/bwx:ro" \
        -w /bwx \
        "${image}" \
        "$@"
}

# ===================================================================
# Alpine (BusyBox coreutils, ash + bash)
# ===================================================================

@test "alpine: bwx --help succeeds" {
    run _docker_run alpine:3.20 sh -c \
        'apk add --quiet --no-cache bash >/dev/null 2>&1 && bash bin/bwx --help'
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Bitwarden Secrets Manager"* ]]
}

@test "alpine: bwx --version succeeds" {
    run _docker_run alpine:3.20 sh -c \
        'apk add --quiet --no-cache bash >/dev/null 2>&1 && bash bin/bwx --version'
    [[ "${status}" -eq 0 ]]
    [[ "${output}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "alpine: bwx completion bash produces valid output" {
    run _docker_run alpine:3.20 sh -c \
        'apk add --quiet --no-cache bash >/dev/null 2>&1 && bash bin/bwx completion bash'
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"complete -F"* ]]
}

@test "alpine: cache hash works with sha256sum (no shasum)" {
    run _docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash coreutils >/dev/null 2>&1
        bash -c "
            source /bwx/include/bwx-cache
            h=\$(bwx-cache-hash test-alpine)
            [[ -n \"\${h}\" ]] && echo \"hash=\${h}\"
        "
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"hash="* ]]
}

@test "alpine: _bwx_realpath resolves paths without GNU readlink" {
    run _docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash >/dev/null 2>&1
        bash -c "
            source /bwx/include/path
            result=\$(_bwx_realpath /bwx/bin/bwx)
            [[ \"\${result}\" == */bin/bwx ]] && echo OK
        "
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}

@test "alpine: _bwx_date_to_epoch converts date via BusyBox date" {
    run _docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash >/dev/null 2>&1
        bash -c "
            source /bwx/include/logging
            source /bwx/lib/bwx-check-expiry
            epoch=\$(_bwx_date_to_epoch 2026-01-15)
            [[ \"\${epoch}\" =~ ^[0-9]+$ ]] && echo \"epoch=\${epoch}\"
        "
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"epoch="* ]]
}

@test "alpine: note-parser extracts fields without GNU grep" {
    run _docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash >/dev/null 2>&1
        bash -c "
            source /bwx/include/note-parser
            note=\"file: my-file
provider: tailscale-manual   # comment
release-tag: v1.0\"
            f=\$(bwx-note-get-field file \"\${note}\")
            p=\$(bwx-note-get-field provider \"\${note}\")
            [[ \"\${f}\" == \"my-file\" ]] && \
            [[ \"\${p}\" == \"tailscale-manual\" ]] && \
            echo OK
        "
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}

@test "alpine: bwx-cache-mtime works with BusyBox stat" {
    run _docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash >/dev/null 2>&1
        bash -c "
            source /bwx/include/bwx-cache
            tmpf=\$(mktemp)
            mtime=\$(bwx-cache-mtime \"\${tmpf}\")
            rm -f \"\${tmpf}\"
            [[ \"\${mtime}\" =~ ^[0-9]+$ ]] && echo \"mtime=\${mtime}\"
        "
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"mtime="* ]]
}

# ===================================================================
# Debian (GNU coreutils, GNU date, GNU sed)
# ===================================================================

@test "debian: bwx --help succeeds" {
    run _docker_run debian:bookworm-slim sh -c \
        'bash /bwx/bin/bwx --help'
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Bitwarden Secrets Manager"* ]]
}

@test "debian: bwx --version succeeds" {
    run _docker_run debian:bookworm-slim sh -c \
        'bash /bwx/bin/bwx --version'
    [[ "${status}" -eq 0 ]]
    [[ "${output}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "debian: cache hash works with sha256sum (no shasum)" {
    run _docker_run debian:bookworm-slim bash -c '
        source /bwx/include/bwx-cache
        h=$(bwx-cache-hash test-debian)
        [[ -n "${h}" ]] && echo "hash=${h}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"hash="* ]]
}

@test "debian: _bwx_date_to_epoch converts date via GNU date" {
    run _docker_run debian:bookworm-slim bash -c '
        source /bwx/include/logging
        source /bwx/lib/bwx-check-expiry
        epoch=$(_bwx_date_to_epoch 2026-06-15)
        [[ "${epoch}" =~ ^[0-9]+$ ]] && echo "epoch=${epoch}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"epoch="* ]]
}

@test "debian: bwx-cache-mtime works with GNU stat" {
    run _docker_run debian:bookworm-slim bash -c '
        source /bwx/include/bwx-cache
        tmpf=$(mktemp)
        mtime=$(bwx-cache-mtime "${tmpf}")
        rm -f "${tmpf}"
        [[ "${mtime}" =~ ^[0-9]+$ ]] && echo "mtime=${mtime}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"mtime="* ]]
}

@test "debian: _bwx_realpath resolves paths with GNU readlink" {
    run _docker_run debian:bookworm-slim bash -c '
        source /bwx/include/path
        result=$(_bwx_realpath /bwx/bin/bwx)
        [[ "${result}" == */bin/bwx ]] && echo OK
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}

@test "debian: project name sanitization uses bash case transform" {
    run _docker_run debian:bookworm-slim bash -c '
        input="my-project_123"
        sanitized="${input//[^[:alnum:]]/_}"
        sanitized="${sanitized^^}"
        [[ "${sanitized}" == "MY_PROJECT_123" ]] && echo OK
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}

# ===================================================================
# Ubuntu (CI runner environment)
# ===================================================================

@test "ubuntu: bwx --help succeeds" {
    run _docker_run ubuntu:24.04 bash /bwx/bin/bwx --help
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Bitwarden Secrets Manager"* ]]
}

@test "ubuntu: full dispatch test with mock bws" {
    run _docker_run ubuntu:24.04 bash -c '
        apt-get update -qq >/dev/null 2>&1
        apt-get install -qq -y jq >/dev/null 2>&1
        export PATH="/bwx/test/fixtures:${PATH}"
        export BWS_ACCESS_TOKEN=test-token
        export BWX_DEFAULT_PROJECT=test-project
        export CITRUS_ENABLE_MOCK_COMMANDS=true
        export BWX_SECRET_LIST_CACHE_TTL_SECONDS=0
        bash /bwx/bin/bwx --version
        bash /bwx/bin/bwx completion bash | grep -q "complete -F" && echo OK
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}

# ===================================================================
# Amazon Linux 2023 (RHEL-family, no shasum by default)
# ===================================================================

@test "al2023: bwx --help succeeds" {
    run _docker_run amazonlinux:2023 bash /bwx/bin/bwx --help
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Bitwarden Secrets Manager"* ]]
}

@test "al2023: cache hash works with sha256sum" {
    run _docker_run amazonlinux:2023 bash -c '
        source /bwx/include/bwx-cache
        h=$(bwx-cache-hash test-al2023)
        [[ -n "${h}" ]] && echo "hash=${h}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"hash="* ]]
}

@test "al2023: _bwx_date_to_epoch converts date" {
    run _docker_run amazonlinux:2023 bash -c '
        source /bwx/include/logging
        source /bwx/lib/bwx-check-expiry
        epoch=$(_bwx_date_to_epoch 2026-03-01)
        [[ "${epoch}" =~ ^[0-9]+$ ]] && echo "epoch=${epoch}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"epoch="* ]]
}

# ===================================================================
# Cross-environment hash consistency
# ===================================================================

@test "cache hash produces identical output on alpine and debian" {
    local alpine_hash debian_hash
    alpine_hash=$(_docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash coreutils >/dev/null 2>&1
        bash -c "source /bwx/include/bwx-cache && bwx-cache-hash cross-env-test"
    ')
    debian_hash=$(_docker_run debian:bookworm-slim bash -c '
        source /bwx/include/bwx-cache && bwx-cache-hash cross-env-test
    ')
    [[ -n "${alpine_hash}" ]]
    [[ "${alpine_hash}" == "${debian_hash}" ]]
}

@test "date epoch conversion produces same result on alpine and debian" {
    local alpine_epoch debian_epoch
    alpine_epoch=$(_docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash >/dev/null 2>&1
        bash -c "
            source /bwx/include/logging
            source /bwx/lib/bwx-check-expiry
            _bwx_date_to_epoch 2026-01-01
        "
    ')
    debian_epoch=$(_docker_run debian:bookworm-slim bash -c '
        source /bwx/include/logging
        source /bwx/lib/bwx-check-expiry
        _bwx_date_to_epoch 2026-01-01
    ')
    [[ -n "${alpine_epoch}" ]]
    [[ "${alpine_epoch}" == "${debian_epoch}" ]]
}

# ===================================================================
# Minimal environment: no jq, no curl, no wget
# ===================================================================

@test "alpine-minimal: bwx --help works without jq" {
    run _docker_run alpine:3.20 sh -c \
        'apk add --quiet --no-cache bash >/dev/null 2>&1 && bash /bwx/bin/bwx --help'
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Usage:"* ]]
}

@test "alpine-minimal: http resolution fails gracefully with no tools" {
    run _docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash >/dev/null 2>&1
        bash -c "
            source /bwx/include/http
            _HTTP_BACKEND=\"\"
            PATH=/nonexistent _http_resolve
        "
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"No HTTP client available"* ]]
}

# ===================================================================
# Locale-free environment
# ===================================================================

@test "alpine: case transform works without en_US.UTF-8 locale" {
    run _docker_run alpine:3.20 sh -c '
        apk add --quiet --no-cache bash >/dev/null 2>&1
        bash -c "
            # Alpine has no en_US.UTF-8 locale installed
            locale -a 2>/dev/null | grep -q en_US.UTF-8 && exit 99
            input=\"my-project_test\"
            sanitized=\"\${input//[^[:alnum:]]/_}\"
            sanitized=\"\${sanitized^^}\"
            [[ \"\${sanitized}\" == \"MY_PROJECT_TEST\" ]] && echo OK
        "
    '
    # status 99 means locale exists (skip); 0 means test ran
    if [[ "${status}" -eq 99 ]]; then
        skip "en_US.UTF-8 unexpectedly available on Alpine"
    fi
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}
