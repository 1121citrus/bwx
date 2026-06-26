<!-- markdownlint-disable MD013 -->

# bwx subcommand reference

Complete reference for `bwx` 1.0.0, a Bitwarden Secrets Manager extended CLI.

- [bwx subcommand reference](#bwx-subcommand-reference)
  - [Installation](#installation)
    - [Clone to `~/.local/lib/bwx`](#clone-to-locallibbwx)
    - [Homebrew](#homebrew)
    - [Vendor dependency](#vendor-dependency)
  - [Subcommand reference](#subcommand-reference)
    - [`secret` family](#secret-family)
      - [`bwx secret get`](#bwx-secret-get)
      - [`bwx secret set`](#bwx-secret-set)
      - [`bwx secret list`](#bwx-secret-list)
      - [`bwx secret show`](#bwx-secret-show)
      - [`bwx secret ls`](#bwx-secret-ls)
      - [`bwx secret create`](#bwx-secret-create)
      - [`bwx secret clone`](#bwx-secret-clone)
      - [`bwx secret delete`](#bwx-secret-delete)
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
    - [`import` family](#import-family)
      - [`bwx import`](#bwx-import)
    - [`check` family](#check-family)
      - [`bwx check expiry`](#bwx-check-expiry)
    - [`rotate` family](#rotate-family)
      - [`bwx rotate`](#bwx-rotate)
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

### Homebrew

```bash
brew tap 1121citrus/bwx https://github.com/1121citrus/bwx
brew install --HEAD bwx
eval "$(bwx completion bash)"
```

The Homebrew formula is currently a HEAD install until a versioned source
archive is published. After a tagged release exists, the formula can be
updated with the release archive URL and SHA-256 checksum.

macOS ships Bash 3.2, which is too old for `bwx`. Install an updated bash and put it first in `PATH`:

```bash
brew install bash
export PATH="$(brew --prefix)/bin:${PATH}"
```

If you prefer pkgsrc/pkgin, use:

```bash
pkgin install bash
export PATH="/opt/pkg/bin:${PATH}"
```

Then make sure `bash --version` reports Bash 4 or newer before running `bwx`.

Or install from a local clone:

```bash
brew install --HEAD --formula ./install/homebrew/Formula/bwx.rb
```

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

#### `bwx secret get`

```text
bwx secret get [options] PROPERTY SECRET [PROJECT]
```

Get a property of a secret.

**Properties:**

| Property | Description |
|----------|-------------|
| `value` | Secret value |
| `note` | Full note text |
| `id` | Secret UUID |
| `key` | Secret key name |
| `name` | Display name (alias for key) |
| `filename` | The `file:` property from the note |
| `tags` | Release tags (one per line) |
| `expires` | The `expires:` date from the note |
| `provider` | The `provider:` name from the note |

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROPERTY` | Yes | Property to retrieve |
| `SECRET` | Yes | Secret name or UUID |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `-R`, `--refresh` | Force a fresh API fetch, bypassing the cache |

**Example:**

```console
$ bwx secret get value secret_key_1
secret_value_1

$ bwx secret get note secret_key_3
file: test-secret-1
note: "A test secret"
release-tag: test-tag-1

$ bwx secret get id secret_key_1
aaaa-bbbb-cccc-dddd

$ bwx secret get tags secret_key_6
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

#### `bwx secret delete`

```text
bwx secret delete SECRET [PROJECT]
```

Delete a secret by name or UUID.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes | Secret name or UUID |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx secret delete old_api_key_v1
[INFO] Deleted secret 'old_api_key_v1' (uuid-here)
```

[**↑ Contents**](#bwx-subcommand-reference)

---

#### `bwx secret set`

```text
bwx secret set [options] PROPERTY SECRET VALUE [PROJECT]
```

Set a property of a secret.

**Properties:**

| Property | Description |
|----------|-------------|
| `value` | Secret value (`--from-file` supported) |
| `note` | Full note text (`--from-file` supported) |
| `key` | Secret key name |
| `filename` | The `file:` property in the note |

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `PROPERTY` | Yes | Property to set |
| `SECRET` | Yes | Secret name or UUID |
| `VALUE` | Yes (unless `--from-file` or `--force`) | New value |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option             | Description                    |
|--------------------|--------------------------------|
| `--from-file FILE` | Read the new value from FILE   |
| `--force`          | Allow setting an empty value   |

**Example:**

```console
$ bwx secret set value secret_key_1 "new_password"
[INFO] Updated value for 'secret_key_1'

$ bwx secret set filename secret_key_3 "new-config.env"
[INFO] Updated filename for 'secret_key_3' to 'new-config.env'

$ bwx secret set --force note secret_key_1 ""
[INFO] Updated note for 'secret_key_1'
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

### `import` family

#### `bwx import`

```text
bwx import [options] TAG OUTPUT_DIR [PROJECT]
```

Export all secrets tagged with TAG from a Bitwarden Secrets Manager
project into OUTPUT_DIR.  Each secret with a matching `release-tag:`
note entry is written as a file named by its `file:` property, with
values stored in `.by-uuid/<id>` and symlinks from the file names.

The `.raw/` directory stores the raw secret JSON for each exported secret,
using the secret UUID as the filename. `.raw/MANIFEST` maps each UUID back
to the original secret key so path-like keys cannot escape the output tree
and users can still inspect or consume the raw archive.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `TAG` | Yes | Release tag to match (or `all` for every secret) |
| `OUTPUT_DIR` | Yes | Target directory for exported files |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Example:**

```console
$ bwx import 2026.06.24.01 .secrets
[INFO] Importing secrets from project 'my-project' [uuid] release '2026.06.24.01' to '.secrets'
[INFO] Exported 'tailscale_authkey_v1' to '.secrets/tailscale-authkey'
[INFO] Export completed
```

[**↑ Contents**](#bwx-subcommand-reference)

---

### `check` family

#### `bwx check expiry`

```text
bwx check expiry [options]
```

Check for secrets with upcoming or past expiration dates.  Reads the
`expires: YYYY-MM-DD` field from each secret's note.  Secrets without
an `expires:` field are silently skipped.

**Options:**

| Option | Description |
|--------|-------------|
| `--exit-on-expiring` | Exit 1 if any expired or soon-expiring secrets found |
| `--warn-days DAYS` | Warning window in days (default: 14) |

**Example:**

```console
$ bwx check expiry
[INFO] tailscale_server_authkey_v1: expires 2026-09-20 (87 days)
[INFO] github_token_v1: expires 2027-06-01 (344 days)
[INFO] No secrets expiring within 14 days. Safe to tag.
```

[**↑ Contents**](#bwx-subcommand-reference)

---

### `rotate` family

#### `bwx rotate`

```text
bwx rotate [options] SECRET [PROJECT]
bwx rotate --all [PROJECT]
```

Rotate a time-limited secret using its provider driver.  The provider
is determined by the `provider:` field in the secret's BWS note.
When no provider is set, the generic `prompt` driver asks the operator
to paste a new value.

**Arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `SECRET` | Yes (unless `--all`) | Secret name or UUID |
| `PROJECT` | No | Project name or UUID. Defaults to `BWX_DEFAULT_PROJECT`. |

**Options:**

| Option | Description |
|--------|-------------|
| `--all` | Rotate all secrets with an `expires:` field |
| `--dry-run` | Show what would be done without making changes |

**Built-in providers:**

| Provider | Automation | Description |
|----------|------------|-------------|
| `tailscale-oauth` | Fully automated | OAuth client credentials |
| `tailscale-manual` | Operator-prompted | Paste key from admin console |
| `github-pat` | Operator-prompted | Paste token from developer settings |
| `prompt` | Operator-prompted | Generic paste-a-value (default fallback) |

**Example:**

```console
$ bwx rotate tailscale_sidecar_authkey_v1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO] Rotating tailscale_sidecar_authkey_v1 (provider: tailscale-oauth)
[INFO] Authenticating with Tailscale OAuth...
[INFO] Creating new tagged pre-auth key...
[INFO] Updating BWS secret tailscale_sidecar_authkey_v1
[INFO] tailscale_sidecar_authkey_v1 rotated successfully (expires 2026-09-24)
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
| `file:` | Single-value | Maps the secret to a deployment filename. Used by `bwx import` to write the secret value to disk at the given path. |
| `note:` | Single-value | Human-readable description of the secret's purpose. |
| `expires:` | Single-value | Expiration date for time-limited credentials (ISO 8601 date, for example `2026-09-20`). Used by `bwx check expiry` to detect upcoming expirations. |
| `provider:` | Single-value | Rotation provider driver name (e.g., `tailscale-oauth`, `github-pat`). Used by `bwx rotate` to determine how to generate a new credential. Falls back to `prompt` if not set. |
| `release-tag:` | Multi-value | One or more release identifiers binding the secret to specific deployments. Each tag is a separate `release-tag:` line. |

### Example note

```text
file: mosquitto-password
note: MQTT broker authentication credential
expires: 2026-09-20
provider: prompt
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
   `${XDG_CACHE_HOME:-$HOME/.cache}/bwx/`). Files are
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
| `BWX_CACHE_DIR` | `${XDG_CACHE_HOME:-$HOME/.cache}/bwx` | Override the cache directory location. |
| `BWX_JQ_IMAGE` | `apteno/alpine-jq` | Docker image used for `jq` when `jq` is not natively installed. |
| `BWX_BWS_IMAGE` | `bitwarden/bws:latest` | Docker image used for `bws` when `bws` is not natively installed. |
| `BWS_IMAGE` | `bitwarden/bws` | Docker image name used by the internal `bws` wrapper (without tag). |
| `BWS_IMAGE_TAG` | `latest` | Docker image tag used by the internal `bws` wrapper. |
| `BWS_CONFIG_FILE` | (auto-generated) | Path to a `bws` config file. If unset, a temporary config is generated from `BWS_SERVER_BASE_URL`. |
| `DEBUG` | (unused) | Retained for compatibility; does not enable shell xtrace. Secret-handling commands deliberately avoid xtrace. Use `LOG_LEVEL=debug` or `LOG_LEVEL=trace` for verbose diagnostics. |
| `LOG_LEVEL` | `info` | Logging verbosity. Available levels: `error`, `warn`, `info`, `debug`, `trace`, `diag`. Can also be set per-command with `--log-level`. |
| `LOGGING_INCLUDE_ALL` | `false` | Include timestamp, command name, and caller location in each log line. |
| `LOGGING_INCLUDE_TIMESTAMP` | `false` | Include timestamp in each log line prolog. |
| `LOGGING_INCLUDE_COMMAND` | `false` | Include command name in each log line prolog. |
| `LOGGING_INCLUDE_LOCATION` | `false` | Include caller function and line in each log line prolog. |
| `LOGGING_INCLUDE_LOCATION_FILE` | `false` | When location is enabled, include filename in the location field. |
| `LOG_DATE_FORMAT` | `%Y%m%dT%H%M%S` | Timestamp format used when timestamp output is enabled. |

See [logging.md](logging.md) for a complete logging
library reference.
