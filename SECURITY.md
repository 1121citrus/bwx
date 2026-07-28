# Security policy

## Reporting a vulnerability

Report security vulnerabilities through the
[GitHub Security tab](https://github.com/1121citrus/bwx/security).
Do not open a public GitHub issue for security vulnerabilities.

---

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.3.x   | Yes       |
| 1.2.x   | No — upgrade to 1.3.x |
| Older   | No — upgrade to latest |

---

## Attack surface

`bwx` is a pure-bash CLI with no compiled code.  Its attack surface
comes entirely from its runtime dependencies:

| Dependency | Source | Used when | Security concern |
| ---------- | ------ | --------- | ---------------- |
| **bash** (4.0+) | System package | Always | OS-level updates; no bwx-specific risk |
| **jq** | Native or Docker `apteno/alpine-jq` | Parsing BWS API JSON | Docker image may contain Alpine CVEs |
| **bws** | Native or Docker `bitwarden/bws` | All BWS API operations | Docker image may contain OS/binary CVEs |
| **curl** | Native or Docker `curlimages/curl` | Provider calls, HTTP fallback | Docker image may contain Alpine CVEs |
| **openssl** | Native or Docker `alpine/openssl` | Self-signed cert generation | Docker image may contain Alpine CVEs |
| **aws** | Native or Docker `amazon/aws-cli` | IAM key rotation (`aws-iam`) | Docker image may contain AL2 CVEs |

### Docker image pins

When native `jq`, `bws`, or `curl` are not installed, `bwx` falls back
to Docker-wrapped alternatives.  The default image references are:

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `BWX_JQ_IMAGE` | `apteno/alpine-jq` | jq wrapper |
| `BWX_BWS_IMAGE` | `bitwarden/bws:latest` | Bitwarden CLI wrapper |
| `BWX_CURL_IMAGE` | `curlimages/curl` | HTTP client and provider API calls |
| `BWX_OPENSSL_IMAGE` | `alpine/openssl` | TLS certificate generation |
| `BWX_AWS_IMAGE` | `amazon/aws-cli` | AWS IAM key rotation |

To pin a specific image version (recommended for production):

```bash
export BWX_JQ_IMAGE="apteno/alpine-jq:2023-01-01"
export BWX_BWS_IMAGE="bitwarden/bws:2025.1.0"
export BWX_CURL_IMAGE="curlimages/curl:8.11.1"
export BWX_OPENSSL_IMAGE="alpine/openssl:3.4.1"
export BWX_AWS_IMAGE="amazon/aws-cli:2.27.0"
```

### Scanning

Stage 4 of the build scans all dependency images for HIGH and
CRITICAL CVEs using Trivy:

```bash
./build                    # includes dependency image scan
./build --dry-run          # shows which images would be scanned
```

The scan is advisory (does not block the build) because the
vulnerabilities are in third-party images that `bwx` cannot patch
directly.  When a CVE is found, update the default pin in
`include/tools` or `include/http`, or override via the environment
variables above.

---

## Token handling

`BWS_ACCESS_TOKEN` is passed to the `bws` CLI (or Docker container)
via environment variable.  This means:

- The token is visible in `docker inspect` output while a container
  is running (Docker wrapper only).
- The token is visible in `/proc/<pid>/environ` on Linux to
  processes running as the same user.
- The token is written to disk by `bwx` only when you ask for it,
  via `bwx config set bws-access-token`.

**Recommendations:**

- On shared hosts, prefer a native `bws` install over the Docker
  wrapper to avoid `docker inspect` exposure.
- Never persist the token in `.bashrc`, `.profile`, or any other
  shell startup file.  Those files are frequently mode `0644`, they
  are read by every interactive shell, and they are easy to commit to
  a dotfiles repository by accident.  Use `bwx config set` instead.
- Pipe the token into `bwx config set` rather than passing it as an
  argument: an argument is visible in the process table and is
  recorded in shell history.
- Use Bitwarden machine account tokens scoped to the minimum
  required project.

### Stored credential files

`bwx config set` writes to
`${BWX_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/bwx}`.  Files
holding credential material:

- Are written with mode `0600` inside a directory with mode `0700`.
- Are written through a temporary file and renamed into place, so a
  concurrent reader never observes a partial value.
- Are **refused** on read when group or other holds any permission
  bit, in the same spirit as `ssh` rejecting a world-readable private
  key.  The refusal names the file and the fix.

The permission check runs only when a file is actually read.  When the
environment already supplies the value, the file is never opened and
never inspected, so a stale over-permissive file cannot break a caller
that does not depend on it.

Non-credential entries (currently `bwx-default-project`, a project
identifier) are classified separately and are not mode-enforced.

---

## Cache file security

`bwx secret list` and `bwx project list` cache API responses in
temporary files under `${BWX_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/bwx}`.  Cache
files:

- Are readable only by the owning user (mode 0600).
- Contain secret metadata (keys, notes, UUIDs) but **not** secret
  values (values are fetched individually and not cached).
- Expire after `BWX_SECRET_LIST_CACHE_TTL_SECONDS` (default: 300).
- Are overwritten on `--refresh`.

On multi-user systems, verify that `TMPDIR` points to a
user-private directory (e.g., `/tmp/user-$(id -u)`).

---

## Defense-in-depth measures

| Measure | How |
| ------- | --- |
| No compiled code | Pure bash; no binary supply chain |
| Shellcheck clean | All scripts pass shellcheck with no suppressed warnings |
| Minimal dependencies | Only bash + Docker required; jq/bws/curl are optional native installs |
| Docker wrapper isolation | Fallback containers run with `--rm` (no persistent state) |
| Input validation | Secret names and project names are validated before passing to `bws` |
| No secrets on disk | `BWS_ACCESS_TOKEN` stays in the environment; secret values are not cached |
| Pinned CI tool versions | Build script pins shellcheck, markdownlint, kcov, and scc image tags |
