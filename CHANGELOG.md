# Changelog

## 1.1.0

### Added

- Nine new rotation providers, bringing the total from 4 to 13:
  - Automated (no TTY): `password-generate`, `mqtt-password`, `aws-iam`,
    `openssl-selfsigned`, `bitwarden-api-key`, `grafana-service-account`,
    `docker-registry`
  - Interactive (guided): `letsencrypt-manual`, `anthropic-api-key`
- Provider configuration protocol (`include/provider-config`):
  - `bwx-provider-config` — typed config field extraction from note
    metadata (string, integer with range, credential, enum)
  - `bwx-resolve-credential` — credential resolution chain supporting
    BWS secret references (`project:secret`), file paths, environment
    variables (`@env:VAR`), and literal values
  - `bwx-scrub-config-value` — input scrubbing that rejects shell
    expansion characters (`$`, backtick, `\`, newlines) from all
    config values before they reach provider code
- Docker-wrapped fallback functions for `curl`, `openssl`, and `aws`
  in `include/tools` — the repo now requires only bash and Docker
- `bwx provider info` — display provider metadata and config fields
- `bwx note validate` — validate structured note metadata
- User-facing provider guide (`doc/providers.md`) covering rotation
  workflow, credential passing protocol, scrubbing, and per-provider
  configuration reference
- Credential file path constraint — `_bwx-credential-file-allowed`
  verifies file references stay inside the secrets directory

### Changed

- Providers use `bwx-provider-config` for typed config parsing instead
  of ad-hoc `grep | sed` pipelines
- Credential-consuming providers (tailscale-oauth, bitwarden-api-key,
  docker-registry, grafana-service-account, aws-iam) support BWS
  secret references in note fields with file-based fallback for
  backward compatibility
- Build coverage uses per-file kcov runs with `kcov --merge` for
  correct per-file attribution of sourced lib files
- `openssl-selfsigned` uses `cert-role` field name (was `provider-role`)
- Note metadata enforces field-naming convention validation

### Fixed

- `bwx-rotate` now passes note contents as `$3` to providers —
  providers that read config fields (password-generate,
  openssl-selfsigned, grafana-service-account) previously received
  empty config and silently used defaults
- Credentials passed via `--header @-` stdin instead of inline
  `--header` or `--user` process arguments — prevents leakage via
  `ps` when using Docker-wrapped curl (bitwarden-api-key,
  docker-registry, grafana-service-account)
- Tailscale OAuth form body URL-encodes credential values to prevent
  corruption from `&`, `=`, or `%` characters
- Grafana service account base64 auth header strips newlines for
  portability across base64 implementations
- Temporary files use `TMPDIR`-aware templates to avoid predictable
  paths in `/tmp`
- RETURN/EXIT trap cleanup uses function references instead of quoted
  paths to avoid word-splitting issues
- BWS server URL validated against `https?://` scheme
- Traced secret arguments redacted in debug output
- Cache hash reports an error when no SHA-256 tool is available
  instead of silently falling back to weak `cksum`
- HTTP client rejects non-http(s) URLs
- `bwx raw --help` test accepts exit code 4 (Docker not found)
- Markdownlint stale TOC link in extending.md

### Security

- All provider config values scrubbed for shell metacharacters before
  reaching provider code (defense-in-depth against injection)
- Credential file references constrained to the secrets directory
  with symlink rejection
- `eval` usage in `bwx-tag-project` and `bwx-untag-project` audited
  and documented as safe (`printf %q` escaping)

## 1.0.0

### Added

- Initial public release of bwx.
- Secret lifecycle commands for create, clone, delete, list, show, get, and set.
- Project, tag, import, expiry-check, and rotation workflows.
- Structured note metadata parsing for file, expires, provider, and release-tag fields.
- Bash completion support and local build/test tooling.

### Changed

- Documented installation and usage guidance for direct install, Homebrew, and vendored usage.

### Fixed

- Aligned install examples with the current Homebrew workflow and repository layout.
