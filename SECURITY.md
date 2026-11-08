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

`bwx` is a Bash CLI with a Docker Hub distribution image. The image
bundles the CLI's runtime dependencies:

| Dependency | Source | Used when | Security concern |
| ---------- | ------ | --------- | ---------------- |
| **Ubuntu 24.04** | Docker base image | Always | OS-level updates; scanned with the final image |
| **bash** | Ubuntu package | Running the CLI | OS-level updates |
| **bws** | Official BWS 1.0.0 binary; SHA-256 verified | BWS API operations | Upstream binary vulnerabilities |
| **AWS CLI** | Pinned `amazon/aws-cli:2.27.0` image runtime | AWS IAM rotation | AWS CLI vulnerabilities |
| **jq**, **curl**, **openssl** | Ubuntu packages | Parsing, provider calls, and TLS | OS/package vulnerabilities |

The published `1121citrus/bwx` image is scanned by the release pipeline.
The host launcher mounts the current working directory, `bwx` config and
cache directories, and `~/.aws` read-only. It does not mount the Docker socket
or the host's entire home directory. Custom provider environment variables
can be supplied through `BWX_DOCKER_ENV_FILE`; keep that file mode `0600`.

### Scanning

```bash
./build
```

The shared CI pipeline scans the complete application image before
publishing a release.

---

## Token handling

`BWS_ACCESS_TOKEN` is passed into the `bwx` container as an environment
variable. This means:

- The token is visible in `docker inspect` output while the container
  is running.
- The token is visible in `/proc/<pid>/environ` on Linux to
  processes running as the same user.
- The token is written to disk by `bwx` only when you ask for it,
  via `bwx config set bws-access-token`.

**Recommendations:**

- On shared hosts, account for the container's environment visibility
  through `docker inspect` while it is running.
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
