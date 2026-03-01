# v0.0.15 - Automatic Token Management

## New Features

### Session-Level Automatic Token Management

This release introduces a comprehensive **automatic token management system** that solves the problem of LLMs failing to correctly pass authentication tokens in multi-turn conversations.

#### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    WebSocket Session                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 SessionContext                        │    │
│  │  - setCurrentSession(sessionId)                       │    │
│  │  - getAccessToken() → TokenManager.getAccessToken()   │    │
│  └─────────────────────────────────────────────────────┘    │
│                            │                                 │
│                            ▼                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   TokenManager                        │    │
│  │  - setToken(sessionId, tokenInfo)                     │    │
│  │  - getAccessToken(sessionId)                          │    │
│  │  - parseLoginResponse(response)                       │    │
│  │  - isLoginEndpoint(url)                               │    │
│  └─────────────────────────────────────────────────────┘    │
│                            │                                 │
│                            ▼                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                     HttpTool                          │    │
│  │  1. Detect login request → Auto-save token            │    │
│  │  2. Detect non-login request → Auto-inject Auth       │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

#### Core Components

| Component | File | Description |
|-----------|------|-------------|
| TokenInfo | `src/tool/token_manager.cj` | Token info wrapper with expiration check |
| TokenManager | `src/tool/token_manager.cj` | Token storage and management, multi-session support |
| SessionContext | `src/tool/token_manager.cj` | Current session context, thread-safe |
| HttpTool | `src/tool/http_tool.cj` | Automatic token save and injection |

#### How It Works

1. **On Login**: HttpTool detects login endpoint, parses response and saves `access_token`
2. **On Subsequent Requests**: HttpTool auto-injects `Authorization: Bearer {token}` header
3. **On Session End**: Tokens are cleaned up automatically

#### Benefits

- **Transparent to LLM**: No need for the model to manage tokens
- **High Reliability**: Doesn't depend on LLM's memory capability
- **Multi-User Support**: Each WebSocket session has independent token management
- **Auto Expiration**: TokenInfo includes expiration time with validity check
- **Thread-Safe**: Uses Mutex to protect shared state

### HTTP Tool Improvements

- Fixed JSON parameter parsing for POST requests
- `JsonString.getValue()` now correctly extracts unescaped string values
- Improved error handling and logging

## Bug Fixes

- Fixed circular dependency issues in token management components
- Fixed immutable variable error in SessionContext
- Removed deprecated `find_skills_skill` references

## Documentation Updates

- Added automatic token management documentation to `uctoo_api_skill` README
- Updated README version badges to 0.0.15
- Added Chinese documentation for token management feature

## SDK Version

- This runtime version requires SDK v0.0.37 or later
- SDK package: `@opencangjie/skills@0.0.37`

## Download

- Windows x64: agentskills-runtime-win-x64.tar.gz

## Installation

```bash
npm install @opencangjie/skills
npx skills install-runtime --runtime-version 0.0.15
npx skills start
```

## Upgrade Notes

If you're upgrading from a previous version:

1. Stop the running runtime: `npx skills stop`
2. Install the new version: `npx skills install-runtime --runtime-version 0.0.15`
3. Start the runtime: `npx skills start`

The automatic token management feature works transparently - no configuration changes required.
