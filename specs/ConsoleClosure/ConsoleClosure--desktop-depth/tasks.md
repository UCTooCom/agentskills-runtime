# 任务规划文档（tasks.md）· S6 桌面端纵深

> 基于 `spec.md` 与 `design.md` 生成。实施原则：**复用优先**、**确定性优先**、**大工程拆分边界（铁律 15）**。
> 主工程：`ConsoleClosure`　子系统 ID：**S6**　feature_name：`ConsoleClosure--desktop-depth`　语言标签：**app（Electron）**
> 上游依赖：S1 / S3 / S5 均 `done`（否则集成半成品，见 `SPECS_INDEX.md` §4）。验收档位：L1 + L2 + L3。

## 文档信息
- 关联需求：`specs/ConsoleClosure/ConsoleClosure--desktop-depth/spec.md`
- 关联设计：`specs/ConsoleClosure/ConsoleClosure--desktop-depth/design.md`
- 生成日期：2026-10-30　版本：v1.0　状态：草稿（待 gate-task）

## 开发规范（全任务强制遵守）
- **语言与工具绑定**：本子系统标签 `app（Electron）`——渲染进程 Vue3 + 主进程 TypeScript，均由 **web-coder** 技能生成；**AI 不运行** `electron-vite build` / NSIS 打包 / 类型检查 / lint，由人工在独立环境执行并回传结果（类比 cangjie「AI 不跑 cjpm build」）。
- **二次开发底座优先（铁律 14）**：原生 64 IPC 通道只增不改不删；业务页一律走上游成品 iframe，禁止在 `src/views/**` 新建技能/智能体/通道/任务业务 `.vue`（design §1.2 / spec §1.4.3）。
- **大工程拆分态（铁律 15）**：每条任务标注「本子系统负责」与「不碰（移交/调用上游）」；跨子系统改动成对成条；契约先行（C-023）。
- **复用原则（铁律 9）**：集成路由注册表复用 `config:*` 键值（design §4.1），**本子系统不新增表、不新增 DDL、不触发 `permissions`+`role_has_permission` 新登记**（S6 不新增后端路由，无 403 风险；iframe 内页权限归上游 S1/S3/S5 经 C-024）。
- **边界**：S6 只做「打通 / 集成 / 桥」；上游成品页、后端契约（C-001~C-005、G6、C-019~C-020）一律调用不重写；不直连 runtime 业务端点（spec §3.2）。

## 任务总览

| 编号 | 任务 | 关联 spec § | 关联 design § | 负责子 agent | 状态 | 预计产出 |
|---|---|---|---|---|---|---|
| T-01 | 集成路由注册表（config 键 schema + 种子值） | §6.1 | §4.1 / §5.2.2 | web-coder | 待开始 | `config:set('desktop.integration.routes')` 种子 + 读取逻辑 |
| T-02 | 原生/iframe 互斥路由解析器 | §1.4 / §5.1.1 | §3.5 / §2.2.3 | web-coder | 待开始 | `resolveIntegrationRoute()` 函数 |
| T-03 | 新增 iframe 深度集成容器 `IframeIntegView.vue` | §2.2 / §5.1 | §3.2 | web-coder | 待开始 | 新 Vue 组件（保留侧边栏） |
| T-04 | 集成页就绪态 + 上游未 done 占位态 | §5.1.1-3 / §5.4.1-4 | §3.5 / §2.2.2 | web-coder | 待开始 | 占位组件 + 路由降级逻辑 |
| T-05 | 处置 A7 假实现（skills 三通道） | §5.2.1-2 / §7-T2 | §3.2 | web-coder | 待开始 | 移除/改桥接 `skills:list/getDetail/install` |
| T-06 | 处置 A8 智能体死页面 → iframe 集成 | §5.2 / A8 | §3.2 | web-coder | 待开始 | `AgentsView.vue` 改造 |
| T-07 | 强化 C-023 桥：origin 精确白名单 + version 校验 | §4.3-4 / §4.4-2 / §5.3 | §3.3 | web-coder | 待开始 | `HomeView`/`App` 消息处理加固 |
| T-08 | safeStorage 令牌持久化接线（W3 归口） | §5.3 / §6.2 / W3 | §3.4 / §7.3 | web-coder | 待开始 | 桥 → `auth:save/get/clearToken` 接线 |
| T-09 | 登出同步（清密文+内存+推送） | §5.3.1-4 | §3.4 / §7.3-5 | web-coder | 待开始 | 登出事件处理 |
| T-10 | 令牌日志脱敏 + 伪造来源安全告警 | §4.3-3 / §4.4-1 | §7.3-6 | web-coder | 待开始 | 主进程日志脱敏 + 告警 |
| T-11 | 设置页「模型通道管理」入口 → S3 集成页 | §5.4 | §2.2.2 / §3.2 | web-coder | 待开始 | `SettingsView` 入口 + 单条配置兼容 |
| T-12 | 多通道不走原生核查（R7/G6） | §5.4.1-3 | §2.2.1 / §3.1 | web-coder | 待开始 | 核查无 `channel:*` 新增、无本地多通道表 |
| T-13 | 原生运维面联调（Runtime/PG/WebAdmin/更新/自启/托盘） | §1.4.1 / §4.5 | §3.1 | web-coder | 待开始 | 联调报告（不重写） |
| T-14 | NSIS 打包 / electron-builder + 更新通道验证 | §4.5 / §7-T4 | §9 | 人工 | 待开始 | 打包配置 + 人工打包回传 |
| T-15 | L1/L2/L3 验收与跨边界冒烟用例 | §5 / L1+L2+L3 | §8 / 全文 | sdd-tester | 待开始 | 测试计划 + 冒烟清单 |
| T-16 | 收敛 §7 待确认项 T1–T7 并回写 SPECS_INDEX | §7 | 全文附录 | 主 agent | 待开始 | 契约冻结 + 索引 §6 登记更新 |

> **DDL / 权限登记说明**：本子系统复用 `config:*` 与既有凭据文件（design §4.2），**无新表、无 `sql/incremental/` 产出、无 `permissions`+`role_has_permission` 新登记**。R6（403 风险）因不新增后端路由而**不触发**；上游 iframe 页的菜单/权限登记属 S1/S3/S5 任务（移交）。

## 任务依赖关系图
```
T-01 → T-02 → T-03 → T-04 → T-13
                │
T-05 ───────────┤（A7 假实现处置，依赖 S1 done）
T-06 ───────────┤（A8 死页改造，依赖 S1 done）
T-07 → T-08 → T-09 → T-10   （C-023 桥链路）
T-11 → T-12                （G6 多通道，依赖 S3 done）
T-13 / T-03 / T-04 / T-05 / T-06 / T-11  ──┐（均依赖 S1/S3/S5 done）
                                           ↓
                                        T-14（打包，人工）
                                           ↓
                                        T-15（L1/L2/L3 验收）
                                           ↓
                                        T-16（收敛待确认项 + 回写索引）
```
- **硬前提**：S1 / S3 / S5 均 `done` 后，T-03/04/05/06/11 才可进 code（design §1.1 / spec §1.2）。
- **可并行**：T-01~T-02（路由基础设施）与 T-07~T-10（桥链路）互不阻塞，可并行起步。

## 任务详细说明（按编号展开）

### T-01 集成路由注册表（config 键 schema + 种子值）
- **目标**：落地 design §4.1 的 `config:desktop.integration.routes` JSON 结构与种子，供 T-02 解析。
- **边界**：本子系统负责（写 config 键）；不碰 runtime 业务表。
- **步骤**：① 定义 JSON schema（routeKey/upstreamId/iframePath/readinessState/requiredContract/sidebarVisible）；② 种子 4 条 iframe 集成项（技能→S1、智能体→S1、通道→S3、运维→S5），`readinessState` 初值 `pending`；③ 提供读取封装 `getIntegrationRoutes()`。
- **产出**：`src/` 内路由注册表模块 + `config:set` 种子脚本（一次性）。
- **验收**：`config:get('desktop.integration.routes')` 返回 4 条且字段合法；`iframePath` 以 `/` 开头不含主机。
- **风险**：`iframePath` 精确值依赖 C-024 菜单路径（§7-T6），先填预估路径，T-16 回填。

### T-02 原生/iframe 互斥路由解析器
- **目标**：实现 `resolveIntegrationRoute(routeKey)`（design §3.5），落实 R7 互斥。
- **边界**：本子系统负责。
- **步骤**：① 读注册表；② 未登记 → `native`；③ `pending` → `placeholder`；④ 调 C-011 查上游 `current_stage`，非 `done` → `placeholder`，否则 `iframe`(带 port)。
- **产出**：解析函数 + 单测（port 取自 `webadmin:status`）。
- **验收**：技能页在 S1 done 后解析为 iframe URL；Runtime/PG 等原生页解析为 native；未 done 上游 → 占位。

### T-03 新增 iframe 深度集成容器 `IframeIntegView.vue`
- **目标**：spec §5.1「保留侧边栏的深度集成页」。
- **边界**：本子系统负责（web-coder）；**禁止**在其中写业务表单/表格（design §3.2）。
- **步骤**：① 新建组件，挂载 `AppSidebar` 常驻；② 复用 `HomeView.vue:14` `MAX_LOAD_ATTEMPTS=5` 重试 + `:33-38` `onIframeError`；③ port 取 `webadmin:status` 非硬编码 3031；④ 实例复用不销毁（≤3）。
- **产出**：`src/views/integ/IframeIntegView.vue` + 路由注册。
- **验收**：集成页可见时 8 导航项可点；iframe 切走保活；首屏 ≤3s；重试失败给手动重试。

### T-04 集成页就绪态 + 上游未 done 占位态
- **目标**：spec §5.1.1-3 / §5.4.1-4 降级。
- **边界**：本子系统负责。
- **步骤**：① `placeholder` 渲染「上游未就绪」并标注依赖对象；② S3 未 done → 通道入口禁用 + 提示。
- **产出**：占位组件 + 入口禁用逻辑。
- **验收**：S1 未完成 → 技能集成页占位标注「等待 S1 完成」；S3 未完成 → 通道入口禁用。

### T-05 处置 A7 假实现（skills 三通道）
- **目标**：spec §5.2.1-2（消除 `data:[]` 与 `Not implemented`）。
- **边界**：本子系统负责（清假实现）；不碰 S1 后端契约 C-001/C-002（移交上游）。
- **步骤**：① `index.ts:583-585` `skills:list` 硬编码空数组 → 改为桥接或移除，使技能集成页走 iframe（S1 真值）；② `skills:getDetail`/`skills:install` `Not implemented` → 同样处置为桥接/移除。
- **产出**：IPC 处理改造（不保留假成功）。
- **验收**：检索 `Not implemented` 与 `data:[]` 假实现为零或仅存明确桥接通道；Web 已装 1 技能 → 桌面集成页同账号展示（L2 用例 2）。

### T-06 处置 A8 智能体死页面 → iframe 集成
- **目标**：spec §5.2（消除 `AgentsView.vue:4` 恒 `[]`）。
- **边界**：本子系统负责；不碰 Agent 数据接口（移交 S1/S2）。
- **步骤**：① `AgentsView.vue` 改为 iframe 集成容器（复用 T-03 容器或同构）；② 移除死 `const agents = ref([])`。
- **产出**：改造后的 `AgentsView.vue`（iframe 集成）。
- **验收**：服务端存在 1 Agent → 桌面集成页展示非死状态；代码审查无新增业务表格。

### T-07 强化 C-023 桥：origin 精确白名单 + version 校验
- **目标**：spec §4.3-4 / §4.4-2 / §5.3。
- **边界**：本子系统负责（前端消息处理）。
- **步骤**：① `HomeView.vue:41-42` 前缀匹配改为精确 origin（取 `webadmin:status` 端口比对）；② 消息加 `version` 校验，不一致降级「仅渲染不交换 token」+ 告警；③ 校验顺序 origin→version→type/payload，未过丢弃+告警。
- **产出**：消息处理加固（复用 `src/views/HomeView.vue:40-49` 处）。
- **验收**：伪造非白名单 origin 的 `auth:loginStateChanged` → 无 token 写入 + 安全告警日志；version 不一致 → 不交换 token。

### T-08 safeStorage 令牌持久化接线（W3 归口）
- **目标**：spec §5.3 / §6.2 / W3（PC 端 safeStorage 一致性）。
- **边界**：本子系统负责（桥→`auth:save/get/clearToken` 接线）；**不碰** web-admin 登录页 `rememberPassword` 改造（移交上游，S6 只定义 C-023 契约）。
- **步骤**：① `postMessage(auth:loginStateChanged)` → 校验后 `electronAPI.auth.saveToken`（主进程 `auth-bridge.ts:75-101`）；② `safeStorage` 不可用 → 仅内存，重启重登，禁止明文；③ 桌面→iframe 经 `auth:token` 注入。
- **产出**：桥落盘接线 + 注入逻辑。
- **验收**：iframe 登录成功 → 凭据文件为 safeStorage 密文；重启仍为登录态；模拟加密不可用 → 磁盘无明文且重启未登录。

### T-09 登出同步（清密文+内存+推送）
- **目标**：spec §5.3.1-4。
- **边界**：本子系统负责。
- **步骤**：① 收到登出事件 → 清磁盘密文 + 内存态；② 推送 `auth:loginStateChanged` 令所有集成页回未登录；③ 托盘状态同步。
- **产出**：登出处理。
- **验收**：iframe 内登出 → 集成页刷新显示登录引导，托盘同步未登录。

### T-10 令牌日志脱敏 + 伪造来源安全告警
- **目标**：spec §4.3-3 / §4.4-1。
- **边界**：本子系统负责。
- **步骤**：① 全链路 iframe 加载/重试/降级日志统一 `key=value`（origin/端口/次数/原因）；② token 永不入日志；③ 伪造来源记录含 origin 的安全告警。
- **产出**：日志脱敏 + 告警逻辑。
- **验收**：日志 grep 无 token；伪造来源告警可追溯。

### T-11 设置页「模型通道管理」入口 → S3 集成页
- **目标**：spec §5.4（G6 入口）。
- **边界**：本子系统负责（入口+单条配置兼容）；多通道后端（S3）不碰（移交）。
- **步骤**：① `SettingsView.vue` 增加「模型通道管理」入口跳 S3 集成页；② 保留现有 `provider/apiKey/baseUrl/model` 四项 + 6 预设读写（`:59-74`）；③ S3 设默认 → 设置页无冲突值。
- **产出**：设置页入口 + 兼容逻辑。
- **验收**：入口点击渲染 S3 集成页；单条配置保存后 `config:get('ai')` 结构不变。

### T-12 多通道不走原生核查（R7/G6）
- **目标**：spec §5.4.1-3 明确「多通道必须 iframe」。
- **边界**：本子系统负责（核查+约束）。
- **步骤**：① 代码核查 `electron/main/index.ts` 无 `channel:*` 新增；② 确认无本地多通道表（本子系统按 design §4.2 零新增表）；③ 多通道数据仅存 iframe 上下文。
- **产出**：核查报告 + 约束说明。
- **验收**：主进程无 `channel:*` 注册；多通道列表仅见于 iframe。

### T-13 原生运维面联调（不重写）
- **目标**：spec §1.4.1 / §4.5，确认混合模式不破坏原生面。
- **边界**：本子系统负责（仅联调，不新增/不改 IPC）。
- **步骤**：① Runtime/PG/WebAdmin/更新/自启/托盘在混合模式下逐一联调；② 三个 `*:stateChanged` 推送 UI 反映 ≤2s（spec §4.2-2）。
- **产出**：联调报告。
- **验收**：原生 4 页 + Tray 行为不变；状态推送实时。

### T-14 NSIS 打包 / electron-builder + 更新通道验证
- **目标**：design §9，spec §4.5。
- **边界**：**人工执行打包/构建**；AI 不跑 `electron-vite build` / NSIS（项目约定）。web-coder 仅产出源码与打包配置。
- **步骤**：① 维护 electron-builder + NSIS 配置；② `updater:*` 更新通道验证；③ Windows 优先，macOS/Linux 待 §7-T4 确认。
- **产出**：打包配置 + 人工回传的安装包。
- **验收**：Windows 安装包可装可更新；非 Windows 标注待确认。

### T-15 L1/L2/L3 验收与跨边界冒烟用例
- **目标**：验收档位 L1+L2+L3（SPECS_INDEX §5）。
- **边界**：sdd-tester 派生；跨边界用例依赖已 done 上游。
- **步骤**：① L1 自测 spec 每条 EARS；② L2 与 S1/S3/S5 done 合并态跑 ≥3 主干 + 1 异常（含跨 S1→S6 用例 2、异常权限/上游超时）；③ L3 端到端（SPECS_INDEX §5.1 用例 1/5）。
- **产出**：测试计划 + 冒烟清单 + `test-report.md`（用户另要求不建 test-report 时以 tasks 验收清单代）。
- **验收**：L2 全绿（硬档位，只跑 L1 不许报 done）。

### T-16 收敛 §7 待确认项 T1–T7 并回写 SPECS_INDEX
- **目标**：spec §7；design 附录。
- **边界**：主 agent 协调；部分待用户/上游（T1 契约口径、T4 平台、T6 路径、T7 远程）。
- **步骤**：① T1 C-023 消息名与现网统一 → 冻结 contract；② T2 skills 三通道处置与 S1 确认；③ T3 「8 接口/1 表」按 design 结论（0 新增表）回写索引 §6；④ T4/T5/T6/T7 记录结论或待确认标注；⑤ 更新 `SPECS_INDEX.md` §6 变更影响面。
- **产出**：契约冻结记录 + 索引登记更新。
- **验收**：索引 §6 反映「S6 复用优先 0 新增表」；待确认项均有去向。

## 需求覆盖追踪矩阵

| spec 需求条目 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §1.4.1 必须原生（R7 一半） | T-12 / T-13 | 全覆盖 | 互斥清单 design §2.2.1 |
| §1.4.2 必须 iframe（R7 一半） | T-03 / T-04 / T-06 / T-11 | 全覆盖 | 互斥清单 design §2.2.2 |
| §1.4.3 明确不做 | T-03 / T-05 / T-12 | 全覆盖 | 代码审查约束 |
| §5.1.1 原生/集成分区 + 侧边栏保留 | T-02 / T-03 | 全覆盖 | |
| §5.1.2 交互流程 | T-03 / T-07 | 全覆盖 | |
| §5.1.3 异常（web-admin 未启动 / iframe 失败） | T-03 / T-04 | 全覆盖 | 复用 5 次重试 |
| §5.2.1 技能/智能体真值 + 假实现清除 | T-05 / T-06 | 全覆盖 | A7 / A8 |
| §5.2.2 交互流程 | T-05 / T-06 / T-08 | 全覆盖 | |
| §5.2.3 异常（未登录 / runtime 未启动） | T-08 / T-04 | 全覆盖 | |
| §5.3.1 令牌桥业务规则（R7 相关/W3） | T-07 / T-08 / T-09 | 全覆盖 | C-023 + W3 |
| §5.3.2 交互流程 | T-07 / T-08 | 全覆盖 | |
| §5.3.3 异常（伪造来源/空token/401） | T-07 / T-08 / T-10 | 全覆盖 | |
| §5.4.1 多通道入口 + 单条兼容 + 不走原生 | T-11 / T-12 | 全覆盖 | G6 |
| §5.4.2 交互流程 | T-11 | 全覆盖 | |
| §5.4.3 异常（S3 未就绪 / 单条保存失败） | T-04 / T-11 | 全覆盖 | |
| §4.1 性能 | T-03 / T-13 / T-15 | 全覆盖 | L1 验证 |
| §4.2 可靠性 | T-03 / T-08 / T-13 | 全覆盖 | 重试/解密失败 |
| §4.3 安全性 | T-07 / T-08 / T-10 | 全覆盖 | origin/加密/隔离 |
| §4.4 可维护性 | T-10 / T-01 | 全覆盖 | 日志/version |
| §4.5 兼容性（IPC 不改 / 上游未 done 降级 / 端口跟随） | T-12 / T-04 / T-03 | 全覆盖 | |
| §6.1 集成路由条目 | T-01 / T-02 | 全覆盖 | 复用 config |
| §6.2 令牌凭据 | T-08 / T-09 / T-10 | 全覆盖 | safeStorage |
| §6.3 原生运维状态快照 | T-13 | 全覆盖 | |
| R7 桌面端双份实现（SPECS_INDEX §7） | T-02 / T-03 / T-12 | 全覆盖 | 互斥清单落地 |
| W3 登录态持久化 safeStorage 归口（SPECS_INDEX §7/R10） | T-08（契约定义）/ 移交上游（web-admin 改造） | 全覆盖 | S6 定义契约，rememberPassword 改造移交 |
| §7 待确认项 T1–T7 | T-16（含等待用户/上游） | 部分 | 部分待确认，T-16 收敛 |
| 规模 8 接口 / 1 表 | T-01 / T-16 | 全覆盖 | design 论证 0 新增表，8 接口 = C-023 4 + 复用 4 |

## 验收检查清单（终验）
- [ ] 全部 spec 功能需求有对应实现并通过其 EARS 验收条件（见覆盖矩阵）
- [ ] DFX 约束（性能/可靠/安全/可维护/兼容）已验证或标注豁免（§4 全约束覆盖）
- [ ] 复用项未被重新实现（64 IPC 不改、config 复用、凭据文件复用）
- [ ] **无新增业务表 / 无新 DDL / 无新增 permissions 登记**（铁律 9 / R6 不触发）
- [ ] R7 互斥清单落地：原生 4 页 + iframe 4 集成页，无双份实现
- [ ] W3：PC 端 safeStorage 令牌持久化落地，无明文兜底；web-admin rememberPassword 改造已移交上游
- [ ] 编译 / 类型检查 / lint / NSIS 打包通过（**人工确认**，AI 不跑）
- [ ] 跨边界冒烟 ≥3 主干 + 1 异常（L2 硬档位）通过
- [ ] spec / design / tasks 三份文档与最终实现一致（无漂移）
- [ ] §7 待确认项 T1–T7 在 T-16 有去向或待确认标注

## 修订记录 / 多轮迭代
- 2026-10-30 | v1.0 | 初始生成（gate-spec 后 design 步产出） | 新增 `tasks.md`：16 任务 + 覆盖矩阵 + 验收清单 | 待 gate-task 确认
