# Changelog

All notable changes to the `@opencangjie/skills` SDK will be documented in this file.

## [1.0.0] - 2026-03-14

### BREAKING CHANGES

This is a major release with architecture upgrade. The `magic.api` module has been migrated to `magic.app` module with three-layer architecture (Controller → Service → Repository).

### Changed

- **Version**: Jumped from v0.0.40 to v1.0.0 to indicate architecture upgrade
- **Architecture**: Migrated from `magic.api` module to `magic.app` module with three-layer architecture

### API Architecture

本版本包含两组独立的 API：

#### 文件系统技能 API（`/skills` 路径）

这组 API 对应 agentskills-runtime 文件系统中真实的 skills 文件目录，SDK 主要使用这组 API：

| 功能 | 路径 | 说明 |
|------|------|------|
| 获取技能列表 | `/skills` | 列出文件系统中安装的技能 |
| 获取技能详情 | `/skills/:id` | 获取技能详细信息 |
| 安装技能 | `/skills/add` | 从 Git 或本地安装技能到文件系统 |
| 编辑技能 | `/skills/edit` | 编辑技能配置 |
| 删除技能 | `/skills/del` | 从文件系统删除技能 |
| 执行技能 | `/skills/execute` | 执行指定技能 |
| 搜索技能 | `/skills/search` | 搜索可安装的技能 |

#### 数据库技能管理 API（`/api/v1/uctoo/agent_skills` 路径）

这组 API 是 agent_skills 数据库表的标准 CRUD 模块 API，与文件系统 API 是独立的：

| 功能 | 路径 | 说明 |
|------|------|------|
| 获取技能列表 | `/api/v1/uctoo/agent_skills` | 数据库中的技能记录 |
| 获取技能详情 | `/api/v1/uctoo/agent_skills/:id` | 数据库技能详情 |
| 创建技能记录 | `/api/v1/uctoo/agent_skills/add` | 添加数据库记录 |
| 编辑技能记录 | `/api/v1/uctoo/agent_skills/edit` | 更新数据库记录 |
| 删除技能记录 | `/api/v1/uctoo/agent_skills/del` | 删除数据库记录 |

#### 重要说明

- **两组 API 是独立的**：`/skills` 路径和 `/agent_skills` 路径的 API 是两组独立的 API，不存在替代关系
- **SDK 对应关系**：SDK 中的 API 与 `/skills` 路径的文件系统真实安装的技能相匹配，不需要与 `/agent_skills` 这组 API 有关联
- **数据同步**：如何将文件系统的信息（`/skills` 这组 API 的数据）和数据库的信息（`/agent_skills` 这组 API 的数据）进行同步，是 agentskills-runtime 还未设计和实现的功能

### Removed

- **magic.api module**: The original api module has been completely removed and migrated to magic.app

### Migration Guide

See [MIGRATION.md](./MIGRATION.md) for detailed migration instructions.

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
