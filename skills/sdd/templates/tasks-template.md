# 任务规划文档模板（tasks.md）

> 基于 `spec.md` 与 `design.md` 生成。实施原则：**复用优先**、**确定性优先**、**L3 进程隔离**（如适用）。
> 仓颉代码编写须使用 cangjie-coder 技能；**严禁运行 cjpm build**（编译与回传由人工在独立 cmd 环境完成）。
> 本模板由 `specs/*/tasks.md` 的 house style 反演而来（高频结构：开发规范 → 任务总览 → 任务依赖关系图 → 需求覆盖追踪 → 验收检查清单 → 多轮修订记录）。

## 文档信息
- 关联需求：`spec.md` 路径
- 关联设计：`design.md` 路径
- 生成日期 / 版本 / 状态（草稿/进行中/收口）

## 开发规范（全任务强制遵守）
- **语言与工具绑定**：仓颉 → cangjie-coder；前端（HTML/CSS/TS）→ web-coder / fullstack-codegen；原生 App（鸿蒙/安卓/iOS）→ app-coder。
- **二次开发底座优先（迭代 runtime / uctoo 时强制）**：
  1. **规范源**：先加载 `uctoo-dev-manual`（`skills/uctoo-dev-manual/`），按要做的事读对应 `docs/uctoo-v4/*.md`
     （接口→`uctoo-v4-api-specification`；表/字段→`uctoo-database-design-specification`；
     CRUD→`uctoo-v4-module-development` + `uctoo-v4-orm-specification`；中间件→`uctoo-v4-middleware-guide`；
     权限→`user-permission-system` / `row-level-permission-system`）。
  2. **脚手架优先确定性代码生成工具**，禁止手撸：
     `loaddbinfo`（灌表结构到 `db_info`）→ `plugingen`（**功能拓展优先做成插件**，默认 L3 进程隔离轨 process，
     需退回内嵌 sync 轨显式加 `--mode sync`）／`crudgen`（**仅**往宿主 `src/app/` 补公共基础设施）／
     `crudweb`（管理界面）；下线插件用对称的 `pluginuninstall`，不要手动删 `skills/{name}` 目录。
     命令一律 `cjpm run --skip-build --name <包名> --run-args "<参数>"`。
  3. **工具链坑位**：`loaddbinfo` 命令行模式有未修问题（见 `skills/uctoo-dev-manual/tools/loaddbinfo.md` 顶部 TODO），
     退到 Web 端「数据库管理 → 加载数据库信息」；crudgen 生成后编译报 `@DAO` 一堆错，看 `docs/uctoo-v4/crud-generator-v2.md`。
  4. **生成后必补**：新增表的 DDL 放 `sql/incremental/`（涨幅受 SDD 铁律 9 白名单额度约束）；
     新增宿主路由必做 `permissions` + `role_has_permission` 登记，否则 403。
  5. **只在生成物上做最小适配**，不要另起炉灶重写一遍生成出来的五层结构。
- **大工程拆分态（铁律 15，本工程是多子系统 SDD 工程之一时强制）**：
  1. **开工前先读主工程 `specs/{主}/SPECS_INDEX.md`**：确认本子系统 ID / `feature_name = {主}--{子系统ID}` /
     契约摘要 / 上游依赖 / 本次该跑到哪档验收（L1 / L2 / L3）。没读就拆任务视为越界开工。
  2. **边界写进任务**：每条任务标注「本子系统负责」与「不碰（移交/调用上游）」，
     跨子系统的一律落成"调用上游契约接口"或"等下游消费"的动作，不许写成"顺手也改一下 X 模块"。
  3. **跨子系统接口改动成对成条**：提供方侧 + 消费方侧各一条任务，同轮完成，只派一条判覆盖不全。
  4. **契约先行**：契约版本（minor / major）在任务里写明契约条目编号；major 必须双侧同轮。
  5. **验收带跨边界冒烟**：验收清单里必须有 ≥ 3 条跨子系统主干 + 1 条异常（权限不足 / 数据不存在 / 上游超时）。
  6. **禁止跨界手写**：不许直连其他私有表/私有目录；改动只落本子系统边界内，跨界先回 SPECS_INDEX §6 登记。
- **编译约束**：AI 不运行 `cjpm build`；编译、类型检查、lint 由人工执行并回传结果（与项目既有约定一致）。
- **复用原则**：优先复用 `design.md` 中"已实现功能/存量功能对比"清单所列基础设施，不重新实现已有能力。
- **命名/注释/错误处理**：遵循 `uctoo-dev-manual` 与 legacy `design-principles.md`（分层、RESTful、软删除、统一错误响应等）。
- **进度与日志**：遵循既有日志/进度通道约定；多轮修订须留痕。

## 任务总览
表格：**编号 | 任务 | 关联需求(spec §) | 关联设计(design §) | 负责子 agent | 状态 | 预计产出**

- 状态建议：`[ ]` 待开始 / 进行中 / 已完成 / 阻塞
- T-01 ……

## 任务依赖关系图
- 用 Mermaid / PlantUML / 缩进列表表达 DAG：哪些可并行、哪些须顺序、哪些互相阻塞。
- 示例：
  ```
  T-01 → T-02 → T-03
              ↘ T-04 → T-05
  ```

## 任务详细说明（按编号展开）
### T-01 [任务名]
- **目标**：对应哪条 spec 需求 / 哪段 design 方案
- **输入**：依赖的前置任务产出
- **步骤**：可执行的子步骤清单（编号）
- **产出物**：文件路径 / 数据库表 / 接口端点
- **验收**：对应 spec 验收条件 + 自检项
- **风险**：已知工程坑（引用 `design.md` 附录/约束清单）

## 需求覆盖追踪矩阵
表格：**spec 需求编号/条目 | 覆盖任务 | 覆盖状态(全覆盖/部分/未覆盖) | 备注**
- 目标：spec 每条功能需求与 DFX 约束都有任务承接，无遗漏、无游离任务。

## 验收检查清单（终验）
- [ ] 全部 spec 功能需求有对应实现并通过其验收条件
- [ ] DFX 约束（性能/可靠/安全/可维护/兼容）已验证或标注豁免
- [ ] 复用项未被重新实现（符合 `design.md` 存量对比结论）
- [ ] 编译 / 类型检查 / lint 通过（人工确认）
- [ ] spec / design / tasks 三份文档与最终实现一致（无漂移）

## 修订记录 / 多轮迭代
- 每轮修复/复核记录：**日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果**（仿 long-running-task/tasks.md 的多轮段，含 P0/P1/P2 问题表与防回归锚点）。

---

> 配套：本目录另提供 `test-report-template.md`（测试验收报告）与 `research-template.md`（研究文档）。
