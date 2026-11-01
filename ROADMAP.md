# AgentSkills Runtime - 路线图

## 版本规划

### v0.1.0 - 基础设施层（已完成）

**目标**: 建立AgentTeams分层协作架构和技能组合引擎核心

- [x] AgentTeams分层协作架构（ManagerGroup/TeamMessenger/Leader/Worker）
- [x] 技能组合引擎（SkillComposer/CompositionExecutor/DependencyResolver/CompositionValidator）
- [x] cangjie-coder技能与子Agent体系
- [x] 代码生成工具Skills化封装（crudgen/crudweb/loaddbinfo）
- [x] SDD规范驱动开发技能集

### v0.2.0 - 编排与审计层（已完成）

**目标**: 实现DAG编排引擎和执行证据链审计体系

- [x] DAG编排引擎（DagConfig/DagScheduler/ConditionEvaluator/ResultAggregator）
- [x] 执行证据链审计（ExecutionEvidenceRecorder/SideEffectTracker/AuditHashChain/VerificationEvidenceCollector）
- [x] 全栈代码生成闭环
- [x] AI驱动开发全流程Demo

### v0.3.0 - 智能增强层（已完成）

**目标**: Agent上下文验证、循环执行、审批回滚、跨语言编排、技能进化、协同技能

- [x] Agent上下文验证（ContextVerifier/ContextGatekeeper/ContextCompressor）
- [x] Agent循环执行（AgentLoopTracer/TuningEngine/IncrementalResultPusher）
- [x] 审批与回滚（ApprovalManager/RollbackManager/CheckpointManager）
- [x] 跨语言技能编排（CrossLanguageOrchestrator/SubAgentProgressTracker）
- [x] 技能进化（SkillCuratorHandler/SkillCuratorYamlParser/SkillCuratorExecutor）
- [x] 协同技能（TaskDecompose/AgentSelect/ContextPass/ResultMerge/ConflictResolve/Handover）

### v0.4.0 - 记忆与优化层（已完成）

**目标**: 分层记忆、记忆提供者插件、上下文优化、Agent智能

- [x] 分层记忆管理（MemoryLayerManager/SemanticMemorySearch/MemorySharingManager）
- [x] 记忆提供者插件体系（MemoryProvider接口/BuiltinProvider/PostgresProvider）
- [x] 上下文优化引擎（ContextCompressionPipeline/PromptCache）
- [x] Agent智能（RepoMap/AgentDynamicGenerator）
- [x] 错误恢复（ErrorRecoveryManager）

### v0.5.0 - 生产就绪层（计划中）

**目标**: 生产环境部署、监控、安全加固

- [ ] WASM沙箱安全隔离完善
- [ ] 运行时监控与可观测性（Metrics/Tracing/Logging）
- [ ] 多租户资源隔离
- [ ] 配置热更新机制
- [ ] 集群模式与高可用

### v1.0.0 - 正式发布（规划中）

**目标**: 首个正式发布版本，API稳定

- [ ] API稳定性承诺与版本策略
- [ ] 完整文档体系（API参考/部署指南/最佳实践）
- [ ] 性能基准测试与优化
- [ ] 多语言SDK（Python/TypeScript/Go）
- [ ] 插件市场基础设施

### v1.1.0 - 生态扩展（规划中）

**目标**: 社区生态与插件市场

- [ ] 插件市场上线
- [ ] 更多内置技能（code-review/doc-generator/data-pipeline）
- [ ] 与主流云服务基础设施集成
- [ ] 可视化编排界面
- [ ] 多模态Agent支持

---

## 功能路线图

```
2026 Q3                    Q4                    2027 Q1
  │                        │                       │
  ├─ v0.1 基础设施层       │                       │
  ├─ v0.2 编排与审计层     │                       │
  ├─ v0.3 智能增强层       │                       │
  ├─ v0.4 记忆与优化层     │                       │
  │                        │                       │
  │                        ├─ v0.5 生产就绪层      │
  │                        ├─ v1.0 正式发布        │
  │                        │                       │
  │                        │                       ├─ v1.1 生态扩展
```

## 核心设计原则

1. **技能是一等公民** — 所有功能优先通过SKILL.md技能实现，而非硬编码
2. **确定性优先，AI增强** — 确定性代码做确定的事，AI做推理决策
3. **可配置引擎优先于硬编码程序** — 通过YAML/Markdown配置动态调整
4. **复用和优化已有基础设施** — 优先复用crudgen/crudweb等已有能力
5. **仓颉原生** — 基于仓颉(Cangjie)语言实现，充分发挥国产语言优势

## 技术栈

| 层级 | 技术选型 |
|------|---------|
| 语言 | 仓颉(Cangjie) |
| 构建工具 | cjpm |
| ORM | Fountain |
| Web框架 | uctoo |
| 数据库 | PostgreSQL |
| 前端 | OpenTiny Vue |
| 沙箱 | WASM |
| 配置 | YAML + Markdown Frontmatter |