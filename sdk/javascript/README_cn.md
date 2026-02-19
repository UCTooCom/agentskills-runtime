# @opencangjie/skills

AgentSkills Runtime 的 JavaScript/TypeScript SDK - 安装、管理和执行 AI 代理技能，内置运行时支持。

## 特性

- **完整的运行时管理**：下载、安装、启动和停止 AgentSkills 运行时
- **技能管理**：安装、列表、执行和移除技能
- **CLI 与编程 API**：通过命令行使用或集成到您的应用程序中
- **跨平台**：支持 Windows、macOS 和 Linux

## 安装

```bash
npm install @opencangjie/skills
```

或直接使用 npx：

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
# 后台启动（默认）
npx skills start

# 前台启动
npx skills start --foreground

# 自定义端口和主机
npx skills start --port 3000 --host 0.0.0.0
```

### 3. 管理技能

```bash
# 查找并安装技能
npx skills find react
npx skills add ./my-skill

# 列出已安装的技能
npx skills list

# 执行技能
npx skills run my-skill -p '{"input": "data"}'
```

## CLI 命令

### 运行时管理

#### `npx skills install-runtime`

下载并安装 AgentSkills 运行时二进制文件。

```bash
npx skills install-runtime
npx skills install-runtime --version 0.0.1
```

#### `npx skills start`

启动 AgentSkills 运行时服务器。

```bash
# 后台启动（默认）
npx skills start

# 前台启动
npx skills start --foreground

# 自定义配置
npx skills start --port 3000 --host 0.0.0.0
```

**选项：**
- `-p, --port <port>` - 监听端口（默认：8080）
- `-h, --host <host>` - 绑定主机（默认：127.0.0.1）
- `-f, --foreground` - 前台运行（默认：后台）

#### `npx skills stop`

停止 AgentSkills 运行时服务器。

```bash
npx skills stop
```

#### `npx skills status`

检查技能运行时服务器的状态。

```bash
npx skills status
```

### 技能管理

#### `npx skills find [query]`

交互式搜索或按关键字搜索技能。

```bash
npx skills find
npx skills find react testing
npx skills find "pdf generation"
```

#### `npx skills add <source>`

从 GitHub 或本地路径安装技能。

```bash
npx skills add ./my-skill
npx skills add github.com/user/skill-repo
npx skills add github.com/user/skill-repo --branch develop
```

#### `npx skills list`

列出已安装的技能。

```bash
npx skills list
npx skills list --limit 50 --page 1
npx skills list --json
```

#### `npx skills run <skillId>`

执行技能。

```bash
npx skills run my-skill -p '{"param1": "value"}'
npx skills run my-skill --tool tool-name -p '{"param1": "value"}'
npx skills run my-skill -i  # 交互模式
```

#### `npx skills remove <skillId>`

移除已安装的技能。

```bash
npx skills remove my-skill
npx skills rm my-skill -y
```

#### `npx skills info <skillId>`

显示技能的详细信息。

```bash
npx skills info my-skill
```

#### `npx skills init [name]`

初始化一个新的技能项目。

```bash
npx skills init my-new-skill
npx skills init my-new-skill --directory ./skills
```

#### `npx skills check`

检查技能更新。

```bash
npx skills check
```

#### `npx skills update [skillId]`

将技能更新到最新版本。

```bash
npx skills update my-skill
npx skills update --all
```

#### `npx skills config <skillId>`

管理技能配置。

```bash
npx skills config my-skill --list
npx skills config my-skill --get API_KEY
npx skills config my-skill --set API_KEY=abc123
```

## 编程 API

### 基本用法

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

### 技能管理

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

## 定义技能

您也可以使用此 SDK 以编程方式定义技能：

```typescript
import { defineSkill, getConfig } from '@opencangjie/skills';

export default defineSkill({
  metadata: {
    name: 'my-skill',
    version: '1.0.0',
    description: '我的精彩技能',
    author: '您的名字'
  },
  tools: [
    {
      name: 'greet',
      description: '按名字问候某人',
      parameters: [
        {
          name: 'name',
          paramType: 'string',
          description: '要问候的名字',
          required: true
        }
      ]
    }
  ],
  validateConfig: (config) => {
    if (!config.API_KEY) {
      return { err: 'API_KEY 是必需的' };
    }
    return { ok: null };
  }
});

// 访问配置
const config = getConfig();
const apiKey = config.API_KEY;
```

## 架构

```
┌─────────────────────────────────────┐
│        语言生态系统                   │
│   (npm, pip, maven, cargo 等)        │
├─────────────────────────────────────┤
│  CLI 命令 (skills find/add/run)      │
├─────────────────────────────────────┤
│     SDK 编程 API                      │
│     (SkillsClient, RuntimeManager)   │
├─────────────────────────────────────┤
│   标准 API 接口层                     │
│     (RESTful + JWT 认证)             │
├─────────────────────────────────────┤
│   Agent Skill 运行时内核              │
│     (仓颉二进制)                      │
└─────────────────────────────────────┘
```

## 手动安装运行时

如果您希望在不使用 SDK 的情况下手动安装运行时：

### 下载

从 [AtomGit](https://atomgit.com/UCToo/agentskills-runtime/releases) 下载最新版本：

- `agentskills-runtime-win-x64.tar.gz` - Windows x64
- `agentskills-runtime-linux-x64.tar.gz` - Linux x64（即将推出）
- `agentskills-runtime-darwin-x64.tar.gz` - macOS x64（即将推出）

### 安装

```bash
# 下载并解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 进入 bin 目录
cd release/bin

# 运行运行时
./agentskills-runtime.exe
```

### 发布包内容

```
release/
├── bin/                    # 可执行文件和所有 DLL
│   ├── agentskills-runtime.exe    # 主入口点
│   ├── magic.api.exe              # 备用入口点
│   └── *.dll                      # 所有必需的 DLL (stdx, runtime, magic)
├── magic/                  # 运行时模块
├── commonmark4cj/          # Markdown 解析器
├── yaml4cj/                # YAML 解析器
└── VERSION                 # 版本信息
```

### 使用方法

解压后，直接运行可执行文件：

```bash
# Windows
cd release/bin
agentskills-runtime.exe

# 服务器将在 http://127.0.0.1:8080 启动
```

### API 端点

| 端点 | 方法 | 描述 |
|------|------|------|
| `/hello` | GET | 健康检查 |
| `/skills` | GET | 列出所有技能 |
| `/skills/:id` | GET | 获取技能详情 |
| `/skills/add` | POST | 安装技能 |
| `/skills/edit` | POST | 更新技能 |
| `/skills/del` | POST | 卸载技能 |
| `/skills/execute` | POST | 执行技能 |
| `/skills/search` | POST | 搜索技能 |
| `/mcp/stream` | GET | MCP 服务器流式传输 |

### 验证安装

```bash
# 检查健康状态
curl http://127.0.0.1:8080/hello
# 响应: {"message":"Hello World"}

# 列出技能
curl http://127.0.0.1:8080/skills
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

| 变量 | 描述 | 默认值 |
|------|------|--------|
| `SKILL_RUNTIME_API_URL` | API 服务器 URL | `http://127.0.0.1:8080` |
| `SKILL_*` | 技能配置（可通过 `getConfig()` 访问） | - |

## API 参考

### SkillsClient

| 方法 | 描述 |
|------|------|
| `runtime` | 访问 RuntimeManager 实例 |
| `healthCheck()` | 检查服务器状态 |
| `listSkills(options)` | 列出已安装的技能 |
| `getSkill(skillId)` | 获取技能详情 |
| `installSkill(options)` | 安装技能 |
| `uninstallSkill(skillId)` | 卸载技能 |
| `executeSkill(skillId, params)` | 执行技能 |
| `executeSkillTool(skillId, toolName, args)` | 执行特定工具 |
| `searchSkills(options)` | 搜索技能（支持 query, source, limit 参数） |
| `updateSkill(skillId, updates)` | 更新技能 |
| `getSkillConfig(skillId)` | 获取技能配置 |
| `setSkillConfig(skillId, config)` | 设置技能配置 |
| `listSkillTools(skillId)` | 列出技能中的工具 |

### RuntimeManager

| 方法 | 描述 |
|------|------|
| `isInstalled()` | 检查运行时是否已安装 |
| `getRuntimePath()` | 获取运行时二进制路径 |
| `downloadRuntime(version)` | 下载并安装运行时 |
| `start(options)` | 启动运行时服务器 |
| `stop()` | 停止运行时服务器 |
| `status()` | 检查运行时状态 |

## 与 Vercel Labs Skills CLI 对比

| 特性 | @opencangjie/skills | Vercel Labs Skills CLI |
|------|---------------------|------------------------|
| 运行时管理 | 内置 | 外部 |
| 安装方式 | npm install | npm install -g skills |
| 语言 | TypeScript/JavaScript | TypeScript |
| 运行时 | 仓颉（原生） | Node.js |
| 平台支持 | Win/Mac/Linux | Win/Mac/Linux |
| API 协议 | RESTful + MCP | RESTful |

## 实际使用示例

此 SDK 在 [UCToo](https://gitee.com/uctoo/uctoo) 开源项目中用于 AI 代理技能管理。

### 项目结构

```
uctoo/
├── apps/
│   ├── backend/                    # 后端 API 服务 (Node.js/TypeScript)
│   │   ├── package.json            # 包含: @opencangjie/skills
│   │   └── src/
│   │       └── app/services/uctoo/
│   │           └── runtimeManager.ts  # 运行时管理服务
│   │
│   ├── uctoo-app-client-pc/        # 前端应用 (Vue 3)
│   │   ├── package.json            # 包含: @opencangjie/skills
│   │   └── src/
│   │       └── views/uctoo/agent_skills/
│   │           └── home.vue        # 技能管理界面
│   │
│   └── agentskills-runtime/        # 运行时内核 (仓颉)
│       └── sdk/javascript/         # 本 SDK
```

### 后端集成 (apps/backend)

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

### 前端集成 (apps/uctoo-app-client-pc)

```vue
<!-- apps/uctoo-app-client-pc/src/views/uctoo/agent_skills/home.vue -->
<template>
  <div class="skill-management">
    <a-input-search
      v-model:value="searchQuery"
      placeholder="搜索技能..."
      @search="handleSearch"
    />
    
    <a-table :dataSource="skills" :columns="columns">
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'action'">
          <a-button @click="executeSkill(record.id)">执行</a-button>
        </template>
      </template>
    </a-table>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { createClient } from '@opencangjie/skills';

const client = createClient({
  baseUrl: '/api/skills'  // 代理到运行时
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
  // 打开执行对话框
};

onMounted(loadSkills);
</script>
```

### 包依赖配置

```json
// apps/backend/package.json
{
  "dependencies": {
    "@opencangjie/skills": "^0.0.13"
  }
}

// apps/uctoo-app-client-pc/package.json
{
  "dependencies": {
    "@opencangjie/skills": "^0.0.13"
  }
}
```

## 许可证

MIT
