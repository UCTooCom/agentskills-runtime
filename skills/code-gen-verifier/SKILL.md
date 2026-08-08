---
name: code-gen-verifier
description: 代码生成验证技能。验证crud-generator生成的代码是否可编译、是否符合仓颉语言规范、是否遵循uctoo-v4模块开发规范。当代码生成后需要自动验证时使用。触发词："验证生成代码"、"code-gen-verifier"、"verify generated code"。
version: 1.0.0
author: OpenCangjie Team
inputs:
  - name: files
    type: string[]
    required: true
    description: 需要验证的生成文件路径列表
  - name: project_path
    type: string
    required: true
    description: 项目根目录路径
  - name: verify_level
    type: string
    default: "compile"
    description: 验证级别（syntax/compile/test）
outputs:
  - name: passed
    type: boolean
    description: 验证是否通过
  - name: errors
    type: object[]
    description: 错误列表
  - name: warnings
    type: object[]
    description: 警告列表
  - name: fix_suggestions
    type: object[]
    description: 修复建议列表
dependencies:
  - cangjie-coder
---

# Code Gen Verifier 技能

## 概述

验证crud-generator生成的代码是否可编译、是否符合仓颉语言规范、是否遵循uctoo-v4模块开发规范。

## 核心功能

1. **语法验证**: 检查生成代码是否符合仓颉语言语法规范
2. **编译验证**: 使用cjpm build验证代码可编译
3. **规范验证**: 检查代码是否遵循uctoo-v4模块开发规范（Model→DAO→Service→Controller→Route）
4. **修复建议**: 验证失败时生成修复建议

## 验证流程

### Step 1: 文件完整性检查

检查生成的文件是否完整：
- Model层: `{TableName}PO.cj`
- DAO层: `{TableName}DAO.cj`
- Service层: `{TableName}Service.cj`
- Controller层: `{TableName}Controller.cj`
- Route层: `{TableName}Route.cj`

### Step 2: 语法验证

使用cangjie-coder的cangjie_syntax_check.py脚本检查语法：
- package声明正确
- import语句正确
- 类定义格式正确
- 命名规范正确

### Step 3: 编译验证

使用cangjie-coder的cangjie_compile.py脚本编译项目：
- 代码可正常编译
- 无编译错误

### Step 4: 规范验证

检查代码是否遵循uctoo-v4规范：
- PO类有@DataAssist注解
- DAO类继承RootDAO
- Service方法返回APIResult<T>
- Controller使用RESTful端点
- Route正确注册

### Step 5: 输出验证结果

将验证结果整理为结构化输出。

## 修复闭环

当验证失败时：
1. 生成修复建议
2. 调用cangjie-coder技能修复代码
3. 重新验证
4. 最多重试3次

## 使用方式

### 作为组合模板的一部分

在code-gen-optimize组合模板中自动调用：
```
loaddbinfo → crud-generator → code-gen-verifier → cangjie-coder(优化)
```

### 单独调用

```
POST /api/skills/code-gen-verifier
{
  "files": ["src/app/models/uctoo/EntityPO.cj", ...],
  "project_path": "/path/to/project",
  "verify_level": "compile"
}
```

## 注意事项

- 验证前需确保项目依赖已安装（cjpm update）
- 编译验证需要仓颉SDK环境
- 修复闭环依赖cangjie-coder技能