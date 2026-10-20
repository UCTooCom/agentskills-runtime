# Laya（System-1 决策引擎）× agentskills-runtime 集成研究

> 子目录：`apps/agentskills-runtime/.codeartsdoer/specs/laya-system1-integration/`
> 研究对象：`apps/laya`（Jev 类开源替代，Apache-2.0，本地/离线 System-1 决策引擎）
> 日期：2026-09-29

## 文档索引
- **`research.md`** — 研究报告：Jev 是什么、Laya 技术剖析、业界评测与案例、开源社区应用方案、Laya vs Jev 基准。
- **`spec.md`** — 应用建议方案：集成可行性、决策点映射（10 个）、三层接入架构、分阶段实施（Phase 0–3）、风险与差异化。
- **`appendix.md`** — 落地工件：`system1-decision` SKILL.md 模板、MCP 注册语义、Laya MCP 工具清单、基准对比、速查表。

## 一句话结论
agentskills-runtime（仓颉实现、全链路自主可控的 Agent 运行时）集成同为开源、可离线的 Laya System-1 决策引擎，可补上当前缺失的"快思考层"，构建"系统二慢思考 + 系统一快思考"双驱架构——既获 Jev 类模型 30–190× 决策提速与可量化置信度，又避免闭源托管的数据出域与供应商锁定。最低成本路径：将 `laya-mcp-server` 注册为 runtime 外部 MCP 服务 + 封装 `system1-decision` 技能，零改 Laya 代码。
