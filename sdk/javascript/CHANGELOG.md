# Changelog

All notable changes to the `@opencangjie/skills` SDK will be documented in this file.

## [0.0.36] - 2026-02-20

### Fixed
- **Windows `npx skills stop` command**: Now uses `taskkill /F /PID` on Windows to properly terminate runtime process
- Previous `process.kill(pid, 'SIGTERM')` didn't work on Windows for detached processes
- **Runtime v0.0.16**: Temporary directory now uses sibling `temp` directory of `SKILL_INSTALL_PATH`
- If `SKILL_INSTALL_PATH=./skills`, temp directory will be `./temp/git-clone`
- This ensures proper permissions and accessibility for the temp directory

## [0.0.35] - 2026-02-20

### Fixed
- **Runtime v0.0.12**: Temporary directory now uses system temp directory (`getTempDirectory()`)
- Permanently fixed Windows "Filename too long" error when cloning Git repositories
- Temporary path is now `C:\Users\xxx\AppData\Local\Temp\skills-git-clone\` (Windows) or `/tmp/skills-git-clone/` (Linux/macOS)
- This is much shorter than the previous path which was nested deep in the pnpm/node_modules directory

## [0.0.34] - 2026-02-20

### Changed
- Added `peerDependencies` with `@types/node: ">=18.0.0"` (optional) to support wider range of `@types/node` versions
- This fixes pnpm resolution issues in monorepo environments where different apps use different `@types/node` versions

## [0.0.33] - 2026-02-20

### Fixed
- **install-runtime command**: Changed `--version` to `--runtime-version` to avoid conflict with CLI's built-in `-v` option
- Updated README documentation with correct command syntax

## [0.0.32] - 2026-02-20

### Fixed
- **Runtime v0.0.11**: Temporary directory now uses skill installation directory's parent
- Fixed Windows "Filename too long" error when cloning Git repositories
- Temporary path shortened from `runtime_dir/temp/git-clone/` to `skills_parent/temp/git-clone/`

## [0.0.31] - 2026-02-20

### Fixed
- **Runtime download URL**: Fixed AtomGit download URL format
- Changed from API endpoint to public download URL: `https://atomgit.com/{owner}/{repo}/releases/download/v{version}/{filename}`

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
