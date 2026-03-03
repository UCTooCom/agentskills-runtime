# v0.0.16 - Local Path Installation Fix

## Bug Fixes

### Fixed: Local Path Skill Installation Not Copying Subdirectories

Previously, when installing a skill from a local path, only the files in the root directory were copied. Subdirectories (like `references/`, `scripts/`, etc.) were not being copied to the destination.

**Root Cause**: Path separator inconsistency on Windows. The `Directory.walk` function returns paths with backslashes (`\`), but the string replacement logic was not normalizing paths correctly, causing relative path calculation to fail for files in subdirectories.

**Fix**: Normalized all paths to use forward slashes (`/`) before calculating relative paths:

```cangjie
// Before (buggy)
let relativePath = fileInfo.path.toString().replace(sourcePath.toString(), "")

// After (fixed)
let normalizedSourcePath = sourcePath.toString().replace("\\", "/")
let normalizedFilePath = fileInfo.path.toString().replace("\\", "/")
let relativePath = normalizedFilePath.replace(normalizedSourcePath, "")
```

**Impact**: Skills installed from local paths now correctly include all subdirectories and their contents.

### Example

Before fix:
```
skills/
└── uctoo-api-skill/
    ├── SKILL.md
    ├── README.md
    └── .env.example
    # Missing: references/, scripts/ directories
```

After fix:
```
skills/
└── uctoo-api-skill/
    ├── SKILL.md
    ├── README.md
    ├── README_zh_CN.md
    ├── .env.example
    ├── references/
    │   ├── api_spec.md
    │   ├── examples.md
    │   └── uctoo_api_design.md
    └── scripts/
        ├── api_client.js
        ├── api_client.py
        └── test_api.py
```

## Version Updates

| Component | Old Version | New Version |
|-----------|-------------|-------------|
| Runtime | 0.0.15 | 0.0.16 |
| Python SDK | 0.0.3 | 0.0.4 |
| JavaScript SDK | 0.0.37 | 0.0.38 |

## Installation

```bash
# Python SDK
pip install agentskills-runtime --upgrade

# JavaScript SDK
npm install @opencangjie/skills@latest

# Install runtime
npx skills install-runtime --runtime-version 0.0.16
npx skills start
```

## Upgrade Notes

If you're upgrading from a previous version:

1. Stop the running runtime: `npx skills stop`
2. Install the new version: `npx skills install-runtime --runtime-version 0.0.16`
3. Start the runtime: `npx skills start`

If you have skills installed from local paths that are missing subdirectories, reinstall them:

```bash
skills remove <skill-id>
skills add /path/to/skill
```
