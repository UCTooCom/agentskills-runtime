# @opencangjie/skills

JavaScript/TypeScript SDK for AgentSkills Runtime - Install, manage, and execute AI agent skills with built-in runtime support.

## Features

- **Complete Runtime Management**: Download, install, start, and stop the AgentSkills runtime
- **Skill Management**: Install, list, execute, and remove skills
- **CLI & Programmatic API**: Use via command line or integrate into your applications
- **Cross-Platform**: Supports Windows, macOS, and Linux

## Installation

```bash
npm install @opencangjie/skills
```

Or use directly with npx:

```bash
npx @opencangjie/skills find react
npx @opencangjie/skills list
npx @opencangjie/skills add ./my-skill
```

## Quick Start

### 1. Install the Runtime

```bash
# Download and install the AgentSkills runtime
npx skills install-runtime

# Or specify a version
npx skills install-runtime --runtime-version 0.0.19
```

### 2. Configure the Runtime

Before starting the runtime, you need to configure the AI model API key. The runtime requires an AI model to process skill execution and natural language understanding.

Edit the `.env` file in the runtime directory:
- **Windows**: `%USERPROFILE%\.agentskills-runtime\<platform>-<arch>\release\.env`
- **macOS/Linux**: `~/.agentskills-runtime/<platform>-<arch>/release/.env`

Where `<platform>-<arch>` is your system architecture, e.g., `win-x64`, `darwin-x64`, or `linux-x64`

Add your AI model configuration (choose one provider):

```ini
# Option 1: StepFun (阶跃星辰)
MODEL_PROVIDER=stepfun
MODEL_NAME=step-1-8k
STEPFUN_API_KEY=your_stepfun_api_key_here
STEPFUN_BASE_URL=https://api.stepfun.com/v1

# Option 2: DeepSeek
MODEL_PROVIDER=deepseek
MODEL_NAME=deepseek-chat
DEEPSEEK_API_KEY=your_deepseek_api_key_here

# Option 3: 华为云 MaaS
MODEL_PROVIDER=maas
MAAS_API_KEY=your_maas_api_key_here
MAAS_BASE_URL=https://api.modelarts-maas.com/v2
MAAS_MODEL_NAME=qwen3-coder-480b-a35b-instruct

# Option 4: Sophnet
MODEL_PROVIDER=sophnet
SOPHNET_API_KEY=your_sophnet_api_key_here
SOPHNET_BASE_URL=https://www.sophnet.com/api/open-apis/v1
```

> **Note**: Without proper AI model configuration, the runtime will fail to start with an error like "Get env variable XXX_API_KEY error."

### 3. Start the Runtime

```bash
# Start in background (default)
npx skills start

# Start in foreground
npx skills start --foreground

# Custom port and host
npx skills start --port 3000 --host 0.0.0.0
```

### 4. Manage Skills

```bash
# Find and install skills
npx skills find react
npx skills add ./my-skill

# List installed skills
npx skills list

# Execute a skill
npx skills run my-skill -p '{"input": "data"}'
```

## CLI Commands

### Runtime Management

#### `npx skills install-runtime`

Download and install the AgentSkills runtime binary.

```bash
npx skills install-runtime
npx skills install-runtime --runtime-version 0.0.19
```

#### `npx skills start`

Start the AgentSkills runtime server.

```bash
# Start in background (default)
npx skills start

# Start in foreground
npx skills start --foreground

# Custom configuration
npx skills start --port 3000 --host 0.0.0.0
```

**Options:**
- `-p, --port <port>` - Port to listen on (default: 8080)
- `-h, --host <host>` - Host to bind to (default: 127.0.0.1)
- `-f, --foreground` - Run in foreground (default: background)

#### `npx skills stop`

Stop the AgentSkills runtime server.

```bash
npx skills stop
```

#### `npx skills status`

Check the status of the skills runtime server.

```bash
npx skills status
```

### Skill Management

#### `npx skills find [query]`

Search for skills interactively or by keyword.

```bash
npx skills find
npx skills find react testing
npx skills find "pdf generation"
npx skills find skill --source github --limit 10
npx skills find skill --source atomgit --limit 5
```

**Options:**
- `-l, --limit <number>`: Maximum number of results, default 10
- `-s, --source <source>`: Search source, options: `all` (default), `github`, `gitee`, `atomgit`

**Note:** AtomGit search requires setting the `ATOMGIT_TOKEN` environment variable in the runtime's `.env` configuration file.

#### `npx skills add <source>`

Install a skill from GitHub or local path.

```bash
# Install from local directory
npx skills add ./my-skill

# Install from GitHub repository
npx skills add github.com/user/skill-repo
npx skills add github.com/user/skill-repo --branch develop

# Install from multi-skill repository (specify subdirectory)
npx skills add https://github.com/user/skills-repo/tree/main/skills/my-skill
npx skills add https://atomgit.com/user/skills-repo/tree/main/skills/skill-creator

# Install with options
npx skills add github.com/user/skill-repo -y  # Skip confirmation
```

> **Tip**: For repositories containing multiple skills, use the `/tree/<branch>/<skill-path>` format to specify the exact subdirectory. This avoids the interactive selection prompt.

#### `npx skills list`

List installed skills.

```bash
npx skills list
npx skills list --limit 50 --page 1
npx skills list --json
```

#### `npx skills run <skillId>`

Execute a skill.

```bash
npx skills run my-skill -p '{"param1": "value"}'
npx skills run my-skill --tool tool-name -p '{"param1": "value"}'
npx skills run my-skill -i  # Interactive mode
```

#### `npx skills remove <skillId>`

Remove an installed skill.

```bash
npx skills remove my-skill
npx skills rm my-skill -y
```

#### `npx skills info <skillId>`

Show detailed information about a skill.

```bash
npx skills info my-skill
```

#### `npx skills init [name]`

Initialize a new skill project.

```bash
npx skills init my-new-skill
npx skills init my-new-skill --directory ./skills
```

#### `npx skills check`

Check for skill updates.

```bash
npx skills check
```

#### `npx skills update [skillId]`

Update skills to their latest versions.

```bash
npx skills update my-skill
npx skills update --all
```

#### `npx skills config <skillId>`

Manage skill configuration.

```bash
npx skills config my-skill --list
npx skills config my-skill --get API_KEY
npx skills config my-skill --set API_KEY=abc123
```

## Programmatic API

### Basic Usage

```typescript
import { createClient, SkillsClient, RuntimeManager } from '@opencangjie/skills';

const client = createClient({
  baseUrl: 'http://127.0.0.1:8080',
  authToken: 'your-jwt-token' // optional
});

// Check runtime status
const status = await client.runtime.status();
console.log(`Runtime running: ${status.running}`);

// List skills
const result = await client.listSkills({ limit: 10 });
console.log(result.skills);

// Execute a skill
const execResult = await client.executeSkill('my-skill', {
  param1: 'value'
});
console.log(execResult.output);
```

### Runtime Management

```typescript
import { RuntimeManager } from '@opencangjie/skills';

const runtime = new RuntimeManager();

// Check if runtime is installed
if (!runtime.isInstalled()) {
  // Download and install
  await runtime.downloadRuntime('1.0.0');
}

// Check status
const status = await runtime.status();
if (!status.running) {
  // Start the runtime
  runtime.start({
    port: 8080,
    host: '127.0.0.1',
    detached: true
  });
}

// Stop the runtime
runtime.stop();
```

### Skill Management

```typescript
// Install from local path
const installResult = await client.installSkill({
  source: './my-skill',
  validate: true
});

// Install from Git
const gitInstallResult = await client.installSkill({
  source: 'https://github.com/user/skill.git',
  branch: 'main'
});

// Uninstall
await client.uninstallSkill('my-skill');

// Update
await client.updateSkill('my-skill', { version: '2.0.0' });
```

### Execute Skills

```typescript
// Execute skill with parameters
const result = await client.executeSkill('my-skill', {
  input: 'data'
});

if (result.success) {
  console.log(result.output);
} else {
  console.error(result.errorMessage);
}

// Execute specific tool
const toolResult = await client.executeSkillTool('my-skill', 'tool-name', {
  param1: 'value'
});
```

## Defining Skills

You can also use this SDK to define skills programmatically:

```typescript
import { defineSkill, getConfig } from '@opencangjie/skills';

export default defineSkill({
  metadata: {
    name: 'my-skill',
    version: '1.0.0',
    description: 'My awesome skill',
    author: 'Your Name'
  },
  tools: [
    {
      name: 'greet',
      description: 'Greet someone by name',
      parameters: [
        {
          name: 'name',
          paramType: 'string',
          description: 'Name to greet',
          required: true
        }
      ]
    }
  ],
  validateConfig: (config) => {
    if (!config.API_KEY) {
      return { err: 'API_KEY is required' };
    }
    return { ok: null };
  }
});

// Access configuration
const config = getConfig();
const apiKey = config.API_KEY;
```

## Architecture

```
┌─────────────────────────────────────┐
│        Language Ecosystem           │
│   (npm, pip, maven, cargo, etc.)    │
├─────────────────────────────────────┤
│  CLI Commands (skills find/add/run) │
├─────────────────────────────────────┤
│     SDK Programmatic API            │
│     (SkillsClient, RuntimeManager)  │
├─────────────────────────────────────┤
│   Standard API Interface Layer      │
│     (RESTful + JWT Auth)            │
├─────────────────────────────────────┤
│   Agent Skill Runtime Kernel        │
│     (Cangjie Binary)                │
└─────────────────────────────────────┘
```

## Manual Runtime Installation

If you prefer to manually install the runtime without using the SDK:

### Download

Download the latest release from [AtomGit](https://atomgit.com/UCToo/agentskills-runtime/releases):

- `agentskills-runtime-win-x64.tar.gz` - Windows x64
- `agentskills-runtime-linux-x64.tar.gz` - Linux x64 (coming soon)
- `agentskills-runtime-darwin-x64.tar.gz` - macOS x64 (coming soon)

### Installation

```bash
# Download and extract
tar -xzf agentskills-runtime-win-x64.tar.gz

# Navigate to bin directory
cd release/bin

# Run the runtime
./agentskills-runtime.exe
```

### Release Package Contents

```
release/
├── bin/                    # Executables and ALL DLLs
│   ├── agentskills-runtime.exe    # Main entry point
│   ├── magic.api.exe              # Alternative entry point
│   └── *.dll                      # All required DLLs (stdx, runtime, magic)
├── magic/                  # Runtime modules
├── commonmark4cj/          # Markdown parser
├── yaml4cj/                # YAML parser
└── VERSION                 # Version information
```

### Usage

After extraction, simply run the executable:

```bash
# Windows
cd release/bin
agentskills-runtime.exe

# The server will start on http://127.0.0.1:8080
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/hello` | GET | Health check |
| `/skills` | GET | List all skills |
| `/skills/:id` | GET | Get skill details |
| `/skills/add` | POST | Install a skill |
| `/skills/edit` | POST | Update a skill |
| `/skills/del` | POST | Uninstall a skill |
| `/skills/execute` | POST | Execute a skill |
| `/skills/search` | POST | Search skills |
| `/mcp/stream` | GET | MCP server with streaming |

### Verify Installation

```bash
# Check health
curl http://127.0.0.1:8080/hello
# Response: {"message":"Hello World"}

# List skills
curl http://127.0.0.1:8080/skills
```

## Environment Variables

### Runtime Configuration

The runtime loads environment variables from a `.env` file in the same directory as the executable.

**Location:** Place the `.env` file in the `bin/` directory alongside `agentskills-runtime.exe`:

```
sdk/javascript/runtime/win-x64/release/bin/.env
```

**Example `.env` file:**

```env
# GitHub Personal Access Token (optional, for higher rate limits)
GITHUB_TOKEN=ghp_your_github_token

# Gitee Private Token (optional, for higher rate limits)
GITEE_TOKEN=your_gitee_token

# AtomGit Access Token (optional, for higher rate limits)
ATOMGIT_TOKEN=your_atomgit_token
```

**How to obtain tokens:**

| Platform | How to Get Token | Auth Method |
|----------|------------------|-------------|
| GitHub | [Settings → Tokens](https://github.com/settings/tokens) | `Authorization: token` header |
| Gitee | [设置 → 私人令牌](https://gitee.com/profile/personal_access_tokens) | `access_token` URL parameter |
| AtomGit | [设置 → 访问令牌](https://atomgit.com/-/profile/personal_access_tokens) | `access_token` URL parameter |

> **Note:** API tokens are **optional**. Without tokens, search still works but with lower rate limits:
> - GitHub: 10 requests/min (unauthenticated) vs 30 requests/min (authenticated)
> - Gitee/AtomGit: Limited without token, higher with token

### SDK Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SKILL_RUNTIME_API_URL` | API server URL | `http://127.0.0.1:8080` |
| `SKILL_*` | Skill configuration (accessible via `getConfig()`) | - |

## API Reference

### SkillsClient

| Method | Description |
|--------|-------------|
| `runtime` | Access RuntimeManager instance |
| `healthCheck()` | Check server status |
| `listSkills(options)` | List installed skills |
| `getSkill(skillId)` | Get skill details |
| `installSkill(options)` | Install a skill |
| `uninstallSkill(skillId)` | Uninstall a skill |
| `executeSkill(skillId, params)` | Execute a skill |
| `executeSkillTool(skillId, toolName, args)` | Execute a specific tool |
| `searchSkills(options)` | Search for skills (supports query, source, limit) |
| `updateSkill(skillId, updates)` | Update a skill |
| `getSkillConfig(skillId)` | Get skill configuration |
| `setSkillConfig(skillId, config)` | Set skill configuration |
| `listSkillTools(skillId)` | List tools in a skill |

### RuntimeManager

| Method | Description |
|--------|-------------|
| `isInstalled()` | Check if runtime is installed |
| `getRuntimePath()` | Get runtime binary path |
| `downloadRuntime(version)` | Download and install runtime |
| `start(options)` | Start the runtime server |
| `stop()` | Stop the runtime server |
| `status()` | Check runtime status |

## Comparison with Vercel Labs Skills CLI

| Feature | @opencangjie/skills | Vercel Labs Skills CLI |
|---------|---------------------|------------------------|
| Runtime Management | Built-in | External |
| Installation | npm install | npm install -g skills |
| Language | TypeScript/JavaScript | TypeScript |
| Runtime | Cangjie (native) | Node.js |
| Platform Support | Win/Mac/Linux | Win/Mac/Linux |
| API Protocol | RESTful + MCP | RESTful |

## Real-World Usage Example

This SDK is used in the [UCToo](https://gitee.com/uctoo/uctoo) open source project for AI agent skill management.

### Project Structure

```
uctoo/
├── apps/
│   ├── backend/                    # Backend API service (Node.js/TypeScript)
│   │   ├── package.json            # Contains: @opencangjie/skills
│   │   └── src/
│   │       └── app/services/uctoo/
│   │           └── runtimeManager.ts  # Runtime management service
│   │
│   ├── uctoo-app-client-pc/        # Frontend application (Vue 3)
│   │   ├── package.json            # Contains: @opencangjie/skills
│   │   └── src/
│   │       └── views/uctoo/agent_skills/
│   │           └── home.vue        # Skill management UI
│   │
│   └── agentskills-runtime/        # Runtime kernel (Cangjie)
│       └── sdk/javascript/         # This SDK
```

### Backend Integration (apps/backend)

```typescript
// apps/backend/src/app/services/uctoo/runtimeManager.ts
import { createClient, RUNTIME_VERSION } from '@opencangjie/skills';

const runtimeClient = createClient({
  baseUrl: process.env.SKILL_RUNTIME_API_URL || 'http://127.0.0.1:8080'
});

export class RuntimeManager {
  async getRuntimeVersion(): Promise<string> {
    return RUNTIME_VERSION;
  }

  async listSkills(limit: number = 10, page: number = 0) {
    return runtimeClient.listSkills({ limit, skip: page * limit });
  }

  async installSkill(source: string) {
    return runtimeClient.installSkill({ source });
  }

  async executeSkill(skillId: string, params: Record<string, any>) {
    return runtimeClient.executeSkill(skillId, params);
  }

  async searchSkills(query: string) {
    return runtimeClient.searchSkills({ query });
  }
}
```

### Frontend Integration (apps/uctoo-app-client-pc)

```vue
<!-- apps/uctoo-app-client-pc/src/views/uctoo/agent_skills/home.vue -->
<template>
  <div class="skill-management">
    <a-input-search
      v-model:value="searchQuery"
      placeholder="Search skills..."
      @search="handleSearch"
    />
    
    <a-table :dataSource="skills" :columns="columns">
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'action'">
          <a-button @click="executeSkill(record.id)">Execute</a-button>
        </template>
      </template>
    </a-table>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { createClient } from '@opencangjie/skills';

const client = createClient({
  baseUrl: '/api/skills'  // Proxied to runtime
});

const skills = ref([]);
const searchQuery = ref('');

const loadSkills = async () => {
  const result = await client.listSkills({ limit: 20 });
  skills.value = result.skills;
};

const handleSearch = async () => {
  if (searchQuery.value) {
    const result = await client.searchSkills({ query: searchQuery.value });
    skills.value = result.skills;
  } else {
    loadSkills();
  }
};

const executeSkill = async (skillId: string) => {
  // Open execution dialog
};

onMounted(loadSkills);
</script>
```

### Package Dependencies

```json
// apps/backend/package.json
{
  "dependencies": {
    "@opencangjie/skills": "^0.0.16"
  }
}

// apps/uctoo-app-client-pc/package.json
{
  "dependencies": {
    "@opencangjie/skills": "^0.0.16"
  }
}
```

## Links

- [NPM Package](https://www.npmjs.com/package/@opencangjie/skills)
- [Documentation](https://atomgit.com/uctoo/agentskills-runtime#readme)
- [Repository](https://atomgit.com/uctoo/agentskills-runtime)
- [Issue Tracker](https://atomgit.com/uctoo/agentskills-runtime/issues)
- [Python SDK](../python)

## License

MIT
