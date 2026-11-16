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
./test/run-all
```

Or through the build script:

```bash
./build --no-lint    # Skip shellcheck, run tests only
```

### Code style

The build script runs shellcheck over the bash entrypoints and support
modules under `bin/`, `include/`, and `lib/`.

```bash
./build
```

### Submitting changes

1. Create a branch from `dev`.
2. Make your changes.
3. Run `./build` to lint and test.
4. Submit a pull request targeting `dev`.

## Protected branches and tags

`main` cannot be force-pushed or deleted. The required GitHub Actions checks
are listed in **Settings > Rules > Rulesets > Require main checks**. Missing
or failed checks block updates; GitHub also accepts skipped and neutral
results. The repository owner is the only actor allowed to create, update,
or delete `v*` tags.

Inspect and fix failed Actions runs before retrying. If a check is missing,
verify that its workflow runs on the source branch. After renaming a check,
verify the new name on a branch and update the ruleset before promoting that
change to `main`.

The current required checks are `ci`, `Analyze (actions)`, and
`Analyze (ruby)`. After the Gitleaks workflow is deployed and reports its
check on a branch, add `gitleaks` to the required checks.

## Release process

Releases are tag-driven:

```bash
git tag v1.2.3
git push origin v1.2.3
```

Pushing a version tag triggers the GitHub Actions workflow.
