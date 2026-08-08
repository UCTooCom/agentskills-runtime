# 记忆持久化与跨会话共享 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式
- 数据库列名使用 snake_case，仓颉代码使用 camelCase
- crudgen 生成的代码写在 `//#region AutoCreateCode` 区域内，增量开发代码写在该区域外

### 数据库结构变更流程（uctoo-v4 通用模块开发流程）
- 涉及数据库结构变更和新增时，必须遵循以下流程：
  1. **[自动化]** 在 `sql/incremental/` 目录生成数据库DDL脚本
  2. **[人工操作]** 通知人工执行数据库变更（执行DDL）
  3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表，使用 `crudgen` 生成标准CRUD模块（Model/DAO/Service/Controller/Route），使用 `crudweb` 生成Web管理界面
  4. **[自动化]** 基于生成的CRUD模块进行迭代开发（定制代码写在 `//#region AutoCreateCode` 区域外）

---

## 仓颉规范合规性要求（来自cangjie-compliance-review.md）

- [ ] AgentMemoryService类添加`public`修饰符
- [ ] `retrieve`方法`limit`参数补充默认值`10`：`func retrieve(agentId: String, query: String, limit!: Int64 = 10)`

---

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| MEM-T001 | 数据库表设计与创建 | P0 | 0.5天 | 无 |
| MEM-T002 | AgentMemoryService核心实现 | P0 | 1.5天 | MEM-T001 |
| MEM-T003 | MemoryLayerManager分层存储 | P0 | 1天 | MEM-T002 |
| MEM-T004 | SemanticMemorySearch语义检索 | P0 | 1天 | MEM-T002 |
| MEM-T005 | MemorySharingManager共享管理 | P1 | 0.5天 | MEM-T002 |
| MEM-T006 | CRUD模块与API实现 | P0 | 1天 | MEM-T001 |
| MEM-T007 | 集成测试与验证 | P0 | 0.5天 | MEM-T001~T006 |

---

## MEM-T001: 数据库表设计与创建

**描述**: 创建agent_memories数据库表，包含向量嵌入字段。

**子任务**:
1. **[自动化]** 编写DDL文件（含VECTOR类型字段）放置在 `sql/incremental/` 目录
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表
4. **[人工操作]** 人工使用 `crudgen` 生成CRUD骨架，使用 `crudweb` 生成Web管理界面

**验收标准**:
- [ ] agent_memories表创建成功，包含embedding字段
- [ ] 索引创建成功

---

## MEM-T002: AgentMemoryService核心实现

**描述**: 实现Agent记忆服务，支持记忆的CRUD操作。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义AgentMemory数据类
2. 实现AgentMemoryService
3. 实现store/retrieve/search/delete方法
4. 与Fountain ORM集成

**验收标准**:
- [ ] 记忆正确持久化到数据库
- [ ] CRUD操作正确

---

## MEM-T003: MemoryLayerManager分层存储

**描述**: 实现四层记忆分层存储。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义MemoryLayer枚举（working/episodic/semantic/procedural）
2. 实现分层存储策略
3. 实现记忆衰减机制
4. 实现记忆压缩

**验收标准**:
- [ ] 四层记忆正确区分
- [ ] 衰减机制正确

---

## MEM-T004: SemanticMemorySearch语义检索

**描述**: 实现基于向量的语义记忆检索。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 记忆写入时自动生成嵌入向量
2. 基于向量相似度的语义检索
3. 混合检索：语义+关键词+时间衰减
4. 与RAG模块集成

**验收标准**:
- [ ] 语义检索返回相关性最高的记忆
- [ ] 混合检索正确

---

## MEM-T005: MemorySharingManager共享管理

**描述**: 实现Agent间记忆共享。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现private/shared/global三种共享范围
2. 主Agent经验标记为shared
3. 子Agent新发现上报给主Agent

**验收标准**:
- [ ] 记忆共享按作用域正确隔离

---

## MEM-T006: CRUD模块与API实现

**描述**: 基于crudgen生成的标准CRUD模块，迭代开发记忆查询API。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 使用crudgen生成AgentMemoryPO的CRUD代码
2. 实现记忆查询API
3. 遵循uctoo-v4 API规范

**验收标准**:
- [ ] 标准 CRUD API可正常调用

---

## MEM-T007: 集成测试与验证

**描述**: 编写集成测试。

**子任务**:
1. 记忆持久化测试
2. 语义检索测试
3. 跨会话记忆加载测试
4. Agent间记忆共享测试

**验收标准**:
- [ ] 所有集成测试通过