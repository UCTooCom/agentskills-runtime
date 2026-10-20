# 任务规划：插件系统增强迭代（plugin-system-enhancement）

> 模板：`skills/sdd/templates/tasks-template.md`
> 关联需求：`specs/plugin-system-enhancement/spec.md`
> 关联设计：`specs/plugin-system-enhancement/design.md`
> 关联账本：`specs/plugin-system-enhancement/SPECS_INDEX.md`（唯一权威）
> 生成日期：2026-10-19 ｜ 版本 v1.0 ｜ 状态：草稿（待 gate-task 确认）
> **范围声明**：本文件只列**主工程的集成与编排类**任务。各子系统内部实现任务见各自 `tasks.md`（共 6 份，合计约 130 条）。

---

## 文档信息

- 关联需求：`spec.md`（跨子系统 REQ-EN-* + REQ-DFX-*）
- 关联设计：`design.md`（组合架构）
- 生成日期 / 版本 / 状态：2026-10-19 / v1.0 / 草稿

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：仓颉 → `cangjie-coder`；前端 → `web-coder` / `fullstack-codegen`；原生 App → `app-coder`。
- **二次开发底座优先（铁律 14）**：
  1. 规范源先加载 `uctoo-dev-manual`（`skills/uctoo-dev-manual/`），按要做的事读对应 `docs/uctoo-v4/*.md`
     （接口→`uctoo-v4-api-specification`；表/字段→`uctoo-database-design-specification`；
     CRUD→`uctoo-v4-module-development` + `uctoo-v4-orm-specification`；中间件→`uctoo-v4-middleware-guide`；
     权限→`user-permission-system` / `row-level-permission-system`）。
  2. 脚手架优先确定性工具：`loaddbinfo`（灌 `db_info`）→ `plugingen`（**功能拓展优先做成插件**，默认 process 轨，退回 sync 须显式 `--mode sync`）／`crudgen`（**仅**宿主 `src/app/` 公共基础设施）／`crudweb`（界面）；下线用 `pluginuninstall`，**禁止手删 `skills/{name}/`**。命令一律 `cjpm run --skip-build --name <包名> --run-args "<参数>"`。
  3. 坑位：`loaddbinfo` 命令行模式有未修问题（见 `skills/uctoo-dev-manual/tools/loaddbinfo.md` 顶部 TODO），退到 Web 端「数据库管理 → 加载数据库信息」；crudgen 生成后编译报 `@DAO` 一堆错，看 `docs/uctoo-v4/crud-generator-v2.md`。
  4. **生成后必补**：新增表/列 DDL 放 `sql/incremental/`（先论证复用不成立，铁律 9）；新增宿主路由必做 `permissions` + `role_has_permission` 登记，否则 403。
  5. 只在生成物上做最小适配，不推倒重写五层结构。
- **大工程拆分态（铁律 15，本工程强制）**：
  1. 开工前先读 `SPECS_INDEX.md`：确认子系统 ID / `feature_name = plugin-system-enhancement--{子系统ID}` / 契约摘要 / 上游依赖 / 该跑到哪档验收。没读就拆任务视为越界开工。
  2. 每条任务标注「本子系统负责」与「不碰（移交/调用上游）」；跨子系统一律落成"调用上游契约接口"或"等下游消费"。
  3. 跨子系统接口改动成对成条：提供方 + 消费方各一条，同轮完成。
  4. 契约先行：minor / major 写明契约条目编号；major 必须双侧同轮。
  5. 验收带跨边界冒烟：≥ 3 条跨子系统主干 + 1 条异常。
  6. 禁止跨界手写：不许直连其他私有表/目录；跨界先回 `SPECS_INDEX` §6 登记。
- **编译约束**：AI **不运行 `cjpm build`**；编译 / 类型检查 / lint 由人工在独立 cmd 执行并回传结果。
- **复用优先（铁律 9）**：优先复用 `research.md` §二 与 `design.md` §3.3 所列既有基础设施，不重新实现已有能力。
- **命名/注释/错误处理**：遵循 `uctoo-dev-manual` 与 `design-principles.md`（分层、RESTful、软删除、统一错误响应）。

---

## 任务总览

| 编号 | 任务 | 关联需求 | 关联设计 | 负责 | 状态 | 预计产出 |
|---|---|---|---|---|---|---|
| T-01 | 契约冻结评审（IF-01~IF-12）与 SPECS_INDEX 基线确认 | REQ-DFX-M3 | design §3.1 | 主工程 | [ ] | SPECS_INDEX §3 状态转「已冻结」 |
| T-02 | 建立共享文件串行约定与 CR 复核机制 | REQ-DFX-M3 | design §3.1 串行表 | 主工程 | [ ] | 串行约定登记 + 复核清单 |
| T-03 | 推进 version-guard 六步至 done | REQ-EN-001~005 | design §2.2 | version-guard | [ ] | 子系统四件套 + L1/L2 报告 |
| T-04 | 推进 capability-governance 六步至 done | REQ-EN-010~015 | design §3.3 | capability-governance | [ ] | 子系统四件套 + L1/L2 报告 |
| T-05 | 推进 capability-handshake 六步至 done（依赖 T-03/T-04） | REQ-EN-020~023 | design §3.2 | capability-handshake | [ ] | 子系统四件套 + L1/L2 报告 |
| T-06 | 推进 dependency-graph 六步至 done（可并行） | REQ-EN-030~033 | design §2.2 | dependency-graph | [ ] | 子系统四件套 + L1/L2 报告 |
| T-07 | 推进 lifecycle-observability 六步至 done（可并行） | REQ-EN-040~043 | design §2.2 | lifecycle-observability | [ ] | 子系统四件套 + L1/L2 报告 |
| T-08 | 推进 authoring-toolchain 六步至 done（依赖 T-04） | REQ-EN-050~052 | design §2.2 | authoring-toolchain | [ ] | 子系统四件套 + L1/L2 报告 |
| T-09 | `InitializeParams` 串行改造协调 | REQ-DFX-M3 | design §3.1 | 主工程 + T-03 + T-05 | [ ] | 串行落地，无合并冲突 |
| T-10 | 存量插件清单体检（51 skill + 4 sync） | REQ-EN-060/061 | spec §5.7 | 主工程 + T-08 | [ ] | 存量体检报告 |
| T-11 | 安全缺陷修复专项验收（env 白名单 + secret 授权） | REQ-EN-012/013、REQ-DFX-S3/S4 | design §6.2 | 主工程 + T-04 | [ ] | 安全验收记录 |
| T-12 | L2 跨子系统集成冒烟（≥3 主干 + 1 异常） | SPECS_INDEX §5 | design §3.2 | 主工程 | [ ] | L2 冒烟报告 |
| T-13 | L3 主工程端到端验收（5 条用例） | SPECS_INDEX §5.1 | design §2.3 | 主工程 | [ ] | L3 验收报告 |
| T-14 | 防回退锚点验证 | REQ-DFX-C1/C2 | spec §5.7 | 主工程 | [ ] | 回归对比记录 |
| T-15 | 权限与增量 DDL 收口 | 铁律 9/14 | design §4.2 | 主工程 | [ ] | `sql/incremental/` + 权限登记（若有） |
| T-16 | 文档一致性核查与归档 | 铁律 12 | design §10.1 | 主工程 | [ ] | 一致性核查记录 |

---

## 任务依赖关系图

```
T-01 ──► T-02 ──┬──► T-03 ──┬──► T-05
                 │           │
                 ├──► T-04 ──┼──► T-05
                 │           └──► T-08
                 ├──► T-06（并行，无上游）
                 └──► T-07（并行，无上游）

T-09 依赖 T-03 与 T-05（串行协调）
T-10 依赖 T-08
T-11 依赖 T-04
T-12 依赖 T-03~T-08 全部达 L1
T-13 依赖 T-12
T-14 依赖 T-13
T-15 依赖 T-04/T-07（若产生新列/新路由）
T-16 依赖全部
```

- **可并行**：T-06（dependency-graph）、T-07（lifecycle-observability）无上游，可与 T-03/T-04 并行开工。
- **须串行**：T-03 → T-05（`InitializeParams` 先 IF-04 后 IF-08）；T-04 → T-08（能力枚举先冻结）。
- **阻塞规则**：上游进 `code` 步前必须已达 `test`。

---

## 任务详细说明（按编号展开）

### T-01 契约冻结评审（IF-01~IF-12）
- **目标**：把 `SPECS_INDEX.md` §3 的 12 条契约从草案转为已冻结，作为全部实现的唯一权威。
- **输入**：`SPECS_INDEX.md`、`research.md`、6 份子系统 `contract.md`。
- **步骤**：
  1. 逐条核对 12 条契约的提供方/消费方/方向是否与子系统 `contract.md` §1 一致；
  2. 校验依赖 DAG 无回边（拓扑序编号递增）；
  3. 校验方向全部单向（出现双向即回 §4 重找边界）；
  4. 闸口 `gate-spec` 确认后，§3 状态置「已冻结」并在 §8 修订记录留痕。
- **产出物**：`SPECS_INDEX.md` §3 状态更新 + §8 修订记录。
- **验收**：12 条契约方向全部单向；无子系统对同一接口有冲突定义。
- **风险**：子系统间对 IF-05/IF-07 的取值域理解不一致 → 以 capability-governance 的 `contract.md` 为准。

### T-02 建立共享文件串行约定与 CR 复核机制
- **目标**：防止多子系统并行改同一文件造成合并冲突与契约漂移。
- **输入**：`design.md` §3.1 串行表。
- **步骤**：
  1. 登记共享文件清单（`message.cj`、`plugin_config.cj`、`cordis_host_manager.cj`）；
  2. 为每个共享文件指定唯一串行顺序与 owners；
  3. 约定 CR 复核点：任何对共享文件的改动必须回查 `SPECS_INDEX` §3 与 §6。
- **产出物**：串行约定登记（写入 `SPECS_INDEX` §6 变更影响面）。
- **验收**：`message.cj` 的改动顺序严格为 T-03 → T-05。
- **风险**：R-05。

### T-03 推进 version-guard 六步至 done
- **目标**：REQ-EN-001~005（P0 版本协商）。
- **输入**：`spec.md` §5.1、`design.md` §2.2、子系统四件套（已产出）。
- **步骤**：research → spec → design → task → code → test，每步挂闸口；上游无依赖，可立即开工。
- **产出物**：宿主 API 版本常量、清单版本字段、加载前校验、L3 协议版本字段、新增版本类错误码（`plugin_types.cj:56-63`）。
- **验收**：L1 自测通过；L2 与下游合并态通过；`dylib` 只预留不接线（R-01）。
- **风险**：存量清单无版本声明 → 必须向后兼容放行（REQ-DFX-C2）。

### T-04 推进 capability-governance 六步至 done
- **目标**：REQ-EN-010~015（能力清单 + 门禁 + env/secret 缺陷修复）。
- **输入**：`spec.md` §5.2、`design.md` §3.3、子系统四件套（已产出）。
- **步骤**：六步 + 闸口；**第一步必须先完成"复用 `src/security/` vs 新建"的论证与 fail-open 修复**。
- **产出物**：能力枚举、门禁接线、env 白名单、secret per-plugin 授权、跨进程禁列表（IF-07）。
- **验收**：REQ-DFX-S1~S5 全绿；`permission_service.cj:295-322` fail-open 已改为 fail-closed。
- **风险**：R-02（死代码未测过）、R-03（env 泄漏）。

### T-05 推进 capability-handshake 六步至 done
- **目标**：REQ-EN-020~023（P0 L3 能力宣告握手）。
- **输入**：IF-04（T-03 已冻结）、IF-05/07（T-04 已冻结）。
- **步骤**：六步 + 闸口；**必须等 T-03 完成 `InitializeParams` 的 IF-04 后再动 IF-08**。
- **产出物**：`declaredCapabilities` 字段、宣告比对器、失败插件不注册 HTTP 路由的修正（`plugin_host_manager.cj:143-155`）。
- **验收**：REQ-DFX-R2（被拒插件未拉起或已安全终止、无僵尸）；预检与握手复用同一张禁列表。
- **风险**：R-05（与 T-03 串行）。

### T-06 推进 dependency-graph 六步至 done（可并行）
- **目标**：REQ-EN-030~033（依赖拓扑 + 逆序停机）。
- **输入**：`spec.md` §5.4、子系统四件套（已产出）。
- **步骤**：六步 + 闸口；无上游依赖，可与 T-03/T-04 并行。
- **产出物**：依赖声明解析、拓扑排序、环检测、逆序停机。
- **验收**：REQ-DFX-C3（`order` 向后兼容）；复用 cordis 既有 `topoSort`，不另写一套。
- **风险**：R-04（存量加载顺序回归）。

### T-07 推进 lifecycle-observability 六步至 done（可并行）
- **目标**：REQ-EN-040~043（退避 / 计数 / 熔断 / crash-reason）。
- **输入**：`spec.md` §5.5、子系统四件套（已产出）。
- **步骤**：六步 + 闸口；无上游依赖，可并行。
- **产出物**：退避策略、重启计数、风暴熔断、结构化崩溃原因、`autoRestart` 真正消费、`inspectProcessPlugin` 对齐 docstring。
- **验收**：REQ-DFX-R4（启动即崩 N 次后熔断）；REQ-DFX-M1/M2。
- **风险**：R-06（倾向新建列）、R-07、R-08。

### T-08 推进 authoring-toolchain 六步至 done
- **目标**：REQ-EN-050~052（模板自带测试 + `plugin validate`）。
- **输入**：IF-05/06/07（T-04）、IF-02（T-03）。
- **步骤**：六步 + 闸口。
- **产出物**：`plugingen` 测试模板、`--validate` 子命令、上游规则收口文件。
- **验收**：新生成插件 → 自带测试通过 + `plugin validate` 全绿；破坏一项声明 → 报对应错。
- **风险**：不得自建能力枚举（REQ-EN-052）。

### T-09 `InitializeParams` 串行改造协调
- **目标**：落实 R-05 的串行约定。
- **步骤**：1. T-03 冻结 `protocolVersion`；2. CR 复核；3. T-05 追加 `declaredCapabilities`；4. 联合编译验证。
- **产出物**：`message.cj` 最终结构 + 双侧确认记录。
- **验收**：两个字段共存且各自语义独立；无覆盖冲突。
- **风险**：并行改动 → 契约漂移，按 P0 计。

### T-10 存量插件清单体检
- **目标**：REQ-EN-060/061，用 `plugin validate` 给存量 51 skill + 4 sync 插件做体检。
- **步骤**：1. 跑 validate 全量；2. 汇总"因新增校验会失败"的清单；3. 对每一项判定：是真实缺陷还是需向后兼容放行。
- **产出物**：存量体检报告（含逐项判定）。
- **验收**：**零存量插件因新增校验而被拒绝加载**（REQ-DFX-C1）；体检报告中"真实缺陷"项需给出修复或豁免结论。

### T-11 安全缺陷修复专项验收
- **目标**：REQ-EN-012/013、REQ-DFX-S3/S4。
- **步骤**：1. 验证插件进程环境不再含宿主敏感变量（如 `orm_connectionUrl`、LLM key）；2. 验证 `host.secret` 的 `env:NAME` 越权取值被拒；3. 验证 DENY 落审计。
- **产出物**：安全验收记录（含实测证据）。
- **验收**：三项全绿；无 fail-open 残留。

### T-12 L2 跨子系统集成冒烟
- **目标**：SPECS_INDEX §5 冒烟清单（≥3 主干 + 1 异常）。
- **步骤**：
  1. version-guard → capability-handshake：不兼容插件加载前被拒，L3 进程未被拉起；
  2. capability-governance → capability-handshake：声明与实际不符 → 拒绝挂载；
  3. capability-governance → authoring-toolchain：生成即 validate 全绿；破坏声明即报错；
  4. 异常：能力门禁拒绝时返回统一错误结构，插件进程不残留、无僵尸。
- **产出物**：L2 冒烟报告。
- **验收**：4 条全绿；任一子系统未跑 L2 不得报 done（硬闸）。

### T-13 L3 主工程端到端验收
- **目标**：SPECS_INDEX §5.1 五条用例。
- **步骤**：全量子系统在宿主上跑起，执行：全新插件全链路通过 → 改 `pluginApi` 被拒 → `kill -9` 触发熔断 → 依赖顺序正确 → **存量零回归**。
- **产出物**：L3 验收报告。
- **验收**：5 条全绿 + 权限/行级可见范围复核通过。

### T-14 防回退锚点验证
- **目标**：REQ-DFX-C1/C2 固化为可复跑的回归锚点。
- **步骤**：1. 记录增强前的存量加载基线（插件数、顺序、状态）；2. 增强后重跑并逐项比对；3. 差异为零方可收口。
- **产出物**：回归对比记录。
- **验收**：零差异；有差异必须归因到具体契约条目，禁止写"实现与文档略有出入"。

### T-15 权限与增量 DDL 收口
- **目标**：铁律 9/14 收口（若产生新列/新路由）。
- **步骤**：1. 复核是否真有新列/新路由（默认 0）；2. 若有，补 `sql/incremental/` 幂等 DDL；3. 补 `permissions` + `role_has_permission` 登记；4. 执行后 `loaddbinfo` 刷新。
- **产出物**：`sql/incremental/*.sql` + 权限登记 SQL（若无则写"确认 0 新增"结论）。
- **验收**：无 403；`db_info` 与实际结构一致。

### T-16 文档一致性核查与归档
- **目标**：铁律 12，确保 spec / design / tasks / 实现四者无漂移。
- **步骤**：1. 逐子系统核对 `contract.md` 接口编号与 `SPECS_INDEX` §3 一致；2. 核对需求覆盖追踪矩阵无游离需求/任务；3. 归档并在 §8 留痕。
- **产出物**：一致性核查记录 + `SPECS_INDEX` §8 修订记录。
- **验收**：无契约漂移；6 个子系统 status 全部 `done`。

---

## 需求覆盖追踪矩阵

| 需求编号 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| REQ-EN-001~005（版本协商） | T-03、T-09 | 全覆盖 | 子系统内部任务见其 `tasks.md` |
| REQ-EN-010~015（能力治理） | T-04、T-11 | 全覆盖 | 含 env/secret 缺陷 |
| REQ-EN-020~023（能力握手） | T-05、T-09 | 全覆盖 | 依赖 T-03/T-04 |
| REQ-EN-030~033（依赖编排） | T-06 | 全覆盖 | 可并行 |
| REQ-EN-040~043（崩溃自愈） | T-07 | 全覆盖 | 可并行 |
| REQ-EN-050~052（创作工具链） | T-08、T-10 | 全覆盖 | 依赖 T-04 |
| REQ-EN-060~061（防回退） | T-10、T-14 | 全覆盖 | 硬锚点 |
| REQ-DFX-P1~P3（性能） | T-03~T-08 | 全覆盖 | 各子系统 spec 内验收 |
| REQ-DFX-R1~R4（可靠） | T-05、T-07、T-12 | 全覆盖 | |
| REQ-DFX-S1~S5（安全） | T-04、T-11 | 全覆盖 | fail-closed 为 P0 |
| REQ-DFX-M1~M3（可维护） | T-02、T-07 | 全覆盖 | |
| REQ-DFX-C1~C3（兼容） | T-10、T-14 | 全覆盖 | 缺省放行策略 |
| 契约 IF-01~IF-12 | T-01、T-02、T-09 | 全覆盖 | |
| 铁律 9（复用优先） | T-04、T-15 | 全覆盖 | 0 新表 0 新列默认口径 |
| 铁律 14（底座优先） | T-08、T-15 | 全覆盖 | 脚手架走确定性工具 |
| 铁律 15（拆分/契约） | T-01、T-02、T-16 | 全覆盖 | |

---

## 验收检查清单（终验）

- [ ] 全部 spec 功能需求（REQ-EN-*）有对应实现并通过其验收条件
- [ ] DFX 约束（性能 / 可靠 / 安全 / 可维护 / 兼容）已验证或标注豁免
- [ ] 复用项未被重新实现（`src/security/`、`topoSort`、`healCrashed`、`PluginRegistry.restore`）
- [ ] 12 条契约方向单向无环，且与各子系统 `contract.md` 一致
- [ ] L2 跨子系统冒烟 ≥3 主干 + 1 异常，全绿
- [ ] L3 端到端 5 条用例全绿
- [ ] 存量 51 skill + 4 sync 插件零回归（T-14）
- [ ] env 白名单与 secret 授权修复验收通过（T-11）
- [ ] 0 新表 0 新列（若有新增，已补 `sql/incremental/` + 权限登记）
- [ ] 编译 / 类型检查 / lint 通过（**人工确认**，AI 不跑 `cjpm build`）
- [ ] spec / design / tasks 三份主文档与最终实现一致（无漂移）

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果 |
|---|---|---|---|---|
| 2026-10-19 | R1 | 基线侦察 + 报告 §9 | 新建 `SPECS_INDEX.md`、`research.md`、`spec.md`、`design.md`、`tasks.md` + 6 个子系统目录（各 4 份） | 25 份文档落盘；契约 IF-01~IF-12 草案冻结；未运行 `cjpm build` |

**防回退锚点**：
1. 存量插件加载零回归（REQ-DFX-C1）—— 每次变更后复跑 T-10/T-14。
2. 新增校验缺省向后兼容放行（REQ-DFX-C2）—— 禁止以"更严格"为由拒绝存量清单。
3. 能力门禁缺省全拒（REQ-DFX-S1）—— 禁止 fail-open；`permission_service.cj:295-322` 的修复不得回退。
