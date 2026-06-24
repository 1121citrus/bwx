# shellcheck shell=bash
# Shared test helpers for bwx BATS tests.
# Source from setup() in each test file.

BWX_ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
BWX="${BWX_ROOT}/bin/bwx"

# Set up the mock bws and required env vars.
# Creates TEST_TMPDIR under the repo root (visible inside Docker).
bwx_test_setup() {
    TEST_TMPDIR="${BWX_ROOT}/test/.tmp-$$-${BATS_TEST_NUMBER}"
    mkdir -p "${TEST_TMPDIR}/stub-bin"

    # Link the shared mock bws into the stub PATH
    cp "${BWX_ROOT}/test/fixtures/mock-bws" "${TEST_TMPDIR}/stub-bin/bws"
    chmod +x "${TEST_TMPDIR}/stub-bin/bws"

    export PATH="${TEST_TMPDIR}/stub-bin:${PATH}"
    export BWS_ACCESS_TOKEN="test-token"
    export BWS_DEFAULT_PROJECT="test-project"

    # Tell lib/bws to preserve the mock bws function instead of
    # redefining it with the Docker wrapper and token validation.
    export CITRUS_ENABLE_MOCK_COMMANDS=true

    # Disable caching to avoid cross-test contamination
    export BWS_SECRET_LIST_CACHE_TTL_SECONDS=0

    # Skip functional tests if jq is not available (e.g., direct
    # bats invocation without test/run-all which installs jq)
    if ! jq --version >/dev/null 2>&1; then
        skip "jq not available (run via test/run-all to auto-install)"
    fi
}

bwx_test_teardown() {
    rm -rf "${TEST_TMPDIR}"
}
