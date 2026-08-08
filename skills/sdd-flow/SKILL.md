---
name: sdd-flow
description: Orchestrate the complete SDD (Specification-Driven Development) workflow from requirements to verified code. Combines sdd-spec, sdd-design, sdd-task, cangjie-coder, and sdd-test skills. Trigger on "SDD flow", "full development", "规范驱动开发", "完整开发流程".
version: 1.0.0
author: OpenCangjie Team
agent_type: sdd-orchestrator
inputs:
  - name: requirement
    type: string
    required: true
    description: 用户需求描述
  - name: project_path
    type: string
    required: true
    description: 项目根目录路径
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
dependencies:
  - sdd-spec
  - sdd-design
  - sdd-task
  - cangjie-coder
  - sdd-test
---