---
name: fullstack-codegen
description: Full-stack code generation workflow that orchestrates database schema loading, CRUD generation, web UI generation, and code verification. Combines loaddbinfo, crudgen, crudweb, cangjie-coder, and code-gen-verifier skills. Trigger on "full stack code gen", "generate full stack", "全栈代码生成", "完整CRUD生成".
version: 1.0.0
author: OpenCangjie Team
agent_type: codegen-orchestrator
inputs:
  - name: table_name
    type: string
    required: true
    description: 要生成代码的数据库表名
  - name: database
    type: string
    required: true
    description: 数据库名称
  - name: project_path
    type: string
    required: true
    description: 项目根目录路径
  - name: generate_frontend
    type: boolean
    default: true
    description: 是否生成前端页面
  - name: optimize_code
    type: boolean
    default: true
    description: 是否使用cangjie-coder优化代码
outputs:
  - name: backend_files
    type: string[]
    description: 生成的后端文件列表
  - name: frontend_files
    type: string[]
    description: 生成的前端文件列表
  - name: verification_passed
    type: boolean
    description: 代码验证是否通过
  - name: api_endpoints
    type: string[]
    description: 生成的API端点列表
dependencies:
  - loaddbinfo
  - crud-generator
  - cangjie-coder
  - code-gen-verifier
---