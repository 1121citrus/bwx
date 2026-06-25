# bwx — Bitwarden Secrets Manager eXtended CLI

A bash CLI that extends the
[Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/)
`bws` binary with the tooling needed to manage secrets across a
release lifecycle: bulk tagging, versioned cloning, structured
metadata, expiry tracking, and provider-driven rotation.

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
- **Rotation** — provider-driven rotation with built-in drivers for
  Tailscale and GitHub, and a generic prompt fallback for anything
  else
- **Versioned cloning** — `clone` increments `_v1` → `_v2` for safe
  key rotation with downgrade support
- **Caching** — TTL-based local cache for API responses; one API
  call per session, not per command
- **Zero install dependencies** — bash + Docker; `jq` and `bws` are
  wrapped via Docker containers when not natively installed

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
   the secret's note and calls the matching driver.  Built-in
   providers handle Tailscale OAuth, Tailscale manual, GitHub PATs,
   and a generic paste-a-value prompt.  The framework updates the
   BWS value, sets the new `expires:` date, and preserves all other
   metadata.

Secrets that do not expire (database passwords, SSH keys, GPG
passphrases) skip steps 5–6 entirely.  They are tagged and imported
like any other secret but have no `expires:` or `provider:` metadata.

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

## Commands

### Secret commands

```text
bwx secret get PROP SECRET   Get a property (value, note, id, key, filename, tags, ...)
bwx secret set PROP SECRET V Set a property (value, note, key, filename)
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
bwx rotate SECRET            Rotate via provider driver
bwx rotate --all             Rotate all expiring secrets
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

## Installation

### Clone

```bash
git clone https://github.com/1121citrus/bwx.git ~/.local/lib/bwx
export PATH="${HOME}/.local/lib/bwx/bin:${PATH}"
eval "$(bwx completion bash)"
```

### Homebrew

```bash
brew tap 1121citrus/bwx https://github.com/1121citrus/bwx
brew install bwx
```

On macOS the system shell is Bash 3.2. If installed via Homebrew, ensure the Homebrew bash is first in your `PATH`:

```bash
brew install bash
export PATH="$(brew --prefix)/bin:${PATH}"
```

If you use pkgsrc/pkgin instead of Homebrew, install Bash with:

```bash
pkgin install bash
export PATH="/opt/pkg/bin:${PATH}"
```

Then verify the shell version:

```bash
bash --version
```

### Vendor dependency

```bash
git clone --branch v1.0.0 https://github.com/1121citrus/bwx.git vendor/bwx
export PATH="${PWD}/vendor/bwx/bin:${PATH}"
```

### Prerequisites

- **Bash 4.0+** (macOS ships 3.2 — install a newer shell with Homebrew or pkgin)
- **Docker** — only when `jq` or `bws` are not natively installed

## Documentation

- [Full subcommand reference](doc/usage.md) — every command with
  examples and expected output
- [Extending bwx](doc/extending.md) — architecture, adding
  subcommands, adding note properties, rotation providers
- [Security policy](SECURITY.md) — attack surface, dependency
  scanning, token handling

## License

[AGPL-3.0-or-later](LICENSE.md)
