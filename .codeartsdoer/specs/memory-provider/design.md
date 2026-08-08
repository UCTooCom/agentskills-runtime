# 记忆提供者插件体系 - 设计文档

## 架构概述

MemoryProvider 是记忆系统的抽象接口层，支持多种记忆后端（内置文件、Postgres数据库、向量数据库）的插件化切换。

## 核心接口

```cangjie
public interface MemoryProvider {
    func store(agentId: String, content: String, layer: String, scope: String, metadata: Option<JsonValue>): Option<String>
    func retrieve(agentId: String, query: String, limit!: Int64 = 10): ArrayList<MemoryEntry>
    func search(agentId: String, query: String, limit!: Int64 = 10): ArrayList<MemoryEntry>
    func delete(memoryId: String): Bool
    func getProviderName(): String
}
```

## 实现类

| 实现类 | 后端 | 说明 |
|--------|------|------|
| BuiltinProvider | MEMORY.md/SOUL.md文件 | 基于现有Markdown文件的记忆提供 |
| PostgresProvider | PostgreSQL+pgvector | 基于数据库的记忆提供，支持向量检索 |

## 关键文件
- `src/interaction/memory_provider.cj` — MemoryProvider接口
- `src/interaction/memory_manager.cj` — MemoryLayerManager/SemanticMemorySearch/MemorySharingManager