# 测试验收步执行提示词（step: test）

> 子 agent：`sdd-tester`（`../agents/sdd-tester.md`）
> 模板：`../templates/test-report-template.md`

## 这一步做什么

对照 `spec.md` / `design.md` / `tasks.md` 核查产出物的**一致性、完成度、缺陷**，给出完善意见与验收结论。

## 执行步骤

1. 派生子 agent `sdd-tester`，传入：三份文档路径 / `feature_name` / `template_path` / `output_dir`。
2. 产出 `test-report.md`（十节）：文档信息 → 测试概述 → 测试依据 → 环境与工具 → 执行结果 → 一致性核查 → 完成度 → 缺陷清单（P0/P1/P2）→ 完善意见 → 验收结论。
3. 回传经契约校验（十节齐全 + 无占位符）；不过 → 重派 1 次 → 仍不过挂人工。
4. 落 `long_running_task_artifact`（`stage=test`）+ 派单留痕。
5. 末步不挂闸口——报告本身即验收依据；进入 `output-result` 聚合。

## 硬约束

- **以文档为准绳，不以自我陈述为准绳**：判断"是否完成"依据 spec 的 REQ 与验收条件，不是开发方说完成了。
- **承诺与实际对齐核查**：逐条核对需求覆盖矩阵的 REQ 是否**真正落地**（文件存在 + 内容相符），明确指出"承诺了但没落地"的项。
- **缺陷分级**：P0（阻断，必须修）/ P1（严重，应修）/ P2（一般，可后续修），每条给位置与判据。
- **不粉饰**：结论为"不通过"时直说并列出阻断项。
- 未覆盖需求必须在缺陷或完善意见中**归因**。

## 回传

`test_report_md_path` + `defect_count` + `verdict`（`pass` / `conditional` / `fail`）。
