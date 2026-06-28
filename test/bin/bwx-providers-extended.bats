#!/usr/bin/env bats
# shellcheck shell=bash
# Tests for extended rotation providers (lib/providers/*).
# Each test spawns a subprocess that opens the input file on fd 9 and
# exports BWX_TTY_FD=9 so the provider reads from the file, not /dev/tty.

bats_require_minimum_version 1.5.0

BWX_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ── password-generate provider ─────────────────────────────────────

@test "password-generate: generates 32-char password by default" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"32-char password"* ]]
}

@test "password-generate: respects password-length from note" {
    local note="password-length: 64"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE_LEN=64"* ]]
}

@test "password-generate: alphanumeric charset excludes symbols" {
    local note="password-charset: alphanumeric"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    local value
    value="$(echo "${output}" | grep '^VALUE=' | sed 's/^VALUE=//')"
    [[ "${value}" =~ ^[A-Za-z0-9]+$ ]]
}

@test "password-generate: rejects length below 8" {
    local note="password-length: 4"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"outside range"* ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
}

@test "password-generate: rejects length above 256" {
    local note="password-length: 512"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"outside range"* ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
}

@test "password-generate: rejects non-numeric length" {
    local note="password-length: abc"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"expected integer"* ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
}

@test "password-generate: warns on unknown charset" {
    local note="password-charset: hex"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"expected one of"* ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
}

@test "password-generate: explicit alphanumeric+symbols charset" {
    local note="password-charset: alphanumeric+symbols"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
}

@test "password-generate: no note uses all defaults" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/password-generate"
        bwx-provider-password-generate "test-secret"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
}

# ── aws-iam provider ──────────────────────────────────────────────

@test "aws-iam: missing aws CLI returns 1" {
    run bash -c '
        export PATH="/nonexistent"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        bwx-provider-aws-iam "test-secret" ".secrets" ""
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Neither aws CLI nor docker found"* ]]
}

@test "aws-iam: list-access-keys failure returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws() { echo "AccessDenied" >&2; return 1; }
        bwx-provider-aws-iam "test-secret" ".secrets" ""
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Failed to list access keys"* ]]
}

@test "aws-iam: create-access-key failure returns 1" {
    local call_log="${TEST_TMPDIR}/aws-calls"
    echo "0" > "${call_log}"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        call_log="'"${call_log}"'"
        aws() {
            local count
            count=$(<"${call_log}")
            count=$((count + 1))
            echo "${count}" > "${call_log}"
            if [[ "${count}" -eq 1 ]]; then
                echo "AKIAOLD123456"
                return 0
            fi
            echo "LimitExceeded"
            return 1
        }
        bwx-provider-aws-iam "test-secret" ".secrets" ""
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Failed to create access key"* ]]
}

@test "aws-iam: successful rotation sets globals" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws() {
            case "$*" in
                *list-access-keys*)
                    echo "AKIAOLD123456"
                    ;;
                *create-access-key*)
                    echo "{\"AccessKey\":{\"AccessKeyId\":\"AKIANEW789\",\"SecretAccessKey\":\"wJalrXUtnFEMI/SECRET\"}}"
                    ;;
                *update-access-key*)
                    return 0
                    ;;
            esac
            return 0
        }
        bwx-provider-aws-iam "test-secret" ".secrets" ""
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=wJalrXUtnFEMI/SECRET"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"AKIANEW789"* ]]
}

@test "aws-iam: handles no existing key gracefully" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        _call=0
        aws() {
            _call=$((_call + 1))
            case "$*" in
                *list-access-keys*)
                    echo "None"
                    ;;
                *create-access-key*)
                    echo "{\"AccessKey\":{\"AccessKeyId\":\"AKIANEW789\",\"SecretAccessKey\":\"newSecret\"}}"
                    ;;
            esac
            return 0
        }
        bwx-provider-aws-iam "test-secret" ".secrets" ""
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"No existing access key found"* ]]
    [[ "${output}" == *"VALUE=newSecret"* ]]
}

@test "aws-iam: note credentials inject into environment" {
    local aws_log="${TEST_TMPDIR}/aws-env"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws_log="'"${aws_log}"'"
        aws() {
            case "$*" in
                *list-access-keys*)
                    printf "KEY_ID=%s\n" "${AWS_ACCESS_KEY_ID}" \
                        >> "${aws_log}"
                    printf "SECRET=%s\n" "${AWS_SECRET_ACCESS_KEY}" \
                        >> "${aws_log}"
                    printf "REGION=%s\n" "${AWS_DEFAULT_REGION}" \
                        >> "${aws_log}"
                    echo "AKIAOLD123456"
                    ;;
                *create-access-key*)
                    echo "{\"AccessKey\":{\"AccessKeyId\":\"AKIANEW\",\"SecretAccessKey\":\"newSec\"}}"
                    ;;
                *update-access-key*)
                    return 0
                    ;;
            esac
            return 0
        }
        note="aws-access-key-id: AKIATEST123
aws-secret-access-key: testSecretKey456
aws-region: eu-west-1"
        bwx-provider-aws-iam "test-secret" ".secrets" "${note}"
    '
    [[ "${status}" -eq 0 ]]
    grep -q "KEY_ID=AKIATEST123" "${aws_log}"
    grep -q "SECRET=testSecretKey456" "${aws_log}"
    grep -q "REGION=eu-west-1" "${aws_log}"
}

@test "aws-iam: note username passes --user-name to aws CLI" {
    local aws_log="${TEST_TMPDIR}/aws-args"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws_log="'"${aws_log}"'"
        aws() {
            echo "$*" >> "${aws_log}"
            case "$*" in
                *list-access-keys*)
                    echo "None"
                    ;;
                *create-access-key*)
                    echo "{\"AccessKey\":{\"AccessKeyId\":\"AKIANEW\",\"SecretAccessKey\":\"s\"}}"
                    ;;
            esac
            return 0
        }
        note="aws-iam-username: backup-service"
        bwx-provider-aws-iam "test-secret" ".secrets" "${note}"
    '
    [[ "${status}" -eq 0 ]]
    grep -q -- "--user-name backup-service" "${aws_log}"
}

@test "aws-iam: defaults region to us-east-1 when absent" {
    local aws_log="${TEST_TMPDIR}/aws-env"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws_log="'"${aws_log}"'"
        aws() {
            printf "REGION=%s\n" "${AWS_DEFAULT_REGION}" \
                >> "${aws_log}"
            case "$*" in
                *list-access-keys*)
                    echo "None"
                    ;;
                *create-access-key*)
                    echo "{\"AccessKey\":{\"AccessKeyId\":\"AKIANEW\",\"SecretAccessKey\":\"s\"}}"
                    ;;
            esac
            return 0
        }
        bwx-provider-aws-iam "test-secret" ".secrets" ""
    '
    [[ "${status}" -eq 0 ]]
    grep -q "REGION=us-east-1" "${aws_log}"
}

@test "aws-iam: rejects only one of key-id/secret-key set" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws() { return 0; }
        note="aws-access-key-id: AKIATEST123"
        bwx-provider-aws-iam "test-secret" ".secrets" "${note}"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Both aws-access-key-id and aws-secret-access-key"* ]]
}

@test "aws-iam: credential fallback to secrets directory files" {
    mkdir -p "${TEST_TMPDIR}/secrets"
    echo -n "AKIAFILE123" > "${TEST_TMPDIR}/secrets/aws-access-key-id"
    echo -n "fileSecretKey" > "${TEST_TMPDIR}/secrets/aws-secret-access-key"
    local aws_log="${TEST_TMPDIR}/aws-env"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws_log="'"${aws_log}"'"
        aws() {
            printf "KEY_ID=%s\n" "${AWS_ACCESS_KEY_ID}" \
                >> "${aws_log}"
            printf "SECRET=%s\n" "${AWS_SECRET_ACCESS_KEY}" \
                >> "${aws_log}"
            case "$*" in
                *list-access-keys*)
                    echo "None"
                    ;;
                *create-access-key*)
                    echo "{\"AccessKey\":{\"AccessKeyId\":\"AKIANEW\",\"SecretAccessKey\":\"s\"}}"
                    ;;
            esac
            return 0
        }
        bwx-provider-aws-iam "test-secret" "'"${TEST_TMPDIR}/secrets"'" ""
    '
    [[ "${status}" -eq 0 ]]
    grep -q "KEY_ID=AKIAFILE123" "${aws_log}"
    grep -q "SECRET=fileSecretKey" "${aws_log}"
}

@test "aws-iam: env var credential reference resolves" {
    local aws_log="${TEST_TMPDIR}/aws-env"
    run bash -c '
        export MY_AWS_KEY="AKIAENV789"
        export MY_AWS_SECRET="envSecretKey"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/aws-iam"
        aws_log="'"${aws_log}"'"
        aws() {
            printf "KEY_ID=%s\n" "${AWS_ACCESS_KEY_ID}" \
                >> "${aws_log}"
            printf "SECRET=%s\n" "${AWS_SECRET_ACCESS_KEY}" \
                >> "${aws_log}"
            case "$*" in
                *list-access-keys*)
                    echo "None"
                    ;;
                *create-access-key*)
                    echo "{\"AccessKey\":{\"AccessKeyId\":\"AKIANEW\",\"SecretAccessKey\":\"s\"}}"
                    ;;
            esac
            return 0
        }
        note="aws-access-key-id: @env:MY_AWS_KEY
aws-secret-access-key: @env:MY_AWS_SECRET"
        bwx-provider-aws-iam "test-secret" ".secrets" "${note}"
    '
    [[ "${status}" -eq 0 ]]
    grep -q "KEY_ID=AKIAENV789" "${aws_log}"
    grep -q "SECRET=envSecretKey" "${aws_log}"
}

# ── openssl-selfsigned provider ────────────────────────────────────

@test "openssl-selfsigned: generates certificate by default" {
    command -v openssl >/dev/null 2>&1 || skip "openssl required"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/openssl-selfsigned"
        bwx-provider-openssl-selfsigned "test-cert" "'"${TEST_TMPDIR}"'"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
        echo "HAS_BEGIN=${PROVIDER_VALUE:+yes}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"Self-signed cert"* ]]
    [[ "${output}" == *"HAS_BEGIN=yes"* ]]
}

@test "openssl-selfsigned: cert role returns PEM certificate" {
    command -v openssl >/dev/null 2>&1 || skip "openssl required"
    local note="cert-role: cert"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/openssl-selfsigned"
        bwx-provider-openssl-selfsigned "test-cert" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        [[ "${PROVIDER_VALUE}" == *"-----BEGIN CERTIFICATE-----"* ]]
        echo "OK"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}

@test "openssl-selfsigned: key role returns PEM private key" {
    command -v openssl >/dev/null 2>&1 || skip "openssl required"
    local note="cert-role: key"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/openssl-selfsigned"
        bwx-provider-openssl-selfsigned "test-key" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        [[ "${PROVIDER_VALUE}" == *"-----BEGIN PRIVATE KEY-----"* ]]
        echo "OK"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"OK"* ]]
}

@test "openssl-selfsigned: custom CN and days" {
    command -v openssl >/dev/null 2>&1 || skip "openssl required"
    local note=$'cert-cn: mqtt.example.com\ncert-days: 30'
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/openssl-selfsigned"
        bwx-provider-openssl-selfsigned "test-cert" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"EXPIRES=30"* ]]
    [[ "${output}" == *"mqtt.example.com"* ]]
}

@test "openssl-selfsigned: warns on unknown role" {
    command -v openssl >/dev/null 2>&1 || skip "openssl required"
    local note="cert-role: ca"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/openssl-selfsigned"
        bwx-provider-openssl-selfsigned "test-cert" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Unknown cert-role"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
}

@test "openssl-selfsigned: invalid cert-days warns and uses default" {
    command -v openssl >/dev/null 2>&1 || skip "openssl required"
    local note="cert-days: -5"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/openssl-selfsigned"
        bwx-provider-openssl-selfsigned "test-cert" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"Invalid cert-days"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
}

# ── bitwarden-api-key provider ─────────────────────────────────────

@test "bitwarden-api-key: missing BWS_ACCESS_TOKEN returns 1" {
    run bash -c '
        unset BWS_ACCESS_TOKEN
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/bitwarden-api-key"
        bwx-provider-bitwarden-api-key "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"BWS_ACCESS_TOKEN not set"* ]]
}

@test "bitwarden-api-key: missing org-id file returns 1" {
    run bash -c '
        export BWS_ACCESS_TOKEN="test-token"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/bitwarden-api-key"
        bwx-provider-bitwarden-api-key "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"organization ID not found"* ]]
}

@test "bitwarden-api-key: missing machine-account-id returns 1" {
    echo "org-123" > "${TEST_TMPDIR}/bitwarden-org-id"
    run bash -c '
        export BWS_ACCESS_TOKEN="test-token"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/bitwarden-api-key"
        bwx-provider-bitwarden-api-key "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"machine account ID not found"* ]]
}

@test "bitwarden-api-key: API failure returns 1" {
    echo "org-123" > "${TEST_TMPDIR}/bitwarden-org-id"
    echo "ma-456" > "${TEST_TMPDIR}/bitwarden-machine-account-id"
    run bash -c '
        export BWS_ACCESS_TOKEN="test-token"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/bitwarden-api-key"
        curl() { return 1; }
        jq() { command jq "$@"; }
        bwx-provider-bitwarden-api-key "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"token creation failed"* ]]
}

@test "bitwarden-api-key: successful rotation sets globals" {
    jq --version >/dev/null 2>&1 || skip "jq required"
    echo "org-123" > "${TEST_TMPDIR}/bitwarden-org-id"
    echo "ma-456" > "${TEST_TMPDIR}/bitwarden-machine-account-id"
    run bash -c '
        export BWS_ACCESS_TOKEN="test-token"
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/bitwarden-api-key"
        curl() {
            echo "{\"accessToken\":\"new-bws-token-abc123\"}"
            return 0
        }
        bwx-provider-bitwarden-api-key "test-secret" "'"${TEST_TMPDIR}"'"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=new-bws-token-abc123"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"Machine account"* ]]
}

# ── mqtt-password provider ─────────────────────────────────────────

@test "mqtt-password: generates 32-char alphanumeric password" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/mqtt-password"
        bwx-provider-mqtt-password "test-secret"
        echo "VALUE_LEN=${#PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE_LEN=32"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"MQTT broker password"* ]]
    local value
    value="$(echo "${output}" | grep '^VALUE=' | sed 's/^VALUE=//')"
    [[ "${value}" =~ ^[A-Za-z0-9]+$ ]]
}

@test "mqtt-password: generates different values on each call" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/mqtt-password"
        bwx-provider-mqtt-password "test-secret"
        val1="${PROVIDER_VALUE}"
        bwx-provider-mqtt-password "test-secret"
        val2="${PROVIDER_VALUE}"
        [[ "${val1}" != "${val2}" ]] && echo "DIFFERENT" || echo "SAME"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"DIFFERENT"* ]]
}

# ── grafana-service-account provider ───────────────────────────────

@test "grafana-service-account: missing sa-id returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/grafana-service-account"
        bwx-provider-grafana-service-account "test-secret" "'"${TEST_TMPDIR}"'" ""
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"required field missing"* ]]
}

@test "grafana-service-account: missing password file returns 1" {
    local note="grafana-sa-id: 42"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/grafana-service-account"
        bwx-provider-grafana-service-account "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"grafana-admin-password"* ]]
}

@test "grafana-service-account: API failure returns 1" {
    local note=$'grafana-sa-id: 42\ngrafana-admin-password: '"${TEST_TMPDIR}/grafana-admin-password"
    echo "admin-pw" > "${TEST_TMPDIR}/grafana-admin-password"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/grafana-service-account"
        curl() { return 1; }
        jq() { command jq "$@"; }
        bwx-provider-grafana-service-account "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"token creation failed"* ]]
}

@test "grafana-service-account: successful rotation sets globals" {
    jq --version >/dev/null 2>&1 || skip "jq required"
    local note=$'grafana-sa-id: 42\ngrafana-admin-password: '"${TEST_TMPDIR}/grafana-admin-password"
    echo "admin-pw" > "${TEST_TMPDIR}/grafana-admin-password"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/grafana-service-account"
        curl() {
            echo "{\"id\":99,\"name\":\"test\",\"key\":\"glsa_newtoken123\"}"
            return 0
        }
        bwx-provider-grafana-service-account "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=glsa_newtoken123"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"Grafana SA token"* ]]
}

@test "grafana-service-account: uses custom admin user from note" {
    jq --version >/dev/null 2>&1 || skip "jq required"
    local note=$'grafana-sa-id: 42\ngrafana-admin-user: superadmin\ngrafana-admin-password: '"${TEST_TMPDIR}/grafana-admin-password"
    echo "admin-pw" > "${TEST_TMPDIR}/grafana-admin-password"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/grafana-service-account"
        curl() {
            echo "{\"key\":\"glsa_token\"}"
            return 0
        }
        bwx-provider-grafana-service-account "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=glsa_token"* ]]
}

@test "grafana-service-account: credential fallback to secrets dir" {
    jq --version >/dev/null 2>&1 || skip "jq required"
    local note="grafana-sa-id: 42"
    echo "admin-pw" > "${TEST_TMPDIR}/grafana-admin-password"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/grafana-service-account"
        curl() {
            echo "{\"key\":\"glsa_fallback\"}"
            return 0
        }
        bwx-provider-grafana-service-account "test-secret" "'"${TEST_TMPDIR}"'" "'"${note}"'"
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=glsa_fallback"* ]]
}

# ── docker-registry provider ──────────────────────────────────────

@test "docker-registry: credential fallback to secrets dir" {
    jq --version >/dev/null 2>&1 || skip "jq required"
    echo "myuser" > "${TEST_TMPDIR}/docker-hub-username"
    echo "mypass" > "${TEST_TMPDIR}/docker-hub-password"
    local call_log="${TEST_TMPDIR}/curl-calls"
    echo "0" > "${call_log}"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/docker-registry"
        call_log="'"${call_log}"'"
        curl() {
            local count
            count=$(<"${call_log}")
            count=$((count + 1))
            echo "${count}" > "${call_log}"
            if [[ "${count}" -eq 1 ]]; then
                echo "{\"token\":\"jwt-login\"}"
            else
                echo "{\"token\":\"dckr_fallback\"}"
            fi
            return 0
        }
        bwx-provider-docker-registry "test-secret" "'"${TEST_TMPDIR}"'" ""
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=dckr_fallback"* ]]
}

@test "docker-registry: missing credential files returns 1" {
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/docker-registry"
        bwx-provider-docker-registry "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"credentials not found"* ]]
}

@test "docker-registry: login failure returns 1" {
    echo "myuser" > "${TEST_TMPDIR}/docker-hub-username"
    echo "mypass" > "${TEST_TMPDIR}/docker-hub-password"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/docker-registry"
        curl() { return 1; }
        jq() { command jq "$@"; }
        bwx-provider-docker-registry "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"login failed"* ]]
}

@test "docker-registry: token creation failure returns 1" {
    jq --version >/dev/null 2>&1 || skip "jq required"
    echo "myuser" > "${TEST_TMPDIR}/docker-hub-username"
    echo "mypass" > "${TEST_TMPDIR}/docker-hub-password"
    local call_log="${TEST_TMPDIR}/curl-calls"
    echo "0" > "${call_log}"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/docker-registry"
        call_log="'"${call_log}"'"
        curl() {
            local count
            count=$(<"${call_log}")
            count=$((count + 1))
            echo "${count}" > "${call_log}"
            if [[ "${count}" -eq 1 ]]; then
                echo "{\"token\":\"jwt-login-token\"}"
                return 0
            fi
            return 1
        }
        bwx-provider-docker-registry "test-secret" "'"${TEST_TMPDIR}"'"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Token creation failed"* ]]
}

@test "docker-registry: successful rotation sets globals" {
    jq --version >/dev/null 2>&1 || skip "jq required"
    echo "myuser" > "${TEST_TMPDIR}/docker-hub-username"
    echo "mypass" > "${TEST_TMPDIR}/docker-hub-password"
    local call_log="${TEST_TMPDIR}/curl-calls"
    echo "0" > "${call_log}"
    run bash -c '
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/docker-registry"
        call_log="'"${call_log}"'"
        curl() {
            local count
            count=$(<"${call_log}")
            count=$((count + 1))
            echo "${count}" > "${call_log}"
            if [[ "${count}" -eq 1 ]]; then
                echo "{\"token\":\"jwt-login-token\"}"
            else
                echo "{\"token\":\"dckr_pat_newtoken456\"}"
            fi
            return 0
        }
        bwx-provider-docker-registry "test-secret" "'"${TEST_TMPDIR}"'"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=dckr_pat_newtoken456"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"Docker Hub PAT"* ]]
}

# ── letsencrypt-manual provider ────────────────────────────────────

@test "letsencrypt-manual: accepts valid PEM certificate" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' \
        "-----BEGIN CERTIFICATE-----" \
        "MIIBkjCB/AIJALRiMLAh0DBjMA0GCSqGSIb3DQEBCwUA" \
        "-----END CERTIFICATE-----" \
        "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/letsencrypt-manual"
        bwx-provider-letsencrypt-manual "test-cert"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
        echo "HAS_VALUE=${PROVIDER_VALUE:+yes}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"EXPIRES=90"* ]]
    [[ "${output}" == *"Encrypt certificate"* ]]
    [[ "${output}" == *"HAS_VALUE=yes"* ]]
}

@test "letsencrypt-manual: empty input returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '\n' > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/letsencrypt-manual"
        bwx-provider-letsencrypt-manual "test-cert"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"No certificate data provided"* ]]
}

@test "letsencrypt-manual: missing PEM header returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' \
        "not-a-certificate-data" \
        "-----END CERTIFICATE-----" \
        "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/letsencrypt-manual"
        bwx-provider-letsencrypt-manual "test-cert"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"PEM certificate header"* ]]
}

@test "letsencrypt-manual: missing PEM footer returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' \
        "-----BEGIN CERTIFICATE-----" \
        "some-data" \
        "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/letsencrypt-manual"
        bwx-provider-letsencrypt-manual "test-cert"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"PEM certificate footer"* ]]
}

# ── anthropic-api-key provider ─────────────────────────────────────

@test "anthropic-api-key: accepts sk-ant- key with default expiry" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "sk-ant-abc123" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/anthropic-api-key"
        bwx-provider-anthropic-api-key "test-secret"
        echo "VALUE=${PROVIDER_VALUE}"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
        echo "NOTE=${PROVIDER_NOTE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"VALUE=sk-ant-abc123"* ]]
    [[ "${output}" == *"EXPIRES=365"* ]]
    [[ "${output}" == *"Anthropic API key"* ]]
}

@test "anthropic-api-key: unrecognized prefix warns but succeeds" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "custom-key-format" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/anthropic-api-key"
        bwx-provider-anthropic-api-key "test-secret"
        echo "VALUE=${PROVIDER_VALUE}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"format not recognized"* ]]
    [[ "${output}" == *"VALUE=custom-key-format"* ]]
}

@test "anthropic-api-key: custom expiry" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "sk-ant-abc123" "30" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/anthropic-api-key"
        bwx-provider-anthropic-api-key "test-secret"
        echo "EXPIRES=${PROVIDER_EXPIRES}"
    '
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"EXPIRES=30"* ]]
}

@test "anthropic-api-key: empty key returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "" "" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/anthropic-api-key"
        bwx-provider-anthropic-api-key "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"No API key provided"* ]]
}

@test "anthropic-api-key: non-numeric expiry returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "sk-ant-abc123" "xyz" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/anthropic-api-key"
        bwx-provider-anthropic-api-key "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"positive integer"* ]]
}

@test "anthropic-api-key: zero expiry returns 1" {
    local f="${TEST_TMPDIR}/input"
    printf '%s\n' "sk-ant-abc123" "0" > "${f}"
    run bash -c '
        exec 9< "'"${f}"'"
        export BWX_TTY_FD=9
        source "'"${BWX_ROOT}"'/include/logging"
        source "'"${BWX_ROOT}"'/include/note-parser"
        source "'"${BWX_ROOT}"'/include/provider-config"
        source "'"${BWX_ROOT}"'/lib/providers/anthropic-api-key"
        bwx-provider-anthropic-api-key "test-secret"
    '
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"positive integer"* ]]
}
