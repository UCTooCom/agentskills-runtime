# 记忆提供者插件体系需求规格

## 项目背景

借鉴Hermes的MemoryProvider ABC设计，实现记忆提供者插件体系，支持多种记忆存储后端。

## 功能需求

### REQ-MP-001: MemoryProvider接口
- 定义MemoryProvider protocol（仓颉接口）
- 生命周期：initialize→systemPromptBlock→prefetch→syncTurn→shutdown
- 可选钩子：onTurnStart、onSessionEnd、onMemoryWrite

### REQ-MP-002: 内置提供者
- builtin: 基于现有MEMORY.md/SOUL.md
- postgres: 基于Fountain ORM和agent_memories表
- vector: 基于RAG向量搜索能力

### REQ-MP-003: 提供者选择
- 通过配置文件指定提供者
- 引擎动态加载
- 支持运行时切换

## 验收标准

- [ ] MemoryProvider接口定义完整
- [ ] 3个内置提供者可正确工作
- [ ] 提供者可通过配置选择

## 依赖

- 依赖agent-memory-persistence工程的记忆持久化