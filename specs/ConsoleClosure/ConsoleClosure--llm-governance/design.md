# S3 LLM 通道与成本治理 —— 技术设计文档

> 主工程：`ConsoleClosure`（三端能力补全）｜ 子系统 ID：`S3` ｜ feature_name：`ConsoleClosure--llm-governance`
> 关联需求：`specs/ConsoleClosure/ConsoleClosure--llm-governance/spec.md`
> 关联任务：`specs/ConsoleClosure/ConsoleClosure--llm-governance/tasks.md`
> 阶段：`design` ｜ 验收档位：L1 + L2 + L3 ｜ 语言标签：`web`
> 事实依据：`research.md` §2.2 / §3.2 / §5.2 / §5.3 / §8（M4/M6）｜ 契约依据：`SPECS_INDEX.md` §3（C-013、C-024 已冻结）、§7（R2/R4/R6）

---

## 文档信息
- **项目名称**: ConsoleClosure -- LLM 通道与成本治理（S3）
- **版本**: v1.0
- **创建日期**: 2026-10-30
- **作者**: sdd-design-writer（SDD 子 agent 派生）
- **状态**: 草稿（待 gate-design 闸口确认）

---

## 1. 设计概述

### 1.1 设计目标
本子系统是**补齐型前端工程**，不重建、不改造后端。目标是把 runtime 已经落表、但 Web 端只有 `crudgen` 裸 CRUD 壳（无业务界面）的五类 LLM 通道治理能力，补齐成五个可用人机界面，使成本可见、配额可控、变更可追溯。具体目标：

1. 交付 5 个新增 Web 治理界面（同级目录，不覆盖既有页）。
2. 对**已冻结契约 C-013**（计费/Token 统计）与 **C-024**（动态菜单）只消费、不改写；对五张治理表只走既有 CRUD 壳，不新增表/列。
3. 把 M6 缺陷（聚合端点硬扫 10000 条且忽略入参）在 UI 层以「常驻范围标注 + 不二次聚合」方式消化，不倒逼服务端改造。
4. 五个界面全部进后端菜单树 + RBAC 双层登记，否则用户看不到入口或 403（R2/R6）。

### 1.2 设计原则
- **复用优先（铁律 9 / R4）**：五张既有表字段齐备，本子系统零新增表/列；只新增前端页面与权限数据种子。
- **二次开发底座优先（铁律 14）**：前端沿用 web-admin 既有 `src/store/models/uctoo/*` Model 层与 `src/router/guard/menu.ts` 动态注入机制，不另起一套取数框架。
- **大工程拆分（铁律 15）**：S3 是 6 个独立子系统之一，边界只落在「Web 新增界面 + 菜单/权限登记 + iframe 可承载交付物」内；通道 CRUD、Electron 壳、服务端计费链路一律不碰，移交上游或下游。
- **只读消费冻结契约**：C-013 / C-024 路径、方法、入参、返回结构一律只读；其「忽略全部 query、固定扫 10000 条」的既有行为在 UI 层标注接受，不要求服务端修改。
- **密钥不落前端（S-1）**：任何界面不渲染/日志/导出 `api_key`，只显示「已配置/未配置」徽标。

### 1.3 技术选型
| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 前端框架 | Vue 3 + TypeScript（沿用 web-admin） | 复用 `src/views/ai/*` 既有范式与 `src/store/models/uctoo/*` Model 层 |
| UI 组件库 | OpenTiny / @opentiny/next（沿用 web-admin） | 与既有 `model_channel`、`token_dashboard`、`billing_report` 页一致 |
| 取数层 | `src/store/models/uctoo/*.ts` Model（97 个 ORM 模型全集） | 真正的接口全集在此，非 `src/api/*` 模板薄层 |
| 路由 | 后端菜单树动态注入（`src/router/guard/menu.ts:79`） | 新界面必须经 C-024 登记才有入口 |
| 后端 | runtime（`LlmChannelRoute.cj` / `ModelPricingRoute.cj` / `LlmUsageStatsController.cj` / `BillingReportController.cj`） | 仅消费，不改造 |
| 数据库 | PostgreSQL（runtime 宿主库） | 仅复用五张既有表，无 schema 变更 |

---

## 2. 系统架构

### 2.1 架构图
```
┌──────────────────────────────────────────────────────────────────────┐
│  浏览器 / pc-client 桌面壳 (S6 经 C-023 iframe 承载，同源 token)        │
└───────────────┬──────────────────────────────────────────────────────┘
                │  GET 治理界面（路由经 C-024 菜单树动态注入）
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  web-admin (S3 新增 5 个同级 Vue 界面 + 共享 governance 模块)          │
│                                                                        │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────┐ │
│  │ C1 定价维护 │ │ C2 配额治理 │ │ C3 明细查询 │ │ C4 健康历史 │ │C5 审计│ │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └───┬───┘ │
│        │              │              │              │            │      │
│  ┌─────┴──────────────┴──────┬───────┴──────────────┴────────────┘      │
│  │  shared: governance models / 范围标注组件 / 深链跳转 / 告警计算工具   │ │
│  └───────────────────┬────────┘                                          │
└──────────────────────┼──────────────────────────────────────────────────┘
                       │ 消费（仅 GET / 既有 CRUD 壳 POST）
        ┌──────────────┼─────────────────────────────────────────┐
        ▼              ▼                                          ▼
┌──────────────┐ ┌───────────────────────┐ ┌──────────────────────────┐
│ llm_channel  │ │ 五表 CRUD 壳          │ │ C-013 冻结聚合/报表       │
│ list/health/ │ │ (model_pricing 等)    │ │ llm-usage-stats/*        │
│ audit        │ │  crudgen 生成         │ │ billing-report/*         │
└──────┬───────┘ └───────────┬───────────┘ └────────────┬─────────────┘
       │                     │                           │
       ▼                     ▼                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  runtime 宿主库（PostgreSQL）—— 仅复用，无新增表/列                    │
│  model_pricing │ usage_quotas │ llm_usage_logs │                      │
│  llm_channel_health │ llm_channel_audit                                        │
└──────────────────────────────────────────────────────────────────────┘
```
> 说明：S3 不新增任何 runtime HTTP 端点、不新增任何表/列；图中所有后端接口均为既有/冻结项，S3 仅在其上叠加前端界面与权限数据种子。

### 2.2 模块划分
| 模块 | 职责 | 边界 |
|------|------|------|
| `views/ai/llm_gov/pricing/` | C1 模型定价维护界面 | 仅前端；写操作走 `model_pricing` CRUD 壳 |
| `views/ai/llm_gov/quota/` | C2 用量配额治理界面 | 仅前端；本地计算告警，不调服务端告警接口 |
| `views/ai/llm_gov/usage/` | C3 用量明细查询 + 汇总视图 | 仅前端；汇总接 C-013 冻结端点 |
| `views/ai/llm_gov/health/` | C4 通道健康历史 | 仅前端；深链跳 `model_channel/index.vue` |
| `views/ai/llm_gov/audit/` | C5 通道审计追溯 | 仅前端；before/after Diff 默认折叠 |
| `store/models/uctoo/` 复用 | 五表 ORM Model + `LlmChannel`/`LlmUsageStats`/`BillingReport` Model | 复用既有，不新增 |
| `components/llm_gov/` 共享 | 范围标注 Banner、告警进度条、深链跳转、Diff 渲染 | 仅前端组件 |
| `sql/incremental/` 数据种子 | 菜单节点 + permissions + role_has_permission（非 DDL） | 仅数据登记，无 schema 变更 |

### 2.3 组件交互
- **界面 ↔ runtime**：每个列表/详情页通过 `src/store/models/uctoo/*` Model 调用对应 CRUD 壳或 C-013/C-024 端点；所有调用受 `RequirePermissionMiddleware` + 菜单树双层把关（S-2/R6）。
- **C4 健康 ↔ 通道映射**：健康页先拉 `GET /llm_channel/list` 取 `channel_id → code` 映射，再以 `code` 作图例；点击异常点深链跳 `model_channel/index.vue`（复用既有页，不另建）。
- **S3 ↔ S6（G6）**：S3 交付「可被 iframe 直达」的治理界面与菜单/权限；S6 负责 Electron 集成壳（C-023 桥接），不在本子系统范围内。

---

## 3. 详细设计

### 3.1 五治理界面模块设计

#### 3.1.1 类 / 组件设计（前端）
| 组件 | 类型 | 说明 |
|------|------|------|
| `LlmGovPricingView.vue` | 页面 | C1：列表倒序 + 生效中标记 + 字段校验 + 快照免责标注 |
| `LlmGovQuotaView.vue` | 页面 | C2：作用域口径 + 阈值比值告警 + 硬/软限区分 + 本地告警 |
| `LlmGovUsageView.vue` | 页面 | C3：五维筛选 + 只读 + 快照优先 + 汇总视图（接 C-013） |
| `LlmGovHealthView.vue` | 页面 | C4：list 映射 + 只增不删 + 失败/慢点分类 + 深链跳 |
| `LlmGovAuditView.vue` | 页面 | C5：四维检索 + before/after Diff + 默认折叠 + 来源可见 |
| `ScopeBadge.vue` | 共享组件 | 常驻「统计范围：最近 10000 条用量明细」标注（P-2） |
| `QuotaAlertBar.vue` | 共享组件 | 本地计算 `quota_used/quota_limit` 比值与 `alert_threshold` 比对，渲染告警色 |
| `ChannelDeepLink.vue` | 共享组件 | 封装跳 `model_channel/index.vue` 并定位通道的路由逻辑 |

#### 3.1.2 接口设计（调用上游，非本子系统新增）
见 §5 API 设计。本子系统不定义任何新后端接口。

#### 3.1.3 数据流
以 C3 明细查询为例：
```
用户设筛选条件 → UsageView 调 GET /llm_usage_logs/:limit/:page（带筛选）
  → runtime 返回分页明细（server 端按 :limit/:page 真实分页，非 C-013）
  → 前端渲染 tokens/cost/error_message，失败样式标红
用户切「汇总视图」→ 调 GET /llm-usage-stats/summary（C-013 冻结）
  → runtime 固定扫 10000 条返回聚合 → 前端渲染 + ScopeBadge 常驻标注
  → 禁止前端二次全量聚合（P-2）
```

### 3.2 共享治理模块设计
- **范围标注组件 `ScopeBadge`**：在任一接 C-013 的视图常驻渲染「统计范围：最近 10000 条用量明细」，且页脚小计与 C-013 聚合不一致时标注口径差异（C3 §5.3.1 规则 4）。
- **告警计算工具 `quotaAlert(used, limit, threshold, isHard)`**：纯前端函数，按 `quota_used/quota_limit >= alert_threshold` 判定告警；`is_hard_limit` 决定「硬限-已拦截」或「软限-放行中」文案，绝不把软限渲染成阻断态（R-3）。
- **深链跳转**：统一经 `ChannelDeepLink` 跳 `model_channel/index.vue`，不另建通道页（spec 1.4 边界 1）。

---

## 4. 数据设计

> **核心结论（铁律 9 / R4）**：本子系统**零新增表、零新增列**。五张治理表字段经 spec §6 复核齐备，覆盖定价/配额/明细/健康/审计全部维度；界面所需展示字段（含 `cost_amount`/`cost_currency`/`rate_prompt`/`rate_completion` 等快照字段）均已存在，无需新增。新增展示诉求一律用既有字段（或 JSON 字段）收纳，**不存在「复用不成立」场景**，故不落任何 schema DDL。

### 4.1 数据模型（复用既有 5 表）
| 表名 | 归属 | 本子系统角色 | 复用 / 新增 | 复用论证 |
|------|------|------------|-----------|---------|
| `model_pricing` | runtime | C1 定价台账源 | **复用** | 单价/币种/生效区间字段齐备（spec §6.1），无需扩展 |
| `usage_quotas` | runtime | C2 配额看板源 | **复用** | target/quota_type/limit/used/threshold/hard 字段齐备（spec §6.2） |
| `llm_usage_logs` | runtime | C3 明细源 + C-013 聚合源 | **复用** | tokens/cost/快照字段齐备（spec §6.3），快照优先策略已满足 |
| `llm_channel_health` | runtime | C4 健康历史源 | **复用** | channel_id/ok/latency_ms/error_code/checked_at 齐备（spec §6.4） |
| `llm_channel_audit` | runtime | C5 审计流水源 | **复用** | action/before/after/operator/source 齐备（spec §6.5） |

### 4.2 数据表结构（仅列关键约束，完整字段见 spec §6）
- `model_pricing`：`provider+model` 业务主键语义；`rate_*_per_million >= 0`；`rate_currency` 必填；`effective_to` 空=长期有效，非空必须晚于 `effective_from`。
- `usage_quotas`：`quota_limit > 0`；`alert_threshold ∈ [0,1]` 为比值；`quota_type` 以 `daily_/weekly_/monthly_` 前缀驱动重置；`target_type=global` 时 `target_id=*`。
- `llm_usage_logs`：只读流水，`cost_amount`/`cost_currency` 为当次快照，以快照为准。
- `llm_channel_health` / `llm_channel_audit`：**均无 `deleted_at`**，界面禁止删除入口（R-1）。

### 4.3 数据关系
```
llm_channel (既有, 非本子系统表)
   │ 1:N
   ├── llm_channel_health.channel_id  (映射 code 经 /llm_channel/list)
   └── llm_channel_audit.channel_id   (可空，空=非通道级)
model_pricing (provider+model) ── 快照关系 ──> llm_usage_logs.rate_prompt/rate_completion
                                          （快照优先，不以现值反算）
usage_quotas (独立维度，按 target_type/target_id 作用)
```
> 五张表均为 runtime 既有表，S3 只读或走其 CRUD 壳写；不新建任何关系表。

---

## 5. API 设计

### 5.1 API 列表（本子系统消费，非新增）
> 本子系统**不新增任何 runtime HTTP 端点**。下表为 S3 实际消费的契约接口，分「冻结契约」与「复用既有壳」两类。

| 方法 | 路径 | 描述 | 契约状态 | 供 C |
|------|------|------|---------|------|
| GET | `/api/v1/uctoo/llm-usage-stats/summary` | Token/费用汇总（固定扫 10000 条） | **C-013 已冻结** | C3/C6 |
| GET | `/api/v1/uctoo/llm-usage-stats/by-agent` | 按 Agent 排名 | **C-013 已冻结** | C3 |
| GET | `/api/v1/uctoo/llm-usage-stats/by-model` | 按模型排名 | **C-013 已冻结** | C3 |
| GET | `/api/v1/uctoo/billing-report/daily` | 计费日报 | **C-013 已冻结** | C6 |
| GET | `/api/v1/uctoo/billing-report/monthly` | 计费月报 | **C-013 已冻结** | C6 |
| GET | `/api/v1/uctoo/billing-report/export-csv` | CSV 透传下载 | **C-013 已冻结** | C6 |
| GET | `/api/v1/uctoo/llm_channel/list` | 通道列表（channel_id→code 映射） | 复用（C4/C5 数据入口） | C4/C5 |
| GET | `/api/v1/uctoo/llm_channel/health` | 健康记录 | 复用 | C4 |
| GET | `/api/v1/uctoo/llm_channel/audit` | 审计记录 | 复用 | C5 |
| GET | `/api/v1/uctoo/model_pricing/:limit/:page` | 定价分页 | 复用 CRUD 壳 | C1 |
| POST | `/api/v1/uctoo/model_pricing/{add,edit}` | 定价写 | 复用 CRUD 壳 | C1 |
| GET | `/api/v1/uctoo/usage_quotas/:limit/:page` | 配额分页 | 复用 CRUD 壳 | C2 |
| POST | `/api/v1/uctoo/usage_quotas/edit` | 配额写 | 复用 CRUD 壳 | C2 |
| GET | `/api/v1/uctoo/llm_usage_logs/:limit/:page` | 明细分页（真实分页） | 复用 CRUD 壳 | C3 |
| GET | `/api/v1/uctoo/llm_channel_health/:limit/:page` | 健康分页 | 复用 CRUD 壳 | C4 |
| GET | `/api/v1/uctoo/llm_channel_audit/:limit/:page` | 审计分页 | 复用 CRUD 壳 | C5 |
| POST | `/api/v1/uctoo/permissions/user/menu` | 菜单树（入口可见性） | **C-024 已冻结** | 全部 |

> 上述 9 个「业务接口」（6 个 C-013 + 3 个 llm_channel）即 `SPECS_INDEX.md` §2 中 S3 的「9 接口」口径；5 张表通过 crudgen CRUD 壳访问，属复用既有基础设施，不计入新接口。

### 5.2 API 详细设计（代表性两条，其余同 CRUD 壳范式）

#### 5.2.1 `GET /api/v1/uctoo/llm-usage-stats/summary`（C-013 冻结，只读消费）
- **请求方法**: GET
- **请求参数**: 忽略全部 query（含 `limit`/`page`/`时间范围`），服务端固定 `(1,10000,...)` 硬扫描（M6）
- **响应格式**: `{ summary:{totalTokens,cost,...}, series:[...], ranking:[...] }`
- **错误处理**: 服务端 `success=false` 时前端保留筛选条件并展示 `reason`（R-2）
- **UI 约束**: 返回即服务端已聚合结果，前端**禁止二次全量聚合**；渲染时 `ScopeBadge` 常驻标注「最近 10000 条」

#### 5.2.2 `GET /api/v1/uctoo/llm_channel/list`（C4/C5 映射数据源）
- **请求方法**: GET
- **请求参数**: 无（或既有 list 参数）
- **响应格式**: `{ items:[{channel_id, code, ...}] }`
- **用途**: 健康/审计页将 `channel_id` 映射为 `code` 作图例；`channel_id` 无对应时以原值兜底并标「失效」（spec §5.4.3）

### 5.3 本子系统新增接口
**无。** 本子系统为纯前端补齐，不定义任何新后端接口、不新增表/列、不改动冻结契约 C-013/C-024。任何「看似需要新接口」的诉求（如告警推送）均按 spec 在界面侧本地计算或显式标注不支持（C2 §5.2.1 规则 5、S-2）。

---

## 6. 接口设计（内部 / 外部）

### 6.1 内部接口（前端模块间）
- `ScopeBadge` / `QuotaAlertBar` / `ChannelDeepLink` 共享组件，仅前端内部调用，无网络。
- `store/models/uctoo/` 既有 Model 作为取数内部契约，不新增。

### 6.2 外部接口
- 上游 runtime 全部为「消费既有/冻结」接口，见 §5.1。
- 下游 S6：经 C-023 iframe 承载本子系统界面，S3 仅保证「同源 token 下可直达渲染」，不实现 Electron 壳。

---

## 7. 安全设计

### 7.1 认证机制
- 沿用 web-admin 既有登录态（token 由 `permissions/user/menu` 等接口携带）；pc-client 经 C-023 `auth:token` 注入同源 token（S6 负责）。
- S3 不新增任何认证逻辑，仅复用宿主鉴权链。

### 7.2 权限控制（S-2 / R6）
- **双层登记硬约束**：五个新界面入口必须同时进 `permissions` 表（权限项）与 `role_has_permission`（角色授权），执行后必跑 `loaddbinfo`；缺登记表现为「看不到入口」而非 403（R6 备注：超管因通配权 `*` 走全量分支，改 `role_has_permission` 对超管无效）。
- 每个后端调用点（`RequirePermissionMiddleware`）依赖上述登记；菜单可见性依赖 C-024 菜单树节点登记（M-1/R2）。

### 7.3 数据安全
- **S-1（密钥不落前端）**：`LlmChannelPO.toJsonValue()` 明确不回显 `api_key`，只输出 `api_key_set` 布尔。五界面**禁止**渲染/日志/导出任何密钥，仅显示「已配置/未配置」徽标。
  - **API Key 加密存储口径**：`api_key` 的落库加密与回显控制完全由 runtime 侧 `LlmChannelPO` 负责，S3 不接触明文、不实现加解密，仅消费 `api_key_set` 标志——此属复用 runtime 既有能力，非本子系统新增。
- **S-3**：审计 `before`/`after` 可能含敏感配置片段，默认折叠，仅审计员显式展开可查看并计入访问留痕。
- **S-4**：写操作一律走 runtime 既有 Service/CRUD 壳（如 `model_pricing/{add,edit}`、`usage_quotas/edit`），禁止绕过 Service 直连写表。

---

## 8. 性能设计

### 8.1 性能目标
- **P-1**：明细/健康/审计三列表首屏（默认 20 条/页，含鉴权）95 分位 ≤ 3s；单页上限 200 条，超出分页。
- **P-2**：C-013 聚合固定扫 10000 条且忽略入参——UI 常驻标注范围，**禁止前端二次全量聚合**。
- **P-3**：健康历史单次查询时间窗默认 ≤ 30 天、点位 ≤ 500；超出提示缩小时间窗，禁止静默截断。
- **P-4**：CSV 导出为服务端结果透传，前端不做二次汇总。

### 8.2 优化策略（M6 分页与聚合下推方案）
M6 缺陷：`LlmUsageStatsController.cj:19` / `BillingReportController.cj:20` 固定 `(1,10000,...)` 硬扫描且忽略入参（C-013 冻结，不可改服务端）。S3 的分页与聚合下推处理如下：

1. **明细列表真实分页（聚合下推到 CRUD 壳）**：C3 明细页调用 `llm_usage_logs/:limit/:page`，该 CRUD 壳**尊重** `:limit/:page` 入参，分页在 server 端完成（下推），前端只渲染当前页；与 C-013 的「忽略 limit」行为隔离，互不影响。
2. **C-013 聚合为服务端独占（不下推、不重算）**：summary/by-agent/by-model/daily/monthly 的聚合完全由服务端完成且固定扫 10000 条；前端**只渲染返回结果 + 常驻 `ScopeBadge` 范围标注**，绝不拉全量后在浏览器重算（满足 P-2）。
3. **by-agent / by-model 排名直接消费**：服务端已返回 `ranking[]`，前端按序渲染，无前端排序/汇总。
4. **健康点位上限（P-3）**：前端在发起 `llm_channel_health` 查询前校验时间窗 ≤ 30 天、预估点位 ≤ 500；超限即拦截并提示「结果超过 500 点，请缩小时间窗」，不静默截断。
5. **CSV 透传（P-4）**：`billing-report/export-csv` 由前端触发下载、直接透传服务端字节流，零前端计算。

---

## 9. 部署设计

### 9.1 部署架构
- **前端**：5 个新增 Vue 界面随 web-admin 构建产物发布；路由由后端 C-024 菜单树动态注入，无需改 `src/router/constant.ts` 静态路由。
- **数据种子（非 DDL）**：菜单节点 + `permissions` + `role_has_permission` 登记脚本置于 `sql/incremental/`，幂等可复跑（INSERT ... WHERE NOT EXISTS），执行后跑 `loaddbinfo`。
- **runtime 侧**：本子系统**不改动** runtime 代码、不新增表/列、不新增端点——故 runtime 无需重新部署，仅 DB 数据种子（权限/菜单）需执行。
- **pc-client（S6）**：经 C-023 iframe 承载，S3 不发布 Electron 产物。

### 9.2 环境配置
| 前置 | 状态 | 说明 |
|------|------|------|
| runtime 宿主已起 | 依赖用户启动 | AI 不跑 `cjpm build` |
| 权限/菜单数据种子已执行 | 本子系统 tasks 产出 | `sql/incremental/` 幂等 SQL，非 schema DDL |
| 前端构建已发版 | 本子系统产出 | web-admin 构建 |
| 动态菜单登记 | 依赖 C-024 | 五个入口节点登记 |

---

## 10. 附录

### 10.1 参考文档
- `specs/ConsoleClosure/ConsoleClosure--llm-governance/spec.md`（需求权威）
- `specs/ConsoleClosure/SPECS_INDEX.md`（契约/风险/集成/验收）
- `specs/ConsoleClosure/research.md`（缺口分析，§5.2 C1-C5、§5.3 G6、§8 M4/M6）
- `skills/sdd/SKILL.md`（铁律 9 复用优先 / 铁律 14 二次开发底座优先 / 铁律 15 大工程拆分）
- `skills/uctoo-dev-manual/`（前端范式、权限系统、CRUD 壳机制）
- runtime 源码实证：`LlmChannelRoute.cj:54-74` / `AutoRouteConfig.cj:1464-1480` / `LlmUsageStatsController.cj:19` / `BillingReportController.cj:20` / `QuotaCheckHandler.cj:67` / `src/router/guard/menu.ts:79`

### 10.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-10-30 | sdd-design-writer | 初始版本：补齐 5 界面设计，零新增表/列，C-013/C-024 冻结只读，M6 前端消化，菜单/权限双层登记 |

> 待确认项（spec §1.5 T-1~T-5）不写入本设计结论，仅在 tasks.md 中按「倾向后者/最小口径」落实为任务约束：T-1 不补 QuotaCheckHandler 调用点（如实展示现状）；T-2 接受 10000 条范围标注；T-3 版本展示位渲染「待用户确认」；T-4 S3 仅交付 iframe 可达界面+菜单权限，Electron 归 S6；T-5 枚举自由输入+服务端校验。
