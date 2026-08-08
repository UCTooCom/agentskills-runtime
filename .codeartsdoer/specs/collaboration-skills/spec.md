# 协同技能集与Kanban需求规格

## 项目背景

用AI推理驱动的协同技能替代固定程序式的Agent协作模式，并实现Agent Kanban任务队列。借鉴Hermes的delegation系统和Kanban多Agent工作队列。

## 核心问题

1. **缺少协同技能**: 当前Agent协作是固定程序式（LinearGroup/LeaderGroup/FreeGroup），无法根据任务特征动态选择
2. **缺少Kanban任务队列**: Agent间无结构化的任务队列
3. **缺少任务分配/认领机制**: 无任务分配和认领流程
4. **缺少失败保护**: 连续失败无自动阻塞

## 功能需求

### REQ-CS-001: 协同技能集
- task-decompose: 将复杂任务分解为子任务DAG
- agent-select: 根据子任务选择合适的Agent
- context-pass: 在Agent间传递结构化上下文
- result-merge: 聚合多个Agent的执行结果
- conflict-resolve: 解决Agent间的执行冲突
- handover: 将控制权移交给另一个Agent

### REQ-CS-002: Agent Kanban任务队列
- 任务持久化到数据库（agent_kanban_tasks表）
- 任务生命周期：create→assign→claim→complete/block
- 支持任务分配、认领、完成、阻塞

### REQ-CS-003: Dispatcher调度器
- 长循环调度，回收过期claim、提升ready任务
- 原子claim操作
- 失败保护：连续失败超过limit自动block

### REQ-CS-004: 协同技能与AgentTeams集成
- 协同技能通过AgentTeams分层架构执行
- Manager使用task-decompose和agent-select
- TeamLeader使用context-pass和result-merge

## 验收标准

- [ ] 6个协同技能可正确执行
- [ ] Kanban任务队列正确工作
- [ ] Dispatcher调度器正确调度
- [ ] 协同技能与AgentTeams正确集成

## 依赖

- 依赖agent-teams工程的AgentTeams分层架构