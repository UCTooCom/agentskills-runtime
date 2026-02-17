# Changelog

All notable changes to the `@opencangjie/skills` SDK will be documented in this file.

## [0.0.6] - 2026-02-17

### Fixed
- **searchSkills method**: Changed from GET to POST request to match API contract
- **searchSkills method**: Now supports `query`, `source`, and `limit` parameters
- Improved compatibility with AgentSkills Runtime v0.0.1

### Changed
- `searchSkills(query: string)` → `searchSkills(options: { query: string; source?: string; limit?: number } | string)`
- Supports searching from multiple sources: `github`, `atomgit`, `gitee`, or `all`

## [0.0.5] - 2026-02-16

### Added
- Initial release of JavaScript/TypeScript SDK
- Runtime management: download, install, start, stop
- Skill management: install, list, execute, remove
- CLI commands: `skills install-runtime`, `skills start`, `skills stop`, `skills list`, `skills find`, `skills add`, `skills run`, `skills remove`
- Support for GitHub and AtomGit download mirrors
- Environment variable configuration support

### Features
- Cross-platform support: Windows, macOS, Linux
- Built-in runtime management
- Programmatic API for integration
- CLI for command-line usage
