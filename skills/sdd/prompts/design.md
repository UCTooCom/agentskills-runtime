# 技术设计步执行提示词（step: design）

> 子 agent：`sdd-design-writer`（`../agents/sdd-design-writer.md`）
> 模板：`../templates/design_template.md` + `../templates/design-principles.md`

## 这一步做什么

把"做什么"转化为"怎么做"。核心是**先盘存量再设计**。

## 执行步骤

1. 派生子 agent `sdd-design-writer`，传入：`spec_md_path` / `feature_name` / `template_path` / `output_dir`。
2. 产出 `design.md`，采用 10 节通用设计模板 + **两段式首章**：
   - 一、需求与存量功能关系分析（已实现 / 需扩展 / 需新增 三张对比表 + 存量详细分析）
   - 二、增量设计方案（实现模型 / 接口设计 / 数据模型 / 进度可观测 / 人在回路 / 防回退约束）
   - 其后：性能 / 可靠性 / 安全 / 可维护 / 兼容、部署运维、风险对策、附录（引用的真实实现文件）
3. 回传经契约校验（两段首章齐全 + 无占位符）；不过 → 重派 1 次 → 仍不过转 `gate-design`。
4. 落 `long_running_task_artifact`（`stage=design`）+ 派单留痕。
5. 触发 `gate-design` 闸口。

## 硬约束

- **任何"新建"决策前必须先回答能否复用**，并给出复用度（100% / 部分 / 不适用）。
- **引用真实实现**：接口 / 表结构 / 配置项必须来自实际代码或文档并标注 `文件:行号`，**禁止**理想化编造 schema。
- 文末**必须**列防回退约束（"禁止复现的问题 + 判据"），供任务与联调核对。
- 库表变更须符合 `spec.md §6.7` 限量（新增表 ≤2、既有表新增列 ≤2），扩展信息优先塞 JSON 字段。

## 回传

`design_md_path` + `reuse_ratio`（可选）。
