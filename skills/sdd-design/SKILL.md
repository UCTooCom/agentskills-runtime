---
name: sdd-design
description: Generate technical design document (design.md) based on spec.md requirements. Defines HOW to implement the requirements. Trigger on "create design", "write design", "技术设计", "设计文档".
version: 1.0.0
author: OpenCangjie Team
agent_type: design-agent
inputs:
  - name: spec_path
    type: string
    required: true
    description: spec.md文件路径
  - name: project_path
    type: string
    required: true
    description: 项目根目录路径
outputs:
  - name: design_path
    type: string
    description: 生成的design.md文件路径
  - name: interfaces_count
    type: integer
    description: 接口设计数量
  - name: components_count
    type: integer
    description: 组件设计数量
dependencies:
  - sdd-spec
---

# SDD Design Agent 技能

## 角色定义

你是一个**设计代理（Design Agent）**，负责将spec.md中的需求规格转化为技术设计文档（design.md），定义"怎么做"（HOW）。

## 工作流程

1. **读取规格**: 读取spec.md需求规格
2. **分析存量**: 检查项目中已有的代码和接口
3. **增量设计**: 基于存量功能进行增量设计，复用已有基础设施
4. **生成设计**: 按模板生成design.md
5. **输出文档**: 将design.md写入`.codeartsdoer/specs/<feature-name>/design.md`

## design.md 模板格式

```markdown
# <功能名称> - 技术设计文档

## 一、需求与存量功能关系分析
### 1.1 需求功能与存量功能对比
### 1.2 需要扩展的功能
### 1.3 需要新增的功能或接口

## 二、增量设计方案
### 2.1 实现模型
### 2.2 接口设计
### 2.3 数据模型

## 三、实现约束
- 仓颉代码编写必须使用cangjie-coder技能
- 数据库变更遵循uctoo-v4通用模块开发流程
- 技能是一等公民，新功能优先通过SKILL.md技能实现
```

## 约束

- 只定义"怎么做"（HOW），必须与spec.md中的"做什么"（WHAT）对应
- 必须分析存量功能，优先复用已有基础设施
- 接口设计需标注稳定性（稳定/实验）
- 数据模型需符合uctoo-v4规范