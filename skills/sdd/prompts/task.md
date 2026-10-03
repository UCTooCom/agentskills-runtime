# 任务规划步执行提示词（step: task）

> 子 agent：`sdd-task-planner`（`../agents/sdd-task-planner.md`）
> 模板：`../templates/tasks-template.md`

## 这一步做什么

把设计文档拆解为**可执行、可独立验收**的任务清单。

## 执行步骤

1. 派生子 agent `sdd-task-planner`，传入：`spec_md_path` / `design_md_path` / `feature_name` / `template_path` / `output_dir`。
2. 产出 `tasks.md`：文档信息 → **开发规范（置顶）** → 任务总览 → 依赖图 → 任务详细说明 → 需求覆盖追踪矩阵 → 验收清单 → 修订记录。
3. 回传经契约校验（六节齐全 + 无占位符）；不过 → 重派 1 次 → 仍不过转 `gate-task`。
4. 落 `long_running_task_artifact`（`stage=task`）+ 派单留痕。
5. 触发 `gate-task` 闸口。

## 硬约束

- **开发规范必须置顶**：骨架来源、语言与工具绑定、复用原则、命名/注释约定、各类红线，一次性说清。
- **二次开发底座优先（置顶必写）**：任务落到 runtime / uctoo 内的，"开发规范"段必须一次性写清
  ① 规范源 = `uctoo-dev-manual`（`skills/uctoo-dev-manual/`）+ `docs/uctoo-v4/*.md`；
  ② 脚手架优先 `loaddbinfo` → `plugingen` / `crudgen` / `crudweb` 确定性工具链生成，禁止手撸五层骨架；
  ③ 生成后补 RBAC 登记与 `sql/incremental/` 增量脚本。对应编码步 `prompts/code.md「二次开发底座优先」`。
- **工具链任务显式成条**：凡新增表、新增 CRUD 模块、新增管理界面、新增插件，各拆一条自带
  「跑哪个工具、跑完再改哪些文件」的任务，不许揉进一条笼统的"实现 XX 功能"。
- **大工程已在拆分态时（铁律 15）**：
  - 开工前先读主工程 `specs/{主}/SPECS_INDEX.md`：确认本子系统 ID、`feature_name = {主}--{子系统ID}`、
    契约摘要、上游依赖、L2 验收归属；**不读就拆任务 = 越界开工**。
  - 任务描述里显式标 `子系统边界`：本子系统负责什么、**不碰什么**（跨子系统的一律写进"移交/调用上游"动作，
    不许写成"顺手也改一下 X 模块"）。
  - 跨子系统接口改动拆成**两条独立任务**（提供方侧 + 消费方侧），同轮完成；只派一条判覆盖不全。
  - 本子系统 tasks.md 的验收清单必须含**一组跨边界冒烟**（≥ 3 条主干 + 1 条异常），归属 L2 档位。
  - 契约版本变化（minor / major）在本任务里写明契约条目编号，便于 test 步归因。
- **需求双向覆盖**：矩阵必须覆盖 spec 中**每一条 REQ**，不允许有未被任何任务覆盖的需求。
- **每个任务四项齐全**：目标 / 步骤 / 产出物 / 验收；禁止"完成开发"这类不可验收描述。
- **人工动作显式标注【人工】**：编译（`cjpm build`）、数据库脚本执行、部署一律归人工。
- **每条编码任务带语言标签**：`cangjie` / `web` / `app`。

## 回传

`tasks_md_path` + `task_count`。
