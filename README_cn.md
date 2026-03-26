# AgentSkills Runtime

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.0.19-blue.svg)](https://github.com/UCTooCom/agentskills-runtime)
[![Cangjie](https://img.shields.io/badge/language-Cangjie-orange.svg)](https://cangjie-lang.cn/)

## 项目简介

AgentSkills Runtime 是一个基于仓颉编程语言实现的 Agent Skills 标准运行时环境。它是对 AgentSkills 开放标准的国产技术栈实现，提供了安全、高效的 AI 智能体技能执行环境。旨在让 AgentSkills 能够在任何地方运行。同时提供了多语言SDK适配各种技术栈。开源项目地址：https://atomgit.com/uctoo/agentskills-runtime 和 https://github.com/UCTooCom/agentskills-runtime

## 概述

AgentSkills Runtime 是一个全面的框架，用于构建和执行 AI 智能体技能。它为遵循 agentskills 标准的 AI 智能体工具提供了安全、便携和智能的运行时环境。该框架基于仓颉编程语言构建，并融合了UCToo项目架构的先进特性。

该框架包括：
- 对 agentskills 标准的支持，包括 SKILL.md 文件的加载和验证
- DSL 支持，包含 `@skill`、`@tool` 和 `@agent` 宏
- 清晰的关注点分离的整洁架构（领域层、应用层、基础设施层）
- MCP（Model Context Protocol）支持，用于与 AI 智能体集成
- 技能到工具的适配器，实现技能与工具的兼容性
- 从可配置目录进行渐进式技能加载
- 基于 WASM 的安全沙箱，用于安全的技能执行
- 具有混合密集+稀疏搜索能力的高级 RAG 搜索
- 多格式技能支持（WASM 组件和 SKILL.md 文件）

## 🎯 项目愿景

打造国产自主可控的 AI 智能体技能运行时，推动 Agent Skills 标准在AI生态中的落地应用，构建开放、安全、高效的 AI 原生应用基础设施。旨在让 AgentSkills 能够在任何地方运行。

## 架构设计

该实现遵循整洁架构原则，采用三层架构设计，具有清晰的关注点分离：

### 三层架构

- **Controller 层（表示层）**：处理 HTTP 请求和响应，管理 API 端点
- **Service 层（应用层）**：业务逻辑处理，协调用例（SkillManagementService、AgentSkillsService 等）
- **Repository 层（基础设施层）**：数据访问和外部资源管理（数据库、文件系统等）

### 核心模块

- **magic.app**：主应用模块，提供完整的 API 服务
- **magic.core**：核心领域模型和业务逻辑
- **magic.skill**：技能管理和执行引擎
- **magic.model**：AI 模型集成和管理

### 技术栈

- **HTTP 框架**：自定义 HTTP 框架（封装 stdx.net.http），支持中间件
- **ORM 框架**：Fountain ORM（f_orm），支持多种数据库
- **认证**：JWT 认证（jwt4cj）
- **日志**：结构化日志（logcj）
- **字符编码**：多语言支持（charset4cj）

## 功能特性

### AgentSkills 标准支持
- 根据 agentskills 规范从 SKILL.md 文件加载技能
- 带验证的 YAML 前置元数据解析
- 用于技能指令的 Markdown 正文处理
- 外部资源访问（scripts/、references/、assets/）

### DSL 支持
- `@skill` 宏用于声明式技能定义
- `@tool` 宏用于工具定义
- `@agent` 宏用于智能体定义

### 安全性
- 基于 WASM 的安全沙箱，支持组件模型
- 基于能力的访问控制（文件系统、网络等）
- 资源配额和执行限制
- 执行上下文隔离

### 搜索与发现
- 具有混合密集+稀疏搜索的高级 RAG 搜索（向量嵌入 + BM25 与 RRF 融合）
- 交叉编码器重排序以提高精度
- 带意图分类和实体提取的查询理解
- 用于令牌高效输出的上下文压缩

### 多格式技能支持
- 支持组件模型的 WASM 组件执行
- 遵循 agentskills 标准的 SKILL.md 文件解析和执行
- 格式无关的技能接口
- 动态格式检测和验证

### MCP 集成
- 从技能清单动态发现工具
- 与 MCP 协议的语义搜索集成
- 大型技能目录的分页支持
- 带嵌入式 Web UI 的 HTTP 流模式

### 多语言生态系统支持
- **跨语言互操作性**：支持不同编程语言编写的技能在同一运行时环境中协同工作
- **语言适配器**：为不同编程语言提供标准化的技能接口适配器
- **统一 API 层**：抽象底层实现细节，提供一致的编程接口
- **依赖管理**：智能处理多语言项目的依赖关系和版本冲突

### 多语言 SDK 支持
- **JavaScript/TypeScript SDK**：完整的 Node.js 和浏览器环境支持
- **Python SDK**：集成流行的 Python AI 和数据科学库

## 内置工具 v2.0

AgentSkills Runtime v2.0 提供了完整的内置工具集,支持CLI、HTTP和内部API三种调用方式,所有工具都集成了RBAC权限体系。

### 工具分类

#### 文件系统工具 (9个)
- `file_read` - 文件读取 (敏感级别: 低)
- `file_write` - 文件写入 (敏感级别: 中)
- `file_edit` - 文件编辑 (敏感级别: 中)
- `file_delete` - 文件删除 (敏感级别: 高,需确认)
- `file_copy` - 文件复制 (敏感级别: 低)
- `file_move` - 文件移动 (敏感级别: 中)
- `file_search` - 文件搜索 (敏感级别: 低)
- `directory_list` - 目录列表 (敏感级别: 低)
- `directory_create` - 创建目录 (敏感级别: 中)

#### 网络工具 (4个)
- `http_request` - HTTP请求 (敏感级别: 中)
- `web_fetch` - 网页抓取 (敏感级别: 低)
- `firecrawl` - Firecrawl爬虫 (敏感级别: 中)
- `browser_tool` - 浏览器工具 (敏感级别: 中)

#### 技能工具 (2个)
- `skill_initializer` - 技能初始化 (敏感级别: 中)
- `skill_packager` - 技能打包 (敏感级别: 中)

#### 代码生成工具 (2个)
- `template_engine` - 模板引擎 (敏感级别: 低)
- `code_snippet_generator` - 代码片段生成 (敏感级别: 低)

#### CLI工具 (1个)
- `cli_execute` - CLI命令执行 (敏感级别: 高,需确认)

### HTTP接口

**基础路径**: `/api/v1/tools`

**接口列表**:
- `GET /api/v1/tools/list` - 获取工具列表
- `GET /api/v1/tools/:toolName/info` - 获取工具信息
- `POST /api/v1/tools/:toolName` - 调用工具

**使用示例**:
```bash
# 获取工具列表
curl -X GET https://javatoarktsapi.uctoo.com/api/v1/tools/list \
  -H "Authorization: Bearer <token>"

# 调用文件读取工具
curl -X POST https://javatoarktsapi.uctoo.com/api/v1/tools/file_read \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"path": "./SKILL.md"}'
```

### 权限体系

所有工具调用都受RBAC权限体系保护:
- **敏感级别**: 低(1)、中(2)、高(3)
- **权限检查**: 每次调用都验证用户权限
- **审计日志**: 所有操作记录到数据库
- **二次确认**: 高敏感操作需要确认参数

详细文档: [内置工具文档](./docs/builtin-tools.md)

## 高性能应用服务器

AgentSkills Runtime 内置了高性能HTTP/HTTPS应用服务器,提供企业级的API服务能力。

### 服务器特性

- **HTTPS支持**: 内置SSL/TLS加密,支持证书配置
- **高性能路由**: 基于Trie树的高效路由匹配
- **中间件系统**: 可扩展的中间件链
- **WebSocket支持**: 实时双向通信
- **连接池**: 数据库连接池管理
- **缓存系统**: 内置缓存管理器

### 核心组件

#### HTTPServer
- 支持HTTP/HTTPS协议
- 可配置的线程池
- 请求/响应拦截器
- 静态文件服务

#### Router
- RESTful路由支持
- 路径参数提取
- 路由分组
- 中间件挂载

#### Middleware
- `DeserializeUserMiddleware` - JWT认证
- `RequirePermissionMiddleware` - 权限检查
- `CORSMiddleware` - 跨域支持
- `LoggingMiddleware` - 请求日志

### 服务配置

```ini
# .env 配置
PORT=443
HOST=0.0.0.0
SSL_CERT=./ssl/server.crt
SSL_KEY=./ssl/server.key
DB_URL=postgresql://user:pass@host:port/db
```

### 启动服务

```bash
# 编译
cjpm build

# 启动HTTPS服务
cjpm run --skip-build --name magic.app
```

### API端点

- `GET /hello` - 健康检查
- `GET /api/v1/health` - 服务状态
- `GET /api/v1/info` - 应用信息
- `/api/v1/uctoo/*` - UCToo业务API
- `/api/v1/tools/*` - 工具管理API
- `/api/v1/skills/*` - 技能管理API

### 性能指标

- **并发连接**: 支持1000+并发连接
- **响应时间**: 平均响应时间 < 50ms
- **吞吐量**: > 10000 req/s
- **内存占用**: 基础内存 < 100MB
- **Java SDK**：企业级应用和 Android 平台支持
- **Go SDK**：高性能并发处理和云原生应用支持
- **Rust SDK**：系统级性能和内存安全保证
- **C# SDK**：.NET 生态系统和 Windows 平台集成

## 核心特性

### 🚀 高性能执行
- **高性能**:  基于仓颉编程语言的高性能运行时
- **强安全**:  WASM 沙箱安全执行环境  + 多层权限控制的安全架构
- **标准化**: 完全兼容 AgentSkills 开放标准规范

### 🔒 安全可靠
- **执行隔离**: 多层安全防护机制
- **权限控制**: 细粒度的权限管理和资源访问控制
- **审计追踪**: 完整的操作日志和安全审计机制

### 📦 标准兼容
- 完全兼容 AgentSkills 开放标准
- 支持 SKILL.md 文件格式
- 实现标准的 YAML 前置元数据规范

### 🔧 易用性
- **简单集成**: 提供简洁的 API 接口
- **丰富示例**: 多样化的使用示例和最佳实践
- **详细文档**: 完善的中英文技术文档

### 🔧 灵活扩展
- 插件化架构设计
- 支持自定义技能开发
- 丰富的 API 接口和工具集

## 快速开始

### 最简单的演示方案（推荐）

如果您想快速体验 AgentSkills Runtime 的功能，**无需下载本项目源码**，只需部署 [UCToo 项目](https://gitee.com/uctoo/uctoo) 即可：

#### 部署步骤

1. **部署 UCToo 项目**
   - 按照 [UCToo 部署文档](https://gitee.com/uctoo/uctoo) 部署 backend 和 web 端
   - UCToo 已内置 AgentSkills Runtime JavaScript SDK

2. **配置大模型 API Key**
   - 在 backend 项目的 agentskills-runtime JavaScript SDK 目录中找到 `.env` 文件
   - 配置大模型 API Key（支持 DeepSeek、OpenAI、华为云 MaaS 等）
   ```ini
   MODEL_PROVIDER=deepseek
   MODEL_NAME=deepseek-chat
   DEEPSEEK_API_KEY=your_api_key_here
   ```

3. **体验自然语言数据库查询**
   - 打开 UCToo Web 端的 **AI 模块 -> 对话页面**
   - 使用自然语言与 AI 对话，实现对 UCToo 数据库的 CRUD 操作
   - 示例对话：
     - *"查询最近一周注册的用户列表"*
     - *"创建一个名为'张三'的新用户"*
     - *"统计本月订单总金额"*

#### 方案优势
- **零配置**: 无需安装仓颉编程语言环境
- **即开即用**: UCToo 已集成完整的运行时环境
- **功能完整**: 支持内置的 uctoo-api-skill 技能，实现自然语言数据库操作
- **易于扩展**: 可在 UCToo 框架基础上继续开发自定义技能

### 从源码开始（开发者）

如果您需要对 runtime 进行二次开发或贡献代码，请参考以下步骤：

#### 环境要求
- 仓颉编程语言环境 (https://cangjie-lang.cn/)
- 支持的操作系统: Windows/Linux/macOS
- **Windows 系统特别要求**: 需要安装 OpenSSL 库以支持 WebSocket 通信
  - 下载地址: https://slproweb.com/products/Win32OpenSSL.html
  - 安装时选择 "Copy OpenSSL DLLs to: The OpenSSL binaries (/bin) directory"
  - 确保 OpenSSL 的 bin 目录已添加到系统 PATH 环境变量

#### 安装

```bash
# 确保已安装仓颉编程语言环境
cjpm --version

# 克隆项目
git clone https://atomgit.com/uctoo/agentskills-runtime.git
cd agentskills-runtime
```

### 运行示例
```bash
# 构建项目（Windows 需要配置CANGJIE_HOME、CANGJIE_STDX_PATH环境变量）
cjpm build

# 运行示例
cjpm run --skip-build --name magic.examples.uctoo_api_skill
```

### 运行 API 服务
```bash
# 在默认端口 8080 上运行 API 服务
cjpm run --skip-build --name magic.app
# 或在指定端口上运行
cjpm run --skip-build --name magic.app 8081
```

有关运行 API 服务的详细说明，请参见 [API 服务运行指南](docs/api-service-run.md)。

## 发布打包

### 构建发布包

AgentSkills Runtime 提供了自动化打包脚本，可以从源码构建发布包。
#### 构建步骤

```bash
# 1. 构建项目
cjpm build

# 2. 运行打包脚本（自动从 cjpm.toml 读取版本号）
cjpm run --name magic.scripts.package_release
```

#### 打包脚本功能

- **自动版本检测**：从 `cjpm.toml` 文件自动读取版本号
- **自动平台检测**：自动检测当前操作系统和架构
- **精简打包**：自动排除 examples、tests 等非必要模块
- **完整依赖**：包含所有运行时所需的 DLL 文件

#### 输出文件

打包完成后，将在 `release/` 目录生成发布包：

```
release/
├── agentskills-runtime-win-x64.tar.gz    # Windows x64 发布包
├── agentskills-runtime-linux-x64.tar.gz  # Linux x64 发布包
├── agentskills-runtime-darwin-arm64.tar.gz # macOS ARM64 发布包
└── .env.example                           # 环境变量配置模板
```

#### 发布包目录结构

```
release/
├── bin/                    # 可执行文件和所有 DLL
│   ├── agentskills-runtime.exe  # 主入口程序
│   └── *.dll               # 所有依赖库
├── magic/                  # 运行时模块
├── commonmark4cj/          # Markdown 解析器
├── yaml4cj/                # YAML 解析器
├── VERSION                 # 版本信息
└── .env.example            # 配置模板
```

#### 使用发布包

```bash
# 1. 解压发布包
tar -xzf agentskills-runtime-win-x64.tar.gz

# 2. 进入目录并配置环境变量
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置 API 密钥

# 3. 运行服务
./bin/agentskills-runtime.exe 8080
```

### 版本发布流程

1. 更新 `cjpm.toml` 中的版本号
2. 更新 `CHANGELOG.md` 记录变更
3. 运行 `cjpm build` 构建项目
4. 运行 `cjpm run --name magic.scripts.package_release` 打包
5. 上传发布包到 GitHub Releases 或 AtomGit Releases

### API 端点
启动 API 服务后，以下端点将可用（所有 API 使用 `/api/v1/uctoo` 前缀）：

#### 技能管理 API
- **GET /api/v1/uctoo/agent_skills** - 获取可用技能列表
- **GET /api/v1/uctoo/agent_skills/:id** - 获取特定技能的详细信息
- **POST /api/v1/uctoo/skills/install** - 安装新技能
- **POST /api/v1/uctoo/agent_skills/edit** - 编辑现有技能
- **POST /api/v1/uctoo/agent_skills/del** - 删除技能
- **POST /api/v1/uctoo/skills/execute** - 执行技能
- **POST /api/v1/uctoo/skills/search** - 搜索技能

#### 其他 API
- **GET /api/v1/uctoo/health** - 健康检查端点
- **GET /api/v1/uctoo/mcp/stream** - MCP 服务器流式接口
- **WS /api/v1/uctoo/ws/chat** - WebSocket 聊天接口（支持 AI 对话和技能执行）

### WebSocket 聊天接口

WebSocket 端点 `/ws/chat` 提供实时 AI 对话和技能执行功能：

#### 连接地址
```
ws://127.0.0.1:8080/api/v1/uctoo/ws/chat
```

#### 消息格式

**发送聊天消息：**
```json
{
  "type": "chat",
  "content": "你好，请帮我分析这段代码"
}
```

**执行技能：**
```json
{
  "type": "execute_skill",
  "skill_id": "skill-name",
  "parameters": {
    "param1": "value1"
  },
  "timeout": "60s"
}
```

**获取技能列表：**
```json
{
  "type": "list_skills"
}
```

**心跳检测：**
```json
{
  "type": "ping"
}
```

#### 响应消息类型

- `welcome` - 连接建立时的欢迎消息
- `chat_response` - AI 对话响应
- `skill_result` - 技能执行结果
- `skills_list` - 技能列表
- `status` - 状态更新
- `error` - 错误消息
- `pong` - 心跳响应

#### 配置要求

WebSocket 聊天功能需要配置大模型 API Key。在 `.env` 文件中配置：

```env
# 华为云 MaaS 配置
MAAS_API_KEY=your_api_key_here
MAAS_BASE_URL=https://api.modelarts-maas.com/v2
```

支持的模型提供商包括：`maas`、`openai`、`deepseek`、`dashscope` 等。

## 使用方法

### 使用 DSL 创建技能

```cangjie
import { Skill, Tool } from "agentskills-runtime";

@Skill(
  name = "hello-world",
  description = "一个简单的问候用户技能",
  license = "MIT",
  metadata = {
    author = "您的姓名",
    version = "1.0.0",
    tags = ["问候", "示例"]
  }
)
public class HelloWorldSkill {
    @Tool(
      name = "greet",
      description = "按姓名问候用户",
      parameters = [
        { name: "name", type: "string", required: true, description: "要问候的人的姓名" }
      ]
    )
    public String greet(String name) {
        return "你好，" + name + "!";
    }
}
```

### 从 SKILL.md 加载技能

创建一个 `SKILL.md` 文件：

```markdown
---
name: example-skill
description: 演示 SKILL.md 格式的示例技能
license: MIT
metadata:
  author: 您的姓名
  version: "1.0"
---

# 示例技能

这是一个演示 SKILL.md 格式的示例技能。

## 提供的工具

### greet

按姓名问候用户。

**参数：**
- `name`（必需，字符串）：要问候的人的姓名

**示例：**
```bash
skill run example-skill:greet name=Alice
```
```

### 渐进式技能加载

```cangjie
let skillDir = "path/to/skill/directory"
let loader = ProgressiveSkillLoader(skillBaseDirectory: skillDir)
let skillManager = CompositeSkillToolManager()
let skills = loader.loadSkillsToManager(skillManager)
```

## 应用案例

### 🎯 自然语言查询数据库 - uctoo-api-skill 示例

**uctoo-api-skill** 是一个完整的后端 API 集成技能示例，展示了如何通过自然语言查询数据库。

#### 功能特点
- **自然语言转 API 调用**：用户可以用自然语言描述查询需求，技能自动转换为 API 调用
- **多数据库支持**：配合 uctoo backend 项目，支持连接多种类型数据库（MySQL、PostgreSQL、MongoDB 等）
- **任意数据库结构**：无需预先定义表结构，支持任意数据库结构的查询
- **通用查询能力**：支持用户管理、产品管理、订单管理、登录认证等功能

#### 使用示例
用户输入：*"请查询最近一周注册的用户列表"*

技能自动执行：
1. 分析用户意图（查询用户）
2. 确定时间范围（最近一周）
3. 构造 API 请求：`GET /api/uctoo/entity/10/0?filter={"created_at":{"gte":"2024-01-01"}}&sort=-created_at`
4. 返回格式化结果

> **API 规范说明**：uctoo 遵循 RESTFul 风格 API，查询接口格式为 `/api/{database}/{table}/{limit}/{page}`，支持 Prisma ORM 的 where 条件查询（filter 参数）和 orderBy 排序（sort 参数，负号表示降序）。详见 [uctoo API 设计规范](https://gitee.com/uctoo/uctoo/blob/master/apps/uctoo-backend/docs/uctooAPI%E8%AE%BE%E8%AE%A1%E8%A7%84%E8%8C%83.md)。

#### 技术实现
- 使用内置的 `http_request` 工具发起 HTTP 请求
- 自动 Token 管理机制，无需手动处理认证
- 支持完整的 CRUD 操作

查看完整示例：[src/examples/uctoo_api_skill](src/examples/uctoo_api_skill)

### 🚀 无需仓颉编程语言 - JavaScript SDK 快速集成

如果您不需要对 runtime 进行二次开发，**无需掌握和安装仓颉编程语言**，只需使用多语言 SDK 即可快速集成。

#### 集成步骤

**1. 安装 JavaScript SDK**
```bash
npm install @opencangjie/skills
```

**2. 安装运行时二进制发布版**
```bash
# 自动下载并安装 AgentSkills 运行时
npx skills install-runtime

# 或指定版本
npx skills install-runtime --runtime-version 0.0.16
```

**3. 配置 AI 模型**
编辑运行时目录中的 `.env` 文件：
- **Windows**: `%USERPROFILE%\.agentskills-runtime\release\.env`
- **macOS/Linux**: `~/.agentskills-runtime/release/.env`

```ini
# 配置 AI 模型（以 DeepSeek 为例）
MODEL_PROVIDER=deepseek
MODEL_NAME=deepseek-chat
DEEPSEEK_API_KEY=your_deepseek_api_key_here
```

**4. 启动运行时**
```bash
npx skills start
```

**5. 安装并执行技能**
```bash
# 查找技能
npx skills find database

# 安装技能
npx skills add ./my-database-skill

# 执行技能
npx skills run my-database-skill -p '{"query": "查询用户信息"}'
```

#### 编程 API 使用
```typescript
import { createClient } from '@opencangjie/skills';

const client = createClient({
  baseUrl: 'http://127.0.0.1:8080'
});

// 列出技能
const skills = await client.listSkills();

// 执行技能
const result = await client.executeSkill('database-skill', {
  query: '查询最近一周注册的用户'
});

console.log(result.output);
```

#### 优势
- **渐进式 AI 能力**：在原有项目中渐进式实现 "+AI" 能力
- **零学习成本**：无需学习仓颉编程语言
- **快速集成**：几行代码即可集成 AI 技能
- **跨平台支持**：支持 Windows、macOS、Linux

查看完整 SDK 文档：[sdk/javascript/README_cn.md](sdk/javascript/README_cn.md)

### 多语言 SDK 使用示例

#### JavaScript/TypeScript 示例
```javascript
import { AgentSkillsRuntime } from '@agentskills/runtime';

// 初始化运行时
const runtime = new AgentSkillsRuntime({
  baseUrl: 'http://localhost:8080',
  apiKey: 'your-api-key'
});

// 加载并执行技能
const result = await runtime.executeSkill('example-skill', {
  name: 'Alice',
  age: 30
});

console.log('执行结果:', result);
```

#### Python 示例
```python
from agentskills import Runtime

# 初始化运行时
runtime = Runtime(
    base_url="http://localhost:8080",
    api_key="your-api-key"
)

# 加载并执行技能
result = runtime.execute_skill("example-skill", {
    "name": "Alice",
    "age": 30
})

print(f"执行结果: {result}")
```

#### Java 示例
```java
import com.agentskills.Runtime;
import com.agentskills.SkillResult;

// 初始化运行时
Runtime runtime = Runtime.builder()
    .baseUrl("http://localhost:8080")
    .apiKey("your-api-key")
    .build();

// 加载并执行技能
Map<String, Object> parameters = new HashMap<>();
parameters.put("name", "Alice");
parameters.put("age", 30);

SkillResult result = runtime.executeSkill("example-skill", parameters);
System.out.println("执行结果: " + result.getOutput());
```

## 开发指南

### 开发环境搭建

```bash
# 安装依赖
cjpm install

# 运行测试
cjpm test

# 代码检查
cjpm check
```

## 项目结构

```
apps/agentskills-runtime/
├── cjpm.toml                            # 仓颉包配置
├── build.cj                             # 构建脚本
├── README.md                            # 项目文档
├── README_cn.md                         # 中文项目文档
├── LICENSE                              # 许可证信息
├── docs/                                # 文档
│   ├── architecture.md                  # 架构概述
│   ├── quickstart.md                    # 快速入门指南
│   ├── builtin-tools.md                 # 内置工具文档
│   └── api-reference.md                 # API 参考
├── src/                                 # 源代码
│   ├── app/                            # 应用服务器模块
│   │   ├── main.cj                     # 应用主入口
│   │   ├── core/                       # 核心组件
│   │   │   ├── server/                 # HTTP/HTTPS服务器
│   │   │   ├── router/                 # 路由系统
│   │   │   ├── middleware/             # 中间件
│   │   │   ├── http/                   # HTTP请求/响应
│   │   │   └── database/               # 数据库连接池
│   │   ├── routes/                     # 路由处理
│   │   │   ├── skill/                  # 技能路由
│   │   │   └── tool/                   # 工具路由
│   │   ├── controllers/                # 控制器
│   │   ├── services/                   # 业务服务
│   │   ├── middlewares/                # 中间件实现
│   │   └── registry/                   # 自动路由注册
│   ├── skill/                          # 技能相关功能
│   │   ├── domain/                     # 技能领域模型
│   │   ├── infrastructure/             # 技能基础设施组件
│   │   └── application/                # 技能应用服务
│   ├── tool/                           # 工具模块
│   │   ├── tool_dispatcher.cj          # 工具调度器
│   │   ├── permission_checker.cj       # 权限检查器
│   │   ├── builtin_tools_registry.cj   # 内置工具注册
│   │   └── file_tools.cj               # 文件工具实现
│   ├── security/                       # 安全模块
│   │   ├── wasm_sandbox/               # WASM 沙箱
│   │   └── access_control/             # 访问控制
│   ├── runtime/                        # 运行时核心
│   ├── utils/                          # 工具函数
│   └── examples/                       # 示例实现
├── specs/                               # 规范文档
├── skills/                              # 示例和参考技能
├── sdk/                                 # 多语言 SDK 实现
│   ├── javascript/                     # JavaScript/TypeScript SDK
│   ├── python/                         # Python SDK
│   ├── java/                           # Java SDK
│   ├── go/                             # Go SDK
│   ├── rust/                           # Rust SDK
│   └── csharp/                         # C# SDK
└── tests/                               # 测试实现
```

## 依赖关系

此实现利用了仓颉生态系统中的现有库：
- `yaml4cj`：用于解析 SKILL.md 文件中的 YAML 前置元数据
- `commonmark4cj`：用于根据 CommonMark 规范处理 SKILL.md 文件中的 markdown 内容
- `stdx`：用于各种实用函数

### 多语言 SDK 依赖
各语言 SDK 依赖相应的生态系统：
- **JavaScript**: npm 包管理器，依赖主流 AI 库如 langchain、openai-api
- **Python**: pip 包管理器，依赖 numpy、scikit-learn、transformers 等
- **Java**: Maven/Gradle，依赖 Spring Boot、Apache HttpComponents
- **Go**: Go modules，依赖 gin、gorilla/websocket 等
- **Rust**: Cargo，依赖 tokio、serde、reqwest 等
- **C#**: NuGet，依赖 .NET Core 相关包

### 基本使用

```cangjie
import magic.agentskills.runtime

// 创建技能运行时实例
let runtime = SkillRuntime()

// 加载技能
let skill = runtime.loadSkill("path/to/skill")

// 执行技能
let result = skill.execute(params)
```

### 技能开发示例
```cangjie
import magic.agentskills.runtime
import magic.agentskills.skill.domain.models.skill_manifest

// 定义技能清单
let manifest = SkillManifest {
    name: "example_skill",
    version: "1.0.0",
    description: "示例技能",
    author: "UCToo",
    parameters: [],
    implementation: "./skill_impl.cj"
}

// 创建技能运行时
let runtime = SkillRuntime()

// 加载并执行技能
let skill_result = runtime.execute(manifest, {})
```

## 文档资源

- [完整文档](docs/)
- [API 参考](docs/api-reference.md)
- [开发指南](docs/skill-development.md)

### 规范驱动开发文档
- [AgentSkills 标准规范](specs/003-agentskills-enhancement/spec.md)
- [数据模型定义](specs/003-agentskills-enhancement/data-model.md)
- [实现计划](specs/003-agentskills-enhancement/plan.md)

## 贡献指南

欢迎参与项目贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

请参阅文档中的贡献指南。

### 贡献方式
1. **代码贡献**: 提交 Pull Request 改进代码
2. **文档完善**: 帮助完善技术文档和使用指南
3. **问题反馈**: 报告 Bug 或提出功能建议
4. **技能开发**: 开发新的技能示例
5. **SDK 开发**: 为新的编程语言开发 SDK
6. **语言适配器**: 开发新的语言适配器和绑定
7. **生态系统集成**: 集成主流开发工具和平台

### 开发流程
```bash
# Fork 项目
# 创建功能分支
git checkout -b feature/your-feature

# 提交更改
git commit -am 'Add new feature'

# 推送分支
git push origin feature/your-feature

# 创建 Pull Request
```

## 项目状态

- [x] 核心运行时实现
- [x] 安全沙箱机制
- [x] 标准兼容性验证
- [ ] 性能优化
- [ ] 生产环境部署
- [ ] 社区生态建设

## 整体流程与关键技术

### 核心工作流程

1. **技能发现与加载**
   - 自动扫描配置目录中的技能文件
   - 解析 SKILL.md 文件的 YAML 前置元数据
   - 验证技能格式和依赖关系

2. **安全执行环境**
   - WASM 沙箱提供隔离执行环境
   - 基于能力的权限控制系统
   - 资源使用监控和限制

3. **技能执行与编排**
   - 动态参数解析和验证
   - 技能间依赖关系管理
   - 执行结果收集和处理

### 关键技术组件

- **Skill Manifest Parser**: 解析和验证 SKILL.md 文件格式
- **WASM Runtime**: 安全的技能执行环境
- **Capability Manager**: 细粒度的权限控制系统
- **Resource Monitor**: 资源使用监控和配额管理
- **Dependency Resolver**: 技能依赖关系解析
- **Execution Orchestrator**: 技能执行编排引擎

## 许可证

本项目采用 MIT 许可证，详情请见 [LICENSE](LICENSE) 文件。

## 联系方式

- 项目主页: https://atomgit.com/uctoo/agentskills-runtime
- 问题反馈: https://atomgit.com/uctoo/agentskills-runtime/issues
- 邮件联系: contact@uctoo.com
- 微信交流群: 请通过项目主页获取入群二维码

## 致谢

感谢以下开源项目和社区的支持：

### 技术标准
- [AgentSkills 开放标准](https://github.com/agentskills/agentskills)
- [MCP (Model Context Protocol)](https://modelcontextprotocol.io/)

### 编程语言
- [仓颉编程语言](https://cangjie-lang.cn/)
- [WebAssembly](https://webassembly.org/)


### 开源工具
- [UCToo](https://gitee.com/uctoo/uctoo)
- [CangjieMagic](https://gitcode.com/Cangjie-TPC/CangjieMagic)
- 各种优秀的开源库和工具

### 参考资料
- [只需免费AI就能用仓颉开发强大Agent](https://mp.weixin.qq.com/s/jcUVuj7bLs9DaHLhol4-Hg)
- [深度解析agent skill标准](https://mp.weixin.qq.com/s/qFae5uqJsOAEkn1LN12tuA)

---
**AgentSkills Runtime - 让 AI 开发更简单、更安全、更快捷！**

