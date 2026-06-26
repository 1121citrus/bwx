# Logging configuration

This page documents runtime logging configuration for `bwx` commands.

For implementation details in the shared include library, see
`include/logging` and `include/logging.md`.

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

Set minimum output level with `LOG_LEVEL` (default: `info`).

```bash
export LOG_LEVEL=debug
bwx secret list
```

## Environment variables

### Core behavior

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Minimum severity that will be emitted |
| `DEFAULT_LOG_LEVEL` | `info` | Fallback when `LOG_LEVEL` is not set |
| `LOG_DATE_FORMAT` | `%Y%m%dT%H%M%S` | Timestamp format used by `date` |
| `DEFAULT_LOG_DATE_FORMAT` | `%Y%m%dT%H%M%S` | Fallback timestamp format |

### Prolog controls

| Variable | Default | Description |
|----------|---------|-------------|
| `LOGGING_INCLUDE_ALL` | `false` | Enable timestamp, command, and location together |
| `LOGGING_INCLUDE_TIMESTAMP` | `false` | Include timestamp in each log line |
| `LOGGING_INCLUDE_COMMAND` | `false` | Include command name in each log line |
| `LOGGING_INCLUDE_LOCATION` | `false` | Include caller function and line in each log line |
| `LOGGING_INCLUDE_LOCATION_FILE` | `false` | When location is enabled, include filename |

## Common usage patterns

```bash
info "starting import"
trace "project=${project} tag=${tag}"
warn "cache file is stale"
```

```bash
fatal "${EXIT_CONFIG}" "missing BWX_DEFAULT_PROJECT"
```

```bash
error-return "${RETURN_ERROR}" "provider returned empty value"
```

```bash
log-level-enabled TRACE && trace "$(jq -c . <<<"${payload}")"
```
