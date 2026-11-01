# S4 协议网关运维 — 技术设计文档

## 文档信息
- **项目名称**: ConsoleClosure（三端能力补全）
- **子系统**: S4 协议网关运维
- **feature_name**: `ConsoleClosure--protocol-gateway`
- **语言标签**: cangjie + web
- **版本**: v1.0
- **创建日期**: 2026-10-30
- **作者**: sdd-design-writer（SDD 派生子 agent）
- **状态**: 评审中（gate-design）
- **关联需求**: `specs/ConsoleClosure/ConsoleClosure--protocol-gateway/spec.md`
- **关联主工程账本**: `specs/ConsoleClosure/SPECS_INDEX.md`（§3 契约 C-014~C-018、§4 DAG、§7 风险 R2/R3/R4/R6）

---

## 1. 设计概述

### 1.1 设计目标
1. 为 runtime 已实现但无界面的 **MCP / WebMCP / AIP / 工具网关** 四类协议能力，补齐 Web 运维业务界面，使协议状态**可见、可控、可审计**。
2. 在 S5 的 C-022 能力暴露达 `test` 后，承接其暴露的能力，在工具网关中完成"列出 + 一次授权调用"主干（L2 主干用例）。
3. 仅补齐界面必需的**只读运维端点**，绝不重新设计协议语义、状态机或消息格式（spec 边界 #1~#3）。
4. 全程复用既有表、既有端点、既有权限/菜单机制，不新增数据表（spec 边界 #7 + 铁律 9 复用优先）。

### 1.2 设计原则
- **复用优先（铁律 9 / 铁律 14）**：所有数据读取复用既有 `aip_*` / `permissions` / 审计表；新增端点只做只读聚合，不落新表；迭代 runtime 走二次开发底座（`loaddbinfo` → `plugingen`/`crudgen`/`crudweb`）。
- **边界清晰（铁律 15）**：S4 只建设运维界面与少数只读运维端点；**不碰 S5 的 C-022 控制器暴露**（那是 S4 开工前置，由 S5 负责）；跨子系统一律走契约接口。
- **故障隔离**：MCP / AIP / WebMCP / 工具网关 4 个区域独立请求、独立失败标记，单区故障不阻塞其他区（spec §4.2#2）。
- **安全双闸**：API 层 `RequirePermissionMiddleware` + 菜单层 C-024 双层把关；新增路由 100% 登记 `permissions` + `role_has_permission`（风险 R6，否则 403）。
- **审计不漏**：关键写操作（吊销/锁定/模式切换/外部调用/工具调用）100% 产生审计记录，敏感凭据与完整消息正文明文记录数 = 0（spec §4.3）。

### 1.3 技术选型
| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 后端语言 | 仓颉（cangjie） | 仅用于新增只读运维端点，宿主 runtime 既有栈；AI 不运行 `cjpm build`，编译由人工回传 |
| 后端框架 | uctoo runtime（Cordis 宿主 + AutoRoute 注册） | 复用 `AutoRouteConfig` / `AutoRouteRegistry` 注册链路，新增端点走同一套 |
| 前端语言 | TypeScript + Vue3 | web-admin 已有栈，运维页作为动态菜单注入的视图 |
| 前端框架 | web-admin（TinyVue + 动态菜单 `permissions/user/menu`） | 新页面经 C-024 菜单树注入，组件解析 `views/${component}.vue` |
| 数据库 | 既有 PostgreSQL（uctoo） | **复用既有表，本子系统零新增表/列** |
| 代码生成 | `loaddbinfo` / `plugingen` / `crudgen` / `crudweb` | 二次开发底座优先；生成物当骨架最小适配 |

---

## 2. 系统架构

### 2.1 架构图
```
┌──────────────────────────────────────────────────────────────────┐
│  Web 浏览器（协议管理员 / 安全审计员 / 低权限用户）                  │
└───────────────┬──────────────────────────────────────────────────┘
                │ HTTP（动态菜单 C-024 + 运维接口）
                ▼
┌──────────────────────────────────────────────────────────────────┐
│  web-admin（S4 运维视图，本子系统负责）                            │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │
│  │ MCP/WebMCP │ │ AIP 身份/  │ │ AIP 发现/  │ │ 工具网关   │     │
│  │ 运维页     │ │ 能力页     │ │ 会话/模式  │ │ （含C-022）│     │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘     │
│        │              │              │              │            │
│  ┌─────┴──────────────┴──────────────┴──────────────┴──────┐     │
│  │ 权限前置：RequirePermissionMiddleware + C-024 菜单可见   │     │
│  └────────────────────────┬───────────────────────────────┘     │
└───────────────────────────┼────────────────────────────────────┘
                            │
        ┌───────────────────┼────────────────────────────────────┐
        │  uctoo runtime（宿主，既有端点 + S4 新增只读运维端点）   │
        │                                                       │
        │  S4 新增只读端点（cangjie，本子系统负责）              │
        │   ├ GET /mcp/ops/summary        （MCP 运维摘要）       │
        │   ├ GET /aip/sessions           （AIP 会话列表）        │
        │   └ GET /tools/audit            （工具调用审计查询）     │
        │                                                       │
        │  契约端点（消费，不重实现）                            │
        │   ├ C-014 POST /mcp/stream       C-015 open/tools+call │
        │   ├ WebMCP /webmcp/{sessions/count,health,remote,client}│
        │   ├ C-016 /aip/{identity,description}/*                │
        │   ├ C-017 /aip/{discovery,interaction}/*               │
        │   └ C-018 /tools/{list,:toolName/info,:toolName}       │
        │                                                       │
        │  上游契约（消费，S5 负责实现）                         │
        │   └ C-022 GET /{vector,retriever,memory,storage}/*      │
        │                                                       │
        │  权限/审计底座（复用，不重实现）                       │
        │   ├ permissions / role_has_permission（R6 登记）       │
        │   └ 既有审计/操作日志设施（复用，不新建表）            │
        └───────────────────────────────────────────────────────┘
```

### 2.2 模块划分
| 模块 | 职责 | 语言 | 边界（铁律 15） |
|------|------|------|----------------|
| M1 MCP/WebMCP 运维 | 状态展示、开放工具目录/调用、诊断发起、WebMCP 4 端点消费 | web + cangjie(摘要端点) | 不重实现 C-014/C-015 协议语义 |
| M2 AIP 身份与能力 | 身份全生命周期、能力描述发布/更新、跨组织受控 | web | 调用 `AipRoute.cj:29-39` 既有端点 |
| M3 AIP 发现/会话/模式 | 发现缓存、会话消息、模式切换、健康检查 | web + cangjie(会话列表端点) | 不扫描表 CRUD 替代 |
| M4 工具网关 | 工具目录/详情/调用、审计查询、S5 C-022 联动 | web + cangjie(审计端点) | C-022 仅消费，不碰 S5 实现 |
| M5 权限与菜单登记 | 新增路由 `permissions`/`role_has_permission` + C-024 菜单节点 | SQL + web | 不建设通用权限平台（spec 边界 #5） |

### 2.3 组件交互
- 前端每个运维页进入时先经 C-024 取菜单（无节点即无入口，规避 R2）；操作前经 `RequirePermissionMiddleware` 鉴权（无登记即 403，规避 R6）。
- 4 个协议区域在前端**并行独立请求**，任一区域超时/失败仅标记该卡片，不阻塞其他区（spec §4.2#2、§4.1#2）。
- 写操作（吊销/锁定/模式切换/工具调用）在前端二次确认后才发 1 次请求（spec §4.3#6、§4.2#1）；成功后 2s 内回读服务端状态（spec §4.2#3）。
- S4 新增只读端点只读既有表聚合，不写协议状态；协议写操作一律走 C-014~C-018 既有端点。

---

## 3. 详细设计

> 本节"关键类"为新增端点的最小骨架示意；既有端点类（如 `AipRoute`、`McpRoute`、`ToolRoutes`、`WebMCPRoutes`、`McpOpenRoutes`）**直接复用，不在 S4 重写**。

### 3.1 M1 MCP/WebMCP 运维模块
#### 3.1.1 类设计（cangjie，新增）
```
class McpOpsController {
  // 只读聚合：消费 C-014 运行态 + WebMCP 4 端点，产出运维摘要
  func summary(ctx): McpOpsSummary   // GET /api/v1/uctoo/mcp/ops/summary
}
// 响应结构 McpOpsSummary:
// { mcp: {streamReachable:bool, error?:string},
//   openTools: {count:int, items:[{toolName,desc}]},
//   webmcp: { sessionsCount:int, health:{status,service},
//             remote?:any, client?:any, partialFailures:[string] } }
```
#### 3.1.2 接口设计
- 消费：`POST /api/v1/uctoo/mcp/stream`（C-014，JSON-RPC 原样）、`GET /api/v1/uctoo/mcp/open/tools`、`POST /api/v1/uctoo/mcp/open/call`（C-015）、`/webmcp/sessions/count`、`/webmcp/health`、`/webmcp/remote`、`/webmcp/client`。
- 新增：`GET /api/v1/uctoo/mcp/ops/summary`（只读，复用既有端点的返回聚合）。
#### 3.1.3 数据流
前端页进入 → 并行请求 `summary` + `open/tools` + 4 个 WebMCP 端点 → 各区域独立渲染；诊断动作 → 用户确认后发 C-014 JSON-RPC → 展示结果与审计关联标识。

### 3.2 M2 AIP 身份与能力模块
#### 3.2.1 类设计（复用）
- 复用 `AipRoute.cj:29-39`（身份：本地/互联注册、登录、查询、启停、锁定、解锁、更新、吊销）与 `AipRoute.cj:41-45`（能力描述：注册/发布/更新/查询）。前端只调用，不改写语义。
#### 3.2.2 接口设计
- 消费 C-016：`POST /api/v1/uctoo/aip/identity/*`、`POST /api/v1/uctoo/aip/description/*`。
- 关键操作（禁用/锁定/吊销/互联注册/能力发布）前端先弹确认框展示 `agentId` + 动作，确认前请求数 = 0（spec §5.2.1#2、§4.3#6）。
#### 3.2.3 数据流
身份列表/详情 → 操作确认 → 调 C-016 → 回读 `agentId`/`status` → 刷新视图；互联失败保留服务端原状不造前端临时身份（spec §5.2.3#1）。

### 3.3 M3 AIP 发现/会话/模式模块
#### 3.3.1 类设计（cangjie，新增会话列表）
```
class AipOpsController {
  // 只读：当现有路由无法列出会话时补齐（spec §5.3.1#3）
  func sessions(ctx): AipSessionList  // GET /api/v1/uctoo/aip/sessions
}
// AipSessionList: { sessions:[{sessionId, mode, peer?, createdAt, status}] }
```
#### 3.3.2 接口设计
- 消费 C-017：`POST /api/v1/uctoo/aip/discovery/*`（发现/缓存刷新/清理）、`POST /api/v1/uctoo/aip/interaction/*`（会话创建/消息/关闭）。
- 新增：`GET /api/v1/uctoo/aip/sessions`（仅当 C-017 现有路由无列表能力时启用，路径与响应以 design 勘查确认为准）。
#### 3.3.3 数据流
发现 → 按 `queryHash` 读缓存/刷新 → 会话创建 → 按 `limit/page` 取消息（服务端顺序，前端不绕过限制）→ 模式切换 → 回读模式 + 双健康。

### 3.4 M4 工具网关模块
#### 3.4.1 类设计（cangjie，新增审计查询）
```
class ToolAuditController {
  // 只读：复用既有审计设施，不新建表（spec §6.5#5 / R4）
  func audit(ctx): ToolAuditList   // GET /api/v1/uctoo/tools/audit
}
// ToolAuditList: { records:[{operator, target, action, result, time, refId}] }
```
#### 3.4.2 接口设计
- 消费 C-018：`GET /api/v1/tools/list`、`GET /api/v1/tools/:toolName/info`、`POST /api/v1/tools/:toolName`。
- 消费上游 C-022（S5 负责实现）：S5 暴露的能力进入工具体系后，在目录展示并完成一次授权调用（spec §5.4.1#5）。
- 新增：`GET /api/v1/uctoo/tools/audit`（复用既有审计表，无新表）。
#### 3.4.3 数据流
打开工具网关页 → C-024 校验菜单与操作权限 → 拉 `tools/list` + `:toolName/info`（含 `sensitiveLevel`/`requiresConfirmation`/`auditEnabled`）→ 调用前按确认要求二次确认 → 调 C-018 → 返回结果与审计关联标识；审计员经 `tools/audit` 查授权范围内记录。

### 3.5 M5 权限与菜单登记模块
- 新增路由在 `permissions` 表登记 `permission_name` + `path` + `method`；在 `role_has_permission` 按角色写入；执行 `loaddbinfo` 刷新（R6）。
- 新增页面在 C-024 菜单树登记节点（`component` 指向 `views/...vue`），否则用户无入口（R2）。
- 不建设通用权限平台，仅登记本子系统所需（spec 边界 #5）。

---

## 4. 数据设计

### 4.1 复用 vs 新增结论（铁律 9）
**本子系统零新增表、零新增列。** 所有数据读取复用既有表与既有审计设施；spec 边界 #7 与风险 R4 要求"新增须论证复用不成立"，本设计经勘查确认：**复用成立，无新增**。

### 4.2 数据表设计（8 表，全部复用）
| # | 表名 | 复用/新增 | 被谁消费 | 用途 | 复用论证 |
|---|------|----------|---------|------|---------|
| 1 | `aip_agent_identity` | **复用** | M2 / C-016 / D3 | 身份全生命周期读写 | spec §6.2#4 明确复用，不建同义表 |
| 2 | `aip_agent_description` | **复用** | M2 / C-016 / D4 | 能力描述发布/更新 | 同上，复用既有表 |
| 3 | `aip_discovery_cache` | **复用** | M3 / C-017 / D5 | 发现缓存按 `queryHash` 读/刷 | spec §6.3#5 复用 |
| 4 | `aip_interaction_session` | **复用** | M3 / C-017 / D6 | 会话创建/关闭/列表 | spec §6.3#5 复用；M3 新增列表端点只读此表 |
| 5 | `aip_interaction_message`（消息落点待勘查确认具体模型） | **复用** | M3 / C-017 / D6 | 会话消息分页 | 消息落点待既有模型勘查（spec §6.3#5），复用既有存储，不新建 |
| 6 | `permissions` | **复用** | M4 / C-018 / D8 + M5 | 工具权限路径 + 本子系统新增路由登记 | C-018 复用 `permissions.*`；新增路由在此登记（R6） |
| 7 | `role_has_permission` | **复用** | M5 / R6 | 角色授权 | spec §6.4#7 复用，不建私有表 |
| 8 | 既有审计/操作日志表（具体表名待勘查既有审计设施确认） | **复用** | M4 / D8 审计 + §4.3 安全 | 关键操作审计查询 | spec §6.5#5：确认前不得新建表，故复用既有审计设施 |

> 第 5、8 项的"具体模型/表名"为 spec 标注的待勘查项（spec §6.3#5、§6.5#5）；本设计在 tasks T-01 落实勘查，结论回填，但无论结论如何**均不新建表**（铁律 9 + spec 边界 #7）。

### 4.3 数据关系
```
aip_agent_identity 1──* aip_agent_description   (agentId 关联)
aip_agent_identity 1──* aip_interaction_session  (agentId 关联)
aip_interaction_session 1──* aip_interaction_message (sessionId 关联)
aip_discovery_cache      (queryHash 定位，独立缓存实体)
permissions 1──* role_has_permission            (permission_id 关联)
审计表 记录 operator/target/action/result/time/refId（外键语义以既有设施为准，不扩展）
```
所有关系均为既有表既有外键，S4 不新增任何关系或约束。

---

## 5. API 设计

### 5.1 API 列表（本子系统消费 11 个契约/上游接口 + 新增 3 个只读运维端点）
| 方法 | 路径 | 归属 | 描述 |
|------|------|------|------|
| POST | `/api/v1/uctoo/mcp/stream`（同路径 GET 待 C-014 冻结确认） | C-014（消费） | MCP JSON-RPC 诊断 |
| GET | `/api/v1/uctoo/mcp/open/tools` | C-015（消费） | 开放工具目录 |
| POST | `/api/v1/uctoo/mcp/open/call` | C-015（消费） | 执行开放工具 |
| GET | `/api/v1/uctoo/webmcp/sessions/count` | 既有（消费） | WebMCP 会话数 |
| GET | `/api/v1/uctoo/webmcp/health` | 既有（消费） | WebMCP 健康 |
| GET | `/api/v1/uctoo/webmcp/remote` | 既有（消费） | 远程连接 |
| GET | `/api/v1/uctoo/webmcp/client` | 既有（消费） | 客户端解析 |
| POST | `/api/v1/uctoo/aip/{identity,description}/*` | C-016（消费） | AIP 身份与能力 |
| POST | `/api/v1/uctoo/aip/{discovery,interaction}/*` | C-017（消费） | AIP 发现与会话 |
| GET/POST | `/api/v1/uctoo/tools/{list,:toolName/info,:toolName}` | C-018（消费） | 工具网关联动 |
| GET | `/api/v1/uctoo/{vector,retriever,memory,storage}/*` | C-022（S5，消费） | S5 暴露能力（工具网关联动） |
| **GET** | **`/api/v1/uctoo/mcp/ops/summary`** | **S4 新增** | MCP/WebMCP 运维摘要（只读） |
| **GET** | **`/api/v1/uctoo/aip/sessions`** | **S4 新增** | AIP 会话列表（只读，条件启用） |
| **GET** | **`/api/v1/uctoo/tools/audit`** | **S4 新增** | 工具调用审计查询（只读） |

> "11 接口"对应 SPECS_INDEX 规模口径（C-014~C-018 及其子端点 + WebMCP 4 端点 + C-022 合计 11 个契约面）。3 个新增端点为本子系统补齐的只读运维端点（spec §5.1.1#4、§5.3.1#3、§5.4.1#4），**路径以 T-01 勘查既有控制器/路由命名规范后最终冻结**。

### 5.2 API 详细设计（新增端点）
#### 5.2.1 MCP 运维摘要 `GET /api/v1/uctoo/mcp/ops/summary`
- **请求参数**: 无（只读聚合）
- **响应**: `{ mcp:{streamReachable,error?}, openTools:{count,items[]}, webmcp:{sessionsCount,health:{status,service},remote?,client?,partialFailures[]} }`
- **错误码**: 401 未认证 / 403 未授权 / 500 内部（含协议域/操作/结果/refId，不记凭据，spec §4.4#2）
- **落表**: 无（只读既有运行态）

#### 5.2.2 AIP 会话列表 `GET /api/v1/uctoo/aip/sessions`
- **请求参数**: `query`（可选，本地/互联）、`page`、`limit`（受服务端限制，前端不绕过）
- **响应**: `{ sessions:[{sessionId,mode,peer?,createdAt,status}], total }`
- **错误码**: 401 / 403 / 404（无会话）
- **落表**: 只读 `aip_interaction_session`（复用）

#### 5.2.3 工具审计查询 `GET /api/v1/uctoo/tools/audit`
- **请求参数**: `toolName?`、`operator?`、`action?`、`page`、`limit`
- **响应**: `{ records:[{operator,target,action,result,time,refId}] }`（敏感凭据/完整正文不返回）
- **错误码**: 401 / 403（越权查他人）/ 空结果正常返回
- **落表**: 复用既有审计表（不新建）

---

## 6. 接口设计（内部 / 外部）

### 6.1 外部接口（契约，S4 消费不实现）
| 契约 | 提供方 | S4 消费方式 | 状态 |
|------|--------|------------|------|
| C-014 MCP Server 运维 | runtime | M1 诊断调用 | 演进中(minor) |
| C-015 MCP 开放调用 | runtime | M1 目录/调用 | 演进中(minor) |
| C-016 AIP 身份与能力 | runtime | M2 | 演进中(minor) |
| C-017 AIP 发现与会话 | runtime | M3 | 演进中(minor) |
| C-018 工具网关联动 | runtime | M4 | 演进中(minor) |
| **C-022 能力暴露（横切前置）** | **S5** | **M4 工具网关联动** | **演进中(minor)，S4 开工前置（须 S5 达 test）** |
| C-024 动态菜单登记 | runtime | M5 菜单注入 | **已冻结** |

> **边界（铁律 15）**：C-022 的控制器暴露由 **S5 负责**，S4 仅消费其暴露后的接口，不得在 S4 重复实现（spec 边界 #4）。S4 进 `code` 前必须确认 S5 的 C-022 已达 `test`（SPECS_INDEX §4）。

### 6.2 内部接口（S4 模块间）
- M1↔M5：运维页经 M5 的权限/菜单校验后才可见可操作。
- M4↔C-022：工具网关页在 S5 达 `test` 后拉取 C-022 能力并展示。
- 内部无跨模块私有表直连，全部经模块边界与服务端契约。

---

## 7. 安全设计

### 7.1 认证机制
- 所有新增端点复用 runtime 既有认证中间件，与 C-014~C-018 一致；**未认证返回 401**（spec §4.3#1）。
- MCP 开放调用与工具调用 100% 绑定可识别调用主体（spec §4.3#2），无法证明受保护的端点不上线到运维界面。

### 7.2 权限控制（R6 双闸）
- **API 层**：新增 3 个端点 + 所有前端操作路由在 `permissions` 登记，经 `RequirePermissionMiddleware` 校验；缺登记即 403。
- **菜单层**：新增页面在 C-024 菜单树登记节点；低权限用户无菜单入口且直达接口仍 403（spec §5.4.1#3、§4.3#5）。
- 角色授权写入 `role_has_permission` 后执行 `loaddbinfo`（tasks T-05/T-10）。
- 跨组织操作（互联注册/能力发布/身份吊销）受独立权限，缺权即隐藏入口 + 服务端 403（spec §5.2.1#4）。

### 7.3 数据安全
- 审计记录 100% 含 操作者/目标/动作/结果/时间/关联标识；**敏感凭据与完整消息正文明文记录数 = 0**（spec §4.3#4）。
- 关键写操作二次确认：确认前服务端写请求数 = 0（spec §4.3#6）。
- 错误日志 100% 含 协议域/操作/结果/refId，**不记凭据或完整消息正文**（spec §4.4#2）。
- 既有 `v1` 路径/方法/响应 100% 向后兼容，不以运维需求替换既有协议端点（spec §4.5）。

---

## 8. 性能设计

### 8.1 性能目标
- 20 并发后台用户下，列表/详情/健康检查/会话数查询服务端 p95 ≤ 2s（外部互联耗时除外，spec §4.1#1）。
- 运维页首屏 ≤ 3s 呈现可操作骨架；单接口超时独立标记失败，不阻塞其他协议卡片（spec §4.1#2）。
- AIP 消息分页由路由 `limit` 控制，前端不绕过服务端限制（spec §4.1#3）。

### 8.2 优化策略
- **4 区域并行独立请求 + 故障隔离**：MCP / AIP / WebMCP / 工具网关 各自独立 fetch，失败仅标该卡片（spec §4.2#2）。
- **只读聚合端点**：新增 `summary`/`sessions`/`audit` 在服务端一次性聚合，减少前端多次往返。
- **写后回读**：成功后 2s 内重读服务端状态，禁止伪造本地成功（spec §4.2#3）。
- **防重复提交**：确认按钮一次点击只发 1 次请求（spec §4.2#1）。

---

## 9. 部署设计

### 9.1 部署架构
- **前端**：新增运维视图随 web-admin 构建产物部署；经 C-024 动态菜单注入，无需改 `constant.ts` 静态路由（遵循 web-admin 既有机制，`src/router/guard/menu.ts:79`）。
- **后端**：3 个新增只读端点随 runtime 宿主编译部署；AI 不运行 `cjpm build`，由人工在独立 cmd 编译回传（铁律约束 + SPECS_INDEX §5.3）。
- **数据**：`sql/incremental/` 登记脚本（permissions / role_has_permission / 菜单节点 INSERT）在部署前执行，并跑 `loaddbinfo`。

### 9.2 环境配置
- 依赖前置：宿主 runtime 已起、S5 的 C-022 达 `test`、DB 迁移与权限登记已执行（SPECS_INDEX §5.3）。
- 新增端点不引入新环境变量；复用 runtime 既有数据库与认证配置。

---

## 10. 附录

### 10.1 参考文档
- `specs/ConsoleClosure/ConsoleClosure--protocol-gateway/spec.md`（需求权威来源）
- `specs/ConsoleClosure/SPECS_INDEX.md`（契约 C-014~C-018、C-022、C-024；DAG；风险 R2/R3/R4/R6）
- `specs/ConsoleClosure/research.md`（三端盘点与缺口 D1-D8；M2 横切前置修正）
- `skills/sdd/SKILL.md`（铁律 9 复用优先 / 铁律 14 二次开发底座 / 铁律 15 大工程拆分 / 铁律 16 git SOP）
- `skills/sdd/templates/design_template.md`、`tasks_template.md`
- `skills/uctoo-dev-manual/`（接口/表/CRUD/中间件/权限规范，二次开发底座）
- 运行时接口：`/api/v1/uctoo/sdd/`（SDD 编排台运行时接口，引用保持原样）

### 10.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-10-30 | sdd-design-writer | 初始版本：覆盖架构/模块/数据(8表全复用)/API(11契约+3新增只读端点)/安全/性能/部署；明确不新增表（铁律9）与不碰 S5 C-022（铁律15）边界 |
