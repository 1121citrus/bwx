<!-- markdownlint-disable MD013 -->

# Extending the bwx CLI

A developer guide for adding subcommands and note properties to the `bwx`
CLI.

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

Dispatch maps the user-facing command syntax to internal function calls.
`bwx <family> <command>` becomes a `bws-<function>()` call inside
`_bwx_dispatch()`:

| User types | Dispatches to |
|---|---|
| `bwx secret value my-key` | `bws-secret-value my-key` |
| `bwx secret set filename my-key config.env` | `bws-secret-set-filename my-key config.env` |
| `bwx tag add my-key v2.1.0` | `bws-secret-add-release-tag my-key v2.1.0` |
| `bwx project default id` | `bws-default-project-id` |

Internal function names use the `bws-*` prefix. Because the functions are
sourced (not placed on PATH), they do not pollute the shell namespace of
callers.

Tab completion is generated from the dispatch table inside
`_bwx_completion()`, which emits a `complete -F` definition for bash and a
`compdef` definition for zsh.

## Adding a new subcommand

### 1. Create the library file

Create `lib/bwx-<name>` containing a single function `bws-<name>()`.
The file must:

- Begin with the `# shellcheck disable=SC1090,SC1091` directive.
- Contain exactly one top-level function whose name matches the filename.
- Set strict mode at the top of the function body.
- Parse `--help` and `--log-level` options before positional arguments.
- Lazy-source any dependency functions it needs (logging, other lib files).
- End with the standalone-invocation guard.

### 2. Add the dispatch entry

Open `bin/bwx` and add a line to the appropriate `case` block inside
`_bwx_dispatch()`. If the new command belongs to an existing family (e.g.,
`secret`), add it alphabetically within that family's case block. Update
the wildcard `*` error list to include the new command name.

For example, adding `bwx secret owner`:

```bash
# In _bwx_dispatch(), inside case "${cmd}" under "secret)"
owner)          bws-secret-owner "$@" ;;
```

Update the `*` branch's valid-command list:

```bash
*)  _bwx_usage_error "secret" "${cmd}" \
        "clone create filename id key list ls name note owner set show tags value" ;;
```

### 3. Add completion support

In `_bwx_completion()`, add the new command to the appropriate `compgen -W`
word list. For a `secret` family command:

```bash
secret) COMPREPLY=($(compgen -W "clone create filename id key list ls name note owner set show tags value" -- "${cur}")) ;;
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
bws-secret-owner() {
    set -o errexit -o errtrace -o nounset -o pipefail
    local _debug="${DEBUG:-false}"
    [[ "${_debug,,}" =~ ^(1|on|true|t|yes|y)$ ]] && set -o verbose -o xtrace

    local refresh_flag=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                declare -F bws-default-project-name >/dev/null 2>&1 || \
                    source "$(dirname "${BASH_SOURCE[0]}")/bws-default-project-name"
                cat <<EOF
Usage: bws-secret-owner [options] SECRET [PROJECT]

Returns the 'owner' property from a Bitwarden Secrets Manager secret.

Arguments:
  SECRET       Secret name or UUID (required)
  PROJECT      Project name or UUID (optional) [default: $(bws-default-project-name)]

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
    for cmd in bws-default-project-name bws-secret-list jq; do
        declare -F "${cmd}" >/dev/null 2>&1 || \
            source "$(dirname "${BASH_SOURCE[0]}")/${cmd}"
    done

    # Parse positional arguments
    local secret="${1:-}" && shift || :
    [[ -n "${secret}" ]] || error "${EXIT_USAGE}" "Secret name or UUID required"

    local project="${1:-}"
    if [[ -z "${project}" ]]; then
        project=$(bws-default-project-name)
    fi
    shift || :
    [[ -n "${project}" ]] || \
        error "${EXIT_NOTFOUND}" "Project name or UUID not found"
    [[ "${#@}" -gt 0 ]] && error "${EXIT_USAGE}" "Too many arguments"

    # Retrieve the note and extract the owner property
    local note
    note=$(bws-secret-list ${refresh_flag} "${project}" \
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
    bws-secret-owner "$@"
fi
```

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

### Required subcommands

Adding a note property requires both a getter and a setter. Each lives in its
own lib file:

| Purpose | Filename | Function |
|---|---|---|
| Getter | `lib/bwx-secret-owner` | `bws-secret-owner()` |
| Setter | `lib/bwx-secret-set-owner` | `bws-secret-set-owner()` |

The getter reads the note via the cached secret list (`bws-secret-list`). The
setter mutates the note through the BWS API (`bws secret edit ... --note`)
and refreshes the cache afterward.

### Setter implementation

The setter for a single-value property follows a three-step pattern:

1. Fetch the current note.
2. Remove any existing lines for the property (`grep -vE`).
3. Append the new value and write back via `bws secret edit`.

Complete setter for `owner:` in `lib/bwx-secret-set-owner`:

```bash
# shellcheck disable=SC1090,SC1091

# Copyright (C) 2026 James Hanlon [mailto:jim@hanlonsoftware.com]
# Licensed under AGPL-3.0-or-later.

# Set the owner property in a secret's note field.
# Args:
#   SECRET   Secret name or UUID (required)
#   OWNER    Owner value (required)
#   PROJECT  Project name or UUID (optional; defaults to BWX_DEFAULT_PROJECT)
# Returns:
#   0 on success; exits non-zero on failure
bws-secret-set-owner() {
    set -o errexit -o errtrace -o nounset -o pipefail
    local _debug="${DEBUG:-false}"
    [[ "${_debug,,}" =~ ^(1|on|true|t|yes|y)$ ]] && set -o verbose -o xtrace

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                declare -F bws-default-project-name >/dev/null 2>&1 || \
                    source "$(dirname "${BASH_SOURCE[0]}")/bws-default-project-name"
                cat <<EOF
Usage: bws-secret-set-owner SECRET OWNER [PROJECT]

Set the owner metadata property for a Bitwarden Secrets Manager secret.

Arguments:
  SECRET      Secret name or UUID (required)
  OWNER       New owner value (required)
  PROJECT     Project name or UUID (optional) [default: $(bws-default-project-name)]

Options:
  -h, --help  Display this help message
  -l, --log-level LEVEL  Set log level (default: info)
EOF
                return "${EXIT_USAGE:-2}"
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
    for cmd in bws bws-project-id bws-project-name bws-secret-id; do
        declare -F "${cmd}" >/dev/null 2>&1 || \
            source "$(dirname "${BASH_SOURCE[0]}")/${cmd}"
    done

    # Parse positional arguments
    local secret="${1:-}"
    [[ -n "${secret}" ]] || error "${EXIT_USAGE}" "Secret name or UUID required"
    local owner="${2:-}"
    [[ -n "${owner}" ]] || error "${EXIT_USAGE}" "Owner value required"
    local project="${3:-}"
    project="$(bws-project-id "${project}")"
    local project_name
    project_name=$(bws-project-name "${project}")

    # Resolve secret UUID
    local secret_uuid
    secret_uuid=$(bws-secret-id "${secret}" "${project}" || :)
    if [[ -z "${secret_uuid:+x}" ]]; then
        error "${EXIT_NOTFOUND}" \
            "Secret '${secret}' not found in project ${project_name}"
    fi

    # Fetch current note
    local existing_notes
    existing_notes="$(bws secret get "${secret_uuid}" --output json \
        | jq -r '.note')"

    # Replace: strip existing owner lines, append new value, sort
    local new_notes
    new_notes=$(echo "${existing_notes}" | grep -vE '^owner:')
    new_notes=$(echo "${new_notes}" && echo "owner: ${owner}")
    new_notes=$(echo "${new_notes}" | sort --unique)

    # Write back
    trace "bws secret edit '${secret_uuid}' --note '${new_notes}'"
    if bws secret edit "${secret_uuid}" --note "${new_notes}" >/dev/null; then
        debug "Secret owner updated successfully"
    else
        error "${EXIT_ERROR}" "Failed to update secret owner"
    fi

    # Refresh the cached secret list
    if bws-secret-list --refresh "${project}" >/dev/null 2>&1; then
        local secret_list_project="${project_name^^}"
        secret_list_project="${secret_list_project//-/_}"
        local secret_list_var="BWS_PROJECT_SECRET_LIST_${secret_list_project}"
        warn "Be sure to unset the cached secret list for project" \
            "'${project_name}' (i.e. 'unset ${secret_list_var}') to" \
            "ensure you get the updated data" || :
    else
        warn "Failed to refresh cached secret list for project" \
            "'${project_name}'" || :
    fi || :
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    bws-secret-set-owner "$@"
fi
```

### Dispatch and completion updates for getter and setter

After creating both lib files, update `bin/bwx` in three places:

**`_bwx_dispatch()`** -- add `owner)` to the `secret` case block and
`set-owner` to the `secret set` sub-case:

```bash
# Under secret)
owner)          bws-secret-owner "$@" ;;

# Under secret set)
owner)    bws-secret-set-owner "$@" ;;
```

**`_bwx_completion()`** -- add `owner` to both the `secret` and `set` word
lists.

**`_bwx_usage()`** -- add help lines for both commands.

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
- **Function names** use kebab-case with a `bws-` prefix: `bws-secret-owner`.
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
    bws-secret-owner() {
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
        bws-secret-owner "$@"
    fi
    ```

- **American English** in all messages, comments, and documentation.
- **Line length** should not exceed 80 characters and must not exceed 120,
  except where syntactically required.
- **No trailing whitespace.**
