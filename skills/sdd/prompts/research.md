# 研究步执行提示词（step: research）

> 子 agent：`sdd-researcher`（`../agents/sdd-researcher.md`）
> 模板：`../templates/research-template.md`
> 触发条件：`enable_research = true`（COMPOSITION 的 `condition: "${input.enable_research}"`）

## 这一步做什么

在写需求之前做一轮开放性技术调研，回答三件事：**现在有什么**、**缺什么**、**推荐怎么走**。

## 执行步骤

1. 确认 `feature_name` 与输出目录 `specs/<feature_name>/`（runtime 自有，**禁止** `.codeartsdoer/specs/`）。
2. 派生子 agent `sdd-researcher`，传入：`task_description` / `feature_name` / `template_path` / `output_dir`。
3. 子 agent 调研并产出 `research.md`（八节骨架，见模板）。
4. 回传结果经**契约校验**（`capabilities.output_contract.required_sections` 八节齐全 + 无占位符残留）。
   - 不过 → 携 `verify_errors` 自动重派 **1 次**；仍不过 → 转 `gate-research` 人工闸口。
5. 文档落 `long_running_task_artifact`（`stage=research` / `usage=deliverable`）。
6. 派单留痕写 `sub_agent_invocations`（含 token / duration / 校验结果 / attempt）。

## 硬约束

- **研究步可跳过**：入口 `enable_research=false` 时整步不执行，下一步 `spec` 自动前移。
- **不得挂"文件是否存在"条件**：那样首轮恒跳过。
- **确定性优先**：结论必须有依据（文件:行号 / 文档原文 / 实测输出），查不到写"缺口"请人工确认，**禁止**猜。
- **子 agent 必须真派生**：缺失立即失败并提示，**禁止**主 agent 自扮演。

## 回传

`research_md_path` + `finding_count`。文档完整落盘后再回传。
