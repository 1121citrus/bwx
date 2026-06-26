# Security policy

## Reporting a vulnerability

Report security vulnerabilities through the
[GitHub Security tab](https://github.com/1121citrus/bwx/security).
Do not open a public GitHub issue for security vulnerabilities.

---

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.0.x   | Yes       |
| Older   | No — upgrade to latest |

---

## Attack surface

`bwx` is a pure-bash CLI with no compiled code.  Its attack surface
comes entirely from its runtime dependencies:

| Dependency | Source | Used when | Security concern |
| ---------- | ------ | --------- | ---------------- |
| **bash** (4.0+) | System package | Always | OS-level updates; no bwx-specific risk |
| **jq** | Native install or Docker `apteno/alpine-jq` | Parsing BWS API JSON | Docker image may contain Alpine CVEs |
| **bws** | Native or Docker `bitwarden/bws` | All BWS API operations | Docker image may contain OS/binary CVEs |
| **curl** / **wget** / **fetch** | System package | `include/http` consumers | OS-level updates |
| **Docker** `curlimages/curl` | Docker Hub | HTTP fallback (no native client) | Docker image may contain Alpine CVEs |

### Docker image pins

When native `jq`, `bws`, or `curl` are not installed, `bwx` falls back
to Docker-wrapped alternatives.  The default image references are:

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `BWX_JQ_IMAGE` | `apteno/alpine-jq` | jq wrapper |
| `BWX_BWS_IMAGE` | `bitwarden/bws:latest` | Bitwarden CLI wrapper |
| `BWX_CURL_IMAGE` | `curlimages/curl` | HTTP client fallback |

To pin a specific image version (recommended for production):

```bash
export BWX_JQ_IMAGE="apteno/alpine-jq:2023-01-01"
export BWX_BWS_IMAGE="bitwarden/bws:2025.1.0"
export BWX_CURL_IMAGE="curlimages/curl:8.11.1"
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
- The token is **not** written to disk by `bwx` itself.

**Recommendations:**

- On shared hosts, prefer a native `bws` install over the Docker
  wrapper to avoid `docker inspect` exposure.
- Set `BWS_ACCESS_TOKEN` in the current shell session only; do not
  persist it in `.bashrc` or `.profile`.
- Use Bitwarden machine account tokens scoped to the minimum
  required project.

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
