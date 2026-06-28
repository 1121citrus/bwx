# Include directory

Reusable bash modules loaded by `bin/bwx` at startup. Each module is
sourced once per session; subsequent calls reuse the already-defined
functions.

## Modules

### `bwx-cache`

TTL-based file cache for project and secret list API responses.

| Function | Description |
|----------|-------------|
| `bwx-cache-dir` | Return (and create) the cache directory path |
| `bwx-cache-hash` | SHA-256 hash of concatenated arguments |
| `bwx-cache-file` | Build a cache file path from namespace + key |
| `bwx-cache-mtime` | Modification time of a file as epoch seconds |
| `bwx-cache-is-fresh` | Test whether a cache file is within its TTL |
| `bwx-cache-read` | Read a cache file if still fresh |
| `bwx-cache-write` | Atomic write with 0600 permissions |
| `bwx-cache-delete` | Remove a cache file and temp fragments |

### `http`

Portable HTTP client abstraction with automatic backend selection.

| Function | Description |
|----------|-------------|
| `http_get` | GET a URL, write response body to stdout |
| `http_download` | GET a URL, save response body to a file |
| `http_backend` | Return the name of the resolved backend |

Backend resolution order: `curl` → `wget` → `fetch` → Docker
(`curlimages/curl`). Override with `HTTP_BACKEND=<name>`.

### `logging`

Leveled logging, exit/return code constants, and traceback support.

| Function | Description |
|----------|-------------|
| `diag` / `diagnostic` | Diagnostic-level message (most verbose) |
| `trace` | Trace-level message |
| `debug` | Debug-level message |
| `info` / `information` | Informational message |
| `notice` | Notice-level message |
| `warn` | Warning message |
| `error` | Error message (logs and exits) |
| `error-return` | Error message (logs and returns, does not exit) |
| `fatal` / `die` | Fatal message (logs and exits immediately) |
| `log` | Log at an explicit severity level |
| `log-and-exit` | Log and exit with a given status |
| `log-level` | Get or set the current log level |
| `log-level-enabled` | Test whether a log level is active |
| `validate-log-level` | Validate a log level string |
| `validate-exit-status` | Validate an exit status code |
| `is-true` / `is-false` | Boolean string evaluation |
| `exit-status-name` | Human-readable name for an exit code |
| `return-status-name` | Human-readable name for a return code |
| `log-traceback` | Print a stack trace |
| `log-traceback-trap` | ERR trap handler for automatic tracebacks |
| `logging-prolog` | Format the log line prefix |
| `logging-severity` | Return the numeric severity for a level name |
| `logging-exit-fatally` | Exit handler for fatal conditions |
| `logging-get-external-caller` | Identify the caller outside the logging module |

Constants: `EXIT_SUCCESS`, `EXIT_FAILURE`, `EXIT_ERROR`, `EXIT_USAGE`,
`EXIT_CONFIG`, `EXIT_NOTFOUND`, `EXIT_FATAL`, and corresponding
`RETURN_*` codes.

Full configuration reference: [logging.md](logging.md)

### `note-parser`

Centralized parser for BWS structured note metadata (`key: value`
format, one field per line).

| Function | Description |
|----------|-------------|
| `bwx-note-get-field` | Extract a single-value field from a note |
| `bwx-note-get-multi-field` | Extract all values for a multi-value field |
| `bwx-note-set-field` | Replace or append a field in a note |
| `bwx-note-remove-field` | Remove all lines matching a field name |
| `bwx-note-release-tag-jq-filter` | jq function definitions for release-tag parsing |

Validators (private):

| Function | Description |
|----------|-------------|
| `_bwx_note_validate_field` | Dispatch validation by field type |
| `_bwx_note_validate_path` | Reject path traversal in `file:` values |
| `_bwx_note_validate_date` | Check YYYY-MM-DD format for `expires:` |
| `_bwx_note_validate_identifier` | Check `[A-Za-z0-9._-]+` for `provider:` and `release-tag:` |

### `path`

Portable path resolution helpers for startup and dispatch.

| Function | Description |
|----------|-------------|
| `bwx-realpath` | Resolve a path to its physical absolute form |
| `bwx-script-dir` | Return the directory of the calling script |

### `provider-config`

Configuration parsing, credential resolution, and input scrubbing
for rotation providers.

| Function | Description |
|----------|-------------|
| `bwx-scrub-config-value` | Reject shell expansion characters (`$`, `` ` ``, `\`, newlines) |
| `bwx-resolve-credential` | Resolve credential references (BWS `project:secret`, file path, `@env:VAR`, literal) |
| `bwx-provider-config` | Typed config field extraction from note text (string, integer, credential, enum) |

Helpers (private):

| Function | Description |
|----------|-------------|
| `_bwx-absolute-path` | Resolve a physical absolute path |
| `_bwx-credential-file-allowed` | Verify a file stays inside the secrets directory |
| `_bwx_provider_fields` | Static field extraction from provider source |

### `tools`

Docker-wrapped fallback functions for external tools. Each function
is defined only when the native command is absent from `PATH`.

| Function | Condition | Docker image |
|----------|-----------|--------------|
| `jq` | `jq` not found | `apteno/alpine-jq` (override: `BWX_JQ_IMAGE`) |
| `curl` | `curl` not found | `curlimages/curl` (override: `BWX_CURL_IMAGE`) |
| `openssl` | `openssl` not found | `alpine/openssl` (override: `BWX_OPENSSL_IMAGE`) |
| `aws` | `aws` not found | `amazon/aws-cli` (override: `BWX_AWS_IMAGE`) |

The `bws` wrapper is in `lib/bwx`, not here — it handles config
mounting, `state_opt_out`, and access-token validation that a simple
Docker fallback cannot provide.
