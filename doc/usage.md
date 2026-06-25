<!-- markdownlint-disable MD013 -->

# bwx subcommand reference

Complete reference for `bwx` 1.0.0, a Bitwarden Secrets Manager extended CLI.

- [bwx subcommand reference](#bwx-subcommand-reference)
  - [Installation](#installation)
    - [Clone to `~/.local/lib/bwx`](#clone-to-locallibbwx)
    - [Homebrew (future)](#homebrew-future)
    - [Vendor dependency](#vendor-dependency)
  - [Subcommand reference](#subcommand-reference)
    - [`secret` family](#secret-family)
      - [`bwx secret list`](#bwx-secret-list)
      - [`bwx secret show`](#bwx-secret-show)
      - [`bwx secret value`](#bwx-secret-value)
      - [`bwx secret note`](#bwx-secret-note)
      - [`bwx secret id`](#bwx-secret-id)
      - [`bwx secret key`](#bwx-secret-key)
      - [`bwx secret name`](#bwx-secret-name)
      - [`bwx secret filename`](#bwx-secret-filename)
      - [`bwx secret tags`](#bwx-secret-tags)
      - [`bwx secret ls`](#bwx-secret-ls)
      - [`bwx secret create`](#bwx-secret-create)
      - [`bwx secret clone`](#bwx-secret-clone)
      - [`bwx secret set value`](#bwx-secret-set-value)
      - [`bwx secret set note`](#bwx-secret-set-note)
      - [`bwx secret set key`](#bwx-secret-set-key)
      - [`bwx secret set filename`](#bwx-secret-set-filename)
    - [`project` family](#project-family)
      - [`bwx project list`](#bwx-project-list)
      - [`bwx project show`](#bwx-project-show)
      - [`bwx project id`](#bwx-project-id)
      - [`bwx project name`](#bwx-project-name)
      - [`bwx project ls`](#bwx-project-ls)
      - [`bwx project default id`](#bwx-project-default-id)
      - [`bwx project default name`](#bwx-project-default-name)
    - [`tag` family](#tag-family)
      - [`bwx tag list`](#bwx-tag-list)
      - [`bwx tag secrets`](#bwx-tag-secrets)
      - [`bwx tag add`](#bwx-tag-add)
      - [`bwx tag remove`](#bwx-tag-remove)
      - [`bwx tag project`](#bwx-tag-project)
      - [`bwx tag unproject`](#bwx-tag-unproject)
    - [`raw`](#raw)
    - [`completion`](#completion)
  - [Structured note metadata](#structured-note-metadata)
    - [Properties](#properties)
    - [Example note](#example-note)
    - [Parsing patterns](#parsing-patterns)
    - [Multi-value vs single-value](#multi-value-vs-single-value)
  - [Caching](#caching)
    - [Cache layers](#cache-layers)
    - [TTL](#ttl)
    - [Forced refresh](#forced-refresh)
    - [Cache file permissions](#cache-file-permissions)
  - [Environment variables](#environment-variables)

## Installation

### Clone to `~/.local/lib/bwx`

```bash
git clone https://github.com/1121citrus/bwx.git ~/.local/lib/bwx
export PATH="${HOME}/.local/lib/bwx/bin:${PATH}"
eval "$(bwx completion bash)"
```

Add the `export` and `eval` lines to `~/.bashrc` (or `~/.zshrc` for zsh)
to make them permanent.

### Homebrew (future)

Not yet available. A Homebrew tap is planned for a future release.

### Vendor dependency

When using `bwx` as a vendored dependency inside another project:

```bash
# From the consuming project root
git submodule add https://github.com/1121citrus/bwx.git vendor/bwx
export PATH="${PWD}/vendor/bwx/bin:${PATH}"
eval "$(bwx completion bash)"
```

The `PATH` export and completion setup can be placed in the consuming
project's shell initialization script (for example, an `include/dot-bashrc`
or similar).

## Subcommand reference

### `secret` family

Commands for querying and mutating individual secrets. Every command that
accepts a `SECRET` argument resolves it by key name or UUID. Every command
that accepts an optional `PROJECT` argument defaults to the value of
`BWX_DEFAULT_PROJECT`.

---

#### `bwx secret list`

```text
bwx secret list [--refresh] [PROJECT]
```

List all secrets in a project as JSON.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--refresh`, `-R` | Force a fresh API fetch, bypassing the cache. |

**Example:**

```console
$ bwx secret list | jq '.[0]'
{
  "id": "aaaa-bbbb-cccc-dddd",
  "key": "secret_key_1",
  "value": "secret_value_1",
  "note": "note 1",
  ...
}
```

JSON output is compact by default; pipe through `jq .` to
pretty-print.

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret show`

```text
bwx secret show SECRET [PROJECT]
```

Print the full JSON metadata for a single secret, including key, value,
note, id, and timestamps.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret show secret_key_1 | jq .
{
  "id": "aaaa-bbbb-cccc-dddd",
  "key": "secret_key_1",
  "value": "secret_value_1",
  "note": "note 1",
  ...
}
```

JSON output is compact by default; pipe through `jq .` to
pretty-print.

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret value`

```text
bwx secret value SECRET [PROJECT]
```

Print only the value of a secret. Useful for piping into other commands
or assigning to a variable.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret value secret_key_1
secret_value_1

$ export TOKEN
$ TOKEN=$(bwx secret value secret_key_2)
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret note`

```text
bwx secret note SECRET [PROJECT]
```

Print the note field of a secret. The note typically contains structured
metadata lines (see [Structured note metadata](#structured-note-metadata)).

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret note secret_key_1
note 1

$ bwx secret note secret_key_3
file: test-secret-1
note: "A test secret"
release-tag: test-tag-1
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret id`

```text
bwx secret id SECRET [PROJECT]
```

Resolve a secret key name to its UUID.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret id secret_key_1
aaaa-bbbb-cccc-dddd

$ bwx secret id secret_key_3
iiii-jjjj-kkkk-llll
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret key`

```text
bwx secret key SECRET [PROJECT]
```

Print the key (name) of a secret. Primarily useful when looking up a
secret by UUID.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret key aaaa-bbbb-cccc-dddd
secret_key_1

$ bwx secret key eeee-ffff-gggg-hhhh
secret_key_2
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret name`

```text
bwx secret name SECRET [PROJECT]
```

Resolve a secret UUID to its human-readable key name. Functionally
equivalent to `bwx secret key` but uses optimized cache lookups for
UUID-to-name resolution.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret name aaaa-bbbb-cccc-dddd
secret_key_1

$ bwx secret name iiii-jjjj-kkkk-llll
secret_key_3
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret filename`

```text
bwx secret filename SECRET [PROJECT]
```

Extract the `file:` property from a secret's structured note. Returns
the filename that deployment tools use to write the secret to disk.
Returns empty (exit 0) if no `file:` property is set.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret filename secret_key_3
test-secret-1

$ bwx secret filename secret_key_1

```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret tags`

```text
bwx secret tags SECRET [PROJECT]
```

List all release tags attached to a secret, one per line, sorted
and deduplicated.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret tags secret_key_3
test-tag-1

$ bwx secret tags secret_key_6
tag-a
tag-b
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret ls`

```text
bwx secret ls [--refresh] [PROJECT]
```

Print secret key names only, one per line, sorted. A compact alternative
to `bwx secret list` when only the names are needed.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--refresh`, `-R` | Force a fresh API fetch. |

**Example:**

```console
$ bwx secret ls
secret_key_1
secret_key_2
secret_key_3
secret_key_4
secret_key_5
secret_key_6
secret_key_7
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret create`

```text
bwx secret create [OPTIONS] KEY [VALUE] [PROJECT]
bwx secret create [OPTIONS] KEY --from-file FILE [PROJECT]
```

Create a new secret in a project. The value can be given as a positional
argument or read from a file with `--from-file` (supports multi-line
content). After creation, the cached secret list is automatically
refreshed.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `KEY` | Yes | Secret key name. |
| `VALUE` | Yes (unless `--from-file`) | Secret value. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `-n`, `--note NOTE` | Set the `note:` field in the structured note. |
| `--note-from-file FILE` | Read note from a file (supports multi-line markdown). |
| `-f`, `--file FILE` | Set the `file:` field in the structured note. |
| `--from-file FILE` | Read the secret value from a file. |
| `--release-tag TAG` | Add a `release-tag:` entry. Repeatable. |

**Example:**

```console
$ bwx secret create mqtt_broker_password_v1 "s3cret" \
    --file mosquitto-password \
    --note "MQTT broker authentication" \
    --release-tag 2026.06.24.01
[INFO] Created secret mqtt_broker_password_v1

$ bwx secret create tls_cert_v1 --from-file ./cert.pem \
    --file tls-cert.pem
[INFO] Created secret tls_cert_v1
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret clone`

```text
bwx secret clone SECRET [VALUE] [PROJECT]
```

Deep-copy a secret and increment the version suffix. The source secret
name must end in `_vN` (for example, `api_key_v1`). The clone is created
as `_v(N+1)`. All note metadata is preserved except release tags, which
are stripped from the clone. An optional new value can replace the
original.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Source secret key name or UUID (must end in `_vN`). |
| `VALUE` | No | New value for the clone. If omitted, the original value is copied. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret clone secret_key_1
[INFO] Cloned secret_key_1 -> secret_key_2

$ bwx secret clone secret_key_2 "new-rotated-value"
[INFO] Cloned secret_key_2 -> secret_key_3
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret set value`

```text
bwx secret set value SECRET VALUE [PROJECT]
bwx secret set value SECRET --from-file FILE [PROJECT]
```

Update the value of an existing secret. Accepts a positional value or
reads from a file with `--from-file`. Refreshes the cache after update.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `VALUE` | Yes (unless `--from-file`) | New value. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--from-file FILE` | Read the new value from a file. |

**Example:**

```console
$ bwx secret set value secret_key_1 "new_password"
[INFO] Updated value for secret_key_1

$ bwx secret set value secret_key_2 --from-file ./new-key.pem
[INFO] Updated value for secret_key_2
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret set note`

```text
bwx secret set note SECRET NOTE [PROJECT]
bwx secret set note SECRET --from-file FILE [PROJECT]
```

Replace the note field of an existing secret. This overwrites the entire
note, including any structured metadata. Use `--from-file` for multi-line
content. Refreshes the cache after update.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `NOTE` | Yes (unless `--from-file`) | New note content. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--from-file FILE` | Read the new note from a file (supports multi-line markdown). |

**Example:**

```console
$ bwx secret set note secret_key_1 "file: api-key
note: rotated 2026-06-24
release-tag: 2026.06.24.01"
[INFO] Updated note for secret_key_1
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret set key`

```text
bwx secret set key SECRET KEY [PROJECT]
bwx secret set key SECRET --from-file FILE [PROJECT]
```

Rename the key of an existing secret. Refreshes the cache after update.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Current secret key name or UUID. |
| `KEY` | Yes (unless `--from-file`) | New key name. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--from-file FILE` | Read the new key from a file. |

**Example:**

```console
$ bwx secret set key secret_key_1 secret_key_1_renamed
[INFO] Updated key for secret_key_1
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret set filename`

```text
bwx secret set filename SECRET FILENAME [PROJECT]
```

Update the `file:` property in a secret's structured note without
affecting other note lines. Any existing `file:` line is replaced; all
other metadata (release tags, notes, expires) is preserved.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `FILENAME` | Yes | New filename value. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret set filename secret_key_3 mosquitto-cert.pem
[INFO] Updated filename for secret_key_3
```

[**↑ Contents**](#bwx-subcommand-reference)

---

### `project` family

Commands for querying Bitwarden Secrets Manager projects.

---

#### `bwx project list`

```text
bwx project list [--refresh]
```

List all projects as JSON.

**Options:**

| Option | Description |
|--------|-------------|
| `--refresh`, `-R` | Force a fresh API fetch, bypassing the cache. |

**Example:**

```console
$ bwx project list | jq '.[].name'
"test-project"
"other-project"
```

JSON output is compact by default; pipe through `jq .` to
pretty-print.

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx project show`

```text
bwx project show [PROJECT]
```

Print the full JSON metadata for a single project.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx project show test-project | jq .name
"test-project"
```

JSON output is compact by default; pipe through `jq .` to
pretty-print.

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx project id`

```text
bwx project id [PROJECT]
```

Resolve a project name to its UUID.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx project id test-project
11111111-1111-1111-1111-111111111111

$ bwx project id other-project
22222222-2222-2222-2222-222222222222
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx project name`

```text
bwx project name [PROJECT]
```

Resolve a project UUID to its human-readable name.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx project name 11111111-1111-1111-1111-111111111111
test-project

$ bwx project name 22222222-2222-2222-2222-222222222222
other-project
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx project ls`

```text
bwx project ls [--refresh]
```

Print project names only, one per line, sorted. Takes no positional
arguments.

**Options:**

| Option | Description |
|--------|-------------|
| `--refresh`, `-R` | Force a fresh API fetch. |

**Example:**

```console
$ bwx project ls
other-project
test-project
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx project default id`

```text
bwx project default id
```

Print the UUID of the default project (resolved from
`BWX_DEFAULT_PROJECT`). The result is cached in
`BWX_DEFAULT_PROJECT_ID` for subsequent calls within the same shell
session.

**Example:**

```console
$ bwx project default id
11111111-1111-1111-1111-111111111111
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx project default name`

```text
bwx project default name
```

Print the name of the default project (the value of
`BWX_DEFAULT_PROJECT`).

**Example:**

```console
$ bwx project default name
test-project
```

[**↑ Contents**](#bwx-subcommand-reference)

---

### `tag` family

Commands for managing release tags. Release tags are stored as
`release-tag:` lines in each secret's note field (see
[Structured note metadata](#structured-note-metadata)). They bind
secrets to specific deployment releases.

---

#### `bwx tag list`

```text
bwx tag list [--refresh] [PROJECT]
```

List all distinct release tags across all secrets in a project, one per
line, sorted.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--refresh`, `-R` | Force a fresh API fetch. |

**Example:**

```console
$ bwx tag list
tag-a
tag-b
test-tag-1
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx tag secrets`

```text
bwx tag secrets [--refresh] [TAG] [PROJECT]
```

List secrets grouped by release tag. If `TAG` is specified, only secrets
with that tag are shown. Output format is `TAG: secret1 secret2 ...`
per line.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `TAG` | No | Filter to a specific release tag. If omitted, all tags are shown. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--refresh`, `-R` | Force a fresh API fetch. |

**Example:**

```console
$ bwx tag secrets test-tag-1
test-tag-1: secret_key_3

$ bwx tag secrets
tag-a: secret_key_6
tag-b: secret_key_6
test-tag-1: secret_key_3
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx tag add`

```text
bwx tag add SECRET TAG [PROJECT]
```

Add a release tag to a single secret by appending a `release-tag:` line
to its note. If the tag already exists, the note is unchanged (tags are
deduplicated via sort). The cached secret list is refreshed after the
update.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `TAG` | Yes | Release tag to add. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx tag add secret_key_1 2026.06.24.01
[INFO] Added tag 2026.06.24.01 to secret_key_1
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx tag remove`

```text
bwx tag remove SECRET TAG [PROJECT]
```

Remove a release tag from a single secret by deleting the matching
`release-tag:` line from its note.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret key name or UUID. |
| `TAG` | Yes | Release tag to remove. |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx tag remove secret_key_3 test-tag-1
[INFO] Removed tag test-tag-1 from secret_key_3
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx tag project`

```text
bwx tag project [OPTIONS] TAG [SECRETS...]
```

Add a release tag to multiple secrets in bulk. Without explicit
`SECRETS` or `--select-tag`, tags all secrets in the project. Uses
`BWX_SKIP_SECRET_LIST_REFRESH=true` internally for each individual
update and performs a single cache refresh at the end.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `TAG` | Yes | Release tag to add. |
| `SECRETS...` | No | Specific secrets to tag. If omitted (and no `--select-tag`), all project secrets are tagged. |

**Options:**

| Option | Description |
|--------|-------------|
| `-p`, `--project PROJECT` | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |
| `-s`, `--select-tag TAG` | Select secrets that already have this tag. Repeatable. Supplements any positional `SECRETS`. |
| `--refresh`, `-R` | Force a fresh API fetch before tagging. |

**Example:**

```console
$ bwx tag project 2026.06.24.01
[INFO] Added tag 2026.06.24.01 to secret_key_1
[INFO] Added tag 2026.06.24.01 to secret_key_2
[INFO] Added tag 2026.06.24.01 to secret_key_3
...

$ bwx tag project 2026.06.24.01 --select-tag test-tag-1
[INFO] Added tag 2026.06.24.01 to secret_key_3

$ bwx tag project 2026.06.24.01 secret_key_1 secret_key_2
[INFO] Added tag 2026.06.24.01 to secret_key_1
[INFO] Added tag 2026.06.24.01 to secret_key_2
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx tag unproject`

```text
bwx tag unproject [OPTIONS] TAG [SECRETS...]
```

Remove a release tag from multiple secrets in bulk. Without explicit
`SECRETS` or `--select-tag`, removes the tag from all secrets in the
project that have it. Only secrets that actually carry the specified tag
are modified.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `TAG` | Yes | Release tag to remove. |
| `SECRETS...` | No | Specific secrets to untag. If omitted (and no `--select-tag`), all project secrets with the tag are untagged. |

**Options:**

| Option | Description |
|--------|-------------|
| `-p`, `--project PROJECT` | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |
| `-s`, `--select-tag TAG` | Select secrets that already have this tag. Repeatable. |
| `--refresh`, `-R` | Force a fresh API fetch before untagging. |

**Example:**

```console
$ bwx tag unproject test-tag-1
[INFO] Removed tag test-tag-1 from secret_key_3

$ bwx tag unproject tag-b secret_key_6
[INFO] Removed tag tag-b from secret_key_6
```

[**↑ Contents**](#bwx-subcommand-reference)

---

### `raw`

```text
bwx raw [bws-args...]
```

Pass-through to the upstream `bws` binary (or Docker-wrapped equivalent).
All arguments are forwarded without modification. Useful for accessing
`bws` subcommands that `bwx` does not wrap.

**Example:**

```console
$ bwx raw secret get aaaa-bbbb-cccc-dddd --output json
{
  "id": "aaaa-bbbb-cccc-dddd",
  "key": "secret_key_1",
  "value": "secret_value_1",
  ...
}

$ bwx raw project list --output json
[...]
```

[**↑ Contents**](#bwx-subcommand-reference)

---

### `completion`

```text
bwx completion bash
bwx completion zsh
```

Print shell completion definitions to stdout. Supports tab completion for
all command families and subcommands.

**Setup:**

```bash
# Bash -- add to ~/.bashrc
eval "$(bwx completion bash)"

# Zsh -- add to ~/.zshrc
eval "$(bwx completion zsh)"
```

[**↑ Contents**](#bwx-subcommand-reference)

---

## Structured note metadata

`bwx` stores structured metadata in the BWS note field using a
line-oriented format. Each property occupies a single line with the
pattern `key: value`.

### Properties

| Property | Cardinality | Description |
|----------|-------------|-------------|
| `file:` | Single-value | Maps the secret to a deployment filename. Used by tools like `import-secrets` to write the secret value to disk at the given path. |
| `note:` | Single-value | Human-readable description of the secret's purpose. |
| `expires:` | Single-value | Expiration date for time-limited credentials (ISO 8601 date, for example `2026-09-20`). Used by pre-release gates to block deployments when a credential is nearing expiry. |
| `release-tag:` | Multi-value | One or more release identifiers binding the secret to specific deployments. Each tag is a separate `release-tag:` line. |

### Example note

```text
file: mosquitto-password
note: MQTT broker authentication credential
expires: 2026-09-20
release-tag: 2026.06.01.01
release-tag: 2026.06.24.01
```

### Parsing patterns

Extract the `file:` property:

```bash
bwx secret filename my_secret_v1
```

Extract `release-tag:` values:

```bash
bwx secret tags my_secret_v1
```

Parse from raw note text:

```bash
# Single-value property
bwx secret note my_secret_v1 | grep '^file:' | sed 's/^file: //'

# Multi-value property
bwx secret note my_secret_v1 | grep '^release-tag:' | awk '{print $2}'
```

### Multi-value vs single-value

- **Single-value properties** (`file:`, `expires:`, `note:`) appear at most
  once per note. When updated via `bwx secret set filename`, the existing
  line is replaced.
- **Multi-value properties** (`release-tag:`) can appear multiple times.
  Lines are deduplicated via `sort --unique` when written. Use
  `bwx tag add` and `bwx tag remove` to manage individual entries.

## Caching

`bwx` caches Bitwarden API responses locally to reduce API calls and
improve performance.

### Cache layers

1. **Environment variable cache** -- secret lists are stored in
   shell variables named `BWS_PROJECT_SECRET_LIST_<PROJECT>` (project
   name uppercased, non-alphanumeric characters replaced with
   underscores). This cache lives only for the duration of the shell
   session.

2. **File cache** -- JSON responses are persisted to disk at
   `${BWX_CACHE_DIR}` (default:
   `${XDG_CACHE_HOME:-$HOME/.cache}/1121-citrus/bws/`). Files are
   keyed by a SHA-256 hash of the server URL, access token, and
   project identifier.

### TTL

Both cache layers use the same TTL, controlled by
`BWX_SECRET_LIST_CACHE_TTL_SECONDS` (default: 300 seconds / 5 minutes).
Set to `0` to disable file caching entirely. The environment variable
cache is always populated.

### Forced refresh

Pass `--refresh` (or `-R`) to any `list` command to bypass both cache
layers and fetch fresh data from the Bitwarden API:

```bash
bwx secret list --refresh
bwx project list --refresh
```

Mutating commands (`secret create`, `secret set *`, `tag add`,
`tag remove`, `tag project`, `tag unproject`, `secret clone`)
automatically refresh the cache after a successful update.

### Cache file permissions

Cache files are created with mode `0600` inside a directory with mode
`0700`. The cache directory is created automatically on first use.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BWS_ACCESS_TOKEN` | (required) | Bitwarden Secrets Manager machine-account access token. Validated on first API call; the validation result is cached for `BWX_VALIDATE_ACCESS_TTL_SECONDS`. |
| `BWX_DEFAULT_PROJECT` | (none) | Default project name for all commands. When set, the `[PROJECT]` argument can be omitted from every subcommand. |
| `BWS_SERVER_BASE_URL` | `https://vault.bitwarden.com` | Bitwarden server URL. Override for self-hosted instances. |
| `BWX_SECRET_LIST_CACHE_TTL_SECONDS` | `300` | TTL in seconds for secret-list and project-list file caches. Set to `0` to disable file caching. |
| `BWX_VALIDATE_ACCESS_TTL_SECONDS` | `300` | TTL in seconds for caching access-token validation results. |
| `BWX_CACHE_DIR` | `${XDG_CACHE_HOME:-$HOME/.cache}/1121-citrus/bws` | Override the cache directory location. |
| `BWX_JQ_IMAGE` | `apteno/alpine-jq` | Docker image used for `jq` when `jq` is not natively installed. |
| `BWX_BWS_IMAGE` | `bitwarden/bws:latest` | Docker image used for `bws` when `bws` is not natively installed. |
| `BWS_IMAGE` | `bitwarden/bws` | Docker image name used by the internal `bws` wrapper (without tag). |
| `BWS_IMAGE_TAG` | `latest` | Docker image tag used by the internal `bws` wrapper. |
| `BWS_CONFIG_FILE` | (auto-generated) | Path to a `bws` config file. If unset, a temporary config is generated from `BWS_SERVER_BASE_URL`. |
| `DEBUG` | `false` | Enable verbose and xtrace output for all commands. Accepts `true`, `1`, `yes`, `on`, `t`, `y`. |
| `LOG_LEVEL` | `info` | Logging verbosity. Available levels: `error`, `warn`, `info`, `debug`, `trace`, `diag`. Can also be set per-command with `--log-level`. |
