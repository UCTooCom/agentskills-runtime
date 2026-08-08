# SDD规范驱动开发技能集需求规格

## 项目背景

借鉴CodeArts Agent的规范驱动开发（SDD）机制，将SDD流程映射到AgentTeams分层架构。SDD的spec→design→tasks→code→test流程天然适合AgentTeams的Manager→TeamLeader→Worker分层架构，每个阶段的输出（spec.md、design.md、tasks.md）就是Agent间上下文传递的标准化载体。

## 核心问题

1. **缺少SDD技能集**: 当前无spec-agent、design-agent、task-agent等SDD流程技能
2. **缺少SDD流程编排**: SDD的spec→design→tasks→code→test流程无自动化编排
3. **缺少SDD输出标准化**: 各阶段输出格式无统一标准
4. **缺少SDD与AgentTeams映射**: SDD流程未映射到Manager→TeamLeader→Worker架构

## 功能需求

### REQ-SDD-001: SpecAgent技能

- 需求规格Agent技能，接收用户需求，生成spec.md
- 输入：用户需求描述
- 输出：spec.md文件（包含项目背景、核心问题、功能需求、验收标准）
- 角色：Manager角色

### REQ-SDD-002: DesignAgent技能

- 技术设计Agent技能，基于spec.md生成design.md
- 输入：spec.md文件路径
- 输出：design.md文件（包含需求与存量功能关系分析、增量设计方案）
- 角色：TeamLeader角色

### REQ-SDD-003: TaskAgent技能

- 任务分解Agent技能，基于design.md生成tasks.md
- 输入：design.md文件路径
- 输出：tasks.md文件（包含任务总览、任务详情、验收标准）
- 角色：TeamLeader角色

### REQ-SDD-004: CodeAgent技能

- 编码实现Agent技能，基于tasks.md执行编码
- 输入：tasks.md文件路径
- 输出：代码文件
- 角色：Worker角色
- 复用cangjie-coder技能

### REQ-SDD-005: TestAgent技能

- 测试验证Agent技能，验证代码质量
- 输入：代码文件路径
- 输出：验证报告
- 角色：Worker角色

### REQ-SDD-006: SDD流程编排

- 定义sdd-flow组合模板
- 流程：SpecAgent→DesignAgent→TaskAgent→CodeAgent→TestAgent
- 支持从用户需求自动执行完整SDD流程
- 各阶段输出作为下一阶段输入

## 验收标准

- [ ] SpecAgent正确生成spec.md
- [ ] DesignAgent基于spec.md正确生成design.md
- [ ] TaskAgent基于design.md正确生成tasks.md
- [ ] CodeAgent基于tasks.md正确执行编码
- [ ] TestAgent正确验证代码质量
- [ ] sdd-flow组合模板可正确执行完整流程

## 依赖

- 依赖agent-teams工程的AgentTeams分层架构
- 依赖skill-composition-engine工程的组合执行能力
- 复用cangjie-coder技能