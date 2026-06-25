<!-- markdownlint-disable MD013 -->

# Extending the bwx CLI

A developer guide for adding subcommands and note properties to the `bwx`
CLI.

- [Extending the bwx CLI](#extending-the-bwx-cli)
  - [Architecture overview](#architecture-overview)
  - [Adding a new subcommand](#adding-a-new-subcommand)
    - [1. Create the library file](#1-create-the-library-file)
    - [2. Add the dispatch table entry](#2-add-the-dispatch-table-entry)
    - [3. Completion (automatic)](#3-completion-automatic)
    - [4. Add usage text](#4-add-usage-text)
    - [5. Add tests](#5-add-tests)
    - [6. Document](#6-document)
    - [Complete example: `bwx secret owner`](#complete-example-bwx-secret-owner)
  - [Adding a rotation provider](#adding-a-rotation-provider)
    - [Provider contract](#provider-contract)
    - [Provider resolution](#provider-resolution)
    - [Adding a provider: step by step](#adding-a-provider-step-by-step)
    - [Example: AWS IAM key provider](#example-aws-iam-key-provider)
  - [Adding a new note property](#adding-a-new-note-property)
    - [The property contract](#the-property-contract)
    - [Parsing pattern](#parsing-pattern)
    - [Adding a property to the unified get/set](#adding-a-property-to-the-unified-getset)
  - [Testing patterns](#testing-patterns)
    - [Test file location and naming](#test-file-location-and-naming)
    - [Stubbing the bws binary](#stubbing-the-bws-binary)
    - [Test template](#test-template)
    - [What the dispatch tests cover](#what-the-dispatch-tests-cover)
  - [Code conventions](#code-conventions)

## Architecture overview

`bin/bwx` is the single entry point. On startup it sources three include
files and then every `lib/bwx-*` file:

```text
bin/bwx
  source include/logging        # exit codes, log functions (error, trace, ...)
  source include/bwx-cache      # file-backed TTL cache helpers
  source include/tools          # docker-wrapped jq and bws fallbacks
  source lib/bwx-*              # all library functions (glob)
```

Dispatch is table-driven.  The associative array `_BWX_COMMANDS` maps
slash-delimited subcommand paths to function names:

```bash
declare -A _BWX_COMMANDS=(
    [secret/get]=bwx-secret-get
    [secret/set]=bwx-secret-set
    [tag/add]=bwx-secret-add-release-tag
    [project/default/id]=bwx-default-project-id
    ...
)
```

`_bwx_dispatch` tries 3-word, 2-word, then 1-word keys against the
table.  Error messages and tab completion are derived from the same
table automatically via `_bwx_valid_commands`, which scans the keys
by prefix.

Adding a subcommand requires **one line** in the table plus the
function implementation.  No case statement to edit, no completion
word list to update.

## Adding a new subcommand

### 1. Create the library file

Create `lib/bwx-<name>` containing a single function `bwx-<name>()`.
The file must:

- Begin with `# shellcheck shell=bash`.
- Contain exactly one top-level function whose name matches the filename
  (prefixed with `bwx-`).
- Set strict mode at the top of the function body.
- Parse `--help` and `--log-level` options before positional arguments.
- Lazy-source any dependency functions it needs (other lib files).
  Logging is already sourced by `bin/bwx` before lib files load.

### 2. Add the dispatch table entry

Add one line to the `_BWX_COMMANDS` associative array in `bin/bwx`:

```bash
declare -A _BWX_COMMANDS=(
    ...
    [secret/owner]=bwx-secret-owner       # ← new entry
    ...
)
```

That's it.  Error messages and tab completion are derived from the
table automatically — no word lists to edit, no case branches to add.

### 3. Completion (automatic)

Tab completion derives from the dispatch table.  No manual editing
needed.  Verify with:

```console
$ eval "$(bwx completion bash)"
$ bwx secret <TAB>
clone  create  filename  id  key  list  ls  name  note  owner  set  show  tags  value
```

### 4. Add usage text

In `_bwx_usage()`, add a line under the appropriate command section:

```text
    bwx secret owner SECRET     Get the owner of a secret
```

### 5. Add tests

Create `test/bin/bwx-secret-owner.bats` (see [testing patterns](#testing-patterns)
below).

### 6. Document

Add the subcommand to `doc/usage.md` if it exists, or to the `README.md`
command reference.

### Complete example: `bwx secret owner`

Library file `lib/bwx-secret-owner`:

```bash
# shellcheck disable=SC1090,SC1091

# Copyright (C) 2026 James Hanlon [mailto:jim@hanlonsoftware.com]
# Licensed under AGPL-3.0-or-later.

# Print the owner property from a secret's note field.
# Args:
#   SECRET   Secret name or UUID (required)
#   PROJECT  Project name or UUID (optional; defaults to BWX_DEFAULT_PROJECT)
# Returns:
#   0 and writes the owner value to stdout, or empty if no owner is set
bwx-secret-owner() {
    set -o errexit -o errtrace -o nounset -o pipefail
    local _debug="${DEBUG:-false}"
    [[ "${_debug,,}" =~ ^(1|on|true|t|yes|y)$ ]] && set -o verbose -o xtrace

    local refresh_flag=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                declare -F bwx-default-project-name >/dev/null 2>&1 || \
                    source "$(dirname "${BASH_SOURCE[0]}")/bwx-default-project-name"
                cat <<EOF
Usage: bwx secret owner [options] SECRET [PROJECT]

Returns the 'owner' property from a Bitwarden Secrets Manager secret.

Arguments:
  SECRET       Secret name or UUID (required)
  PROJECT      Project name or UUID (optional) [default: $(bwx-default-project-name)]

Options:
  -h, --help   Display this help message
  -l, --log-level LEVEL  Set log level (default: info)
  -R, --refresh  Refresh the cached secret list

EOF
                return "${EXIT_USAGE:-2}"
                ;;
            -R|--refresh)
                refresh_flag="--refresh"
                shift
                ;;
            -l|--log-level)
                [[ -n "${2:-}" && "${2}" != -* ]] || \
                    error "${EXIT_USAGE}" "--log-level requires a value"
                LOG_LEVEL="${2}"
                export LOG_LEVEL
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    # Lazy-source dependencies
    declare -F error trace >/dev/null 2>&1 || \
        source "$(dirname "${BASH_SOURCE[0]}")/../include/logging"
    for cmd in bwx-default-project-name bwx-secret-list jq; do
        declare -F "${cmd}" >/dev/null 2>&1 || \
            source "$(dirname "${BASH_SOURCE[0]}")/${cmd}"
    done

    # Parse positional arguments
    local secret="${1:-}" && shift || :
    [[ -n "${secret}" ]] || error "${EXIT_USAGE}" "Secret name or UUID required"

    local project="${1:-}"
    if [[ -z "${project}" ]]; then
        project=$(bwx-default-project-name)
    fi
    shift || :
    [[ -n "${project}" ]] || \
        error "${EXIT_NOTFOUND}" "Project name or UUID not found"
    [[ "${#@}" -gt 0 ]] && error "${EXIT_USAGE}" "Too many arguments"

    # Retrieve the note and extract the owner property
    local note
    note=$(bwx-secret-list ${refresh_flag} "${project}" \
        | jq -r --arg id "${secret}" \
            '.[] | select(.key == $id or .id == $id) | .note // ""' \
        || :)
    [[ -n "${note}" ]] || \
        error "${EXIT_NOTFOUND}" "Secret '${secret}' not found"

    local owner
    owner=$(printf '%s' "${note}" \
        | grep -iE '^owner: ' \
        | sed -E 's/^[Oo]wner:[[:space:]]*//' \
        | head -1)
    trace "secret '${secret}' owner '${owner}'"
    [[ -n "${owner}" ]] && echo "${owner}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    bwx-secret-owner "$@"
fi
```

## Adding a rotation provider

Rotation providers live in `lib/providers/<name>`.  Each provider is
a bash script that exports one function: `bwx-provider-<name>()`.

### Provider contract

The function receives two arguments and sets three global variables:

```bash
# Args:
#   $1 — BWS secret key (e.g., tailscale_server_authkey_v1)
#   $2 — secrets directory (e.g., .secrets/)
# Sets:
#   PROVIDER_VALUE    — the new credential value
#   PROVIDER_EXPIRES  — expiry in days from now
#   PROVIDER_NOTE     — human-readable note for the BWS note field
# Returns:
#   0 on success; non-zero to abort rotation
bwx-provider-<name>() {
    ...
}
```

The rotation framework (`bwx-rotate`) handles all BWS mechanics
after the provider returns: updating the value, setting the
`expires:` date, and preserving release-tag and file metadata.

### Provider resolution

`bwx rotate SECRET` reads the `provider:` field from the secret's
BWS note:

```yaml
provider: tailscale-oauth
```

When no `provider:` field is set, the `prompt` driver is used as a
generic fallback.

### Adding a provider: step by step

1. Create `lib/providers/<name>` with function `bwx-provider-<name>()`
2. Add `# shellcheck shell=bash` and `# shellcheck disable=SC2034`
   (the `PROVIDER_*` variables are used by the caller, not the provider)
3. Set `PROVIDER_VALUE`, `PROVIDER_EXPIRES`, `PROVIDER_NOTE` before
   returning
4. Add `provider: <name>` to the BWS note of each secret that uses it
5. No dispatch table or completion changes needed — providers are
   discovered by filename

### Example: AWS IAM key provider

```bash
# lib/providers/aws-iam
# shellcheck shell=bash
# shellcheck disable=SC2034

bwx-provider-aws-iam() {
    local secret="${1}"

    info "Rotating AWS IAM access key..."
    local old_key_id new_creds
    old_key_id=$(aws iam list-access-keys \
        --query 'AccessKeyMetadata[0].AccessKeyId' --output text)
    new_creds=$(aws iam create-access-key --output json)

    PROVIDER_VALUE=$(printf '%s' "${new_creds}" \
        | jq -r '.AccessKey.SecretAccessKey')
    PROVIDER_EXPIRES=365
    PROVIDER_NOTE="note: AWS IAM access key (rotated $(date +%Y-%m-%d))"

    aws iam update-access-key \
        --access-key-id "${old_key_id}" --status Inactive
}
```

---

## Adding a new note property

### The property contract

Metadata properties are stored as line-oriented key-value pairs in the BWS
note field. Each line follows the format `property: value`. A secret's note
might look like:

```text
file: mosquitto.conf
owner: ops-team
release-tag: v1.2.0
release-tag: v1.3.0
```

Properties fall into two categories:

| Category | Example | Cardinality | Getter returns |
|---|---|---|---|
| Single-value | `file:`, `owner:` | At most one line per secret | The value (or empty) |
| Multi-value | `release-tag:` | Zero or more lines per secret | All values, one per line |

### Parsing pattern

Getters extract a property from the note using `grep -iE` (case-insensitive
extended regex) and `sed -E` to strip the key prefix:

```bash
# Single-value property (returns first match)
owner=$(printf '%s' "${note}" \
    | grep -iE '^owner: ' \
    | sed -E 's/^[Oo]wner:[[:space:]]*//' \
    | head -1)

# Multi-value property (returns all matches, sorted and deduplicated)
release_tags=$(printf '%s' "${note}" \
    | grep -iE '^release-tag: ' \
    | awk '{print $2}' \
    | sort --unique)
```

### Adding a property to the unified get/set

Adding a note property requires no new files — just add `case`
branches to `lib/bwx-secret-get` and `lib/bwx-secret-set`.

**Getter** — add to the `case "${property}"` in `bwx-secret-get`:

```bash
        owner)
            local note
            note="$(printf '%s' "${secret_json}" | jq -r '.note // ""')"
            printf '%s' "${note}" \
                | grep -iE '^[[:space:]]*owner[[:space:]]*:' \
                | sed -E 's/^[[:space:]]*owner[[:space:]]*:[[:space:]]*//' \
                | head -1
            ;;
```

**Setter** — add to the `case "${property}"` in `bwx-secret-set`:

```bash
        owner)
            local current_note
            current_note="$(bwx-secret-get note "${secret}" ${project_id:+"${project_id}"})"
            local new_note
            if printf '%s' "${current_note}" | grep -qiE '^[[:space:]]*owner[[:space:]]*:'; then
                new_note="$(printf '%s' "${current_note}" \
                    | sed -E "s|^([[:space:]]*)owner[[:space:]]*:.*|\1owner: ${value}|")"
            else
                new_note="owner: ${value}"$'\n'"${current_note}"
            fi
            bws secret edit "${secret_uuid}" --note "${new_note}" >/dev/null || \
                error "${EXIT_ERROR}" "Failed to update owner for '${secret}'"
            info "Updated owner for '${secret}' to '${value}'"
            ;;
```

No dispatch table changes, no completion changes, no new lib files.
The property is immediately available:

```console
$ bwx secret set owner my_secret_v1 "ops-team"
[INFO] Updated owner for 'my_secret_v1' to 'ops-team'

$ bwx secret get owner my_secret_v1
ops-team
```

## Testing patterns

### Test file location and naming

Tests live in `test/bin/`. The dispatch-layer tests are in `bwx.bats`. Per-
subcommand tests go in a file named after the subcommand:

```text
test/bin/bwx.bats                  # dispatch and help tests
test/bin/bwx-secret-owner.bats     # tests for bwx secret owner
```

### Stubbing the bws binary

Subcommand tests must not make live API calls. The standard approach is to
create a fake `bws` script in a temporary directory and prepend it to
`PATH`:

```bash
setup() {
    BWX_ROOT="$(realpath "$(dirname "${BATS_TEST_FILENAME}")/../..")"
    BWX="${BWX_ROOT}/bin/bwx"

    # Create a stub bws that returns canned JSON
    STUB_DIR="$(mktemp -d)"
    cat > "${STUB_DIR}/bws" <<'STUB'
#!/usr/bin/env bash
# Stub bws: returns canned data for testing
case "${1:-} ${2:-}" in
    "secret list")
        cat <<'JSON'
[
  {
    "id": "aaaa-bbbb-cccc",
    "key": "test-secret",
    "value": "s3cret",
    "note": "file: config.env\nowner: ops-team\nrelease-tag: v1.0.0",
    "organizationId": "org-1",
    "projectId": "proj-1"
  }
]
JSON
        ;;
    "secret get")
        cat <<'JSON'
{
  "id": "aaaa-bbbb-cccc",
  "key": "test-secret",
  "value": "s3cret",
  "note": "file: config.env\nowner: ops-team\nrelease-tag: v1.0.0"
}
JSON
        ;;
    "secret edit")
        echo '{"id": "aaaa-bbbb-cccc"}'
        ;;
    *)
        echo "stub: unhandled: $*" >&2
        exit 1
        ;;
esac
STUB
    chmod +x "${STUB_DIR}/bws"
    export PATH="${STUB_DIR}:${PATH}"
}

teardown() {
    rm -rf "${STUB_DIR}"
}
```

### Test template

```bash
#!/usr/bin/env bats
# Tests for bwx secret owner.

setup() {
    BWX_ROOT="$(realpath "$(dirname "${BATS_TEST_FILENAME}")/../..")"
    BWX="${BWX_ROOT}/bin/bwx"
    # ... stub setup as shown above ...
}

teardown() {
    rm -rf "${STUB_DIR}"
}

@test "secret owner --help exits 2" {
    run "${BWX}" secret owner --help
    [[ "${status}" -eq 2 ]]
    [[ "${output}" == *"Usage:"* ]]
}

@test "secret owner requires SECRET argument" {
    run "${BWX}" secret owner
    [[ "${status}" -ne 0 ]]
    [[ "${output}" == *"Secret name or UUID required"* ]]
}

@test "secret owner returns owner from note" {
    run "${BWX}" secret owner test-secret
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "ops-team" ]]
}

@test "secret owner returns empty for secret without owner" {
    # Override stub to return note without owner line
    # ...
    run "${BWX}" secret owner no-owner-secret
    [[ "${status}" -eq 0 ]]
    [[ -z "${output}" ]]
}
```

### What the dispatch tests cover

The tests in `test/bin/bwx.bats` verify:

- `--help`, `-h`, and bare invocation show usage and exit 0.
- `--version` prints a semver string.
- Unknown commands at every dispatch level exit 2 with a valid-commands hint.
- Every known subcommand name is recognized (exits 0 or 2, never an
  unrecognized-command error).
- Completion output contains the expected shell constructs.
- `bin/bwx` cannot be sourced (must be executed).

When adding a subcommand, add it to the appropriate `for cmd in ...` loop in
the "all ... subcommands are recognized" tests so the new name is verified.

## Code conventions

- **Shellcheck clean.** No suppressed warnings without a justifying comment.
  The only project-wide suppression is `SC1090,SC1091` (non-constant source
  paths) at the top of each lib file.
- **4-space indentation.** No tabs.
- **Function names** use kebab-case with a `bwx-` prefix: `bwx-secret-owner`.
  The name must match the lib filename exactly.
- **Functions are lexically sorted** within files. When a file contains only
  one function this is trivially satisfied; in files with helpers, sort them
  alphabetically.
- **Declaration comment** above every function:

    ```bash
    # Print the owner property from a secret's note field.
    # Args:
    #   SECRET   Secret name or UUID (required)
    #   PROJECT  Project name or UUID (optional)
    # Returns:
    #   0 and writes the owner value to stdout
    bwx-secret-owner() {
    ```

- **Strict mode** at the function entry, not the file level:

    ```bash
    set -o errexit -o errtrace -o nounset -o pipefail
    ```

- **Debug toggle** via `DEBUG` environment variable:

    ```bash
    local _debug="${DEBUG:-false}"
    [[ "${_debug,,}" =~ ^(1|on|true|t|yes|y)$ ]] && \
        set -o verbose -o xtrace
    ```

- **Lazy sourcing** of dependencies with the `declare -F` guard:

    ```bash
    declare -F error trace >/dev/null 2>&1 || \
        source "$(dirname "${BASH_SOURCE[0]}")/../include/logging"
    ```

- **Standalone invocation guard** at the end of every lib file:

    ```bash
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        bwx-secret-owner "$@"
    fi
    ```

- **American English** in all messages, comments, and documentation.
- **Line length** should not exceed 80 characters and must not exceed 120,
  except where syntactically required.
- **No trailing whitespace.**
