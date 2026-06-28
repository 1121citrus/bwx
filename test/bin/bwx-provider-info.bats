#!/usr/bin/env bats
# shellcheck shell=bash
# Tests for bwx provider info and _bwx_provider_fields.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    source "${BWX_ROOT}/test/bin/helpers.bash"
    bwx_test_setup
}

teardown() {
    bwx_test_teardown
}

# ── _bwx_provider_fields unit tests ──────────────────────────────

@test "provider-fields: extracts password-generate fields" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        _bwx_provider_fields "password-generate" \
            | while IFS=$'"'"'\x1f'"'"' read -r f d t; do
                printf "%s|%s|%s\n" "${f}" "${d}" "${t}"
            done
    '
    [[ "${status}" -eq 0 ]]
    [[ "${lines[0]}" == "password-length|32|integer:8:256" ]]
    [[ "${lines[1]}" == "password-charset|alphanumeric+symbols|enum:alphanumeric|alphanumeric+symbols" ]]
}

@test "provider-fields: extracts openssl-selfsigned fields" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        _bwx_provider_fields "openssl-selfsigned" \
            | while IFS=$'"'"'\x1f'"'"' read -r f d t; do
                printf "%s|%s|%s\n" "${f}" "${d}" "${t}"
            done
    '
    [[ "${status}" -eq 0 ]]
    [[ "${lines[0]}" == "cert-role|cert|enum:cert|key" ]]
    [[ "${lines[1]}" == "cert-cn|bwx-selfsigned|string" ]]
    [[ "${lines[2]}" == "cert-days|365|integer:1:3650" ]]
}

@test "provider-fields: marks required fields with empty default" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        _bwx_provider_fields "grafana-service-account" \
            | while IFS=$'"'"'\x1f'"'"' read -r f d t; do
                printf "%s|%s|%s\n" "${f}" "${d}" "${t}"
            done
    '
    [[ "${status}" -eq 0 ]]
    [[ "${lines[0]}" == "grafana-url|http://localhost:3000|string" ]]
    [[ "${lines[1]}" == "grafana-sa-id||integer" ]]
    [[ "${lines[4]}" == "grafana-admin-password||credential" ]]
}

@test "provider-fields: extracts credential-only providers" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        _bwx_provider_fields "bitwarden-api-key" \
            | while IFS=$'"'"'\x1f'"'"' read -r f d t; do
                printf "%s|%s|%s\n" "${f}" "${d}" "${t}"
            done
    '
    [[ "${status}" -eq 0 ]]
    [[ "${lines[0]}" == "bitwarden-org-id||credential" ]]
    [[ "${lines[1]}" == "bitwarden-machine-account-id||credential" ]]
}

@test "provider-fields: returns empty for prompt provider" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        result="$(_bwx_provider_fields "prompt")"
        printf "<%s>" "${result}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "<>" ]]
}

@test "provider-fields: returns 1 for nonexistent provider" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        _bwx_provider_fields "does-not-exist"
    '
    [[ "${status}" -eq 1 ]]
}

# ── bwx provider info CLI tests ─────────────────────────────────

@test "provider info: shows password-generate fields" {
    run "${BWX}" provider info password-generate
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Provider: password-generate"* ]]
    [[ "${output}" == *"Type: automated"* ]]
    [[ "${output}" == *"password-length"* ]]
    [[ "${output}" == *"integer:8:256"* ]]
    [[ "${output}" == *"32"* ]]
    [[ "${output}" == *"password-charset"* ]]
    [[ "${output}" == *"enum:alphanumeric|alphanumeric+symbols"* ]]
}

@test "provider info: shows required fields as (required)" {
    run "${BWX}" provider info grafana-service-account
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"grafana-sa-id"* ]]
    [[ "${output}" == *"(required)"* ]]
}

@test "provider info: detects interactive providers" {
    run "${BWX}" provider info prompt
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Type: interactive"* ]]
    [[ "${output}" == *"No configurable note fields"* ]]
}

@test "provider info: detects automated providers" {
    run "${BWX}" provider info password-generate
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Type: automated"* ]]
}

@test "provider info: github-pat is interactive" {
    run "${BWX}" provider info github-pat
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Type: interactive"* ]]
}

@test "provider info: --list shows all providers" {
    run "${BWX}" provider info --list
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"password-generate"* ]]
    [[ "${output}" == *"grafana-service-account"* ]]
    [[ "${output}" == *"prompt"* ]]
    [[ "${output}" == *"docker-registry"* ]]
    [[ "${output}" == *"openssl-selfsigned"* ]]
}

@test "provider info: --list output is one name per line" {
    run "${BWX}" provider info --list
    [[ "${status}" -eq 0 ]]
    local count
    count=$(printf '%s\n' "${output}" | wc -l)
    [[ "${count}" -ge 13 ]]
}

@test "provider info: unknown provider returns error" {
    run "${BWX}" provider info nonexistent-provider
    [[ "${status}" -eq 4 ]]
    [[ "${output}" == *"unknown provider"* ]]
}

@test "provider info: invalid provider name returns error" {
    run "${BWX}" provider info "../escape"
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"invalid provider name"* ]]
}

@test "provider info: no argument returns usage error" {
    run "${BWX}" provider info
    [[ "${status}" -eq 2 ]]
}

@test "provider info: --help returns usage" {
    run "${BWX}" provider info --help
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"Usage:"* ]]
}

@test "provider info: docker-registry shows credential fields" {
    run "${BWX}" provider info docker-registry
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"docker-token-label"* ]]
    [[ "${output}" == *"docker-hub-username"* ]]
    [[ "${output}" == *"credential"* ]]
}

@test "provider info: openssl-selfsigned shows enum and range" {
    run "${BWX}" provider info openssl-selfsigned
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"cert-role"* ]]
    [[ "${output}" == *"enum:cert|key"* ]]
    [[ "${output}" == *"cert-days"* ]]
    [[ "${output}" == *"integer:1:3650"* ]]
}

# ── dispatch and completion ──────────────────────────────────────

@test "provider info: dispatch table routes correctly" {
    run "${BWX}" provider info password-generate
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Provider: password-generate"* ]]
}

@test "unknown provider subcommand shows valid commands" {
    run "${BWX}" provider bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"unknown command: bogus"* ]]
    [[ "${output}" == *"info"* ]]
}
