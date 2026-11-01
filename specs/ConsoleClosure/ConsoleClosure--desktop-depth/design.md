# S6 桌面端纵深 · design

> 主工程：`ConsoleClosure`（三端能力补全）　子系统 ID：**S6**　中文名：桌面端纵深
> feature_name：`ConsoleClosure--desktop-depth`　产物目录：`specs/ConsoleClosure/ConsoleClosure--desktop-depth/`
> 语言标签：**app（Electron）**　集成契约：**C-023 桌面端 iframe 集成桥**
> 上游依赖：**S1 / S3 / S5 均 `done`**（见 `SPECS_INDEX.md` §4 DAG）
> 设计依据：`spec.md`（需求权威）、`SPECS_INDEX.md`、`research.md`、`skills/sdd/SKILL.md`（铁律 9 / 12 / 14 / 15）
> 版本：v1.0　创建日期：2026-10-30　状态：草稿（待 gate-design）

---

## 文档信息
- **项目名称**：ConsoleClosure 主工程 · S6 桌面端纵深
- **版本**：v1.0
- **创建日期**：2026-10-30
- **作者**：sdd-design-writer（子 agent 派生）
- **状态**：草稿（待 gate-design 确认）

---

## 1. 设计概述

### 1.1 设计目标

1. 在 Electron 桌面端以「**核心运维原生 + 业务 iframe 深度集成**」混合模式，承接技能、智能体、LLM 通道与运维能力，消除 PC 端假实现（A7：`skills:list` 硬编码空数组、`skills:getDetail`/`skills:install` 返回 `Not implemented`）与死页面（A8：`AgentsView.vue` 恒为 `[]`）。
2. 把 S1 技能控制台、S3 通道治理、S5 运维可观测的**成品页以 iframe 深度集成**进来，保留桌面端侧边栏与窗口框架，**不重复写第二套 Vue 业务页**（消解风险 R7 桌面端双份实现）。
3. 落地 **C-023 桌面端 iframe 集成桥** 与 **W3 登录态持久化方案**（PC 端 `safeStorage` 一致性），token 只在跨上下文 `postMessage` 中流动，绝不明文落盘或走 URL。

### 1.2 设计原则

| 原则 | 落地口径 |
|---|---|
| **铁律 9 复用优先** | 集成路由注册表复用 `config:*` 键值（JSON），不新增大表；令牌凭据复用既有 `auth-bridge.ts` + `safeStorage`，不另造。 |
| **铁律 12 落盘优先** | 本设计所有结论落 `design.md`，并驱动 `tasks.md`；不只在回复里讲。 |
| **铁律 14 二次开发底座优先** | 原生 64 IPC 通道只增不改不删（`spec.md` §4.5.1）；业务页一律走上游成品 iframe，不在 `src/views/**` 新建业务 `.vue`。 |
| **铁律 15 大工程拆分** | 本子系统边界严守：只做「打通 / 集成 / 桥」，上游成品页、后端契约一律调用不重写；跨子系统改动成对成条。 |
| **互斥清单（R7）** | 凡操作系统能力 → 必须原生；凡服务端业务 → 必须 iframe。两者互斥，见 §1.4 与 §3.1/§3.2。 |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 桌面壳 | Electron（主进程 `electron/main/index.ts` + 渲染进程 Vue3 `src/`） | 单 `BrowserWindow` + 单 `Tray`；3 入口 HTML（loading/setup/home）同窗切换 |
| 渲染框架 | Vue 3 + `vue-router`（8 条路由，`src/router/index.ts:4-52`） | 新增 iframe 集成页路由；原生页保持不变 |
| 跨上下文通道 | `contextBridge` 暴露 13 方法组 + `postMessage`（C-023） | 渲染进程**禁止** `nodeIntegration` |
| 令牌加密 | Electron `safeStorage`（系统级加密） | `isEncryptionAvailable()` 为 false 时仅内存，绝不明文兜底 |
| 凭据存储 | 凭据文件（主进程 `auth-bridge.ts:75-101`，复用） | 不进 `config:*`、不进日志、不走 URL |
| 集成路由注册表 | 复用 `config:*` 命名空间键（JSON 数组） | 铁律 9 论证后**不新增表**（见 §4） |
| 就绪态派生 | 复用 C-011 `GET /api/v1/uctoo/sdd/status/:featureName` | 查 S1/S3/S5 的 `current_stage`，不另存 |
| 打包 | electron-builder / NSIS（Windows 优先） | **人工执行打包**，AI 不跑 `electron-vite build` / NSIS |

---

## 2. 系统架构

### 2.1 架构图（ASCII）

```
┌──────────────────────────── 桌面端 Electron 主进程 (electron/main/index.ts) ────────────────────────────┐
│  64 IPC 通道（只增不改不删）      │  safeStorage 凭据文件       │  Tray + autoLaunch + updater:*         │
│  runtime:* / pgsql:* / webadmin:* │  auth:get/save/clearToken   │  dep:* / system:openExternal/openPath  │
│  config:* / setup:* / envsync:*   │  (auth-bridge.ts:75-101)    │  (research.md §4.3)                    │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
        │  contextBridge 暴露 13 方法组                 │  postMessage 桥（C-023，双向）                  │
        ▼                                             ▼                                               │
┌──────────────────────────── 渲染进程 (Vue3, src/) ──────────────────────────────────────────────────┐ │
│  原生运维面（保留，不重写）：                                                                       │ │
│   RuntimeStatus / PgsqlView / SettingsView / AboutView  ←── 直接 IPC                                 │ │
│   侧边栏 AppSidebar（常驻，挂载于 src/App.vue:40）                                                    │ │
│                                                                                                      │ │
│  iframe 深度集成容器（新增，保留侧边栏）：                                                             │ │
│   IframeIntegView  ←── 按「集成路由注册表」解析 原生 / iframe                                         │ │
│        │ 加载 http://localhost:<port>/<iframePath>   （port 取自 webadmin:status，非硬编码 3031）      │ │
│        │ postMessage: uctoo://route-change / auth:token / auth:loginStateChanged / ack               │ │
│        ▼                                                                                             │ │
│  web-admin 静态站（iframe 宿主，本地托管）──→ S1/S3/S5 成品业务页 ──→ AgentSkills-runtime 服务         │ │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

#### 2.2.1 原生能力模块（必须原生，禁止改走 iframe，禁止重写）— `spec.md` §1.4.1
| 模块 | 承载 IPC 通道 | 说明 |
|---|---|---|
| Runtime 进程管理 | `runtime:*` 11 通道 | 启停/重启/状态/安装/日志/版本/检查更新/升级/集成 |
| 内置 PostgreSQL 管理 | `pgsql:*` 8 通道 | init/start/stop/status/backup/restore/testConnection/updateEnvUrl |
| WebAdmin 托管与环境同步 | `webadmin:*` + `envsync:*` 8 通道 | 静态站启停、运行时环境变量同步 |
| 更新 / 自启 / 依赖 / 托盘 / 窗口 | `updater:*` / `autoLaunch:*` / `dep:*` | 应用升级、开机自启、依赖检测、Tray |
| 系统路径 / 本地配置 / 首次建号 | `system:*` / `config:*` 15 / `setup:*` 5 | 路径、配置键值、向导 |
| 令牌保管（加密/读/清） | `auth:get/save/clearToken` | 主进程 `auth-bridge.ts`，`safeStorage` |

> **互斥判据（R7）**：以上一律原生，PC 端不在 iframe 外另写等价 UI。

#### 2.2.2 iframe 集成模块（必须 iframe，禁止渲染进程写第二套 Vue 业务页）— `spec.md` §1.4.2
| 模块 | 承载上游 / 契约 | 说明 |
|---|---|---|
| 技能列表 / 详情 / 安装 / 校验 / 用量 | S1 成品页；C-001~C-005 | iframe 内渲染，PC 端只做容器 |
| 智能体管理 / 任务 / Agent | S1 / S2 成品页 | iframe 内渲染 |
| LLM 多通道管理与成本治理 | S3 成品页；G6 | iframe 内渲染，设置页仅给入口 |
| 日志查看 / 环境采集 / 健康检查 | S5 成品页；C-019 / C-020 | iframe 内渲染 |
| 登录与注册 | web-admin 登录页（iframe 内） | PC 端**无原生登录页** |

#### 2.2.3 桥接模块（C-023 + 集成路由解析 + 令牌持久化）— 本子系统新增核心
- `IframeIntegView.vue`：iframe 容器，保留侧边栏，按注册表决定加载哪个上游页。
- 路由解析器 `resolveIntegrationRoute(routeKey)`：读 `config:*` 注册表 + 调 C-011 派生就绪态 → 输出「原生 / iframe(URL) / 占位」。
- C-023 消息处理器：origin 精确校验 + `version` 字段校验 + token 落盘/下发/登出同步。

### 2.3 组件交互

- **点击侧边栏** → `resolveIntegrationRoute` 判定 → 原生页直接渲染，或 `IframeIntegView` 加载 `http://localhost:<port>/<iframePath>`。
- **iframe 内登录成功** → `postMessage(auth:loginStateChanged, {accessToken})` → 渲染进程校验 origin → `electronAPI.auth.saveToken` → 主进程 `safeStorage` 加密落盘 → 推送 `auth:loginStateChanged`。
- **桌面端需注入 token** → `postMessage(auth:token, {accessToken})` 给 iframe（绝不经 URL）。
- **路由变化** → iframe `postMessage(uctoo://route-change, {route})`；桌面端 `postMessage(uctoo://ack, {type, ok})` 回执。
- **三个 `*:stateChanged` 推送** → 主进程 → 渲染进程 → 侧边栏 / 原生页实时反映。

---

## 3. 详细设计

### 3.1 原生能力模块设计（不重写，仅打通）
- **类/对象**：既有 `electron/main/index.ts` 64 通道 + `electron/modules/*.ts` 26 模块，全部复用。
- **接口**：无新增 IPC（铁律 §4.5.1 签名只增不改不删；本子系统不增）。
- **数据流**：用户操作 → 原生 `.vue` 页 → `electronAPI.*` → 主进程 IPC → OS / runtime 服务。
- **本步动作**：仅联调验证 Runtime/PG/WebAdmin/更新/自启/托盘在混合模式下不被破坏（见 `tasks.md` T-13）。

### 3.2 iframe 集成模块设计
- **新增组件 `src/views/integ/IframeIntegView.vue`**（区别于 `HomeView.vue` 的全屏 iframe）：
  - props：`routeKey`；内部读 `webadmin:status` 取 `port`（非硬编码 3031）；
  - 复用 `HomeView.vue:14` 的 `MAX_LOAD_ATTEMPTS = 5` 重试逻辑（同源 `webadmin.status()` 复查）；
  - 保留 `AppSidebar` 常驻（挂载于 `App.vue:40`），iframe 不覆盖侧边栏；
  - 同屏 iframe 实例复用不销毁（≤3 个，见 §8）。
- **禁止项落地**：代码审查 `src/views/{skills,agents,channels,tasks}/**` 不得新增业务表单/表格页（spec §5.1.1-4）。

### 3.3 C-023 桥详细设计（本子系统新增契约）

**消息协议（4 类，带 `version` 字段）**：

| 方向 | type | payload | 说明 |
|---|---|---|---|
| iframe → 桌面 | `auth:loginStateChanged` | `{accessToken}` | token 回传（现网已是此名，`spec.md` §7-T1 待与 `auth:token` 口径统一，本设计以现网 `auth:loginStateChanged` 为准并登记） |
| iframe → 桌面 | `uctoo://route-change` | `{route}` | 路由同步 |
| 桌面 → iframe | `auth:token` | `{accessToken}` | 令牌下发注入 |
| 桌面 → iframe | `uctoo://ack` | `{type, ok}` | 回执 |

**校验顺序（铁律 §4.3-3 / §4.4-2）**：
1. 校验 `event.origin` 命中**精确白名单**（取 `webadmin:status` 返回端口比对，废弃前缀匹配 `http://localhost:`）；
2. 校验 `version` 一致，不一致 → 降级「仅渲染、不交换 token」+ 告警；
3. 校验消息 `type` 与 `payload` 合法；
4. **以上任一不过 → 丢弃消息、不回传 token、记安全告警日志**。

> `spec.md` §7-T1 口径差异（C-023 记为 `auth:token` / `uctoo://route-change`，现网实现为 `auth:loginStateChanged`）由 T-16 在 contract 冻结时统一，本设计按现网实现落地，避免改 runtime。

### 3.4 令牌持久化（safeStorage，W3 归口）

- **落盘（saveToken）**：`auth-bridge.ts:75-101` 已有分支：
  - `safeStorage.isEncryptionAvailable()` 为 true → `encryptString` 写凭据文件（`:86-88`）；
  - 为 false → **仅存内存，不落盘**（`:90-93`），重启须重新登录，**禁止明文兜底**。
- **读取（getToken）**：返回 `{token, valid}`；文件缺失 / 解密失败 → `valid:false`，清除本地凭据并引导重登（spec §4.2-3）。
- **清除（clearToken）**：登出时同步清磁盘密文 + 内存态，并推送 `auth:loginStateChanged` 令所有集成页回未登录（spec §5.3.1-4）。
- **W3 归口说明**：web-admin 登录页「记住密码」（`rememberPassword`，`login-mail.vue:59` 未绑 v-model）在 PC 端语义 = 经 C-023 桥持久化到 `safeStorage`。**该 web-admin 改造归属上游（移交），S6 只定义契约与桥协议**，不碰 web-admin 登录页源码。
- **禁止项**：token 不进 URL、不进 `config:*`、不进日志（spec §4.3-1/5、§6.2）。

### 3.5 导航与路由解析（原生/iframe 互斥）

```ts
// 伪代码：resolveIntegrationRoute(routeKey)
const reg = config.get('desktop.integration.routes') // JSON 数组，见 §4.1
const entry = reg.find(r => r.routeKey === routeKey)
if (!entry) return { kind: 'native' }            // 未登记 → 原生页兜底
if (entry.readinessState === 'pending') return { kind: 'placeholder', upstream: entry.upstreamId }
const status = await sddStatus(entry.upstreamId)  // C-011 派生就绪态
if (status.current_stage !== 'done') return { kind: 'placeholder', upstream: entry.upstreamId }
return { kind: 'iframe', url: `http://localhost:${port}${entry.iframePath}` }
```

- 侧边栏 8 个导航项：原生 4（Runtime/PG/设置/关于）+ iframe 集成 4（技能/智能体/通道/运维），iframe 项保持侧边栏可见、实例保活（spec §5.1.1-2）。

---

## 4. 数据设计

### 4.1 数据模型（集成路由注册表，复用 `config:*`）

> **铁律 9 论证结论：复用优先成立，本子系统不新增表（新增表 = 0）。**
> 理由：① 集成路由是「路由键 → 上游页路径 + 契约依赖」的静态映射，天然适合 `config:*` 的 JSON 值收纳（铁律 9 明文允许 `config` 等 JSON 字段）；② 就绪态 `readinessState` 为**运行时派生**（查 C-011），不须落库；③ 新增独立表会带来跨进程 DB 访问与额外 CRUD IPC（违反 §4.5.1「IPC 只增不改不删」精神），收益不足以覆盖成本。
> 故 `SPECS_INDEX.md` 登记的「1 表」为 §7-T3 的** provisional 口径**，本 design 论证后覆盖为「0 新增表」，待 `SPECS_INDEX.md` §6 登记更新（铁律 9 胜利结果）。

`config` 键：`desktop.integration.routes`，值结构（JSON 数组）：

| 字段 | 类型 | 约束 | 来源 |
|---|---|---|---|
| `routeKey` | string | 命中 `src/router/index.ts` 已定义 name 或本子系统新增集成页 name，全端唯一 | 本子系统定义 |
| `upstreamId` | enum | `S1` / `S3` / `S5`，必填 | 本子系统定义 |
| `iframePath` | string | 以 `/` 开头，不含协议主机；port 运行时注入 | 本子系统定义（依赖 C-024 菜单路径回填，§7-T6） |
| `readinessState` | enum | `ready` / `pending`；仅 `ready` 允许加载 | 本子系统定义（初值 `pending`，C-011 派生后转 `ready`） |
| `requiredContract` | string[] | 至少 1 项（如 `C-001,C-002`），用于 L2 冒烟 | 本子系统定义 |
| `sidebarVisible` | bool | 恒 `true`（iframe 集成页保留侧边栏） | 本子系统定义 |

### 4.2 表设计（复用 vs 新增）
- **新增表**：**无**（铁律 9 论证见 §4.1）。
- **复用**：`config`（键值收纳注册表）、`sdd_projects`（C-011 查上游 `current_stage` 派生就绪态）、凭据文件（`auth-bridge.ts` 管理，非表）。
- **无 `sql/incremental/` 新 DDL 产出**（本子系统不新增表/列）；亦**不触发 `permissions` + `role_has_permission` 新登记**（S6 不新增后端路由，iframe 内页面权限由上游 S1/S3/S5 经 C-024 负责，见 `tasks.md` 风险 R6 说明）。

### 4.3 数据关系
```
config.desktop.integration.routes ──(upstreamId)──> S1 / S3 / S5（上游 SDD 工程，done 后就绪）
config.desktop.integration.routes ──(requiredContract)──> C-001..C-024（契约编号，仅引用）
sdd_projects.current_stage ──(C-011 派生)──> readinessState（不落库，运行时算）
auth-bridge 凭据文件 ──(safeStorage)──> accessToken（加密，非表）
```

---

## 5. API 设计

### 5.1 API 列表（本子系统对外登记的「8 接口」口径）

| # | 编号 | 方法/类型 | 路径或标识 | 方向 | 归属 | 描述 |
|---|---|---|---|---|---|---|
| 1 | C-023-A | postMessage | `auth:loginStateChanged` | iframe→桌面 | **新增（S6）** | token 回传，经 origin+version 校验后落 safeStorage |
| 2 | C-023-B | postMessage | `uctoo://route-change` | iframe→桌面 | **新增（S6）** | 路由同步 |
| 3 | C-023-C | postMessage | `auth:token` | 桌面→iframe | **新增（S6）** | 令牌下发注入（绝不经 URL） |
| 4 | C-023-D | postMessage | `uctoo://ack` | 桌面→iframe | **新增（S6）** | 回执 |
| 5 | — | IPC（复用） | `auth:get/save/clearToken` | 桌面↔主进程 | 复用现有 | 令牌读/存/清，主进程 safeStorage |
| 6 | — | IPC（复用） | `webadmin:status` | 桌面↔主进程 | 复用现有 | 取 WebAdmin 端口（注入 iframe URL） |
| 7 | — | IPC（复用） | `config:get` / `config:set` | 桌面↔主进程 | 复用现有 | 读写集成路由注册表 |
| 8 | C-011 | HTTP（复用） | `GET /api/v1/uctoo/sdd/status/:featureName` | 桌面→runtime | 复用现有 | 派生 S1/S3/S5 就绪态 |

> 口径说明：S6 真正**新增**的契约接口 = C-023 桥（消息 1–4）；消息 5–8 为**复用/依赖的上游契约接口**。合计对外登记的「8 接口」即上表；其中无新增大表（见 §4）。

### 5.2 API 详细设计

#### 5.2.1 C-023 桥（auth:loginStateChanged / uctoo://route-change / auth:token / uctoo://ack）
- **请求形态（iframe → 桌面）**：
  ```json
  { "version": "1.0", "type": "auth:loginStateChanged", "data": { "accessToken": "<jwt>" } }
  { "version": "1.0", "type": "uctoo://route-change",  "data": { "route": "/skills" } }
  ```
- **响应形态（桌面 → iframe）**：
  ```json
  { "version": "1.0", "type": "auth:token",   "data": { "accessToken": "<jwt>" } }
  { "version": "1.0", "type": "uctoo://ack",  "data": { "type": "auth:loginStateChanged", "ok": true } }
  ```
- **错误码/降级**：origin 不命中 → 丢弃 + 安全告警；version 不一致 → 仅渲染不交换 token + 告警；token 空/写失败/401 → 见 spec §5.3.3。

#### 5.2.2 集成路由注册表（config 键读写，复用 `config:get/set`）
- **读取**：`config:get('desktop.integration.routes')` → JSON 数组（§4.1 结构）。
- **写入（仅首次播种 / 上游 done 后翻 `ready`）**：`config:set('desktop.integration.routes', <json>)`，由 `tasks.md` T-01 定义种子值与翻态时机。
- **就绪态不落库**：`readinessState` 由 C-011 在渲染时派生，注册表仅存静态映射。

---

## 6. 接口设计

### 6.1 内部接口
- `resolveIntegrationRoute(routeKey)`：渲染进程内函数，聚合 §3.5 逻辑，输出 `native / iframe / placeholder`。
- `IframeIntegView` 生命周期：`onMounted` 读 `webadmin:status` → 复查 `webadmin.status()` → 加载 + 5 次重试 → `onIframeError` 处理（复用 `HomeView.vue:33-38`）。

### 6.2 外部接口（跨上下文 / 跨子系统）
- **C-023**（见 §5.2.1）：与 web-admin iframe 宿主的桥。
- **C-011**（复用）：上游就绪态派生。
- **C-001~C-005 / G6 / C-019~C-020**：S6 不实现，仅经 iframe 内页面调用，PC 端不直连（spec §3.2）。
- **C-024（菜单登记）**：上游成品页入口由后端菜单树驱动，PC 端只消费不生产；S6 不新增菜单（spec §1.4.3-3）。

---

## 7. 安全设计

### 7.1 认证机制
- token 仅在 `postMessage` 跨上下文流动；**绝不**拼接进 iframe URL 或写入 `config:*` / 日志（spec §4.3-1/5、§6.2）。
- 登录在 iframe 内完成，PC 端无原生登录页（research.md §4.4）。

### 7.2 权限控制
- PC 端不新增后端路由 → **不触发** R6 的 `permissions` + `role_has_permission` 新登记（无新界面即无 403 风险）。
- iframe 内业务页的权限由上游 S1/S3/S5 经 C-024 菜单树负责；S6 只消费，菜单登记属上游任务（移交）。

### 7.3 数据安全
1. **加密落盘**：`safeStorage` 可用时密文落盘；不可用仅内存，重启重登，禁止明文兜底（spec §4.3-1/2、§5.3.1-3）。
2. **origin 精确白名单**：取 `webadmin:status` 端口比对，废弃 `http://localhost:` 前缀匹配（spec §4.3-4）。
3. **校验顺序**：origin → version → type/payload，未过即丢弃并告警（spec §4.4-2、§4.3-3）。
4. **渲染进程隔离**：禁止 `nodeIntegration`，能力仅经 `contextBridge` 13 方法组（spec §4.3-6）。
5. **登出全清**：清磁盘密文 + 内存态 + 推送 `auth:loginStateChanged`（spec §5.3.1-4）。
6. **日志脱敏**：iframe 加载/重试/降级全链路落主进程日志，含 origin/端口/次数/原因，统一 `key=value`，**token 永不入日志**（spec §4.4-1、§6.2）。

---

## 8. 性能设计

### 8.1 性能目标（spec §4.1）
1. 状态类 IPC ≤ 100ms，其余原生通道 ≤ 200ms（不含进程启停长操作）。
2. iframe 深度集成页首屏可交互 ≤ 3s（自 `webadmin:status` 返回 `state=running` 起算）。
3. 路由切换渲染 ≤ 300ms；同屏并存 iframe ≤ 3 个，实例复用不销毁，常驻内存增量 ≤ 50MB。

### 8.2 优化策略
- iframe 实例复用（Vue `<keep-alive>` 或手动保活），切走不销毁，满足 ≤3 个与 ≤50MB。
- 注册表与就绪态在侧边栏点击时**惰性解析**，不在启动期全量拉取。
- `webadmin:status` 端口缓存，避免每次导航重复 IPC。

---

## 9. 部署设计

### 9.1 部署架构
- 桌面端为独立 Electron 应用；Windows 为首要目标平台（spec §4.5-3，§7-T4 待确认 macOS/Linux）。
- 内置 PostgreSQL 实例、runtime 进程、web-admin 静态站均由主进程本地托管（research.md §4.3）。

### 9.2 环境配置 / 打包
- **打包工具**：electron-builder + NSIS（Windows 安装包）。
- **更新通道**：`updater:*`（`electron/main/index.ts:307-322`）主进程自更新。
- **构建约束（铁律 / 项目约定）**：AI（sdd 文档步与 code 步）**不运行** `electron-vite build` / NSIS 打包 / 类型检查 / lint；上述由人工在独立环境执行并回传结果（类比 cangjie 的「AI 不跑 cjpm build」）。渲染进程 Vue 与主进程 TS 由 `web-coder` 技能生成。
- **首次运行向导**：`setup:*` 5 通道（`:217-240`）保持不变，建号入口不变。

---

## 10. 附录

### 10.1 参考文档
- `specs/ConsoleClosure/ConsoleClosure--desktop-depth/spec.md`（需求权威）
- `specs/ConsoleClosure/SPECS_INDEX.md`（契约 / 风险 R7 / W3 / 依赖 DAG）
- `specs/ConsoleClosure/research.md`（三端缺口 A7/A8/G6、pc-client 基线 §4）
- `skills/sdd/SKILL.md`（铁律 9 / 12 / 14 / 15）
- `apps/pc-client` 源码：`electron/main/index.ts`、`electron/modules/auth-bridge.ts`、`src/views/HomeView.vue`、`src/router/index.ts`、`src/App.vue`、`src/components/AppSidebar.vue`
- 契约：`C-001~C-005`（S1）、`C-011`（SDD 状态）、`C-019/C-020`（S5）、`C-023`（本桥）、`C-024`（菜单）

### 10.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-30 | sdd-design-writer | 初始设计：混合模式架构、C-023 桥协议、safeStorage 令牌持久化、R7 互斥清单、W3 归口；铁律 9 论证「0 新增表，集成路由复用 config:*」 |

> 待 §7 待确认项（T1–T7）在 code 前由 T-16 收敛并回写 `SPECS_INDEX.md` §6 / contract 冻结口径。
