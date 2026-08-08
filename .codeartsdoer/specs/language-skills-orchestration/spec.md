# 专用语言多Skills编排协作架构需求规格

## 项目背景

agentskills-runtime作为coding agent的核心差异化能力是"专用语言多Skills编排协作"：每种编程语言一组专用技能（文档查阅→代码检索→代码编辑→代码验证），通过编排协作引擎自动选择和执行。本工程实现编排协作引擎和Agent subagent配置增强。

## 核心问题

1. **缺少编排协作引擎**: 无法根据编程语言自动选择和编排对应的技能集
2. **缺少语言上下文注入**: 无法自动加载编程语言的相关资料和编程规范
3. **缺少跨语言协作**: 多语言项目无法跨语言编排（如仓颉后端+Vue前端）
4. **缺少subagent配置增强**: subagent不支持类型选择、模型覆盖、后台执行

## 功能需求

### REQ-LSO-001: 编排协作引擎
- 根据编程语言自动选择和编排对应的技能集
- 语言→技能集映射可配置
- 支持仓颉、TypeScript、Python等语言

### REQ-LSO-002: 语言上下文注入
- 自动加载编程语言的相关资料和编程规范作为上下文
- 上下文来源：CangjieSkills、TypeScript文档等
- 上下文注入到subagent的system prompt

### REQ-LSO-003: 跨语言协作
- 支持多语言项目的跨语言skills编排
- 示例：仓颉后端(crudgen) + Vue前端(crudweb)
- 跨语言数据传递标准化

### REQ-LSO-004: Agent subagent配置增强
- 支持subagent_type配置（在agents/子目录中声明）
- 支持模型覆盖（每个subagent可指定不同模型）
- 支持后台执行（subagent异步执行）
- 支持进度追踪和结果聚合

## 验收标准

- [ ] 编排协作引擎根据编程语言自动选择技能集
- [ ] 语言上下文正确注入到subagent
- [ ] 跨语言协作（仓颉+Vue）可正确执行
- [ ] subagent支持类型选择、模型覆盖、后台执行

## 依赖

- 依赖cangjie-coder-agents工程的agents子目录
- 依赖skill-composition-engine工程的组合执行能力