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
- **需求双向覆盖**：矩阵必须覆盖 spec 中**每一条 REQ**，不允许有未被任何任务覆盖的需求。
- **每个任务四项齐全**：目标 / 步骤 / 产出物 / 验收；禁止"完成开发"这类不可验收描述。
- **人工动作显式标注【人工】**：编译（`cjpm build`）、数据库脚本执行、部署一律归人工。
- **每条编码任务带语言标签**：`cangjie` / `web` / `app`。

## 回传

`tasks_md_path` + `task_count`。
