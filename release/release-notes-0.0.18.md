# v0.0.18 - Critical Bug Fix: Builtin Tools Registration

## Bug Fix

### Fixed: All Builtin Tools Now Properly Registered

**Issue:** In previous versions, only `http_request` tool was registered with the Agent. Other builtin tools like `web_fetch`, `file_read`, `file_edit`, `firecrawl`, etc. were not available to the Agent.

**Root Cause:** In `skill_aware_agent.cj`, the `_registerSkillsAsTools()` method only registered `HttpTool`, but did not call `BuiltinToolsRegistry.registerAll()` to register all builtin tools.

**Fix:** Modified `_registerSkillsAsTools()` to call `BuiltinToolsRegistry.registerAll()` which registers all 20+ builtin tools:

| Tool Category | Tools |
|---------------|-------|
| HTTP Tools | http_request |
| File Tools | file_read, file_write, file_edit, file_delete, file_copy, file_move, file_search, directory_list, directory_create |
| Web Tools | web_fetch, firecrawl |
| Skill Tools | skill_initializer, skill_packager |
| Code Gen Tools | template_engine, code_snippet_generator |
| CLI Tools | cli, python_executor, browser, http_server, sub_agent, eval_runner |

**Impact:** This fix enables the Agent to properly use all builtin tools when executing skills. Previously, skills that required file operations or web fetching would fail because those tools were not available.

## Version Updates

| Component | Old Version | New Version |
|-----------|-------------|-------------|
| Runtime | 0.0.17 | 0.0.18 |
| JavaScript SDK | 0.0.39 | 0.0.40 |
| Python SDK | 0.0.5 | 0.0.6 |

## Installation

```bash
# Python SDK
pip install agentskills-runtime --upgrade

# JavaScript SDK
npm install @opencangjie/skills@latest

# Install runtime
npx skills install-runtime --runtime-version 0.0.18
npx skills start
```

## Upgrade Notes

If you're upgrading from a previous version:

1. Stop the running runtime: `npx skills stop`
2. Install the new version: `npx skills install-runtime --runtime-version 0.0.18`
3. Start the runtime: `npx skills start`

## Technical Details

### Code Change

**Before (v0.0.17):**
```cangjie
private func _registerSkillsAsTools(): Unit {
    LogUtils.info("Registering built-in tools")
    try {
        let httpTool = HttpTool()
        _toolManager.addTool(httpTool)
        LogUtils.info("Registered built-in tool '${httpTool.name}'")
    } catch (ex: Exception) {
        LogUtils.error("Failed to register built-in HTTP tool: ${ex.message}")
    }
    // ... register skills as tools
}
```

**After (v0.0.18):**
```cangjie
private func _registerSkillsAsTools(): Unit {
    LogUtils.info("Registering built-in tools")
    try {
        BuiltinToolsRegistry.registerAll(_toolManager)
        LogUtils.info("All builtin tools registered via BuiltinToolsRegistry")
    } catch (ex: Exception) {
        LogUtils.error("Failed to register builtin tools: ${ex.message}")
    }
    // ... register skills as tools
}
```

## Contributors

- OpenCangJie Team
- UCToo Project Team
