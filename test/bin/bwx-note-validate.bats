#!/usr/bin/env bats
# shellcheck shell=bash
# Tests for bwx note validate — core field and provider config validation.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    source "${BWX_ROOT}/test/bin/helpers.bash"
    bwx_test_setup
}

teardown() {
    bwx_test_teardown
}

# ── _bwx_validate_credential_syntax unit tests ──────────────────

@test "credential syntax: accepts secrets-dir file path reference" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "./.secrets/password" "test"
    '
    [[ "${status}" -eq 0 ]]
}

@test "credential syntax: rejects absolute path reference" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "/etc/secrets/key" "test"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"outside secrets directory"* ]]
}

@test "credential syntax: rejects relative path outside secrets directory" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "./tmp/password" "test"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"outside secrets directory"* ]]
}

@test "credential syntax: accepts env var reference" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "@env:MY_SECRET" "test"
    '
    [[ "${status}" -eq 0 ]]
}

@test "credential syntax: accepts project:secret reference" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "my-project:admin-pass" "test"
    '
    [[ "${status}" -eq 0 ]]
}

@test "credential syntax: accepts literal value" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "plain-literal" "test"
    '
    [[ "${status}" -eq 0 ]]
}

@test "credential syntax: rejects empty reference" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "" "test"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"empty credential reference"* ]]
}

@test "credential syntax: rejects invalid env var name" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "@env:invalid-name" "test"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"invalid env var name"* ]]
}

@test "credential syntax: rejects shell metachar in project" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "\$(evil):secret" "test"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

@test "credential syntax: rejects shell metachar in literal" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax "hello\`world\`" "test"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

@test "credential syntax: rejects empty project in project:secret" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_credential_syntax ":secret" "test"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"both project and secret required"* ]]
}

# ── _bwx_validate_provider_field unit tests ──────────────────────

@test "provider field: string type passes clean value" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "my-url" "default" "string" \
            "my-url: http://localhost:3000"
    '
    [[ "${status}" -eq 0 ]]
}

@test "provider field: string type rejects metachar" {
    printf '%s\n' 'my-url: http://evil$(cmd)' > "${TEST_TMPDIR}/note"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        note=$(<"'"${TEST_TMPDIR}/note"'")
        _bwx_validate_provider_field "my-url" "default" "string" "${note}"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"shell metacharacter"* ]]
}

@test "provider field: integer type passes valid number" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "port" "3000" "integer" \
            "port: 8080"
    '
    [[ "${status}" -eq 0 ]]
}

@test "provider field: integer type rejects non-numeric" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "port" "3000" "integer" \
            "port: abc"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"expected integer"* ]]
}

@test "provider field: integer range rejects out-of-bounds" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "length" "32" "integer:8:256" \
            "length: 4"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"outside range"* ]]
}

@test "provider field: integer range passes in-bounds" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "length" "32" "integer:8:256" \
            "length: 64"
    '
    [[ "${status}" -eq 0 ]]
}

@test "provider field: enum type passes valid value" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "role" "cert" "enum:cert|key" \
            "role: key"
    '
    [[ "${status}" -eq 0 ]]
}

@test "provider field: enum type rejects invalid value" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "role" "cert" "enum:cert|key" \
            "role: both"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"expected one of"* ]]
}

@test "provider field: credential type validates syntax" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "admin-pass" "" "credential" \
            "admin-pass: my-project:admin-password"
    '
    [[ "${status}" -eq 0 ]]
}

@test "provider field: required field missing returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "required-field" "" "string" \
            "other-field: value"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"required provider field missing"* ]]
}

@test "provider field: optional absent field passes" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        _bwx_validate_provider_field "optional-field" "default-val" \
            "string" "other-field: value"
    '
    [[ "${status}" -eq 0 ]]
}

# ── bwx note validate CLI — valid notes ──────────────────────────

@test "note validate: passes for valid provider note" {
    run "${BWX}" note validate secret_rotatable_v1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Note validation passed"* ]]
}

@test "note validate: passes for note with tags and expiry" {
    run "${BWX}" note validate secret_expiring_v1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Note validation passed"* ]]
}

@test "note validate: passes for note with file and tags" {
    run "${BWX}" note validate secret_key_3
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Note validation passed"* ]]
}

@test "note validate: empty note passes" {
    run "${BWX}" note validate secret_key_1
    [[ "${status}" -eq 0 ]]
}

@test "note validate: quiet mode suppresses success message" {
    run "${BWX}" note validate --quiet secret_rotatable_v1
    [[ "${status}" -eq 0 ]]
    [[ "${output}" != *"Note validation passed"* ]]
}

# ── bwx note validate CLI — core field errors ────────────────────

@test "note validate: detects bad file path via sourced note" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() { printf "file: ../escape\nnote: bad path"; }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"file: invalid path"* ]]
    [[ "${output}" == *"1 validation error"* ]]
}

@test "note validate: detects bad expires date" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() { printf "expires: not-a-date"; }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"expires: invalid date"* ]]
}

@test "note validate: detects bad provider identifier" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() { printf "provider: bad name!"; }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"provider: invalid identifier"* ]]
}

@test "note validate: detects bad release-tag" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() { printf "release-tag: bad tag!"; }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"release-tag: invalid identifier"* ]]
}

@test "note validate: accumulates multiple core errors" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "file: ../bad\nexpires: nope\nrelease-tag: bad!"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"file: invalid path"* ]]
    [[ "${output}" == *"expires: invalid date"* ]]
    [[ "${output}" == *"release-tag: invalid identifier"* ]]
    [[ "${output}" == *"3 validation error"* ]]
}

# ── bwx note validate CLI — provider config errors ───────────────

@test "note validate: detects unknown provider" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "provider: nonexistent-provider"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"unknown provider"* ]]
}

@test "note validate: detects missing required provider field" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "provider: grafana-service-account\ngrafana-url: http://localhost:3000"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"grafana-sa-id: required provider field missing"* ]]
}

@test "note validate: detects password-length out of range" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "provider: password-generate\npassword-length: 4"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"outside range"* ]]
}

@test "note validate: detects invalid enum value" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "provider: password-generate\npassword-charset: hex"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"expected one of"* ]]
}

@test "note validate: --provider overrides note provider" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "provider: prompt\npassword-length: 32"
        }
        bwx-note-validate --provider password-generate "test-secret"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Note validation passed"* ]]
}

@test "note validate: --provider adds validation to untyped note" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "file: my-secret"
        }
        bwx-note-validate --provider grafana-service-account "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"grafana-sa-id: required provider field missing"* ]]
}

# ── bwx note validate CLI — field-naming convention ──────────────

@test "note validate: rejects unhyphenated non-core field" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "file: test\nrole: admin"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"role: unhyphenated field name is reserved"* ]]
}

@test "note validate: accepts core fields without hyphen" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "file: test\nnote: hello\nexpires: 2026-12-31\nprovider: prompt"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Note validation passed"* ]]
}

@test "note validate: accepts hyphenated provider fields" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "file: test\ncustom-owner: ops-team\napp-env: production"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Note validation passed"* ]]
}

@test "note validate: naming error accumulates with other errors" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/bwx-note-validate"
        bwx-secret-get() {
            printf "file: ../bad\nowner: ops\nexpires: nope"
        }
        bwx-note-validate "test-secret"
    '
    [[ "${status}" -eq 1 ]]
    [[ "${output}" == *"owner: unhyphenated field name"* ]]
    [[ "${output}" == *"file: invalid path"* ]]
    [[ "${output}" == *"expires: invalid date"* ]]
    [[ "${output}" == *"3 validation error"* ]]
}

# ── bwx note validate CLI — option handling ──────────────────────

@test "note validate: no argument returns usage error" {
    run "${BWX}" note validate
    [[ "${status}" -eq 2 ]]
}

@test "note validate: --help returns usage" {
    run "${BWX}" note validate --help
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"Usage:"* ]]
}

@test "note validate: unknown option returns error" {
    run "${BWX}" note validate --bogus secret
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"Unknown option"* ]]
}

@test "note validate: --provider without value returns error" {
    run "${BWX}" note validate --provider
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"--provider requires a value"* ]]
}

# ── dispatch ─────────────────────────────────────────────────────

@test "note validate: dispatch table routes correctly" {
    run "${BWX}" note validate secret_rotatable_v1
    [[ "${status}" -eq 0 ]]
}

@test "unknown note subcommand shows valid commands" {
    run "${BWX}" note bogus
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"unknown command: bogus"* ]]
    [[ "${output}" == *"validate"* ]]
}
