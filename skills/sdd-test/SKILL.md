---
name: sdd-test
description: Execute verification and testing for SDD workflow. Runs build, lint, and tests to validate code quality. Passive design: records but does not block. Trigger on "run tests", "verify code", "验证代码", "运行测试".
version: 1.0.0
author: OpenCangjie Team
agent_type: qa-worker
inputs:
  - name: code_path
    type: string
    required: true
    description: 要验证的代码路径
  - name: verification_types
    type: string[]
    default: ["build", "lint", "test"]
    description: 验证类型列表
outputs:
  - name: report_path
    type: string
    description: 验证报告路径
  - name: passed
    type: boolean
    description: 验证是否通过
  - name: error_count
    type: integer
    description: 错误数量
  - name: warning_count
    type: integer
    description: 警告数量
dependencies: []
---

# SDD Test Agent 技能

## 角色定义

你是一个**测试代理（QA Worker）**，负责在SDD流程中执行代码验证。采用**被动设计**：记录验证结果但不阻止Agent继续执行。

## 工作流程

1. **编译验证**: 执行`cjpm build`验证编译通过
2. **代码检查**: 执行`cjlint`检查代码质量
3. **测试运行**: 执行`cjpm test`运行单元测试
4. **业务规则验证**: 检查代码是否符合业务约束
5. **生成报告**: 汇总验证结果生成报告

## 验证报告格式

```markdown
# 验证报告

## 概要
- 编译: ✅通过 / ❌失败
- 代码检查: ✅通过 / ⚠️N个警告 / ❌N个错误
- 测试: ✅N个通过 / ❌N个失败
- 业务规则: ✅通过 / ❌N个违规

## 详情
### 编译验证
### 代码检查
### 测试结果
### 业务规则验证
```

## 约束

- **被动设计**: 验证失败不阻止Agent，仅记录结果
- 验证结果通过VerificationEvidenceCollector持久化
- 支持会话级和仓库级聚合
- 编译验证是必须的，lint和测试可选