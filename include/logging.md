# Logging library (`include/logging`)

`bwx` uses a shared logging library for all command output.
The library writes messages to stderr, supports severity filtering,
and provides optional message context fields.

Source in scripts:

```bash
source "${BWX_ROOT}/include/logging"
```

## Levels

Logging levels are ordered from least to most severe:

| Level | Numeric value |
|-------|---------------|
| `DIAG` | `0` |
| `TRACE` | `10` |
| `DEBUG` | `20` |
| `INFO` | `30` |
| `NOTICE` | `40` |
| `WARN` | `50` |
| `ERROR` | `60` |
| `FATAL` | `70` |

The active threshold is controlled by `LOG_LEVEL` (default: `info`).

Example:

```bash
export LOG_LEVEL=debug
bwx secret list
```

## Configuration variables

### Core behavior

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Minimum severity that will be emitted |
| `DEFAULT_LOG_LEVEL` | `info` | Fallback when `LOG_LEVEL` is not set |
| `LOG_DATE_FORMAT` | `%Y%m%dT%H%M%S` | Timestamp format used by `date` |
| `DEFAULT_LOG_DATE_FORMAT` | `%Y%m%dT%H%M%S` | Fallback timestamp format |

### Message prolog controls

Each log line can include optional context fields before `[LEVEL]`.

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGING_INCLUDE_ALL` | `false` | Enables timestamp, command, and location together |
| `LOGGING_INCLUDE_TIMESTAMP` | `false` | Prefix each message with a timestamp |
| `LOGGING_INCLUDE_COMMAND` | `false` | Prefix each message with the command name |
| `LOGGING_INCLUDE_LOCATION` | `false` | Prefix each message with caller function and line |
| `LOGGING_INCLUDE_LOCATION_FILE` | `false` | When location is enabled, append filename |

Examples:

```bash
# Command name + caller location + timestamp
export LOGGING_INCLUDE_ALL=true

# Fine-grained controls
export LOGGING_INCLUDE_TIMESTAMP=true
export LOGGING_INCLUDE_COMMAND=true
export LOGGING_INCLUDE_LOCATION=true
export LOGGING_INCLUDE_LOCATION_FILE=true
```

## Functions

### Severity helpers

- `diag`, `diagnostic`
- `trace`
- `debug`
- `info`, `information`
- `notice`
- `warn`, `warning`
- `error`
- `fatal`, `die`

### Core helpers

- `log [SEVERITY] [MESSAGE...]`
- `log-and-exit [SEVERITY] [EXIT_STATUS] [MESSAGE...]`
- `log-level LEVEL`
- `log-level-enabled LEVEL`
- `validate-log-level LEVEL`
- `log-traceback`

### Status helpers

- `exit-status-name CODE`
- `return-status-name CODE`
- `validate-exit-status CODE`
- `error-return [RETURN_CODE] [MESSAGE...]`

## Exit and return constants

Exit constants:

- `EXIT_SUCCESS=0`
- `EXIT_ERROR=1`
- `EXIT_USAGE=2`
- `EXIT_CONFIG=3`
- `EXIT_NOTFOUND=4`
- `EXIT_FATAL=5`

Return constants:

- `RETURN_SUCCESS=0`
- `RETURN_ERROR_FLOOR=10`
- `RETURN_ERROR=11`
- `RETURN_USAGE=12`
- `RETURN_CONFIG=13`
- `RETURN_NOTFOUND=14`
- `RETURN_FATAL=15`

## Common usage patterns

Basic logging:

```bash
info "starting import"
trace "project=${project} tag=${tag}"
warn "cache file is stale"
```

Exit from script on unrecoverable error:

```bash
fatal "${EXIT_CONFIG}" "missing BWX_DEFAULT_PROJECT"
```

Return from function without exiting process:

```bash
error-return "${RETURN_ERROR}" "provider returned empty value"
```

Gate expensive message construction:

```bash
log-level-enabled TRACE && trace "$(jq -c . <<<"${payload}")"
```
