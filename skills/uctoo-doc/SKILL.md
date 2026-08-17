---
name: uctoo-doc
description: UCTOO AgentSkills Runtime 项目文档查询、API 规范阅读与数据库 CRUD 查询助手。帮助用户和大模型快速查找和阅读 UCTOO 项目的各类文档（API 设计规范、数据库设计、后端架构、模块开发、权限体系、AgentSkills 标准等），并告知大模型可自行组装查询条件从数据库表的标准 CRUD API 中查询所需数据。当用户提及 UCTOO 文档、API 规范、数据库设计、项目文档、技术文档、CRUD 查询、AgentSkills Runtime、智能体互联国标 等关键词时，应使用此技能。
license: MIT
compatibility: 需要 runtime 内置文件工具支持（file_read/directory_list/file_search/web_fetch）
version: 2.0.0
---

# UCTOO 项目文档查询与数据库 CRUD 查询助手

## 概述

本技能帮助用户和大模型快速查找和阅读 UCTOO AgentSkills Runtime 项目的各类技术文档，并告知大模型可自行组装查询条件从数据库表的标准 CRUD API 中查询所需数据。大模型和 Agent 聊天产生的所有数据都已入库记录，可参考历史数据辅助决策。

### 核心能力

1. **文档检索**：从本地 docs 目录和远程 Gitee 仓库检索最新的 UCTOO 项目文档
2. **本地文档读取**：读取 runtime 项目中的本地技能文件和文档
3. **文档阅读**：获取并展示文档内容，支持 Markdown 格式
4. **知识问答**：基于文档内容回答用户的技术问题
5. **数据库 CRUD 查询**：告知大模型可参考 API 设计规范，自行组装查询条件，从数据库表的标准 CRUD API 中查询所需数据
6. **快速定位**：帮助用户快速找到特定章节或内容

## AgentSkills Runtime 项目说明

AgentSkills Runtime 是一个基于仓颉编程语言实现的 Agent Skills 标准运行时环境，是对 AgentSkills 开放标准的国产技术栈实现，提供安全、高效的 AI 智能体技能执行环境。旨在让 AgentSkills 能够在任何地方运行。

### 项目愿景

打造国产自主可控的 AI 智能体技能运行时，推动 Agent Skills 标准在 AI 生态中的落地应用，构建开放、安全、高效的 AI 原生应用基础设施。

### 三层架构

遵循整洁架构原则，采用三层架构设计，具有清晰的关注点分离：

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

### 智能体互联国家标准（GB/Z 185-2026）支持

AgentSkills Runtime 已实现对《人工智能 智能体互联》国家标准（GB/Z 185.1~185.7-2026）的支持，采用双模式分层架构：

- **本地模式（Local Mode）**：面向同一系统内 Agent 间协作场景，复用现有 uctoo_user + RBAC 体系进行身份管理，复用 agent_messages + agent_tasks 进行消息传递。系统默认运行在本地模式。
- **互联模式（Interconnection Mode）**：面向需要与外部系统智能体互联的场景，在本地模式基础上完整实现 GB/Z 185.2~185.7 能力，对接 ACPs 注册服务、CA 服务、发现服务、MQ 服务。互联模式是本地模式的超集。

| 国标部分 | 能力 | 本地模式 | 互联模式 |
|----------|------|----------|----------|
| GB/Z 185.2 | 智能体身份管理（AIC/CAI） | uctoo_user + RBAC | ACPs 注册服务 + AIC + CAI + mTLS |
| GB/Z 185.3 | 智能体可信注册（ATR） | 本地自动创建 | ACPs 注册服务完整流程 |
| GB/Z 185.4 | 智能体能力描述（ACS） | agents + agent_skills 表扩展 | 同步到 ACPs 注册/发现服务 |
| GB/Z 185.5 | 智能体发现（ADP） | 本地 agents 表查询 | ACPs 发现服务跨系统发现 |
| GB/Z 185.6 | 智能体交互协议（AIP） | agent_messages + agent_tasks | MQ 消息分发 + mTLS 认证 |
| GB/Z 185.7 | 工具调用 | 复用 MCP 工具体系 | 复用 MCP 工具体系 |

### 框架能力清单

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

## 可用工具

### 1. file_read - 读取本地文件

**功能**：读取本地文件内容，支持行范围选择和行号显示

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件路径（推荐使用绝对路径） |
| withLineNumber | Boolean | ❌ 否 | false | 是否在输出中添加行号 |
| startLine | Int | ❌ 否 | 1 | 起始行号（从 1 开始） |
| endLine | Int | ❌ 否 | -1 | 结束行号（-1 表示文件末尾） |
| offset | Int | ❌ 否 | 0 | 偏移量（兼容旧版 API，与 startLine 等效） |
| limit | Int | ❌ 否 | 0 | 读取行数限制（兼容旧版 API） |

**使用示例**：

```
file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills\\uctoo-doc\\SKILL.md"}
```

```
file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\builtin-tools.md", "withLineNumber": true, "startLine": 1, "endLine": 100}
```

### 2. directory_list - 列出目录内容

**功能**：列出指定目录的文件和子目录

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 目录路径（推荐使用绝对路径） |
| recursive | Boolean | ❌ 否 | false | 是否递归列出子目录 |
| pattern | String | ❌ 否 | - | 文件匹配模式（如 `*.md`） |

**使用示例**：

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\skills"}
```

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs", "recursive": true, "pattern": "*.md"}
```

### 3. file_search - 搜索文件内容

**功能**：在文件或目录中搜索指定文本

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件或目录路径（推荐使用绝对路径） |
| query | String | ✅ 是 | - | 搜索关键词 |
| recursive | Boolean | ❌ 否 | false | 是否递归搜索目录 |
| caseSensitive | Boolean | ❌ 否 | false | 是否区分大小写 |
| filePattern | String | ❌ 否 | - | 文件匹配模式 |

**使用示例**：

```
file_search: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs", "query": "API设计", "recursive": true, "filePattern": "*.md"}
```

### 4. file_write - 写入本地文件

**功能**：写入内容到本地文件

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件路径（推荐使用绝对路径） |
| content | String | ✅ 是 | - | 要写入的内容 |
| append | Boolean | ❌ 否 | false | 是否追加模式 |

### 5. file_delete - 删除文件或目录

**功能**：删除指定文件或目录

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| path | String | ✅ 是 | - | 文件或目录路径（推荐使用绝对路径） |
| recursive | Boolean | ❌ 否 | false | 删除目录时是否递归删除子内容 |

### 6. web_fetch - 获取远程文档

**功能**：从远程 URL 获取网页内容并转换为 Markdown

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| url | String | ✅ 是 | - | 文档 URL |

**使用示例**：

```
web_fetch: {"url": "https://atomgit.com/UCToo/agentskills-runtime/blob/main/README_cn.md"}
```

### 7. http_request - 通用 HTTP 客户端（数据库 CRUD 查询）

**功能**：通用 HTTP 客户端，支持 GET/POST/PUT/DELETE/PATCH 方法。**用于数据库 CRUD 查询时，请参考 API 设计规范文档组装查询条件**。

**参数说明**：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| method | String | ✅ 是 | - | HTTP 方法（GET/POST/PUT/DELETE/PATCH） |
| url | String | ✅ 是 | - | 完整 URL |
| headers | String | ❌ 否 | - | JSON 对象格式的请求头 |
| body | String | ❌ 否 | - | JSON 对象格式的请求体 |
| timeout | Int | ❌ 否 | 30000 | 超时时间（毫秒） |

## 数据库 CRUD 查询机制

### 设计意图

我们框架的设计意图是让大模型可以参考 API 设计规范文档，自行组装查询条件，从数据库表的标准 CRUD API 中查询所需数据。大模型和 Agent 聊天产生的所有数据都进行了入库记录，可参考历史数据辅助决策。

### 如何查询数据库

1. **先阅读 API 设计规范**：通过 `file_read` 读取 `docs/uctoo-v4/uctoo-v4-api-specification.md`，了解标准 CRUD API 的端点和查询参数格式
2. **了解数据库表结构**：通过 `file_read` 读取 `docs/uctoo-v4/uctoo-database-design-document.md` 或 `docs/uctoo-v4/uctoo-database-design-specification.md`，了解表结构
3. **组装查询条件**：根据 API 规范的 filter 格式，组装查询条件 JSON
4. **调用 CRUD API**：通过 `http_request` 工具调用标准 CRUD API（如 `GET /api/v1/uctoo/<table>?filter=<filter_json>`）

### 示例：查询所有技能

```
http_request: {
  "method": "GET",
  "url": "https://javatoarktsapi.uctoo.com/api/v1/uctoo/agent_skills",
  "headers": "{\"Authorization\": \"Bearer <token>\", \"Content-Type\": \"application/json\"}",
  "body": "{}",
  "timeout": 30000
}
```

### 示例：按条件过滤查询

```
http_request: {
  "method": "GET",
  "url": "https://javatoarktsapi.uctoo.com/api/v1/uctoo/agent_skills?filter=%7B%22name%22%3A%22investment-research-assistant%22%7D",
  "headers": "{\"Authorization\": \"Bearer <token>\"}",
  "body": "{}",
  "timeout": 30000
}
```

### 常用数据库表

| 表名 | 说明 | CRUD API 端点 |
|------|------|--------------|
| uctoo_user | 用户表 | /api/v1/uctoo/uctoo_user |
| agent_skills | 技能表 | /api/v1/uctoo/agent_skills |
| agents | Agent 定义表 | /api/v1/uctoo/agents |
| agent_messages | Agent 消息表 | /api/v1/uctoo/agent_messages |
| agent_tasks | Agent 任务表 | /api/v1/uctoo/agent_tasks |
| agent_memories | Agent 记忆表 | /api/v1/uctoo/agent_memories |
| agent_kanban_tasks | Agent 看板任务表 | /api/v1/uctoo/agent_kanban_tasks |
| skill_usage_stats | 技能使用统计表 | /api/v1/uctoo/skill_usage_stats |
| agent_loop_metrics | Agent 循环指标表 | /api/v1/uctoo/agent_loop_metrics |
| agent_verification_records | Agent 验证记录表 | /api/v1/uctoo/agent_verification_records |
| crontab | 定时任务表 | /api/v1/uctoo/crontab |
| crontab_log | 定时任务日志表 | /api/v1/uctoo/crontab_log |
| crontab_task_registry | 任务注册表 | /api/v1/uctoo/crontab_task_registry |
| entity | 实体表 | /api/v1/uctoo/entity |
| operate_log | 操作日志表 | /api/v1/uctoo/operate_log |
| login_log | 登录日志表 | /api/v1/uctoo/login_log |
| llm_usage_log | LLM 用量日志表 | /api/v1/uctoo/llm_usage_log |
| company | 公司表 | /api/v1/uctoo/company |
| tasks | 任务/研报表 | /api/v1/uctoo/tasks |

## 文档全索引

### 项目说明文档

| 文档 | 路径 | 说明 |
|------|------|------|
| README_cn.md | `README_cn.md` | AgentSkills Runtime 后台项目说明文档（产品介绍、架构设计、功能特性、落地案例） |
| 快速开始 | `docs/quickstart.md` | 快速上手指南 |
| 安装指南 | `docs/install.md` | 安装配置说明 |
| 使用指南 | `docs/how-to.md` | 使用方法说明 |
| 教程（中文） | `docs/tutorial.md` | 中文教程 |
| 教程（英文） | `docs/tutorial-en.md` | 英文教程 |
| 架构文档 | `docs/architecture.md` | 架构设计说明 |
| 应用开发指南 | `docs/application_development_guide.md` | 应用开发指导 |
| 跨平台兼容性 | `docs/cross-platform-compatibility.md` | 跨平台说明 |
| HTTPS 配置 | `docs/https-configuration.md` | HTTPS 配置指南 |
| HITL（人机协同） | `docs/hitl.md` | 人机协同实现说明 |
| 发布指南 | `docs/release-guide.md` | 版本发布说明 |
| 第三方库 | `docs/third_party_libs.md` | 第三方库依赖说明 |

### API 与数据库设计文档

| 文档 | 路径 | 说明 |
|------|------|------|
| **API 设计规范** | `docs/uctoo-v4/uctoo-v4-api-specification.md` | **核心**：API 设计规范，含标准 CRUD API 端点和 filter 格式 |
| API 参考 | `docs/api_reference.md` | API 参考文档 |
| 数据库设计文档 | `docs/uctoo-v4/uctoo-database-design-document.md` | 数据库设计说明 |
| 数据库设计规范 | `docs/uctoo-v4/uctoo-database-design-specification.md` | 数据库设计规范 |
| API 增强提案 | `docs/uctoo-v4/uctoo-v4-api-enhancement-proposal.md` | API 增强建议 |
| ORM 规范 | `docs/uctoo-v4/uctoo-v4-orm-specification.md` | ORM 规范说明 |
| 查询解析器实现 | `docs/uctoo-v4/query-parser-implementation.md` | 查询解析器实现说明 |

### 后台模块与架构文档

| 文档 | 路径 | 说明 |
|------|------|------|
| v4 架构 | `docs/uctoo-v4/uctoo-v4-architecture.md` | UCTOO v4 架构设计 |
| 模块开发规范 | `docs/uctoo-v4/uctoo-v4-module-development.md` | **核心**：后台模块开发规范 |
| 中间件指南 | `docs/uctoo-v4/uctoo-v4-middleware-guide.md` | 中间件配置指南 |
| 权限体系 | `docs/uctoo-v4/user-permission-system.md` | **核心**：用户权限体系规范 |
| 行级权限 | `docs/uctoo-v4/row-level-permission-system.md` | 行级权限系统说明 |
| CRUD 生成器 v2 | `docs/uctoo-v4/crud-generator-v2.md` | CRUD 生成器 v2 说明 |
| CRUD 生成器重构 | `docs/uctoo-v4/crud-generator-refactor-plan.md` | CRUD 生成器重构计划 |
| Entity 重构计划 | `docs/uctoo-v4/entity-refactor-plan.md` | Entity 重构计划 |
| Entity 重构修正 | `docs/uctoo-v4/entity-refactor-plan-corrected.md` | Entity 重构修正版 |
| 静态文件服务 | `docs/uctoo-v4/static-file-service-architecture.md` | 静态文件服务架构 |

### AgentSkills 标准与 SDK 文档

| 文档 | 路径 | 说明 |
|------|------|------|
| AgentSkills API 参考 | `docs/agentskills-api-reference.md` | AgentSkills API 参考 |
| AgentSkills API 服务运行 | `docs/agentskills-api-service-run.md` | AgentSkills API 服务运行说明 |
| AgentSkills API 测试指南 | `docs/agentskills-api-testing-guide.md` | AgentSkills API 测试指南 |
| 技能开发 | `docs/skill-development.md` | 技能开发说明 |
| SDK JavaScript | `docs/sdk-javascript.md` | JavaScript SDK 说明 |
| 内置工具 | `docs/builtin-tools.md` | 内置工具文档 |
| Agent 声明规范 | `docs/agents/agent-declaration-spec.md` | Agent 声明规范 |

### 智能体互联国标（GB/Z 185-2026）文档

| 文档 | 路径 | 说明 |
|------|------|------|
| GB/Z 185.1-2026 | `docs/standard/aip/GBZ+185.1-2026.md` | 智能体互联标准第 1 部分 |
| GB/Z 185.2-2026 | `docs/standard/aip/GBZ+185.2-2026.md` | 智能体身份管理 |
| GB/Z 185.3-2026 | `docs/standard/aip/GBZ+185.3-2026.md` | 智能体可信注册 |
| GB/Z 185.4-2026 | `docs/standard/aip/GBZ+185.4-2026.md` | 智能体能力描述 |
| GB/Z 185.5-2026 | `docs/standard/aip/GBZ+185.5-2026.md` | 智能体发现 |
| GB/Z 185.6-2026 | `docs/standard/aip/GBZ+185.6-2026.md` | 智能体交互协议 |
| GB/Z 185.7-2026 | `docs/standard/aip/GBZ+185.7-2026.md` | 工具调用 |
| Agent 标准 - 什么是 Agent | `docs/standard/agents/what-are-agents.mdx` | Agent 概念说明 |
| Agent 标准 - 规范 | `docs/standard/agents/specification.mdx` | Agent 标准规范 |
| Agent 标准 - 集成 Agent | `docs/standard/agents/integrate-agents.mdx` | Agent 集成说明 |
| Agent 标准 - 文件系统数据库同步 | `docs/standard/agents/filesystem-database-sync.mdx` | 文件系统数据库同步 |

### 包文档（package_docs）

| 文档 | 路径 | 说明 |
|------|------|------|
| agent.base | `docs/package_docs/agent.base.md` | Agent 基础包 |
| agent | `docs/package_docs/agent.md` | Agent 包 |
| agent_executor.common | `docs/package_docs/agent_executor.common.md` | Agent 执行器通用 |
| agent_executor | `docs/package_docs/agent_executor.md` | Agent 执行器 |
| agent_executor.naive | `docs/package_docs/agent_executor.naive.md` | 朴素执行器 |
| agent_executor.react | `docs/package_docs/agent_executor.react.md` | ReAct 执行器 |
| agent_executor.tool_loop | `docs/package_docs/agent_executor.tool_loop.md` | 工具循环执行器 |
| agent_group | `docs/package_docs/agent_group.md` | Agent 组 |
| app | `docs/package_docs/app.md` | 应用包 |
| compactor | `docs/package_docs/compactor.md` | 压缩器 |
| config | `docs/package_docs/config.md` | 配置包 |
| core.agent | `docs/package_docs/core.agent.md` | 核心 Agent |
| core.interaction | `docs/package_docs/core.interaction.md` | 核心交互 |
| core.memory | `docs/package_docs/core.memory.md` | 核心记忆 |
| core.message | `docs/package_docs/core.message.md` | 核心消息 |
| core.model | `docs/package_docs/core.model.md` | 核心模型 |
| core.rag | `docs/package_docs/core.rag.md` | 核心 RAG |
| core.tokenizer | `docs/package_docs/core.tokenizer.md` | 核心分词器 |
| core.tool | `docs/package_docs/core.tool.md` | 核心工具 |
| http | `docs/package_docs/http.md` | HTTP 包 |
| interaction | `docs/package_docs/interaction.md` | 交互包 |
| jsonable | `docs/package_docs/jsonable.md` | JSON 序列化包 |
| log | `docs/package_docs/log.md` | 日志包 |
| mcp | `docs/package_docs/mcp.md` | MCP 包 |
| memory | `docs/package_docs/memory.md` | 记忆包 |
| model | `docs/package_docs/model.md` | 模型包 |
| parser | `docs/package_docs/parser.md` | 解析器包 |
| rag.graph | `docs/package_docs/rag.graph.md` | RAG 图 |
| rag | `docs/package_docs/rag.md` | RAG 包 |
| rag.splitter | `docs/package_docs/rag.splitter.md` | RAG 分割器 |
| storage.graph | `docs/package_docs/storage.graph.md` | 存储图 |
| storage.kv | `docs/package_docs/storage.kv.md` | KV 存储 |
| storage | `docs/package_docs/storage.md` | 存储包 |
| storage.vdb | `docs/package_docs/storage.vdb.md` | VDB 存储 |
| tokenizer | `docs/package_docs/tokenizer.md` | 分词器包 |
| tool | `docs/package_docs/tool.md` | 工具包 |
| vdb | `docs/package_docs/vdb.md` | 向量数据库 |

### SQL 脚本

| 文档 | 路径 | 说明 |
|------|------|------|
| v4 融合全表 | `docs/sql/v4_fusion_all_tables.sql` | v4 融合全表 SQL |
| v4 融合修复 timestamptz | `docs/sql/v4_fusion_fix_timestamptz.sql` | timestamptz 修复 |
| LLM 用量日志标准字段 | `docs/sql/v4_fusion_llm_usage_logs_add_standard_fields.sql` | LLM 用量日志标准字段 |

### 参考文档（ref）

| 文档 | 路径 | 说明 |
|------|------|------|
| AI 驱动架构 | `docs/ref/AIDrivenArchitecture.md` | AI 驱动架构参考 |
| GLM5 AgentSkills Runtime 路线图 | `docs/ref/GLM5Tagentskills-runtimeRoadMapAdv.md` | GLM5 路线图 |
| GLM5 harness VS AI 基础设施 | `docs/ref/GLM5TharnessVSAIinfra.md` | harness VS AI 基础设施 |
| Metis VS openclaw | `docs/ref/MetisVSopenclaw.md` | Metis VS openclaw 对比 |
| claudecode | `docs/ref/claudecode.md` | claudecode 参考 |
| harness | `docs/ref/harness.md` | harness 参考 |
| self-evolution-framework | `docs/ref/self-evolution-framework.md` | 自演化框架参考 |
| 原生编程 vs 注解方式 | `docs/原生编程vs注解方式对比分析.md` | 原生编程 vs 注解方式对比 |

### 其他文档

| 文档 | 路径 | 说明 |
|------|------|------|
| BCRYPT 后端兼容性 | `docs/BCRYPT_BACKEND_COMPATIBILITY.md` | BCRYPT 兼容性说明 |
| 索引 | `docs/index.md` | 文档索引 |
| 架构总览 HTML | `docs/architecture_overview.html` | 架构总览（HTML） |

## 关键路径参考

**Runtime 项目根目录**：
```
D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime
```

**技能目录**：
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\` - 所有技能安装目录
  - `skills\uctoo-doc\SKILL.md` - uctoo-doc 技能文档（本文件）
  - `skills\skill-creator\SKILL.md` - skill-creator 技能文档
  - `skills\cangjie-coder\SKILL.md` - cangjie-coder 技能文档
  - `skills\investment-research-assistant\SKILL.md` - 智能投研助理技能文档

**文档目录**：
- `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\docs\` - 项目文档目录
  - `docs\builtin-tools.md` - 内置工具文档
  - `docs\uctoo-v4\` - UCTOO V4 架构文档（含 API 规范、数据库设计、模块开发、权限体系）
  - `docs\standard\aip\` - 智能体互联国标文档
  - `docs\package_docs\` - 包文档
  - `docs\sql\` - SQL 脚本

**开源地址**：
- AgentSkills Runtime：https://atomgit.com/uctoo/agentskills-runtime 和 https://github.com/UCTooCom/agentskills-runtime
- web-admin 管理前端：https://atomgit.com/UCToo/web-admin

## 工作流程

### 1. 路径检测（重要）

**第一步必须先检测当前工作目录**，确保路径正确：

```
directory_list: {"path": "."}
```

如果返回空目录或不是预期的路径，请使用**绝对路径**：

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime"}
```

### 2. 接收用户请求

当用户提出文档相关需求时，首先识别用户想要查询的文档类型：
- API 相关 → API 设计规范（`docs/uctoo-v4/uctoo-v4-api-specification.md`）
- 数据库相关 → 数据库设计文档（`docs/uctoo-v4/uctoo-database-design-document.md`）
- 架构相关 → 架构文档（`docs/architecture.md` 或 `docs/uctoo-v4/uctoo-v4-architecture.md`）
- 模块开发相关 → 模块开发规范（`docs/uctoo-v4/uctoo-v4-module-development.md`）
- 权限相关 → 权限体系（`docs/uctoo-v4/user-permission-system.md`）
- 技能相关 → 本地技能文件（使用 `file_read`）
- AgentSkills 标准 → 技能开发文档（`docs/skill-development.md`）
- 智能体互联国标 → `docs/standard/aip/` 目录
- 数据库 CRUD 查询 → 先读 API 规范，再组装条件调用 CRUD API
- 其他 → 询问用户具体需求

### 3. 选择工具策略

**本地文档优先策略**：

```
用户请求文档
    │
    ├─→ 是否涉及技能文件？
    │       ├─→ 是 → 使用 file_read 读取本地 SKILL.md（使用绝对路径）
    │       └─→ 否 → 继续
    │
    ├─→ 是否涉及 runtime 本地文档？
    │       ├─→ 是 → 使用 file_read 读取本地文档（使用绝对路径）
    │       └─→ 否 → 继续
    │
    ├─→ 是否涉及数据库 CRUD 查询？
    │       ├─→ 是 → 先读 API 规范，再用 http_request 调用 CRUD API
    │       └─→ 否 → 继续
    │
    └─→ 使用 web_fetch 从远程仓库获取文档
```

### 4. 检索文档

#### 4.1 读取本地文档

使用 `file_read` 工具读取 runtime 项目中的文档：

```
file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\uctoo-v4\\uctoo-v4-api-specification.md"}
```

#### 4.2 浏览文档目录

使用 `directory_list` 查看可用文档：

```
directory_list: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs", "recursive": true}
```

#### 4.3 搜索文档内容

使用 `file_search` 在文档目录中搜索：

```
file_search: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs", "query": "CRUD", "recursive": true, "filePattern": "*.md"}
```

#### 4.4 获取远程文档

使用 `web_fetch` 工具从远程仓库获取文档内容：

```
web_fetch: {"url": "https://atomgit.com/uctoo/agentskills-runtime/blob/main/README_cn.md"}
```

#### 4.5 数据库 CRUD 查询

先读 API 规范了解端点和 filter 格式，再用 `http_request` 调用 CRUD API：

```
file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\uctoo-v4\\uctoo-v4-api-specification.md"}
```

然后用 `http_request` 调用标准 CRUD API 查询所需数据。

### 5. 展示内容

- 将获取的文档内容以清晰的格式展示给用户
- 如果文档较长，可以提供章节摘要和导航
- 支持用户提问关于文档内容的特定问题

### 6. 知识问答

基于文档内容回答用户问题：
- 准确引用文档中的相关内容
- 提供上下文解释
- 如果文档中没有明确答案，诚实告知用户

## 使用示例

### 示例 1：查询 API 设计规范

**用户请求**："我想了解 UCTOO 的 API 设计规范"

**操作**：
1. 使用 `file_read` 获取 API 设计规范文档
   ```
   file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\uctoo-v4\\uctoo-v4-api-specification.md"}
   ```
2. 展示文档内容
3. 根据用户进一步提问提供详细解答

### 示例 2：查询数据库设计

**用户请求**："数据库表结构是怎么设计的？"

**操作**：
1. 使用 `file_read` 获取数据库设计文档
   ```
   file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\uctoo-v4\\uctoo-database-design-document.md"}
   ```
2. 提取并展示表结构相关内容
3. 解释实体关系

### 示例 3：通过 CRUD API 查询技能列表

**用户请求**："当前数据库中安装了哪些技能？"

**操作**：
1. 先读 API 规范了解端点格式
   ```
   file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\uctoo-v4\\uctoo-v4-api-specification.md"}
   ```
2. 用 `http_request` 调用 CRUD API 查询 agent_skills 表
   ```
   http_request: {"method": "GET", "url": "https://javatoarktsapi.uctoo.com/api/v1/uctoo/agent_skills", "headers": "{\"Authorization\": \"Bearer <token>\"}", "body": "{}", "timeout": 30000}
   ```
3. 展示查询结果

### 示例 4：查询智能体互联国标

**用户请求**："GB/Z 185.6 智能体交互协议讲了什么？"

**操作**：
1. 使用 `file_read` 读取国标文档
   ```
   file_read: {"path": "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\docs\\standard\\aip\\GBZ+185.6-2026.md"}
   ```
2. 展示并解释内容

## 关键规则

1. **使用绝对路径**：所有文件工具操作必须使用完整的绝对路径，避免相对路径导致的目录检测错误
2. **路径检测优先**：每次操作前先使用 `directory_list: {"path": "."}` 检测当前工作目录，如果为空则切换到绝对路径
3. **本地优先**：优先使用 `file_read` 读取本地文档，本地文档不可用时再使用 `web_fetch`
4. **准确引用**：回答问题时引用文档原文，确保准确性
5. **参数正确**：使用 `file_read` 时必须使用以下参数名：
   - `path`（必填，绝对路径）
   - `withLineNumber`（可选）
   - `startLine`（可选）
   - `endLine`（可选）
6. **主动询问**：如果用户需求不明确，主动询问具体想了解的文档部分
7. **持续支持**：支持用户对文档内容的深入提问
8. **CRUD 查询先读规范**：数据库 CRUD 查询前，必须先读 API 设计规范，了解端点和 filter 格式，再组装查询条件

## 注意事项

- 文档内容可能较长，建议分章节展示
- 如果远程仓库访问受限，可以尝试备用链接或告知用户
- 保持文档内容的原样引用，不随意修改
- **必须使用绝对路径**，相对路径可能导致文件工具找不到目标文件
- `file_read` 的行号参数 `startLine` 和 `endLine` 从 1 开始计数
- Windows 路径分隔符使用 `\\`（双反斜杠）或 `/`（正斜杠）
- 如果目录列表返回为空，说明当前工作目录不正确，请使用绝对路径重试
- 数据库 CRUD 查询需要有效的 JWT token，请从用户会话中获取
