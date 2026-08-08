# GOAI 2026 需求分解与规范驱动开发工程规划

## 文档信息
- **版本**: 1.0
- **创建日期**: 2026-07-23
- **目标**: 将gap-analysis.md中的30项需求分解为独立的规范驱动开发工程

---

## 1. 分解原则

1. **逻辑内聚**: 强相关的需求归入同一工程，减少跨工程依赖
2. **规模可控**: 每个工程预估3-7天工时，确保可完整开发和验收
3. **依赖清晰**: 工程间依赖关系明确，支持并行开发
4. **复用优先**: 复用已有spec目录，避免重复创建
5. **赛事对齐**: P0工程优先保障复赛提交，P1工程增强竞争力，P2工程锦上添花

---

## 2. 工程总览

### 2.1 P0 核心工程（9个，复赛前必须完成）

| 编号 | 工程名称 | 目录名 | 覆盖需求 | 预估工时 | 依赖 | 对标维度 | 状态 |
|------|---------|--------|---------|---------|------|---------|------|
| P0-1 | AgentTeams分层协作架构 | agent-teams | GOAI-001 | 5天 | 无 | 多Agent协同(25%) | 新建 |
| P0-2 | 任务分解与DAG编排引擎 | agent-orchestration | GOAI-002 | 5天 | P0-1 | 多Agent协同(25%) | 复用已有spec |
| P0-3 | 执行证据链与审计系统 | execution-audit | GOAI-003, GOAI-017 | 5天 | P0-1 | 工程落地(20%) | 新建 |
| P0-4 | 技能组合引擎 | skill-composition-engine | GOAI-005, GOAI-010 | 7天 | 无 | Skill工程(25%) | 复用已有spec |
| P0-5 | cangjie-coder agents子目录完善 | cangjie-coder-agents | GOAI-022 | 3天 | 无 | Skill工程(25%) | 新建 |
| P0-6 | 代码生成工具Skills化封装 | code-gen-skills | GOAI-023, GOAI-027 | 4天 | 无 | Skill工程(25%) | 新建 |
| P0-7 | SDD规范驱动开发技能集 | sdd-skills | GOAI-013 | 3天 | P0-1 | 场景价值(25%) | 新建 |
| P0-8 | 全栈代码生成闭环 | fullstack-codegen | GOAI-014 | 3天 | P0-5, P0-6 | 场景价值(25%) | 新建 |
| P0-9 | AI驱动开发全流程Demo | ai-dev-demo | GOAI-004 | 5天 | P0-1~8 | 场景价值(25%) | 新建 |

### 2.2 P1 增强工程（8个，决赛前完成）

| 编号 | 工程名称 | 目录名 | 覆盖需求 | 预估工时 | 依赖 | 对标维度 | 状态 |
|------|---------|--------|---------|---------|------|---------|------|
| P1-1 | Agent间上下文传递与结果验证 | agent-context-verify | GOAI-006 | 3天 | P0-1, P0-2 | 多Agent协同(25%) | 新建 |
| P1-2 | 记忆持久化与跨会话共享 | agent-memory-persistence | GOAI-007 | 4天 | 无 | 多Agent协同(25%) | 复用已有spec |
| P1-3 | AgentLoop观测评估飞轮 | agent-loop | GOAI-008 | 4天 | P0-3 | 工程落地(20%) | 新建 |
| P1-4 | 审批与回滚机制 | approval-rollback | GOAI-009 | 3天 | P0-3 | 工程落地(20%) | 新建 |
| P1-5 | 专用语言多Skills编排协作 | language-skills-orchestration | GOAI-024, GOAI-028 | 5天 | P0-5, P0-4 | 多Agent协同(25%) | 新建 |
| P1-6 | 技能自进化闭环 | skill-evolution | GOAI-015, GOAI-026 | 6天 | P0-4 | Skill工程(25%) | 新建 |
| P1-7 | 协同技能集与Kanban | collaboration-skills | GOAI-016, GOAI-018 | 7天 | P0-1 | 多Agent协同(25%) | 新建 |
| P1-8 | 测试脚本动态生成 | test-generator | GOAI-025 | 3天 | P0-5 | 工程落地(20%) | 新建 |

### 2.3 P2 锦上添花工程（5个，时间允许时完成）

| 编号 | 工程名称 | 目录名 | 覆盖需求 | 预估工时 | 依赖 | 对标维度 | 状态 |
|------|---------|--------|---------|---------|------|---------|------|
| P2-1 | 错误恢复与自愈系统 | agent-error-recovery | GOAI-011 | 4天 | P0-3 | 工程落地(20%) | 复用已有spec |
| P2-2 | 开源计划与社区建设 | open-source-plan | GOAI-012 | 1天 | 无 | 开源贡献(5%) | 新建 |
| P2-3 | 记忆提供者插件体系 | memory-provider | GOAI-019 | 4天 | P1-2 | 多Agent协同(25%) | 新建 |
| P2-4 | 上下文优化引擎 | context-optimization | GOAI-020, GOAI-021 | 6天 | 无 | 工程落地(20%) | 新建 |
| P2-5 | Agent智能增强 | agent-intelligence | GOAI-029, GOAI-030 | 6天 | P1-5 | Skill工程(25%) | 新建 |

---

## 3. 需求覆盖矩阵

| 需求编号 | 需求名称 | 归属工程 | 优先级 |
|---------|---------|---------|--------|
| GOAI-001 | AgentTeams分层协作架构 | agent-teams | P0 |
| GOAI-002 | 任务分解与DAG编排引擎 | agent-orchestration | P0 |
| GOAI-003 | 执行证据链与审计系统 | execution-audit | P0 |
| GOAI-004 | AI驱动开发全流程Demo场景 | ai-dev-demo | P0 |
| GOAI-005 | 技能组合引擎核心 | skill-composition-engine | P0 |
| GOAI-006 | Agent间上下文传递与结果验证 | agent-context-verify | P1 |
| GOAI-007 | 记忆持久化与跨会话共享 | agent-memory-persistence | P1 |
| GOAI-008 | AgentLoop观测评估飞轮 | agent-loop | P1 |
| GOAI-009 | 审批与回滚机制 | approval-rollback | P1 |
| GOAI-010 | 技能组合模板与依赖解析 | skill-composition-engine | P0 |
| GOAI-011 | 错误恢复与自愈系统 | agent-error-recovery | P2 |
| GOAI-012 | 开源计划与社区建设 | open-source-plan | P2 |
| GOAI-013 | SDD规范驱动开发技能集 | sdd-skills | P0 |
| GOAI-014 | 全栈代码生成闭环 | fullstack-codegen | P0 |
| GOAI-015 | 技能自进化闭环 | skill-evolution | P1 |
| GOAI-016 | 协同技能集 | collaboration-skills | P1 |
| GOAI-017 | 验证证据账本 | execution-audit | P0 |
| GOAI-018 | Agent Kanban任务队列 | collaboration-skills | P1 |
| GOAI-019 | 记忆提供者插件体系 | memory-provider | P2 |
| GOAI-020 | 上下文多层压缩管道 | context-optimization | P2 |
| GOAI-021 | 提示缓存机制 | context-optimization | P2 |
| GOAI-022 | cangjie-coder agents子目录完善 | cangjie-coder-agents | P0 |
| GOAI-023 | 代码生成工具Skills化封装 | code-gen-skills | P0 |
| GOAI-024 | 专用语言多Skills编排协作架构 | language-skills-orchestration | P1 |
| GOAI-025 | 测试脚本动态生成技能 | test-generator | P1 |
| GOAI-026 | 技能脚本动态生成机制 | skill-evolution | P1 |
| GOAI-027 | 代码生成闭环验证 | code-gen-skills | P0 |
| GOAI-028 | Agent subagent配置增强 | language-skills-orchestration | P1 |
| GOAI-029 | RepoMap代码库智能 | agent-intelligence | P2 |
| GOAI-030 | Agent动态生成能力 | agent-intelligence | P2 |

---

## 4. 工程依赖关系图

```
P0-1 agent-teams ─────────┬──→ P0-2 agent-orchestration ──→ P1-1 agent-context-verify
                          ├──→ P0-3 execution-audit ──┬──→ P1-3 agent-loop
                          │                          ├──→ P1-4 approval-rollback
                          │                          └──→ P2-1 agent-error-recovery
                          ├──→ P0-7 sdd-skills ──→ P0-9 ai-dev-demo
                          └──→ P1-7 collaboration-skills

P0-4 skill-composition-engine ──→ P1-5 language-skills-orchestration ──→ P2-5 agent-intelligence
                               └──→ P1-6 skill-evolution

P0-5 cangjie-coder-agents ──┬──→ P0-8 fullstack-codegen ──→ P0-9 ai-dev-demo
                            ├──→ P1-5 language-skills-orchestration
                            ├──→ P1-8 test-generator
                            └──→ P1-5 language-skills-orchestration

P0-6 code-gen-skills ──→ P0-8 fullstack-codegen

P1-2 agent-memory-persistence ──→ P2-3 memory-provider

P2-4 context-optimization (独立)

P2-2 open-source-plan (独立)
```

---

## 5. 开发阶段规划

### 阶段一：初赛准备（7月23日 - 8月16日）
- 完成所有P0工程的spec.md和design.md
- 制作初赛PPT

### 阶段二：核心功能开发（8月17日 - 9月3日）
- 第1周：P0-1 agent-teams + P0-5 cangjie-coder-agents + P0-6 code-gen-skills
- 第2周：P0-2 agent-orchestration + P0-3 execution-audit + P0-4 skill-composition-engine
- 第3周：P0-7 sdd-skills + P0-8 fullstack-codegen + P0-9 ai-dev-demo
- 第4周：P1关键工程

### 阶段三：决赛准备（9月4日 - 9月22日）
- 完善Demo稳定性
- 完成P1工程
- 答辩材料准备

---

## 6. 复用已有工程目录

| 已有目录 | 复用方式 | 需补充文档 |
|---------|---------|-----------|
| agent-orchestration | 已有spec.md，需更新对齐GOAI-002 | design.md, tasks.md |
| skill-composition-engine | 已有spec.md，需扩展GOAI-010 | design.md, tasks.md |
| agent-memory-persistence | 已有spec.md，对齐GOAI-007 | design.md, tasks.md |
| agent-error-recovery | 已有spec.md，对齐GOAI-011 | design.md, tasks.md |