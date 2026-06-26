# Include directory

The `include` directory contains reusable bash modules loaded by
`bin/bwx`. These modules are implementation details for command behavior,
logging, caching, and tool wrappers.

## Modules

### `logging`

Shared logging and status-code constants used by every command.

- Leveled logging: `diag`, `trace`, `debug`, `info`, `notice`, `warn`,
  `error`, `fatal`
- Exit and return code constants: `EXIT_*`, `RETURN_*`
- Runtime logging controls via `LOG_LEVEL` and `LOGGING_INCLUDE_*`

Full configuration reference:

- [logging configuration](logging.md)

### `bwx-cache`

TTL-based file cache helpers for project and secret list lookups.

- Maintains cache freshness windows
- Reduces repeated Bitwarden API calls for list-heavy commands

### `tools`

Wrapper functions for external tooling.

- Native `jq` / `bws` usage when available
- Docker fallback for `jq` / `bws` when native binaries are missing
- Centralized image and runtime behavior for wrappers

### `http`

Small HTTP helper utilities shared by provider and lifecycle flows.

### `path`

Portable path manipulation helpers used during startup and dispatch.
