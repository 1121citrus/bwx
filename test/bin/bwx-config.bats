#!/usr/bin/env bats
# shellcheck shell=bash
# Unit tests for include/bwx-config and the 'bwx config' command family.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
BWX="${BWX_ROOT}/bin/bwx"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export BWX_CONFIG_DIR="${TEST_TMPDIR}/config"

    # The suite must never resolve to a developer's real credentials.
    unset BWS_ACCESS_TOKEN BWX_DEFAULT_PROJECT || true

    source "${BWX_ROOT}/include/logging"
    source "${BWX_ROOT}/include/bwx-config"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# Write a config file directly, bypassing bwx-config-write, so that
# permission handling can be tested independently of the writer.
# Args:
#   $1 — configuration name
#   $2 — value
#   $3 — octal mode
_store() {
    mkdir -p "${BWX_CONFIG_DIR}"
    printf '%s\n' "${2}" > "${BWX_CONFIG_DIR}/${1}"
    chmod "${3}" "${BWX_CONFIG_DIR}/${1}"
}

_mode_of() {
    stat -c '%a' "${1}" 2>/dev/null || stat -f '%Lp' "${1}" 2>/dev/null
}

# ── bwx-config-dir ──────────────────────────────────────────────────

@test "config-dir returns BWX_CONFIG_DIR when set" {
    [[ "$(bwx-config-dir)" == "${TEST_TMPDIR}/config" ]]
}

@test "config-dir does not create the directory" {
    bwx-config-dir >/dev/null
    [[ ! -d "${BWX_CONFIG_DIR}" ]]
}

@test "config-dir honors XDG_CONFIG_HOME when BWX_CONFIG_DIR is unset" {
    unset BWX_CONFIG_DIR
    export XDG_CONFIG_HOME="${TEST_TMPDIR}/xdg"
    [[ "$(bwx-config-dir)" == "${TEST_TMPDIR}/xdg/bwx" ]]
}

@test "config-dir falls back to HOME/.config/bwx" {
    unset BWX_CONFIG_DIR XDG_CONFIG_HOME
    export HOME="${TEST_TMPDIR}/home"
    [[ "$(bwx-config-dir)" == "${TEST_TMPDIR}/home/.config/bwx" ]]
}

@test "config-dir fails when no location can be determined" {
    unset BWX_CONFIG_DIR XDG_CONFIG_HOME HOME
    run bwx-config-dir
    [[ "${status}" -eq 1 ]]
}

# ── entry metadata ──────────────────────────────────────────────────

@test "every entry maps to a variable and a known class" {
    local name class variable
    while IFS= read -r name; do
        variable="$(bwx-config-entry-variable "${name}")"
        [[ -n "${variable}" ]]
        class="$(bwx-config-entry-class "${name}")"
        [[ "${class}" == "secret" || "${class}" == "plain" ]]
    done < <(bwx-config-names)
}

@test "entry lookups reject unknown names" {
    run bwx-config-entry-variable no-such-entry
    [[ "${status}" -eq 1 ]]
    run bwx-config-file no-such-entry
    [[ "${status}" -eq 1 ]]
}

@test "the access token is secret-class and the project is not" {
    [[ "$(bwx-config-entry-class bws-access-token)" == "secret" ]]
    [[ "$(bwx-config-entry-class bwx-default-project)" == "plain" ]]
}

# ── bwx-config-read ─────────────────────────────────────────────────

@test "read returns a stored value" {
    _store bws-access-token "0.token-value" 600
    [[ "$(bwx-config-read bws-access-token)" == "0.token-value" ]]
}

@test "read strips trailing newlines" {
    mkdir -p "${BWX_CONFIG_DIR}"
    printf '0.token-value\n\n\n' > "${BWX_CONFIG_DIR}/bws-access-token"
    chmod 600 "${BWX_CONFIG_DIR}/bws-access-token"
    [[ "$(bwx-config-read bws-access-token)" == "0.token-value" ]]
}

@test "read fails when nothing is stored" {
    run bwx-config-read bws-access-token
    [[ "${status}" -eq 1 ]]
}

# ── permission enforcement ──────────────────────────────────────────

@test "assert-mode accepts a 600 secret file" {
    _store bws-access-token "0.token-value" 600
    run bwx-config-assert-mode bws-access-token "${BWX_CONFIG_DIR}/bws-access-token"
    [[ "${status}" -eq 0 ]]
}

@test "assert-mode rejects a group-readable secret file" {
    _store bws-access-token "0.token-value" 640
    run bwx-config-assert-mode bws-access-token "${BWX_CONFIG_DIR}/bws-access-token"
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"accessible to other users"* ]]
    [[ "${output}" == *"chmod 600"* ]]
}

@test "assert-mode rejects a world-readable secret file" {
    _store bws-access-token "0.token-value" 644
    run bwx-config-assert-mode bws-access-token "${BWX_CONFIG_DIR}/bws-access-token"
    [[ "${status}" -eq 1 ]]
}

@test "assert-mode ignores permissions on plain entries" {
    _store bwx-default-project "project-uuid" 644
    run bwx-config-assert-mode bwx-default-project "${BWX_CONFIG_DIR}/bwx-default-project"
    [[ "${status}" -eq 0 ]]
}

@test "read refuses an over-permissive secret file" {
    _store bws-access-token "0.token-value" 644
    run bwx-config-read bws-access-token
    [[ "${status}" -eq 1 ]]
    [[ "${output}" != *"0.token-value"* ]]
}

# ── bwx-config-load precedence ──────────────────────────────────────

@test "load populates variables from files" {
    _store bws-access-token "0.from-file" 600
    _store bwx-default-project "project-from-file" 644
    bwx-config-load
    [[ "${BWS_ACCESS_TOKEN}" == "0.from-file" ]]
    [[ "${BWX_DEFAULT_PROJECT}" == "project-from-file" ]]
}

@test "load leaves an already-set variable untouched" {
    _store bws-access-token "0.from-file" 600
    export BWS_ACCESS_TOKEN="0.from-environment"
    bwx-config-load
    [[ "${BWS_ACCESS_TOKEN}" == "0.from-environment" ]]
}

@test "load does not mode-check a file it never reads" {
    # An over-permissive file is tolerated while the environment
    # supplies the value, because the file is never opened.
    _store bws-access-token "0.from-file" 644
    export BWS_ACCESS_TOKEN="0.from-environment"
    run bwx-config-load
    [[ "${status}" -eq 0 ]]
    [[ "${output}" != *"accessible to other users"* ]]
}

@test "load succeeds when no files are present" {
    run bwx-config-load
    [[ "${status}" -eq 0 ]]
}

@test "load runs only once per process" {
    _store bws-access-token "0.first" 600
    bwx-config-load
    _store bws-access-token "0.second" 600
    unset BWS_ACCESS_TOKEN
    bwx-config-load
    [[ -z "${BWS_ACCESS_TOKEN:-}" ]]
}

# ── bwx-config-source ───────────────────────────────────────────────

@test "source reports unset when nothing supplies a value" {
    [[ "$(bwx-config-source bws-access-token)" == "unset" ]]
}

@test "source reports file for a stored but unloaded value" {
    _store bws-access-token "0.from-file" 600
    [[ "$(bwx-config-source bws-access-token)" == "file" ]]
}

@test "source still reports file after loading exports the value" {
    _store bws-access-token "0.from-file" 600
    bwx-config-load
    [[ -n "${BWS_ACCESS_TOKEN}" ]]
    [[ "$(bwx-config-source bws-access-token)" == "file" ]]
}

@test "source reports environment for an exported value" {
    export BWS_ACCESS_TOKEN="0.from-environment"
    bwx-config-load
    [[ "$(bwx-config-source bws-access-token)" == "environment" ]]
}

# ── bwx-config-write ────────────────────────────────────────────────

@test "write stores a secret entry at 600 inside a 700 directory" {
    bwx-config-write bws-access-token "0.written"
    [[ "$(_mode_of "${BWX_CONFIG_DIR}/bws-access-token")" == "600" ]]
    [[ "$(_mode_of "${BWX_CONFIG_DIR}")" == "700" ]]
    [[ "$(bwx-config-read bws-access-token)" == "0.written" ]]
}

@test "write stores a plain entry at 644" {
    bwx-config-write bwx-default-project "project-uuid"
    [[ "$(_mode_of "${BWX_CONFIG_DIR}/bwx-default-project")" == "644" ]]
}

@test "write replaces an existing value and leaves no temporary files" {
    bwx-config-write bws-access-token "0.first"
    bwx-config-write bws-access-token "0.second"
    [[ "$(bwx-config-read bws-access-token)" == "0.second" ]]
    [[ "$(_mode_of "${BWX_CONFIG_DIR}/bws-access-token")" == "600" ]]
    run bash -c "ls -A '${BWX_CONFIG_DIR}' | grep -c '^\\.'"
    [[ "${output}" == "0" ]]
}

@test "write rejects an unknown name" {
    run bwx-config-write no-such-entry value
    [[ "${status}" -eq 1 ]]
}

# ── command family ──────────────────────────────────────────────────

@test "config set stores a value given as an argument" {
    run "${BWX}" config set bwx-default-project project-uuid
    [[ "${status}" -eq 0 ]]
    [[ "$(cat "${BWX_CONFIG_DIR}/bwx-default-project")" == "project-uuid" ]]
}

@test "config set reads the value from stdin when omitted" {
    run bash -c "printf '0.piped-token' | '${BWX}' config set bws-access-token"
    [[ "${status}" -eq 0 ]]
    [[ "$(cat "${BWX_CONFIG_DIR}/bws-access-token")" == "0.piped-token" ]]
    [[ "$(_mode_of "${BWX_CONFIG_DIR}/bws-access-token")" == "600" ]]
}

@test "config set refuses an empty value" {
    run bash -c "printf '' | '${BWX}' config set bws-access-token"
    [[ "${status}" -ne 0 ]]
}

@test "config set rejects an unknown name" {
    run "${BWX}" config set no-such-entry value
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Unknown configuration name"* ]]
}

@test "config get prints a stored value" {
    _store bwx-default-project "project-uuid" 644
    run "${BWX}" config get bwx-default-project
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "project-uuid" ]]
}

@test "config get reports a missing value as not found" {
    run "${BWX}" config get bwx-default-project
    [[ "${status}" -eq "${EXIT_NOTFOUND}" ]]
}

@test "config get refuses an over-permissive secret file" {
    _store bws-access-token "0.exposed" 644
    run "${BWX}" config get bws-access-token
    [[ "${status}" -ne 0 ]]
    [[ "${output}" != *"0.exposed"* ]]
}

@test "config path prints the directory and one file path" {
    run "${BWX}" config path
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "${BWX_CONFIG_DIR}" ]]

    run "${BWX}" config path bws-access-token
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "${BWX_CONFIG_DIR}/bws-access-token" ]]
}

@test "config path rejects an unknown name" {
    run "${BWX}" config path no-such-entry
    [[ "${status}" -ne 0 ]]
}

@test "config list reports the effective source without printing values" {
    _store bws-access-token "0.super-secret-value" 600
    run "${BWX}" config list
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"bws-access-token"* ]]
    [[ "${output}" == *"file"* ]]
    [[ "${output}" != *"0.super-secret-value"* ]]
}

@test "config list marks an environment override as effective" {
    _store bws-access-token "0.from-file" 600
    BWS_ACCESS_TOKEN="0.from-environment" run "${BWX}" config list
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"environment"* ]]
}

@test "config rejects an unknown subcommand and lists valid ones" {
    run "${BWX}" config bogus
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"get"* ]]
    [[ "${output}" == *"set"* ]]
}

# ── wiring ──────────────────────────────────────────────────────────

@test "bin/bwx loads configuration before dispatching" {
    local load_line dispatch_line
    load_line=$(grep -n 'bwx-config-load' "${BWX}" | tail -1 | cut -d: -f1)
    dispatch_line=$(grep -n '_bwx_dispatch "\$@"' "${BWX}" | tail -1 | cut -d: -f1)
    [[ -n "${load_line}" && -n "${dispatch_line}" ]]
    [[ "${load_line}" -lt "${dispatch_line}" ]]
}

@test "config mode detection uses busybox-safe stat spellings" {
    # '-c' covers GNU and busybox; '-f' covers BSD. The long
    # '--format' spelling must not appear: busybox rejects it and its
    # own '-f' reports filesystem status, which would read as success
    # and silently disable the permission check.
    grep -q "stat -c" "${BWX_ROOT}/include/bwx-config"
    grep -q "stat -f" "${BWX_ROOT}/include/bwx-config"
    ! grep -q "stat --format" "${BWX_ROOT}/include/bwx-config"
}
