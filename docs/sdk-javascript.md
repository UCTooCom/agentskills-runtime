# JavaScript SDK 文档

`@opencangjie/skills` 是 AgentSkills Runtime 的 JavaScript/TypeScript SDK，允许开发者通过 npm 安装并调用 AgentSkills Runtime API 来管理技能，同时内置运行时管理功能。

## 概述

本 SDK 提供以下功能：

- **运行时管理**：下载、安装、启动、停止 AgentSkills 运行时
- **CLI 工具**：命令行界面，支持技能搜索、安装、执行、删除等操作
- **编程 API**：TypeScript/JavaScript 客户端库，可在代码中调用
- **类型定义**：完整的 TypeScript 类型支持
- **跨平台支持**：Windows、macOS、Linux

## 安装

```bash
npm install @opencangjie/skills
```

或直接使用 npx 运行：

```bash
npx @opencangjie/skills find react
npx @opencangjie/skills list
npx @opencangjie/skills add ./my-skill
```

## 快速开始

### 1. 安装运行时

```bash
# 下载并安装 AgentSkills 运行时
npx skills install-runtime

# 或指定版本
npx skills install-runtime --version 0.0.1
```

### 2. 启动运行时

```bash
# 前台启动
npx skills start

# 后台启动
npx skills start --detached

# 自定义端口和主机
npx skills start --port 3000 --host 0.0.0.0
```

### 3. 管理技能

```bash
# 查找并安装技能
npx skills find react
npx skills add ./my-skill

# 列出已安装技能
npx skills list

# 执行技能
npx skills run my-skill -p '{"input": "data"}'
```

## 项目结构

```
sdk/javascript/
├── package.json          # NPM 包配置
├── tsconfig.json         # TypeScript 编译配置
├── README.md             # 快速入门文档
├── scripts/
│   ├── postinstall.js    # 安装后脚本
│   └── runtime.js        # 运行时管理脚本
└── src/
    ├── index.ts          # 主入口 - API Client、RuntimeManager 和类型定义
    └── cli.ts            # CLI 工具实现
```

## CLI 命令

### 运行时管理

#### `skills install-runtime`

下载并安装 AgentSkills 运行时二进制文件。

```bash
skills install-runtime
skills install-runtime --version 0.0.1
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-v, --version <version>` | 要安装的运行时版本，默认 0.0.1 |

#### `skills start`

启动 AgentSkills 运行时服务器。

```bash
# 前台启动
skills start

# 后台启动
skills start --detached

# 自定义配置
skills start --port 3000 --host 0.0.0.0
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-p, --port <port>` | 监听端口，默认 8080 |
| `-h, --host <host>` | 绑定主机，默认 127.0.0.1 |
| `-d, --detached` | 后台运行 |

#### `skills stop`

停止 AgentSkills 运行时服务器。

```bash
skills stop
```

#### `skills status`

检查技能运行时服务器状态。

```bash
skills status
```

### 技能管理

#### `skills find [query]`

搜索技能，支持交互式搜索或关键字搜索。

```bash
# 交互式搜索
skills find

# 按关键字搜索
skills find react testing
skills find "pdf generation"
skills find deployment
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-l, --limit <number>` | 最大结果数量，默认 10 |

#### `skills add <source>`

从 GitHub 或本地路径安装技能。

```bash
# 从本地路径安装
skills add ./my-skill

# 从 GitHub 安装
skills add github.com/user/skill-repo

# 带选项安装
skills add ./my-skill --validate
skills add github.com/user/skill-repo --branch develop
skills add github.com/user/skill-repo --tag v1.0.0
skills add github.com/user/skill-repo --commit abc1234
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-g, --global` | 全局安装（用户级别） |
| `-p, --path <path>` | 本地技能路径 |
| `-b, --branch <branch>` | Git 分支名 |
| `-t, --tag <tag>` | Git 标签名 |
| `-c, --commit <commit>` | Git 提交 ID |
| `-n, --name <name>` | 技能名称覆盖 |
| `--validate` | 安装前验证技能 |
| `--no-validate` | 跳过验证 |
| `-y, --yes` | 跳过确认提示 |

#### `skills list`

列出已安装的技能。

```bash
skills list
skills list --limit 50
skills list --page 1
skills list --json
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-l, --limit <number>` | 最大结果数量，默认 20 |
| `-p, --page <number>` | 页码，默认 0 |
| `--json` | JSON 格式输出 |

#### `skills run <skillId>`

执行技能。

```bash
# 带参数执行
skills run my-skill -p '{"param1": "value"}'

# 执行特定工具
skills run my-skill --tool tool-name -p '{"param1": "value"}'

# 交互模式
skills run my-skill -i

# 从文件加载参数
skills run my-skill -f params.json
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-t, --tool <name>` | 要执行的工具名称 |
| `-p, --params <json>` | JSON 格式的参数字符串 |
| `-f, --params-file <file>` | 参数 JSON 文件路径 |
| `-i, --interactive` | 交互式参数输入 |

#### `skills remove <skillId>`

删除已安装的技能。

```bash
skills remove my-skill
skills rm my-skill -y  # 跳过确认
```

**别名：** `rm`, `uninstall`

**选项：**

| 选项 | 说明 |
|------|------|
| `-y, --yes` | 跳过确认提示 |

#### `skills info <skillId>`

显示技能详细信息。

```bash
skills info my-skill
```

#### `skills init [name]`

初始化新的技能项目。

```bash
skills init my-new-skill
skills init my-new-skill --directory ./skills
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-d, --directory <dir>` | 目标目录，默认当前目录 |
| `-t, --template <template>` | 技能模板，默认 basic |

#### `skills check`

检查技能更新。

```bash
skills check
```

#### `skills update [skillId]`

更新技能到最新版本。

```bash
# 更新特定技能
skills update my-skill

# 更新所有技能
skills update --all
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-a, --all` | 更新所有已安装技能 |

#### `skills config <skillId>`

管理技能配置。

```bash
# 列出所有配置
skills config my-skill --list

# 获取特定配置值
skills config my-skill --get API_KEY

# 设置配置值
skills config my-skill --set API_KEY=abc123
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-s, --set <key=value>` | 设置配置值 |
| `-g, --get <key>` | 获取配置值 |
| `-l, --list` | 列出所有配置 |

## 编程 API

### 基本使用

```typescript
import { createClient, SkillsClient, RuntimeManager } from '@opencangjie/skills';

const client = createClient({
  baseUrl: 'http://127.0.0.1:8080',
  authToken: 'your-jwt-token' // 可选
});

// 检查运行时状态
const status = await client.runtime.status();
console.log(`运行时运行中: ${status.running}`);

// 列出技能
const result = await client.listSkills({ limit: 10 });
console.log(result.skills);

// 执行技能
const execResult = await client.executeSkill('my-skill', {
  param1: 'value'
});
console.log(execResult.output);
```

### 运行时管理

```typescript
import { RuntimeManager } from '@opencangjie/skills';

const runtime = new RuntimeManager();

// 检查运行时是否已安装
if (!runtime.isInstalled()) {
  // 下载并安装
  await runtime.downloadRuntime('1.0.0');
}

// 检查状态
const status = await runtime.status();
if (!status.running) {
  // 启动运行时
  runtime.start({
    port: 8080,
    host: '127.0.0.1',
    detached: true
  });
}

// 停止运行时
runtime.stop();
```

### 安装和管理技能

```typescript
// 从本地路径安装
const installResult = await client.installSkill({
  source: './my-skill',
  validate: true
});

// 从 Git 安装
const gitInstallResult = await client.installSkill({
  source: 'https://github.com/user/skill.git',
  branch: 'main'
});

// 卸载
await client.uninstallSkill('my-skill');

// 更新
await client.updateSkill('my-skill', { version: '2.0.0' });
```

### 执行技能

```typescript
// 带参数执行技能
const result = await client.executeSkill('my-skill', {
  input: 'data'
});

if (result.success) {
  console.log(result.output);
} else {
  console.error(result.errorMessage);
}

// 执行特定工具
const toolResult = await client.executeSkillTool('my-skill', 'tool-name', {
  param1: 'value'
});
```

### 配置管理

```typescript
// 获取配置
const config = await client.getSkillConfig('my-skill');
console.log(config);

// 设置配置
await client.setSkillConfig('my-skill', {
  API_KEY: 'abc123',
  DEBUG: 'true'
});
```

## 类型定义

### Skill

```typescript
interface Skill {
  id: string;
  name: string;
  version: string;
  description: string;
  author: string;
  license?: string;
  format?: string;
  source_path: string;
  created_at?: string;
  updated_at?: string;
  metadata?: Record<string, unknown>;
  dependencies?: string[];
  tools?: ToolDefinition[];
}
```

### ToolDefinition

```typescript
interface ToolDefinition {
  name: string;
  description: string;
  parameters: ToolParameter[];
}

interface ToolParameter {
  name: string;
  paramType: 'string' | 'number' | 'boolean' | 'file' | 'array' | 'object';
  description: string;
  required: boolean;
  defaultValue?: string | number | boolean;
}
```

### SkillExecutionResult

```typescript
interface SkillExecutionResult {
  success: boolean;
  output: string;
  errorMessage: string | null;
  data?: Record<string, unknown>;
}
```

### RuntimeStatus

```typescript
interface RuntimeStatus {
  running: boolean;
  version?: string;
  pid?: number;
  port?: number;
}
```

### RuntimeOptions

```typescript
interface RuntimeOptions {
  port?: number;
  host?: string;
  detached?: boolean;
}
```

## API 参考

### SkillsClient 方法

| 方法 | 说明 |
|------|------|
| `runtime` | 访问 RuntimeManager 实例 |
| `healthCheck()` | 检查服务器状态 |
| `listSkills(options)` | 列出已安装技能 |
| `getSkill(skillId)` | 获取技能详情 |
| `installSkill(options)` | 安装技能 |
| `uninstallSkill(skillId)` | 卸载技能 |
| `executeSkill(skillId, params)` | 执行技能 |
| `executeSkillTool(skillId, toolName, args)` | 执行特定工具 |
| `searchSkills(query)` | 搜索技能 |
| `updateSkill(skillId, updates)` | 更新技能 |
| `getSkillConfig(skillId)` | 获取技能配置 |
| `setSkillConfig(skillId, config)` | 设置技能配置 |
| `listSkillTools(skillId)` | 列出技能中的工具 |

### RuntimeManager 方法

| 方法 | 说明 |
|------|------|
| `isInstalled()` | 检查运行时是否已安装 |
| `getRuntimePath()` | 获取运行时二进制路径 |
| `downloadRuntime(version)` | 下载并安装运行时 |
| `start(options)` | 启动运行时服务器 |
| `stop()` | 停止运行时服务器 |
| `status()` | 检查运行时状态 |

## 架构

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

## 环境变量

### 运行时配置

运行时从可执行文件所在目录的 `.env` 文件加载环境变量。

**位置：** 将 `.env` 文件放置在 `bin/` 目录中，与 `agentskills-runtime.exe` 同级：

```
sdk/javascript/runtime/win-x64/release/bin/.env
```

**`.env` 文件示例：**

```env
# GitHub Personal Access Token（可选，用于提高速率限制）
GITHUB_TOKEN=ghp_your_github_token

# Gitee Private Token（可选，用于提高速率限制）
GITEE_TOKEN=your_gitee_token

# AtomGit Access Token（可选，用于提高速率限制）
ATOMGIT_TOKEN=your_atomgit_token
```

**获取 Token 的方式：**

| 平台 | 获取方式 | 认证方式 |
|------|----------|----------|
| GitHub | [Settings → Tokens](https://github.com/settings/tokens) | `Authorization: token` 请求头 |
| Gitee | [设置 → 私人令牌](https://gitee.com/profile/personal_access_tokens) | `access_token` URL 参数 |
| AtomGit | [设置 → 访问令牌](https://atomgit.com/-/profile/personal_access_tokens) | `access_token` URL 参数 |

> **注意：** API Token 是**可选的**。不配置 Token 也可以搜索，只是速率限制较低：
> - GitHub：未认证 10 次/分钟，认证后 30 次/分钟
> - Gitee/AtomGit：未认证有限制，认证后限制更高

### SDK 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `SKILL_RUNTIME_API_URL` | API 服务器地址 | `http://127.0.0.1:8080` |
| `SKILL_*` | 技能配置（通过 `getConfig()` 访问） | - |

## 与 Vercel Labs Skills CLI 对比

| 特性 | @opencangjie/skills | Vercel Labs Skills CLI |
|------|---------------------|------------------------|
| 运行时管理 | 内置 | 外部依赖 |
| 搜索技能 | `skills find` | `npx skills find` |
| 安装技能 | `skills add` | `npx skills add` |
| 列出技能 | `skills list` | 无 |
| 执行技能 | `skills run` | 无 |
| 删除技能 | `skills remove` | 无 |
| 初始化项目 | `skills init` | `npx skills init` |
| 检查更新 | `skills check` | `npx skills check` |
| 配置管理 | `skills config` | 无 |
| 后端服务 | 本地 AgentSkills Runtime | skills.sh 云服务 |
| 运行时 | Cangjie (原生) | Node.js |
| 平台支持 | Win/Mac/Linux | Win/Mac/Linux |
| API 协议 | RESTful + MCP | RESTful |

## 定义技能

可以使用 SDK 以编程方式定义技能：

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

// 访问配置
const config = getConfig();
const apiKey = config.API_KEY;
```

## 发布到 NPM

```bash
cd apps/agentskills-runtime/sdk/javascript
npm login
npm publish --access public
```

## 许可证

MIT
