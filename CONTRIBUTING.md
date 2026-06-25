# Contributing

## Prerequisites

- Bash 4.0+ (macOS ships 3.2 — install via Homebrew or pkgin)
  - Homebrew: `brew install bash`
  - pkgsrc/pkgin: `pkgin install bash`
- Docker (used to run `jq`, `bws`, and other wrapped tools — no local
  installation of these tools is required)

## Development workflow

### Building

The `build` script runs all stages: lint → test.

```bash
./build              # Lint and test
./build --help       # See all options
```

### Testing

Run the test suite directly:

```bash
bats test/bin/
```

Or through the build script:

```bash
./build --no-lint    # Skip shellcheck, run tests only
```

### Code style

All shell scripts must pass shellcheck:

```bash
shellcheck bin/bwx src/**/*.bash
```

This check runs automatically in `./build`.

### Submitting changes

1. Create a branch from `dev`.
2. Make your changes.
3. Run `./build` to lint and test.
4. Submit a pull request targeting `dev`.

## Release process

Releases are tag-driven:

```bash
git tag v1.2.3
git push origin v1.2.3
```

Pushing a version tag triggers the GitHub Actions workflow.
