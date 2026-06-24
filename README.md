# bwx — Bitwarden Secrets Manager eXtended CLI

Extended command-line tooling for
[Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/).
The official `bws` CLI provides single-secret CRUD; `bwx` adds bulk
operations, release-tag lifecycle management, structured note metadata,
local caching, and secret cloning with automatic version increment.

## Quick start

```bash
# Clone and add to PATH
git clone https://github.com/1121citrus/bwx.git ~/.local/lib/bwx
export PATH="${HOME}/.local/lib/bwx/bin:${PATH}"

# Enable tab completion
eval "$(bwx completion bash)"

# Set your BWS access token
export BWS_ACCESS_TOKEN="your-token-here"

# List all secrets in the default project
bwx secret list

# Get a secret's value
bwx secret value my_secret_v1

# Tag all secrets for a release
bwx tag project 2026.06.24.01
```

## Prerequisites

- **Bash 4.0+** (macOS ships 3.2 — install via
  [Homebrew](https://brew.sh/): `brew install bash`)
- **Docker** — required only when `jq` or `bws` are not natively
  installed; `bwx` wraps them transparently via Docker containers

No other tools need to be installed.

## Commands

### Secret commands

```text
bwx secret list              List all secrets in a project
bwx secret show SECRET       Show full secret details
bwx secret value SECRET      Get a secret's value
bwx secret note SECRET       Get a secret's note
bwx secret id SECRET         Get a secret's UUID
bwx secret key SECRET        Get a secret's key name
bwx secret name SECRET       Get a secret's name
bwx secret filename SECRET   Get the file: property from a note
bwx secret tags SECRET       List release tags on a secret
bwx secret ls                List secrets (summary format)
bwx secret create KEY VALUE  Create a new secret
bwx secret clone SECRET      Clone with version increment (_v1 → _v2)
bwx secret set value SECRET VALUE     Set a secret's value
bwx secret set note SECRET NOTE       Set a secret's note
bwx secret set key SECRET KEY         Set a secret's key name
bwx secret set filename SECRET NAME   Set the file: note property
```

### Project commands

```text
bwx project list             List all projects
bwx project show PROJECT     Show project details
bwx project id PROJECT       Get a project's UUID
bwx project name PROJECT     Get a project's name
bwx project ls               List projects (summary format)
bwx project default id       Get the default project UUID
bwx project default name     Get the default project name
```

### Tag commands

```text
bwx tag list                 List all release tags across secrets
bwx tag secrets TAG          List secrets tagged with TAG
bwx tag add SECRET TAG       Add a release tag to a secret
bwx tag remove SECRET TAG    Remove a release tag from a secret
bwx tag project TAG          Tag all secrets in the project
bwx tag unproject TAG        Remove tag from all secrets
```

### Other commands

```text
bwx raw [bws-args...]        Pass-through to the upstream bws binary
bwx completion bash          Print bash completion definition
bwx completion zsh           Print zsh completion definition
bwx --help                   Show help
bwx --version                Show version
```

## Structured note metadata

`bwx` uses the BWS note field for structured metadata.  Each property
is a single line in YAML-like format:

```yaml
file: docker-compose-secret-filename
note: Human-readable description
expires: 2026-09-20
release-tag: 2026.06.24.01
release-tag: 2026.07.01.01
```

- **`file:`** — maps the BWS secret to a local filename (used by
  deployment tools like `import-secrets`)
- **`expires:`** — optional expiration date for time-limited
  credentials (Tailscale keys, GitHub PATs)
- **`release-tag:`** — one or more release tags binding the secret
  to specific deployments; multi-value (one per line)

## Caching

`bwx secret list` and `bwx project list` cache API responses locally
with a configurable TTL (default: 300 seconds).  Use `--refresh` to
force a fresh fetch, or set `BWS_SECRET_LIST_CACHE_TTL_SECONDS=0` to
disable caching.

## Environment variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `BWS_ACCESS_TOKEN` | (required) | Bitwarden Secrets Manager access token |
| `BWS_DEFAULT_PROJECT` | (none) | Default project name for all commands |
| `BWS_SERVER_BASE_URL` | `https://vault.bitwarden.com` | Bitwarden server URL |
| `BWS_SECRET_LIST_CACHE_TTL_SECONDS` | `300` | Cache TTL for secret/project lists |
| `BWX_JQ_IMAGE` | `apteno/alpine-jq` | Docker image for jq wrapper |
| `BWX_BWS_IMAGE` | `bitwarden/bws:latest` | Docker image for bws wrapper |

## Shell completion

```bash
# Bash — add to ~/.bashrc
eval "$(bwx completion bash)"

# Zsh — add to ~/.zshrc
eval "$(bwx completion zsh)"
```

## License

[AGPL-3.0-or-later](LICENSE.md)
