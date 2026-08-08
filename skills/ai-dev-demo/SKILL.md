---
name: ai-dev-demo
description: AI-driven development demo that showcases the complete SDD workflow with AgentTeams collaboration. Orchestrates spec→design→task→code→verify with team-based execution. Trigger on "AI dev demo", "run demo", "AI驱动开发Demo", "演示".
version: 1.0.0
author: OpenCangjie Team
agent_type: demo-orchestrator
inputs:
  - name: requirement
    type: string
    required: true
    description: 需求描述（如：为employee表生成全栈CRUD模块）
  - name: project_path
    type: string
    required: true
    description: 项目根目录路径
  - name: team_config
    type: string
    required: false
    description: AgentTeams配置名称
outputs:
  - name: spec_path
    type: string
    description: 生成的spec.md路径
  - name: design_path
    type: string
    description: 生成的design.md路径
  - name: tasks_path
    type: string
    description: 生成的tasks.md路径
  - name: code_files
    type: string[]
    description: 生成的代码文件列表
  - name: verification_passed
    type: boolean
    description: 验证是否通过
  - name: evidence_chain_valid
    type: boolean
    description: 证据链完整性校验
  - name: total_duration_ms
    type: integer
    description: 总耗时（毫秒）
dependencies:
  - sdd-flow
  - fullstack-codegen
---

# AI驱动开发全流程Demo

## 演示场景

用户输入需求："为employee表生成全栈CRUD模块"

## 执行流程

1. **Manager Agent** 接收需求，分析并分解为子任务
2. **Spec Agent** (TeamLeader) 生成spec.md需求规格
3. **Design Agent** (TeamLeader) 生成design.md技术设计
4. **Task Agent** (TeamLeader) 生成tasks.md编码任务
5. **Code Agent** (Worker) 使用cangjie-coder/crudgen生成代码
6. **QA Agent** (Worker) 执行编译验证和代码检查
7. **Manager Agent** 汇总结果，验证证据链完整性

## 关键展示点

- **技能是一等公民**: 所有功能通过SKILL.md技能编排实现
- **AgentTeams分层协作**: Manager→Leader→Worker三层架构
- **执行证据链**: 每个步骤都有可验证的审计证据
- **DAG编排**: 步骤按依赖关系自动调度
- **被动验证**: 验证失败不阻止流程，仅记录结果