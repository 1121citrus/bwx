# bwx — Bitwarden Secrets Manager eXtended CLI

A bash CLI that extends the
[Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/)
`bws` binary with the tooling needed to manage secrets across a
release lifecycle: bulk tagging, versioned cloning, structured
metadata, expiry tracking, and provider-driven rotation.

- [bwx — Bitwarden Secrets Manager eXtended CLI](#bwx--bitwarden-secrets-manager-extended-cli)
  - [Why bwx](#why-bwx)
  - [Intended workflow](#intended-workflow)
  - [Quick start](#quick-start)
  - [Commands](#commands)
    - [Secret commands](#secret-commands)
    - [Project commands](#project-commands)
    - [Tag commands](#tag-commands)
    - [Lifecycle commands](#lifecycle-commands)
    - [Other commands](#other-commands)
  - [Structured note metadata](#structured-note-metadata)
  - [Installation](#installation)
    - [Docker wrapper](#docker-wrapper)
    - [Run the image directly](#run-the-image-directly)
    - [Clone for development](#clone-for-development)
    - [Vendor dependency](#vendor-dependency)
    - [Prerequisites](#prerequisites)
  - [Documentation](#documentation)
  - [License](#license)

## Why bwx

The official `bws` CLI provides single-secret CRUD.  `bwx` adds
the operational layer on top:

- **Release tags** — bind secrets to deployment versions; tag or
  untag an entire project in one command
- **Structured metadata** — `file:`, `expires:`, `provider:`, and
  `release-tag:` fields in the BWS note, parsed and validated by
  `bwx` commands
- **Import** — export all tagged secrets to a deployment directory
  with symlinks and UUID-based storage
- **Expiry checking** — pre-release gate that blocks deployments
  when credentials are near expiration
- **Rotation** — provider-driven rotation with 13 built-in drivers
  (8 fully automated, 5 interactive) covering AWS IAM, Tailscale,
  GitHub, Docker Hub, Grafana, Bitwarden, TLS certificates, MQTT,
  random passwords, and a generic prompt fallback
- **Versioned cloning** — `clone` increments `_v1` → `_v2` for safe
  key rotation with downgrade support
- **Caching** — TTL-based local cache for API responses; one API
  call per session, not per command
- **Portable Docker distribution** — the Docker Hub image includes
  Bash, `bws`, `jq`, `curl`, `openssl`, and AWS CLI; no host Bash
  upgrade or separate tool installation is required

## Intended workflow

`bwx` is process-agnostic but tilted toward a specific operational
pattern:

```text
develop → tag → import → deploy → rotate (on schedule)
                  ↑                    |
                  └────── check ───────┘
```

1. **Develop** — secrets are created and updated in BWS via `bwx
   secret create`, `bwx secret set value`, etc.  Each secret's note
   carries `file:` (deployment filename) and `release-tag:` entries.

2. **Tag** — before a release, `bwx tag project 2026.07.01.01` stamps
   every secret in the project with the release tag.  Old tags are
   preserved for downgrade.

3. **Import** — at deployment time, `bwx import 2026.07.01.01 .secrets`
   exports exactly the secrets tagged for that release.  Each secret
   becomes a file named by its `file:` property, with values stored
   in `.by-uuid/` for deduplication.

4. **Deploy** — the application reads secrets from `.secrets/` (Docker
   secrets, env files, mounted volumes — whatever the app expects).

5. **Check** — `bwx check expiry --exit-on-expiring` runs as a
   pre-release gate.  Secrets with an `expires:` date within the
   warning window (default: 14 days) block the release until rotated.

6. **Rotate** — `bwx rotate SECRET` reads the `provider:` field from
   the secret's note and calls the matching driver.  Automated
   providers (password-generate, aws-iam, openssl-selfsigned,
   mqtt-password, tailscale-oauth, bitwarden-api-key,
   grafana-service-account, docker-registry) run without operator
   input; interactive providers (github-pat, anthropic-api-key,
   letsencrypt-manual, tailscale-manual, prompt) guide the operator
   through a paste-and-validate flow.  The framework updates the BWS
   value, sets the new `expires:` date, and preserves all other
   metadata.  Provider credentials can be stored as BWS secrets
   themselves (`project:secret` references), read from files, or
   passed via environment variables.  See
   [doc/providers.md](doc/providers.md) for the full reference.

Secrets that do not expire (SSH keys, GPG passphrases) skip steps
5–6 entirely.  They are tagged and imported like any other secret
but have no `expires:` or `provider:` metadata.  Secrets like
database passwords that *should* rotate can now use the
`password-generate` provider for fully automated rotation.

## Quick start

```bash
export BWS_ACCESS_TOKEN="your-token-here"

bwx secret get value my_secret_v1       # get a value
bwx secret set value my_secret_v1 "pw"  # set a value
bwx tag project 2026.07.01.01           # tag all secrets
bwx import 2026.07.01.01 .secrets       # export to disk
bwx check expiry                        # any expiring?
bwx rotate --all                        # rotate what's due
```

For unattended callers (cron, `ssh host command`, systemd), store the
token instead of exporting it — a non-interactive shell never reads
past the interactive guard in `~/.bashrc`, so an exported token is
invisible to exactly the automation that needs it:

```bash
pbpaste | bwx config set bws-access-token   # stored at mode 0600
bwx config list                             # what resolves from where
```

## Commands

### Secret commands

```text
bwx secret get PROP SECRET   Get a property (value, note, id, key, filename, tags, mode, ...)
bwx secret set PROP SECRET V Set a property (value, note, key, filename, mode)
bwx secret list              List all secrets in a project (JSON)
bwx secret show SECRET       Show full secret details (JSON)
bwx secret ls                List secrets (summary format)
bwx secret create KEY VALUE  Create a new secret
bwx secret clone SECRET      Clone with version increment (_v1 → _v2)
bwx secret delete SECRET     Delete a secret
```

### Project commands

```text
bwx project list             List all projects
bwx project show PROJECT     Show project details
bwx project id PROJECT       Resolve name to UUID
bwx project name PROJECT     Resolve UUID to name
bwx project ls               List projects (summary)
bwx project default id       Default project UUID
bwx project default name     Default project name
```

### Tag commands

```text
bwx tag project TAG          Tag all secrets in the project
bwx tag unproject TAG        Remove tag from all secrets
bwx tag add SECRET TAG       Tag one secret
bwx tag remove SECRET TAG    Untag one secret
bwx tag list                 List all tags
bwx tag secrets TAG          List secrets with TAG
```

### Lifecycle commands

```text
bwx import TAG DIR [PROJECT] Export tagged secrets to a directory
bwx check expiry [--exit-on-expiring]  Pre-release expiry gate
bwx note validate SECRET     Validate note fields and provider config
bwx rotate SECRET            Rotate via provider driver
bwx rotate --all             Rotate all expiring secrets
```

### Provider commands

```text
bwx provider info NAME       Show expected config fields for a provider
bwx provider info --list     List all available providers
```

### Config commands

```text
bwx config list              Show entries and which source is effective
bwx config path [NAME]       Print the config directory or one file path
bwx config get NAME          Print a stored value
bwx config set NAME [VALUE]  Store a value (reads stdin when VALUE omitted)
```

### Other commands

```text
bwx raw [bws-args...]        Pass-through to upstream bws
bwx completion bash          Bash tab completion
bwx completion zsh           Zsh tab completion
```

## Structured note metadata

Each secret's BWS note carries structured properties:

```yaml
file: app-password
note: Database credential for the web service
expires: 2026-09-20
provider: prompt
release-tag: 2026.06.24.01
release-tag: 2026.07.01.01
```

| Property | Purpose |
| -------- | ------- |
| `file:` | Deployment filename (used by `bwx import`) |
| `expires:` | Expiration date (checked by `bwx check expiry`) |
| `provider:` | Rotation driver (used by `bwx rotate`) |
| `release-tag:` | One or more deployment version bindings |
| `mode:` | Octal file mode for `bwx import` (e.g. `0644` for a non-root container mount); defaults to `0600` |

## Installation

### Docker wrapper

```bash
mkdir -p "${HOME}/.local/bin" && \
curl -fsSL \
  https://raw.githubusercontent.com/1121citrus/bwx/main/install/bwx \
  -o "${HOME}/.local/bin/bwx" && \
chmod 0755 "${HOME}/.local/bin/bwx"
```

Add `${HOME}/.local/bin` to `PATH` if it is not already present. The
wrapper pulls `1121citrus/bwx:latest` on first use and runs it as your
host user. It mounts the current directory, the `bwx` config and cache
directories, and `~/.aws` when present. Interactive commands and shell
completion work through the wrapper.

```bash
export BWS_ACCESS_TOKEN="your-token-here"
bwx secret list
bwx completion bash
```

Set `BWX_DOCKER_IMAGE` to pin a release or use a private mirror:

```bash
export BWX_DOCKER_IMAGE="1121citrus/bwx:1.3.2"
```

For provider credentials supplied through custom environment variables,
put them in a mode-`0600` file and set `BWX_DOCKER_ENV_FILE` to its
path. Standard BWS, AWS, and `bwx` environment variables are forwarded
by the wrapper.

### Run the image directly

The wrapper is recommended because it maps the working directory,
configuration, cache, AWS credentials, host user, and terminal. For
direct use, mount the working directory at the same path:

```bash
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --volume "${PWD}:${PWD}" \
  --workdir "${PWD}" \
  --env BWS_ACCESS_TOKEN \
  1121citrus/bwx:latest secret list
```

### Clone for development

```bash
git clone https://github.com/1121citrus/bwx.git ~/.local/lib/bwx
export PATH="${HOME}/.local/lib/bwx/bin:${PATH}"
eval "$(bwx completion bash)"
```

Running from a source checkout requires Bash 4 or newer. The Docker
wrapper does not require Bash 4 on the host.

### Vendor dependency

```bash
git clone https://github.com/1121citrus/bwx.git vendor/bwx
export PATH="${PWD}/vendor/bwx/bin:${PATH}"
```

Pin the checkout to a tag or commit when you need reproducible vendoring.

### Prerequisites

- **Docker Desktop or Docker Engine** — required by the Docker wrapper
- **curl** — required only to download the wrapper
- **Bash 4.0+** — required only when running directly from a source checkout

## Documentation

- [Full subcommand reference](doc/usage.md) — every command with
  examples and expected output
- [Rotation providers](doc/providers.md) — provider reference,
  credential passing, config fields, and input scrubbing
- [Extending bwx](doc/extending.md) — architecture, adding
  subcommands, adding note properties, writing custom providers
- [Include modules](include/README.md) — shared runtime modules used by
  `bin/bwx`
- [Logging configuration](doc/logging.md) — log levels, prolog
  controls, and status constants
- [Security policy](SECURITY.md) — attack surface, dependency
  scanning, token handling

## License

[AGPL-3.0-or-later](LICENSE.md)
