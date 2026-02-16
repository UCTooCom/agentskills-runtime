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
npx skills install-runtime --version 0.0.1
```

### 2. Start the Runtime

```bash
# Start in foreground
npx skills start

# Start in background
npx skills start --detached

# Custom port and host
npx skills start --port 3000 --host 0.0.0.0
```

### 3. Manage Skills

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

#### `skills install-runtime`

Download and install the AgentSkills runtime binary.

```bash
skills install-runtime
skills install-runtime --version 0.0.1
```

#### `skills start`

Start the AgentSkills runtime server.

```bash
# Start in foreground
skills start

# Start in background
skills start --detached

# Custom configuration
skills start --port 3000 --host 0.0.0.0
```

#### `skills stop`

Stop the AgentSkills runtime server.

```bash
skills stop
```

#### `skills status`

Check the status of the skills runtime server.

```bash
skills status
```

### Skill Management

#### `skills find [query]`

Search for skills interactively or by keyword.

```bash
skills find
skills find react testing
skills find "pdf generation"
```

#### `skills add <source>`

Install a skill from GitHub or local path.

```bash
skills add ./my-skill
skills add github.com/user/skill-repo
skills add github.com/user/skill-repo --branch develop
```

#### `skills list`

List installed skills.

```bash
skills list
skills list --limit 50 --page 1
skills list --json
```

#### `skills run <skillId>`

Execute a skill.

```bash
skills run my-skill -p '{"param1": "value"}'
skills run my-skill --tool tool-name -p '{"param1": "value"}'
skills run my-skill -i  # Interactive mode
```

#### `skills remove <skillId>`

Remove an installed skill.

```bash
skills remove my-skill
skills rm my-skill -y
```

#### `skills info <skillId>`

Show detailed information about a skill.

```bash
skills info my-skill
```

#### `skills init [name]`

Initialize a new skill project.

```bash
skills init my-new-skill
skills init my-new-skill --directory ./skills
```

#### `skills check`

Check for skill updates.

```bash
skills check
```

#### `skills update [skillId]`

Update skills to their latest versions.

```bash
skills update my-skill
skills update --all
```

#### `skills config <skillId>`

Manage skill configuration.

```bash
skills config my-skill --list
skills config my-skill --get API_KEY
skills config my-skill --set API_KEY=abc123
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

## Environment Variables

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
| `searchSkills(query)` | Search for skills |
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

## License

MIT
