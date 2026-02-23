# v0.0.13 - Fix Windows stop command and temp directory path

## Bug Fixes

### Windows `npx skills stop` command fix

- **Fixed**: `npx skills stop` command now properly terminates runtime process on Windows
- Previous implementation used `process.kill(pid, 'SIGTERM')` which doesn't work for detached processes on Windows
- Now uses `taskkill /F /PID` on Windows platform

### Temporary directory path fix

- **Fixed**: Git clone temporary directory now uses the sibling `temp` directory of `SKILL_INSTALL_PATH`
- Previous implementation tried to use system temp directory which could fail in certain environments
- New approach: If `SKILL_INSTALL_PATH=./skills`, temp directory will be `./temp/git-clone`
- This ensures the temp directory is always accessible and has proper permissions

## Configuration

The temporary directory is now resolved based on `SKILL_INSTALL_PATH`:
- If `SKILL_INSTALL_PATH=./skills` (relative path), temp directory will be `./temp/git-clone`
- If `SKILL_INSTALL_PATH=/absolute/path/to/skills`, temp directory will be `/absolute/path/to/temp/git-clone`

## SDK Version

- This runtime version requires SDK v0.0.36 or later

## Download

- Windows x64: agentskills-runtime-win-x64.tar.gz

## Installation

```bash
npm install @opencangjie/skills
npx skills install-runtime --runtime-version 0.0.13
npx skills start
```
