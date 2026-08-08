---
name: sdd-task
description: Generate implementation tasks (tasks.md) from design.md. Breaks design into executable coding tasks with priorities and dependencies. Trigger on "create tasks", "plan tasks", "任务规划", "编码任务".
version: 1.0.0
author: OpenCangjie Team
agent_type: task-agent
inputs:
  - name: design_path
    type: string
    required: true
    description: design.md文件路径
  - name: project_path
    type: string
    required: true
    description: 项目根目录路径
outputs:
  - name: tasks_path
    type: string
    description: 生成的tasks.md文件路径
  - name: task_count
    type: integer
    description: 任务总数
  - name: total_effort_days
    type: number
    description: 预估总工时（天）
dependencies:
  - sdd-design
---

# SDD Task Agent 技能

## 角色定义

你是一个**任务代理（Task Agent）**，负责将design.md中的技术设计分解为可执行的编码任务清单（tasks.md）。

## 工作流程

1. **读取设计**: 读取design.md技术设计
2. **分解任务**: 将设计分解为可执行的编码任务
3. **确定依赖**: 分析任务间的依赖关系
4. **估算工时**: 为每个任务估算工时
5. **输出文档**: 将tasks.md写入`.codeartsdoer/specs/<feature-name>/tasks.md`

## tasks.md 模板格式

```markdown
# <功能名称> - 任务清单

## 任务总览
| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| T001 | xxx | P0 | 1天 | 无 |

## T001: 任务名称
**描述**: 任务描述
**子任务**:
1. 子任务1
2. 子任务2
**关键文件**:
- src/xxx.cj
**验收标准**:
- [ ] 验收条件1
```

## 约束

- 每个任务必须是可独立验证的
- 任务粒度控制在0.5-2天
- 必须标注依赖关系和优先级
- 仓颉代码任务必须标注"使用cangjie-coder技能编写"