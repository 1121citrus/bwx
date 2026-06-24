# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-24

### Added

- Initial release: 30 subcommands extracted from 1121-citrus private repo
- Single `bwx` entry point with subcommand dispatch
- Bash completion via `bwx completion bash`
- Structured note metadata: `file:`, `expires:`, `release-tag:`
- TTL-based local caching for project and secret lists
- Release-tag lifecycle management (add, remove, bulk tag/untag)
- Secret cloning with automatic version increment
- Docker-wrapped tool functions (jq, bws) — zero install dependencies
  beyond bash and Docker

[Unreleased]: https://github.com/1121citrus/bwx/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/1121citrus/bwx/releases/tag/v1.0.0
