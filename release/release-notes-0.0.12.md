# v0.0.12 - Fix Windows path length issue

## Bug Fixes

### Critical Fix: Windows "Filename too long" error

- **Temporary directory now uses system temp directory** (`getTempDirectory()`)
- Permanently fixed the "Filename too long" error when cloning Git repositories on Windows
- Temporary path is now:
  - Windows: `C:\Users\xxx\AppData\Local\Temp\skills-git-clone\`
  - Linux/macOS: `/tmp/skills-git-clone/`
- This is much shorter than the previous path which was nested deep in the pnpm/node_modules directory

## Technical Details

The previous implementation placed the temporary Git clone directory relative to the runtime installation path, which in a pnpm monorepo could be extremely long:

```
D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\node_modules\.pnpm\@opencangjie+skills@0.0.34_@types+node@20.12.7\node_modules\@opencangjie\skills\runtime\win-x64\release\temp\git-clone\...
```

This exceeded Windows MAX_PATH limitation (260 characters) and caused Git clone operations to fail.

The new implementation uses the system's temporary directory via `getTempDirectory()` from the Cangjie standard library, resulting in a much shorter path:

```
C:\Users\xxx\AppData\Local\Temp\skills-git-clone\...
```

## Upgrade

Update your SDK to v0.0.35 to get the new runtime:

```bash
npm install @opencangjie/skills@0.0.35
npx skills install-runtime --runtime-version 0.0.12
```
