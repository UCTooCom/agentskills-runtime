# 全栈代码生成闭环需求规格

## 项目背景

整合crudgen、crudweb、loaddbinfo、cangjie-coder等已有基础设施，形成从需求到部署的完整AI驱动开发闭环。这是agentskills-runtime作为"AI驱动开发框架"的核心差异化能力，与赛事"场景价值与行业可复制性"维度高度对齐。

## 核心问题

1. **缺少全栈闭环流程**: loaddbinfo→crudgen→crudweb→cangjie-coder各工具独立，无自动化闭环
2. **缺少前后端同构映射**: 后端PO与前端ORM模型无自动同构机制
3. **缺少增量代码生成**: 不支持在已有代码基础上增量生成
4. **缺少部署验证闭环**: 代码生成后无自动构建和部署验证

## 功能需求

### REQ-FSC-001: 全栈代码生成闭环流程

- 实现loaddbinfo→crudgen→crudweb→cangjie-coder的自动化闭环
- 支持从数据库表结构自动生成全栈代码
- 支持从业务需求描述自动生成全栈代码（通过SDD流程）

### REQ-FSC-002: 前后端模型同构

- 后端PO模型自动映射为前端ORM模型
- 遵循UMI全栈模型同构设计
- 字段类型、验证规则、关联关系自动同步

### REQ-FSC-003: 增量代码生成

- 支持在已有代码基础上增量生成
- 不覆盖自定义代码（标记AutoCreateCode区域）
- 支持代码合并策略

### REQ-FSC-004: 构建验证闭环

- 代码生成后自动调用cjpm build验证
- 验证失败时自动反馈到代码修复
- 支持从验证失败到修复的自动闭环

## 验收标准

- [ ] loaddbinfo→crudgen→crudweb→cangjie-coder闭环可自动执行
- [ ] 后端PO模型可自动映射为前端ORM模型
- [ ] 增量代码生成不覆盖自定义代码
- [ ] 代码生成后自动构建验证
- [ ] 验证失败时自动反馈到代码修复

## 依赖

- 依赖code-gen-skills工程的技能化封装
- 依赖cangjie-coder-agents工程的agents子目录
- 依赖skill-composition-engine工程的组合执行能力