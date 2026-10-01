# 需求规格步执行提示词（step: spec）

> 子 agent：`sdd-spec-writer`（`../agents/sdd-spec-writer.md`）
> 模板：`../templates/spec_template.md` + `../templates/ears-format.md`

## 这一步做什么

把任务描述（及可选的研究文档）转化为**"做什么"**的规格。只写 WHAT，**不写 HOW**。

## 执行步骤

1. 派生子 agent `sdd-spec-writer`，传入：`task_description` / `feature_name` / `research_md_path`（可空）/ `template_path` / `output_dir`。
2. 子 agent 按 6 节组件定位模板产出 `spec.md`：
   1. 组件定位（职责/输入/输出/边界）  2. 领域术语  3. 角色与边界  4. DFX 约束
   5. 核心能力（逐条 REQ + EARS 验收 + 时序图 + 异常场景）  6. 数据约束
3. 回传经契约校验（六节齐全 + 无 `TODO`/`待补充` 残留 + 满足 `min_chars`）；不过 → 重派 1 次 → 仍不过转 `gate-spec`。
4. 落 `long_running_task_artifact`（`stage=spec` / `usage=deliverable`）+ 派单留痕。
5. 触发 `gate-spec` 闸口：confirm → 进设计；revise → 回退重做（round+1）；abandon → 终止。

## 硬约束

- 需求编号 `REQ-<FEATURE>-NNN`；每条需求**必须**用 EARS 写可验收条件。
- 涉及既有系统能力 / 表结构 / 接口契约时先查证（读代码 / 读库 / 读文档），**禁止**凭印象编造。
- 不写实现方案（属 design 步）。
- 落盘目录 runtime 自有 `specs/<feature_name>/`。

## 回传

`spec_md_path` + `acceptance_criteria_count`。
