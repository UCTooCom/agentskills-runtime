# v0.0.17 - Skill Hot Reloading and Tool Testing

## New Features

### Skill Hot Reloading

Implemented skill hot reloading functionality that automatically detects and loads new skills without requiring a runtime restart.

**Key Features:**
- Background task that periodically scans skill directories
- Automatic reloading of skills every 30 seconds
- No downtime or service interruption
- Works with both local and remote skills

**Implementation Details:**
- Added `_startHotReloadTask()` method in `api_router.cj`
- Uses `spawn` to create a background task
- Periodically calls `ProgressiveSkillLoader.reloadSkills()`
- Logs reloading events for debugging

### Comprehensive Tool Testing

Created 5 test skills to comprehensively test all built-in tools:

| Skill Name | Tools Tested |
|------------|-------------|
| test-file-tools | FileReadTool, FileWriteTool, FileEditTool, FileDeleteTool, FileCopyTool, FileMoveTool, FileSearchTool, DirectoryListTool, DirectoryCreateTool |
| test-http-tools | HttpTool |
| test-web-tools | WebFetchTool, FirecrawlTool |
| test-code-gen-tools | TemplateEngineTool, CodeSnippetGeneratorTool |
| test-cli-tools | CliTool, PythonExecutorTool, BrowserTool, HttpServerTool, SubAgentTool |

## Improvements

### Optimized Skill Loading
- Enhanced skill discovery and loading mechanism
- Improved error handling during skill loading
- Faster skill initialization

### API Enhancements
- Standardized API response formats
- Improved error messages
- Better skill metadata validation

## Bug Fixes
- Fixed minor issues in skill loading process
- Improved error handling for invalid skill formats

## Version Updates

| Component | Old Version | New Version |
|-----------|-------------|-------------|
| Runtime | 0.0.16 | 0.0.17 |
| JavaScript SDK | 0.0.38 | 0.0.39 |
| Python SDK | 0.0.4 | 0.0.5 |
| PHP SDK | 0.0.2 | 0.0.3 |
| UniApp SDK | 0.0.1 | 0.0.2 |

## Installation

```bash
# Python SDK
pip install agentskills-runtime --upgrade

# JavaScript SDK
npm install @opencangjie/skills@latest

# Install runtime
npx skills install-runtime --runtime-version 0.0.17
npx skills start
```

## Upgrade Notes

If you're upgrading from a previous version:

1. Stop the running runtime: `npx skills stop`
2. Install the new version: `npx skills install-runtime --runtime-version 0.0.17`
3. Start the runtime: `npx skills start`

## Usage Examples

### Testing Hot Reloading

1. Start the runtime: `npx skills start`
2. Add a new skill to the skills directory
3. Wait 30 seconds for hot reload to detect the new skill
4. List skills: `npx skills list` (new skill should appear)

### Testing Built-in Tools

```bash
# Execute file tools test
npx skills run test-file-tools

# Execute HTTP tools test
npx skills run test-http-tools

# Execute web tools test
npx skills run test-web-tools

# Execute code generation tools test
npx skills run test-code-gen-tools

# Execute CLI tools test
npx skills run test-cli-tools
```

## Technical Details

### Hot Reloading Implementation

```cangjie
private func _startHotReloadTask(): Unit {
    spawn {
        while (true) {
            try {
                // Sleep for the configured interval
                sleep2(Int64(_hotReloadInterval) * 1000) // Convert seconds to milliseconds
                
                // For simplicity, just reload skills periodically
                // In a real project, you would implement more sophisticated change detection
                LogUtils.info("Reloading skills periodically...")
                _progressiveSkillLoader.reloadSkills(_skillManager)
                LogUtils.info("✅ Skills reloaded successfully")
            } catch (ex: Exception) {
                LogUtils.error("Error in hot reload task: ${ex.message}")
            }
        }
    }
}
```

### Test Skills

Each test skill is designed to verify specific tool functionality:
- **test-file-tools**: Tests all file operations
- **test-http-tools**: Tests HTTP requests
- **test-web-tools**: Tests web fetching and crawling
- **test-code-gen-tools**: Tests code generation and templating
- **test-cli-tools**: Tests CLI commands and execution

## Contributors

- OpenCangJie Team
- UCToo Project Team