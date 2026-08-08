# GOAI 2026「新智基座」赛道：差距分析与夺冠需求规划

## 文档信息
- **项目名称**: agentskills-runtime 参赛差距分析与需求规划
- **版本**: 2.0
- **创建日期**: 2026-07-23
- **更新日期**: 2026-07-23
- **目标**: 获得GOAI 2026「新智基座」赛道第一名
- **状态**: 草稿（已整合Hermes调研、架构师理念、Harness对比分析）

---

## 1. 赛事核心要求解析

### 1.1 赛道定位
赛道的核心考察点不是"谁的Agent更聪明"，而是"谁能把多个Agent组织成一个可治理、可观测、可进化的生产级系统"。

### 1.2 五项评审维度与权重

| 维度 | 权重 | 核心考察点 |
|------|------|-----------|
| 场景价值与行业可复制性 | 25% | 真实场景、行业意义、可迁移性 |
| 多Agent协同与自主闭环能力 | 25% | ≥3个Agent协作、任务闭环、上下文传递 |
| Skill工程体系与生态复用 | 25% | Skill可复用、工程化封装、生态贡献 |
| 工程落地与运行验证及安全审计 | 20% | 可运行、可验证、可审计、安全边界 |
| 开放与开源贡献 | 5% | 开源计划、长期成长价值 |

### 1.3 关键基础设施要求
- **AgentTeams（必选）**: Manager–TeamLeader–Worker 分层架构，实现任务编排与混合框架调度
- **AgentLoop（推荐）**: 全栈观测、效果评估与自进化调优能力

### 1.4 赛程时间线
- 初赛提交截止：8月16日（方案PPT即可）
- 复赛入围公布：8月24日（Top 30）
- 复赛提交截止：9月3日（可执行代码包+Demo）
- 决赛入围公布：9月10日（Top 15）
- 线下决赛答辩：9月22日
- 颁奖：9月23日

---

## 2. 项目现有能力盘点

### 2.1 已具备的核心能力

| 能力领域 | 现有实现 | 完成度 | 对标赛事维度 |
|---------|---------|--------|------------|
| Agent框架 | CangjieMagic @agent DSL、BaseAgent、SkillAwareAgent | ★★★★☆ | 多Agent协同 |
| 多Agent协作 | LinearGroup、LeaderGroup、FreeGroup、AutoDiscussGroup | ★★★☆☆ | 多Agent协同 |
| 技能系统 | SKILL.md加载、ProgressiveSkillLoader、SkillToToolAdapter | ★★★★☆ | Skill工程体系 |
| HITL人机协作 | 三级事件处理器(@handler/@interact/@asyncInteract) | ★★★★☆ | 安全审计 |
| MCP协议 | 完整MCP客户端/服务端(stdio/sse/http) | ★★★★☆ | Skill工程体系 |
| 安全机制 | WASM沙箱、RBAC权限、JWT认证、敏感操作二次确认 | ★★★★☆ | 安全审计 |
| 记忆系统 | ShortMemory、WorkspaceLoader、MemoryService | ★★☆☆☆ | 多Agent协同 |
| 内置工具 | 19+工具(文件/网络/技能/代码/CLI) | ★★★★☆ | Skill工程体系 |
| API层 | RESTful API、WebSocket实时通信 | ★★★★☆ | 工程落地 |
| 定时任务 | Crontab调度器 | ★★★☆☆ | 工程落地 |
| RAG搜索 | 向量嵌入、混合检索、语义搜索 | ★★★☆☆ | Skill工程体系 |
| 多模型支持 | 11+LLM提供商 | ★★★★☆ | 工程落地 |
| Agent DSL | @agent/@prompt/@tool/@handler宏、执行DSL | ★★★★☆ | 多Agent协同 |
| 数据库持久化 | PostgreSQL + Fountain ORM、agents表 | ★★★☆☆ | 工程落地 |
| 前端界面 | Vue 3 + OpenTiny Vue管理后台 | ★★★☆☆ | 工程落地 |

### 2.2 已有但未完成的Spec（可复用）

| Spec名称 | 核心内容 | 对标赛事维度 | 实现状态 |
|----------|---------|------------|---------|
| agent-orchestration | DAG调度、动态重编排、资源仲裁、执行回滚 | 多Agent协同(25%) | 仅spec |
| skill-composition-engine | 技能组合DSL、数据传递、依赖解析、组合模板 | Skill工程体系(25%) | 仅spec |
| agent-memory-persistence | 记忆持久化、分层、语义检索、跨会话共享 | 多Agent协同(25%) | 仅spec |
| agent-error-recovery | 错误分类、智能重试、降级执行、熔断器、补偿事务 | 工程落地(20%) | 仅spec |
| aiagent-app-fusion | Agent运行时桥接、Memory持久化、Token计费 | 工程落地(20%) | 部分实现 |
| openclaw-compatibility | 工作空间兼容、Cron转换、Standing Orders | Skill工程体系(25%) | 仅spec |
| agents | Agent动态生成、SubAgent、协作系统 | 多Agent协同(25%) | 部分实现 |

---

## 3. 差距分析：对标赛事评分标准

### 3.1 维度一：场景价值与行业可复制性（25%）

**差距等级：🔴 严重**

| 差距项 | 说明 | 优先级 |
|--------|------|--------|
| 缺少真实业务场景Demo | 当前项目偏技术框架，缺少一个完整的、有行业价值的业务场景闭环演示 | P0 |
| 缺少行业可复制性论证 | 未展示技能和协作模式如何迁移到相似行业场景 | P1 |
| 缺少"小闭环"演示 | 赛事特别提示"场景真实、结构清晰、证据完整的小闭环更具竞争力" | P0 |

**建议场景方向**（结合项目已有能力）：
- **AI驱动软件开发全流程**：需求分析Agent → 代码生成Agent → 测试验证Agent → 部署发布Agent
- **零人工运维**：告警分析Agent → 根因定位Agent → 方案制定Agent → 执行变更Agent → 结果验证Agent
- **智能客服自主闭环**：意图识别Agent → 知识检索Agent → 方案生成Agent → 执行确认Agent

**推荐场景**：**AI驱动软件开发全流程**（与项目AI驱动开发框架定位完全吻合，且已有crudgen/crudweb/cangjie-coder等技能基础）

### 3.2 维度二：多Agent协同与自主闭环能力（25%）

**差距等级：🔴 严重**

| 差距项 | 说明 | 优先级 |
|--------|------|--------|
| 缺少AgentTeams分层架构 | 赛事要求Manager-TeamLeader-Worker分层架构，当前LeaderGroup过于简单 | P0 |
| 缺少结构化任务分解 | Agent无法将复杂任务自动分解为DAG形式的执行计划 | P0 |
| 缺少上下文传递机制 | Agent间无法结构化传递执行上下文和中间结果 | P0 |
| 缺少执行证据沉淀 | 任务执行过程无完整证据链，无法回溯和审计 | P0 |
| 缺少结果验证机制 | Agent执行结果无自动验证，无法确认任务是否真正完成 | P1 |
| 记忆系统不完善 | 无跨会话记忆、无语义检索、无Agent间记忆共享 | P1 |

### 3.3 维度三：Skill工程体系与生态复用（25%）

**差距等级：🟡 中等**

| 差距项 | 说明 | 优先级 |
|--------|------|--------|
| 缺少技能组合引擎 | 技能无法声明式组合（串行/并行/条件分支），spec已定义但未实现 | P0 |
| 缺少技能依赖解析 | 技能间依赖关系无自动解析和加载 | P1 |
| 缺少技能组合模板 | 常见组合模式无法保存为模板复用 | P1 |
| 缺少技能市场/生态 | 无技能搜索、安装、版本管理的生态体系 | P2 |
| 缺少技能执行验证 | 组合执行前无法验证技能兼容性和依赖完整性 | P1 |

**已有优势**：
- SKILL.md标准已建立
- 17个已有技能（cangjie-coder、crud-generator等）
- ProgressiveSkillLoader渐进式加载
- 语义搜索能力

### 3.4 维度四：工程落地与运行验证及安全审计（20%）

**差距等级：🟡 中等偏上**

| 差距项 | 说明 | 优先级 |
|--------|------|--------|
| 缺少完整审计链 | 当前operate_log仅记录工具调用，缺少Agent决策、任务流转的完整审计 | P0 |
| 缺少执行回滚机制 | 编排失败时无法回滚已完成的步骤 | P1 |
| 缺少审批机制 | 高风险操作无人工审批流程（HITL框架已有，但审批记录未持久化） | P1 |
| 缺少熔断保护 | 反复失败的Agent无熔断保护 | P2 |
| 缺少可运行Demo | 复赛需要可执行的AgentTeams代码包和可运行Demo | P0 |

**已有优势**：
- RBAC权限体系完善
- WASM沙箱安全隔离
- JWT认证
- HITL三级事件处理
- 敏感操作二次确认

### 3.5 维度五：开放与开源贡献（5%）

**差距等级：🟢 轻微**

| 差距项 | 说明 | 优先级 |
|--------|------|--------|
| 开源计划不够明确 | 需要更清晰的开源路线图和社区建设计划 | P2 |
| 缺少贡献者指南 | 需要CONTRIBUTING.md等社区文档 | P3 |

**已有优势**：
- 已在AtomGit和GitHub双平台开源
- MIT许可证
- 已有README、API文档、教程等

---

## 4. 夺冠需求规划

### 4.1 需求优先级矩阵

按赛事评分权重和实现难度排序：

| 优先级 | 需求编号 | 需求名称 | 对标维度 | 预估工时 | 依赖 |
|--------|---------|---------|---------|---------|------|
| P0 | GOAI-001 | AgentTeams分层协作架构 | 多Agent协同(25%) | 5天 | 无 |
| P0 | GOAI-002 | 任务分解与DAG编排引擎 | 多Agent协同(25%) | 5天 | GOAI-001 |
| P0 | GOAI-003 | 执行证据链与审计系统 | 工程落地(20%) | 3天 | GOAI-001 |
| P0 | GOAI-004 | AI驱动开发全流程Demo场景 | 场景价值(25%) | 5天 | GOAI-001,002,003 |
| P0 | GOAI-005 | 技能组合引擎核心 | Skill工程(25%) | 4天 | 无 |
| P1 | GOAI-006 | Agent间上下文传递与结果验证 | 多Agent协同(25%) | 3天 | GOAI-001,002 |
| P1 | GOAI-007 | 记忆持久化与跨会话共享 | 多Agent协同(25%) | 4天 | 无 |
| P1 | GOAI-008 | AgentLoop观测评估飞轮 | 工程落地(20%) | 4天 | GOAI-003 |
| P1 | GOAI-009 | 审批与回滚机制 | 工程落地(20%) | 3天 | GOAI-003 |
| P1 | GOAI-010 | 技能组合模板与依赖解析 | Skill工程(25%) | 3天 | GOAI-005 |
| P2 | GOAI-011 | 错误恢复与自愈系统 | 工程落地(20%) | 4天 | GOAI-003 |
| P2 | GOAI-012 | 开源计划与社区建设 | 开源贡献(5%) | 1天 | 无 |

### 4.2 核心需求详细定义

---

#### GOAI-001: AgentTeams 分层协作架构

**对标维度**: 多Agent协同与自主闭环能力(25%)

**需求描述**: 实现赛事要求的 Manager–TeamLeader–Worker 分层协作架构。Manager负责任务接收和全局规划，TeamLeader负责子团队管理和任务分配，Worker负责具体执行。

**核心能力**:
1. **Manager Agent**: 接收用户任务，分解为子任务，分配给TeamLeader，汇总结果
2. **TeamLeader Agent**: 管理一组Worker，分配子任务，监控进度，聚合Worker结果
3. **Worker Agent**: 执行具体子任务，返回执行结果和证据
4. **分层通信**: Manager↔TeamLeader↔Worker的层级消息传递
5. **动态组队**: 运行时根据任务需要动态创建/销毁Team和Worker

**与现有系统的关系**:
- 复用现有LeaderGroup，扩展为ManagerGroup
- 复用现有AgentGroup DSL，新增 `@agentTeams` 宏
- 复用现有Interaction事件系统进行层级通信

**验收标准**:
- [ ] 可创建Manager-TeamLeader-Worker三层Agent组
- [ ] Manager正确分解任务并分配给TeamLeader
- [ ] TeamLeader正确管理Worker并聚合结果
- [ ] Worker执行任务并返回结果和执行证据
- [ ] 三层Agent间消息正确传递
- [ ] 支持运行时动态调整Team组成

---

#### GOAI-002: 任务分解与DAG编排引擎

**对标维度**: 多Agent协同与自主闭环能力(25%)

**需求描述**: 实现基于DAG的任务分解和编排引擎，支持复杂任务的结构化分解、依赖管理、并行执行和动态调整。

**核心能力**:
1. **任务分解**: Manager Agent将用户任务分解为DAG形式的执行计划
2. **DAG调度**: 基于有向无环图调度步骤执行，自动识别并行步骤
3. **条件分支**: 基于前序步骤结果决定后续执行路径
4. **动态重编排**: 运行时根据执行结果动态调整后续计划
5. **执行计划持久化**: 执行计划存储到orchestration_plans表

**与现有系统的关系**:
- 复用agent-orchestration spec中的数据模型
- 复用现有AgentExecutor的react/plan-react模式
- 新增DAG解析和调度引擎

**验收标准**:
- [ ] 可创建DAG形式的执行计划并持久化
- [ ] DAG调度引擎正确识别并行步骤并并行执行
- [ ] 条件分支根据前序结果正确选择路径
- [ ] 动态重编排可在运行时调整计划
- [ ] 执行计划状态变更实时通知（WebSocket）

---

#### GOAI-003: 执行证据链与审计系统

**对标维度**: 工程落地与运行验证及安全审计(20%)

**需求描述**: 实现完整的执行证据链，记录Agent执行的每一步决策、工具调用、结果和副作用，支持执行回溯和审计。

**核心能力**:
1. **执行轨迹记录**: 记录Agent执行的每个步骤（决策、工具调用、结果）
2. **证据链完整性**: 每步执行结果包含时间戳、Agent ID、输入输出、耗时
3. **副作用追踪**: 记录每个步骤的副作用（文件修改、数据库变更）
4. **不可篡改审计日志**: 审计日志写入operate_log表，支持查询和导出
5. **执行回放**: 可根据审计日志回放Agent执行过程

**与现有系统的关系**:
- 扩展现有operate_log审计日志
- 复用EventHandlerManager的事件系统
- 复用WebSocket推送机制

**验收标准**:
- [ ] Agent执行的每个步骤都有完整的证据记录
- [ ] 证据链包含时间戳、Agent ID、输入输出、耗时
- [ ] 副作用（文件修改、数据库变更）被正确追踪
- [ ] 审计日志不可篡改且可查询
- [ ] 可根据审计日志回放Agent执行过程

---

#### GOAI-004: AI驱动开发全流程Demo场景

**对标维度**: 场景价值与行业可复制性(25%)

**需求描述**: 构建一个完整的AI驱动软件开发全流程Demo，展示3+个Agent协作完成从需求到部署的闭环，体现场景价值和行业可复制性。

**Demo场景设计**:

**场景**: 用户提交一个业务需求（如"开发一个员工管理模块"），系统自动完成从需求分析到代码生成的全流程。

**Agent角色定义**:
1. **ProductManager Agent（Manager角色）**: 接收用户需求，分析需求，分解为开发任务，分配给开发团队，验证最终结果
2. **Developer Agent（TeamLeader角色）**: 接收开发任务，规划代码生成步骤（数据库→后端→前端），分配给Worker执行，聚合代码结果
3. **CoderWorker Agent（Worker角色）**: 执行具体编码任务（生成数据库DDL、生成后端CRUD代码、生成前端页面代码）
4. **QA Agent（Worker角色）**: 验证生成的代码，执行测试，报告问题

**完整闭环流程**:
```
用户: "开发一个员工管理模块"
  → ProductManager: 分析需求，分解为[数据库设计, 后端开发, 前端开发, 测试验证]
  → Developer: 规划执行顺序，分配给CoderWorker
    → CoderWorker-1: 使用crudgen生成数据库DDL和后端CRUD
    → CoderWorker-2: 使用crudweb生成前端管理页面
    → QA Agent: 验证生成代码的完整性和正确性
  → ProductManager: 汇总结果，验证闭环，交付用户
```

**Skill复用**:
- crud-generator: 数据库DDL和CRUD代码生成
- cangjie-coder: 代码优化和修复
- skill-creator: 技能创建和验证
- file_read/file_write: 文件操作

**验收标准**:
- [ ] 3+个Agent协作完成从需求到代码的完整闭环
- [ ] 每个Agent有明确的职责和输出
- [ ] 执行过程有完整的证据链
- [ ] Demo可重复运行，结果一致
- [ ] 场景具有行业可复制性（可迁移到其他业务模块）

---

#### GOAI-005: 技能组合引擎核心

**对标维度**: Skill工程体系与生态复用(25%)

**需求描述**: 实现技能组合引擎的核心功能，支持技能的声明式组合、数据传递和执行优化。

**核心能力**:
1. **组合定义语言**: COMPOSITION.yaml格式定义技能组合
2. **技能间数据传递**: 标准化SkillOutput格式，支持输入映射表达式
3. **组合执行引擎**: 串行/并行/条件分支执行
4. **组合验证**: 执行前验证技能兼容性和依赖完整性
5. **组合与Agent集成**: 组合步骤可声明agent_type，自动创建Agent

**与现有系统的关系**:
- 复用skill-composition-engine spec中的设计
- 复用现有CompositeSkillToolManager
- 复用现有SkillToToolAdapter

**验收标准**:
- [ ] COMPOSITION.yaml格式正确解析和执行
- [ ] 技能间数据通过映射表达式正确传递
- [ ] 串行/并行/条件分支执行正确
- [ ] 组合验证在执行前正确检测问题
- [ ] 组合与Agent系统正确集成

---

#### GOAI-006: Agent间上下文传递与结果验证

**对标维度**: 多Agent协同与自主闭环能力(25%)

**需求描述**: 实现Agent间结构化的上下文传递和执行结果自动验证机制。

**核心能力**:
1. **结构化上下文传递**: Agent间传递标准化的上下文对象（任务描述、输入数据、约束条件）
2. **结果验证框架**: 每个Agent执行结果可配置验证规则（schema校验、断言检查）
3. **验证失败处理**: 验证失败时自动重试或降级执行
4. **增量结果传递**: 支持流式传递中间结果，不等待全部完成

**验收标准**:
- [ ] Agent间上下文通过标准化对象正确传递
- [ ] 执行结果按验证规则自动校验
- [ ] 验证失败时正确处理（重试/降级）
- [ ] 支持流式传递中间结果

---

#### GOAI-007: 记忆持久化与跨会话共享

**对标维度**: 多Agent协同与自主闭环能力(25%)

**需求描述**: 实现Agent记忆的数据库持久化、分层存储、语义检索和跨会话共享。

**核心能力**:
1. **记忆持久化**: 记忆写入agent_memories表，进程重启不丢失
2. **记忆分层**: 工作记忆/情景记忆/语义记忆/程序记忆
3. **语义检索**: 基于向量嵌入的语义记忆检索
4. **跨会话记忆**: Agent重启后自动加载历史记忆
5. **Agent间记忆共享**: 支持private/shared/global三种共享范围

**与现有系统的关系**:
- 复用agent-memory-persistence spec中的设计
- 复用现有ShortMemory和MemoryService
- 复用现有RAG向量搜索能力

**验收标准**:
- [ ] 记忆正确持久化到数据库
- [ ] 四层记忆正确区分和使用
- [ ] 语义检索返回相关性最高的记忆
- [ ] Agent重启后可加载历史记忆继续工作
- [ ] Agent间记忆共享按作用域正确隔离

---

#### GOAI-008: AgentLoop 观测评估飞轮

**对标维度**: 工程落地与运行验证及安全审计(20%)

**需求描述**: 实现AgentLoop观测评估飞轮，提供全栈观测、效果评估与自进化调优能力。

**核心能力**:
1. **全栈观测**: Agent执行全链路追踪（请求→决策→工具调用→结果→副作用）
2. **效果评估**: 基于执行证据链自动评估Agent执行质量（成功率、耗时、Token消耗）
3. **自进化调优**: 基于评估结果自动调整Agent策略（提示词优化、工具选择、执行路径）
4. **可视化仪表板**: Agent运行状态、协作拓扑、Token消耗实时展示

**验收标准**:
- [ ] Agent执行全链路可追踪
- [ ] 执行质量可自动评估
- [ ] 基于评估结果可自动调整策略
- [ ] 仪表板实时展示Agent运行状态

---

#### GOAI-009: 审批与回滚机制

**对标维度**: 工程落地与运行验证及安全审计(20%)

**需求描述**: 实现高风险操作的人工审批和编排失败时的执行回滚机制。

**核心能力**:
1. **审批流程**: 高风险操作暂停等待人工审批（确认/拒绝/修改）
2. **审批记录持久化**: 审批记录写入agent_approvals表
3. **执行回滚**: 编排失败时按逆序回滚已完成步骤的副作用
4. **检查点恢复**: 支持从最近检查点恢复执行

**与现有系统的关系**:
- 复用现有HITL三级事件处理
- 复用agent-orchestration spec中的回滚设计
- 扩展EventHandlerManager

**验收标准**:
- [ ] 高风险操作正确触发审批流程
- [ ] 审批记录持久化且可查询
- [ ] 编排失败时正确回滚已完成步骤
- [ ] 可从最近检查点恢复执行

---

#### GOAI-010: 技能组合模板与依赖解析

**对标维度**: Skill工程体系与生态复用(25%)

**需求描述**: 实现技能组合模板和技能依赖自动解析功能。

**核心能力**:
1. **内置组合模板**: code-gen-optimize、code-gen-test、analyze-refactor-verify等
2. **模板实例化**: 从模板创建组合实例（提供参数）
3. **依赖解析**: 解析SKILL.md中的dependencies字段，自动加载依赖技能
4. **循环依赖检测**: 检测并报告循环依赖

**验收标准**:
- [ ] 内置模板可正确实例化和执行
- [ ] 技能依赖自动解析和加载
- [ ] 循环依赖正确检测和报告

---

#### GOAI-011: 错误恢复与自愈系统

**对标维度**: 工程落地与运行验证及安全审计(20%)

**需求描述**: 实现Agent执行的错误分类、智能重试、降级执行和熔断保护。

**核心能力**:
1. **错误分类**: transient/recoverable/degradable/fatal四级分类
2. **智能重试**: 根据错误类型选择重试策略（指数退避、固定间隔）
3. **降级执行**: Agent/技能不可用时自动降级到替代方案
4. **熔断器**: 连续失败时熔断保护，半开状态探测恢复

**验收标准**:
- [ ] 错误自动分类为四种类型
- [ ] 智能重试根据错误类型选择正确策略
- [ ] 降级执行在Agent/技能不可用时正确降级
- [ ] 熔断器在连续失败时正确熔断和恢复

---

#### GOAI-012: 开源计划与社区建设

**对标维度**: 开放与开源贡献(5%)

**需求描述**: 完善开源计划和社区建设文档。

**核心能力**:
1. **开源路线图**: 明确版本规划和功能路线图
2. **贡献者指南**: CONTRIBUTING.md、开发环境搭建指南
3. **技能生态**: 技能开发规范、技能市场规划
4. **社区运营**: Issue模板、PR模板、讨论区

**验收标准**:
- [ ] 开源路线图文档完整
- [ ] CONTRIBUTING.md可指导新贡献者
- [ ] 技能开发规范文档完整

---

## 5. 实施路线图

### 5.1 阶段一：初赛准备（7月23日 - 8月16日）

**目标**: 完成初赛方案PPT，展示设计思路和核心架构

| 任务 | 工时 | 交付物 |
|------|------|--------|
| 完善AgentTeams架构设计 | 2天 | 架构设计文档 |
| 编写Demo场景方案 | 2天 | 场景方案文档 |
| 制作初赛PPT | 2天 | 方案PPT |
| 整理开源计划 | 1天 | ROADMAP.md |

### 5.2 阶段二：核心功能开发（8月17日 - 9月3日）

**目标**: 完成复赛可执行代码包和可运行Demo

| 周次 | 任务 | 交付物 |
|------|------|--------|
| 第1周 | GOAI-001 AgentTeams分层架构 + GOAI-005 技能组合引擎核心 | 可运行的AgentTeams + 组合引擎 |
| 第2周 | GOAI-002 DAG编排引擎 + GOAI-003 执行证据链 | DAG调度 + 审计系统 |
| 第3周 | GOAI-004 Demo场景 + GOAI-006 上下文传递 | 完整Demo |
| 第4周 | GOAI-007 记忆持久化 + GOAI-008 AgentLoop + GOAI-009 审批回滚 | 观测评估 + 审批回滚 |

### 5.3 阶段三：决赛准备（9月4日 - 9月22日）

**目标**: 完善Demo、准备答辩材料

| 任务 | 工时 | 交付物 |
|------|------|--------|
| GOAI-010 技能组合模板 | 3天 | 组合模板库 |
| GOAI-011 错误恢复 | 4天 | 自愈系统 |
| Demo优化和稳定性测试 | 3天 | 稳定可演示的Demo |
| 答辩PPT和视频准备 | 3天 | 答辩材料 |

---

## 6. 差异化竞争优势分析

### 6.1 相比其他参赛团队的核心优势

| 优势 | 说明 | 对标维度 |
|------|------|---------|
| 仓颉语言实现 | 国产自主可控技术栈，与赛事"新智基座"定位高度吻合 | 全部维度 |
| AI驱动开发框架 | 独特的"AI驱动开发框架"定位，不是通用Agent平台而是垂直领域基础设施 | 场景价值(25%) |
| 技能是一等公民 | 以技能为核心的设计理念，天然支持Skill工程化和复用 | Skill工程(25%) |
| 企业级安全 | RBAC权限、WASM沙箱、JWT认证、审批机制，达到企业级安全标准 | 安全审计(20%) |
| 全栈数据同构 | 通模一体(UMI)设计，后端PO↔前端ORM模型自动同构 | 工程落地(20%) |
| 已有落地案例 | 暖守黑客松、AGI Builder等实际项目验证 | 场景价值(25%) |
| 智能体互联国标 | 支持GB/Z 185-2026智能体互联国家标准 | 工程落地(20%) |

### 6.2 需要重点突出的差异化亮点

1. **"仓颉+Agent"国产自主可控基座**: 唯一使用仓颉语言实现的参赛作品，体现国产技术栈的Agent基础设施能力
2. **"AI驱动开发框架"新物种**: 不是通用Agent平台，而是将Agent与服务器端应用有机集成的AI驱动开发框架
3. **"技能是一等公民"设计哲学**: 从架构层面保证Skill的可复用性和工程化
4. **"通模一体"全栈同构**: 后端PO↔前端ORM模型自动同构，确保AI驱动开发的数据一致性
5. **企业级安全与审计**: 从设计之初就考虑了企业级安全要求

---

## 7. 风险与对策

| 风险 | 影响 | 概率 | 对策 |
|------|------|------|------|
| 仓颉语言生态不够成熟 | 开发效率受限 | 中 | 复用已有基础设施，避免重新开发 |
| DAG编排引擎实现复杂 | 可能延期 | 高 | 先实现简化版MVP，逐步完善 |
| Demo稳定性不足 | 答辩演示风险 | 中 | 提前录制Demo视频作为备份 |
| AgentTeams架构与赛事要求不完全匹配 | 评分受影响 | 低 | 仔细研究赛事AgentTeams规范，确保对齐 |
| 多Agent协作调试困难 | 开发效率受限 | 高 | 完善日志和观测系统，便于调试 |

---

## 8. 总结

agentskills-runtime项目在Agent框架、技能系统、安全机制等方面已有扎实基础，但在赛事核心考察的**多Agent分层协作架构（AgentTeams）**、**执行证据链与审计**、**真实业务场景闭环Demo**三个维度存在明显差距。

夺冠的关键在于：
1. **快速实现AgentTeams分层架构**，这是赛事的必选基点
2. **构建一个真实、完整、有行业价值的Demo场景**，体现"小闭环"竞争力
3. **完善执行证据链和审计系统**，证明系统的可治理、可观测、可审计能力
4. **突出差异化优势**：仓颉语言、AI驱动开发框架、技能一等公民、企业级安全

时间紧迫，应优先实现P0需求（GOAI-001~005），确保复赛提交时有可运行的AgentTeams代码包和完整Demo。

---

## 9. 架构优化方向：从固定程序到可配置引擎

### 9.1 核心设计哲学：确定性优先，AI增强

基于架构师观点（AIDrivenArchitecture.md）和Harness对比分析，确立以下架构原则：

**"确定性优先，AI增强"原则**：
- 凡是可确定性实现的逻辑（CRUD、权限、同步、调度），用代码实现
- 凡是需要推理、判断、创造的逻辑（任务分解、技能选择、代码生成），由AI驱动
- 两者不是替代关系，而是分层协作关系
- 这是"双驱动"框架的架构根基：有AI是AI驱动自动化+全部框架能力，无AI仍是完备的服务提供方

**"可配置引擎优先于硬编码程序"原则**：
- 不硬编码业务功能到系统中，所有功能均可通过可视化配置实现动态调整
- 参照已实现的从多目录agents.md和子agent定义的markdown文件动态加载和生成agents
- 参照从多目录动态加载agentskills、从crontab配置loop等已实现的方案
- 区分业务功能层（可配置化）和基础设施层（需硬编码保障确定性）

### 9.2 已验证的可配置引擎模式

agentskills-runtime中已成功实现的可配置引擎模式，应作为新功能的设计范式：

| 已实现模式 | 实现方式 | 可借鉴到 |
|-----------|---------|---------|
| Agent动态生成 | 从多目录agents.md和子agent定义的markdown文件动态加载 | AgentTeams分层架构应通过配置定义角色和层级 |
| 技能动态加载 | 从多目录动态加载agentskills，SKILL.md标准 | 技能组合引擎应通过配置定义组合模板 |
| 定时任务配置 | 从crontab配置loop | DAG编排应通过配置定义执行计划 |
| RBAC权限配置 | 数据库驱动的权限体系 | 安全护栏应通过配置定义规则 |
| 多模型适配 | 11+LLM提供商适配器模式 | AgentLoop应通过配置选择执行策略 |

### 9.3 新功能应遵循的可配置引擎设计

**AgentTeams分层架构（GOAI-001）**：
- ❌ 不应：硬编码Manager/TeamLeader/Worker三种Agent类型
- ✅ 应该：通过YAML/Markdown配置定义Agent角色和层级关系，引擎动态创建
- 配置示例：
```yaml
# agent_teams.yaml
team:
  name: "dev-team"
  manager:
    agent_type: "product-manager"
    skills: ["requirement-analysis", "task-decomposition"]
  leaders:
    - agent_type: "developer"
      skills: ["code-generation", "code-review"]
      workers:
        - agent_type: "coder-worker"
          skills: ["crudgen", "crudweb", "cangjie-coder"]
        - agent_type: "qa-worker"
          skills: ["test-generation", "code-verification"]
```

**DAG编排引擎（GOAI-002）**：
- ❌ 不应：硬编码执行步骤和分支逻辑
- ✅ 应该：通过DAG配置定义执行计划，引擎解析并调度
- 参考Hermes的Kanban系统：通过SQLite持久化任务状态，通过dispatcher协调多worker

**技能组合引擎（GOAI-005）**：
- ❌ 不应：硬编码技能组合的执行顺序
- ✅ 应该：通过COMPOSITION.yaml定义组合，引擎解析并执行
- 参考Hermes的Footprint Ladder：优先扩展已有代码 → CLI命令+技能 → 服务门控工具 → 插件 → MCP服务器 → 核心工具

---

## 10. 多Agent协同能力：从固定程序到AI推理决策

### 10.1 当前差距

当前agentskills-runtime的Agent协作模式是**固定程序式**的：
- LinearGroup：线性顺序执行
- LeaderGroup：Leader分配任务给Follower
- FreeGroup：自由讨论
- AutoDiscussGroup：自动讨论

这些模式都是**预定义的协作策略**，无法根据任务特征动态选择最优协作方式。

### 10.2 目标：AI推理驱动的协同决策

参考Hermes的delegation系统和Kanban多Agent工作队列，以及Claude Code的子Agent编排模式，提出以下改进方向：

**用Skills替代固定协同程序**：
- 设计一组"协同技能"（collaboration skills），由大模型自行推理决策如何协同
- 协同技能包括：任务分解、Agent选择、上下文传递、结果聚合、冲突解决
- 大模型根据任务特征自动选择和组合这些协同技能

**协同技能设计**：

| 协同技能 | 功能 | 对标Hermes/Claude Code |
|---------|------|----------------------|
| `task-decompose` | 将复杂任务分解为子任务DAG | Hermes delegate_task的goal模式 |
| `agent-select` | 根据子任务选择合适的Agent | Claude Code的子Agent类型选择 |
| `context-pass` | 在Agent间传递结构化上下文 | Hermes的context_from链式传递 |
| `result-merge` | 聚合多个Agent的执行结果 | Hermes的batch delegate_task |
| `conflict-resolve` | 解决Agent间的执行冲突 | Hermes Kanban的block/unblock |
| `handover` | 将控制权移交给另一个Agent | OpenAI SDK的移交机制 |

**实现路径**：
1. 将协同技能定义为SKILL.md格式的技能文件
2. 大模型在执行任务时自动推理需要哪些协同技能
3. 协同技能通过调用工具/skills实现具体的协同操作
4. 保持"确定性优先"：关键路径（权限、安全、审计）仍用确定性代码保障

### 10.3 参考CodeArts Agent的规范驱动开发机制

CodeArts Agent内置了规范驱动开发（SDD）的技能和subagent机制，可以借鉴到AI驱动软件开发全流程场景中：

**SDD流程映射到AgentTeams**：
1. **Spec Agent（需求规格）** → Manager角色：接收用户需求，生成spec.md
2. **Design Agent（技术设计）** → TeamLeader角色：基于spec生成design.md
3. **Task Agent（任务分解）** → TeamLeader角色：基于design生成tasks.md
4. **Code Agent（编码实现）** → Worker角色：基于tasks执行编码
5. **Test Agent（测试验证）** → Worker角色：验证代码质量

**关键借鉴点**：
- SDD的spec→design→tasks→code→test流程天然适合AgentTeams的分层架构
- 每个阶段的输出（spec.md、design.md、tasks.md）就是Agent间上下文传递的标准化载体
- SDD的验收条件天然适合作为Agent执行结果的验证规则
- SDD的"what to build"vs"how to build"分离，与"确定性优先，AI增强"原则完美契合

---

## 11. AI驱动软件开发全流程：全栈自完备的开发框架

### 11.1 场景定位

AI驱动软件开发全流程是agentskills-runtime最核心的差异化场景，与项目的"AI驱动开发框架"定位完全吻合。需要结合和复用已有的crudgen、crudweb、loaddbinfo等工具和能力，形成开发框架自完备的全栈全流程开发能力。

### 11.2 全栈全流程能力矩阵

| 流程阶段 | 已有能力 | 需要增强 | 对标赛事维度 |
|---------|---------|---------|------------|
| **需求分析** | SKILL.md标准、RAG搜索 | Spec Agent技能（SDD规范驱动） | 场景价值(25%) |
| **数据建模** | loaddbinfo（数据库信息加载） | Agent自动分析业务实体、生成ER模型 | Skill工程(25%) |
| **代码生成（后端）** | crudgen（CRUD代码生成）、cangjie-coder | Agent编排多表CRUD生成、代码优化 | Skill工程(25%) |
| **代码生成（前端）** | crudweb（前端CRUD页面生成） | Agent生成Vue 3+OpenTiny页面、表单校验 | Skill工程(25%) |
| **代码验证** | file_read/file_write工具 | Agent自动编译、测试、代码检查 | 工程落地(20%) |
| **部署发布** | cli_execute工具 | Agent执行cjpm构建、部署脚本 | 工程落地(20%) |

### 11.3 Demo场景增强设计

**增强后的完整闭环流程**：

```
用户: "开发一个员工管理模块"
  → SpecAgent(Manager): 分析需求，生成spec.md
    → 定义实体（员工、部门、岗位）
    → 定义CRUD接口（增删改查）
    → 定义业务规则（工号唯一、部门归属）
  → DesignAgent(TeamLeader): 基于spec生成技术设计
    → 数据库表结构设计
    → API接口设计
    → 前后端模型同构映射（UMI规范）
  → CoderAgent(Worker): 执行代码生成
    → loaddbinfo: 加载数据库信息
    → crudgen: 生成仓颉后端CRUD代码
    → crudweb: 生成Vue 3前端管理页面
    → cangjie-coder: 代码优化和修复
  → QAAgent(Worker): 验证生成代码
    → cjpm build: 编译验证
    → 代码完整性检查
    → 业务规则一致性验证
  → SpecAgent(Manager): 汇总结果，验证闭环
```

### 11.4 与已有基础设施的集成

**crudgen集成**：
- 作为CoderWorker的核心技能
- 输入：数据库表结构（来自loaddbinfo或DesignAgent生成）
- 输出：仓颉后端CRUD代码（Controller/Service/DAO/Entity）
- 增强：支持Agent动态配置生成模板和代码风格

**crudweb集成**：
- 作为CoderWorker的前端生成技能
- 输入：后端API定义（来自crudgen输出）
- 输出：Vue 3 + OpenTiny Vue前端管理页面
- 增强：支持Agent根据业务需求定制页面布局和交互

**loaddbinfo集成**：
- 作为DesignAgent的数据发现技能
- 输入：数据库连接配置
- 输出：表结构、字段信息、关系信息
- 增强：支持Agent分析业务实体关系，自动生成ER模型

**cangjie-coder集成**：
- 作为CoderWorker的代码优化技能
- 输入：生成的代码文件
- 输出：优化后的代码（修复编译错误、优化性能）
- 增强：支持Agent在代码生成后自动调用优化

---

## 12. Hermes项目借鉴：Skills自进化机制与工程实践

### 12.1 Hermes项目概述

Hermes Agent（由Nous Research构建）是目前开源社区star数排名前列的支持skills自进化机制的开源项目，其核心定位是"自进化的AI代理"（The self-improving AI agent）。

**核心特性**：
- 内置学习闭环：从经验中创建技能，在使用中改进技能
- 主动持久化知识：定期自我提醒，搜索过往对话
- 跨会话用户建模：通过Honcho辩证式用户建模构建深度理解
- 兼容agentskills.io开放标准
- 40+工具、20+消息平台、6种终端后端
- Kanban多Agent工作队列系统
- 技能Curator（策展人）自动维护系统

### 12.2 可借鉴的核心机制

#### 12.2.1 技能自进化闭环（Curator系统）

**Hermes实现**：
- **Curator**：后台技能维护编排器，定期审查Agent创建的技能
- **学习图谱**（learning_graph）：可视化技能间的关联关系
- **技能使用追踪**（skill_usage）：记录每个技能的使用次数、查看次数、修改次数、最后活动时间
- **自动状态流转**：active → stale → archived，基于使用频率自动转换
- **LLM审查**：使用辅助模型审查技能质量，可pin/archive/consolidate/patch
- **严格不变量**：只触碰Agent创建的技能，永不自动删除（只归档），Pinned技能豁免

**agentskills-runtime借鉴方案**：

| Hermes机制 | agentskills-runtime适配 | 优先级 |
|-----------|----------------------|--------|
| Curator后台审查 | 实现`skill-curator`技能，定期审查Agent创建的技能 | P1 |
| 技能使用追踪 | 扩展operate_log，增加技能使用统计 | P1 |
| 自动状态流转 | 在SKILL.md中增加`state`和`last_activity_at`字段 | P2 |
| LLM审查 | 使用辅助模型审查技能质量，生成改进建议 | P2 |
| 学习图谱 | 基于技能的`related_skills`字段构建关联图谱 | P3 |
| 技能归档与恢复 | 实现`skill-archive`和`skill-restore`技能 | P2 |

**实现原则**：
- Curator应作为可配置引擎实现，而非硬编码程序
- 审查规则通过YAML配置定义，引擎动态执行
- 参照crontab配置loop的模式，Curator通过crontab定期触发
- 保持"确定性优先"：归档操作需人工确认（HITL）

#### 12.2.2 记忆提供者插件体系

**Hermes实现**：
- `MemoryProvider` ABC定义了记忆提供者的标准接口
- 生命周期：initialize → system_prompt_block → prefetch → sync_turn → get_tool_schemas → handle_tool_call → shutdown
- 可选钩子：on_turn_start、on_session_end、on_session_switch、on_pre_compress、on_memory_write、on_delegation
- 已有8+记忆提供者：honcho、mem0、supermemory、byterover、hindsight、holographic、openviking、retaindb
- 一个外部提供者限制：防止工具schema膨胀和冲突

**agentskills-runtime借鉴方案**：
- 设计`MemoryProvider`接口（仓颉protocol），与现有ShortMemory和MemoryService兼容
- 实现内置提供者：`builtin`（基于现有MEMORY.md/SOUL.md）
- 实现数据库提供者：`postgres`（基于现有Fountain ORM和agents表）
- 实现向量提供者：`vector`（基于现有RAG搜索能力）
- 提供者选择通过配置文件指定，引擎动态加载

#### 12.2.3 验证证据账本

**Hermes实现**：
- `verification_evidence.py`：记录Agent在代码工作空间中实际验证了什么
- 被动设计：从不决定运行测试套件，从不阻止完成，从不将目标检查升级为"仓库全绿"
- 分类记录：command、canonical_command、kind、scope、status、exit_code、output_summary
- SQLite持久化，30天保留期
- 会话级和仓库级聚合

**agentskills-runtime借鉴方案**：
- 扩展GOAI-003执行证据链，增加验证证据子模块
- 验证证据分类：编译验证（cjpm build）、代码检查（lint）、业务规则验证、完整性验证
- 参照Hermes的被动设计：记录验证结果但不阻止Agent继续执行
- 验证证据持久化到数据库，支持回溯和审计

#### 12.2.4 子Agent委派与并行

**Hermes实现**：
- `delegate_task`工具：生成隔离子Agent处理子任务
- 两种形态：单个（goal）和批量并行（tasks列表）
- 两种角色：leaf（专注worker，不能委派）和orchestrator（可继续委派）
- 后台模式：`background=true`立即返回delegation id
- 配置控制：max_concurrent_children、max_spawn_depth、child_timeout_seconds

**agentskills-runtime借鉴方案**：
- 设计`delegate-task`技能，作为Agent间委派的标准接口
- 支持单个委派和批量并行委派
- 支持leaf和orchestrator两种角色
- 通过配置控制并发数、嵌套深度、超时时间
- 与AgentTeams分层架构集成：Manager→TeamLeader→Worker的委派链

#### 12.2.5 Kanban多Agent工作队列

**Hermes实现**：
- SQLite持久化的看板系统，支持多Profile/Worker协作
- 任务生命周期：create → assign → claim → complete/block
- Dispatcher：长循环（默认60s），回收过期claim、提升ready任务、原子claim、spawn worker
- 隔离模型：Board是硬边界，Tenant是软命名空间
- 失败保护：连续失败超过limit自动block

**agentskills-runtime借鉴方案**：
- 设计`agent-kanban`技能，实现Agent间任务队列
- 任务持久化到数据库（复用现有agents表或新建agent_tasks表）
- 支持任务分配、认领、完成、阻塞
- 与AgentTeams分层架构集成：Manager分配任务到看板，Worker从看板认领任务
- 失败保护：连续失败自动阻塞，防止spin loop

#### 12.2.6 Footprint Ladder（足迹阶梯）

**Hermes实现**：
- 新能力的决策阶梯，从最小足迹到最大足迹：
  1. 扩展已有代码（零新表面）
  2. CLI命令+技能（零模型工具足迹）
  3. 服务门控工具（check_fn，条件激活）
  4. 插件（第三方/小众能力）
  5. MCP服务器（零永久核心schema足迹）
  6. 新核心工具（最后手段）

**agentskills-runtime借鉴方案**：
- 建立类似的"能力扩展决策阶梯"
- 优先级：扩展已有技能 → 新技能（SKILL.md） → 服务门控工具 → 插件 → MCP服务器 → 新核心工具
- 这与"可配置引擎优先于硬编码程序"原则完全一致
- 新功能应优先通过技能实现，而非硬编码到核心

### 12.3 Hermes与agentskills-runtime架构对比

| 维度 | Hermes (Python) | agentskills-runtime (仓颉) | 借鉴方向 |
|------|----------------|--------------------------|---------|
| **语言** | Python (解释型) | 仓颉 (编译型) | 保持仓颉性能优势 |
| **核心循环** | 同步while循环 | ReactExecutor | 增强为TAO循环 |
| **技能系统** | SKILL.md + Curator | SKILL.md + ProgressiveSkillLoader | 增加Curator机制 |
| **记忆系统** | MemoryProvider ABC + 8+插件 | ShortMemory + MemoryService | 增加Provider接口 |
| **子Agent** | delegate_task + Kanban | AgentGroup DSL | 增加委派和看板 |
| **验证** | verification_evidence | operate_log | 增加验证证据 |
| **安全** | 命令审批 + DM配对 | RBAC + WASM沙箱 + HITL | 保持已有优势 |
| **上下文管理** | 5层压缩管道 | 基础对话管理 | 增加多层压缩 |
| **插件系统** | PluginManager + ABC | 无 | 增加插件接口 |
| **提示缓存** | 对话级缓存（sacred） | 无 | 增加缓存机制 |

---

## 13. 更新后的需求优先级矩阵

基于新信息，调整需求优先级和新增需求：

### 13.1 新增需求

| 优先级 | 需求编号 | 需求名称 | 对标维度 | 预估工时 | 依赖 | 来源 |
|--------|---------|---------|---------|---------|------|------|
| P0 | GOAI-013 | SDD规范驱动开发技能集 | 场景价值(25%) | 3天 | GOAI-001 | CodeArts SDD机制 |
| P0 | GOAI-014 | 全栈代码生成闭环（crudgen+crudweb+loaddbinfo集成） | 场景价值(25%) | 3天 | GOAI-013 | 已有基础设施 |
| P1 | GOAI-015 | 技能自进化闭环（Curator机制） | Skill工程(25%) | 4天 | GOAI-005 | Hermes Curator |
| P1 | GOAI-016 | 协同技能集（AI推理驱动的Agent协同） | 多Agent协同(25%) | 4天 | GOAI-001 | Hermes delegation |
| P1 | GOAI-017 | 验证证据账本 | 工程落地(20%) | 2天 | GOAI-003 | Hermes verification_evidence |
| P1 | GOAI-018 | Agent Kanban任务队列 | 多Agent协同(25%) | 3天 | GOAI-001 | Hermes Kanban |
| P2 | GOAI-019 | 记忆提供者插件体系 | 多Agent协同(25%) | 4天 | GOAI-007 | Hermes MemoryProvider |
| P2 | GOAI-020 | 上下文多层压缩管道 | 工程落地(20%) | 3天 | 无 | Claude Code 5层压缩 |
| P2 | GOAI-021 | 提示缓存机制 | 工程落地(20%) | 3天 | 无 | Hermes prompt caching |

### 13.2 调整后的完整优先级矩阵

| 优先级 | 需求编号 | 需求名称 | 对标维度 | 预估工时 | 关键设计原则 |
|--------|---------|---------|---------|---------|------------|
| P0 | GOAI-001 | AgentTeams分层协作架构 | 多Agent协同(25%) | 5天 | 可配置引擎：YAML定义角色和层级 |
| P0 | GOAI-002 | 任务分解与DAG编排引擎 | 多Agent协同(25%) | 5天 | 可配置引擎：DAG配置定义执行计划 |
| P0 | GOAI-003 | 执行证据链与审计系统 | 工程落地(20%) | 3天 | 扩展operate_log，增加验证证据 |
| P0 | GOAI-004 | AI驱动开发全流程Demo场景 | 场景价值(25%) | 5天 | SDD流程+全栈代码生成闭环 |
| P0 | GOAI-005 | 技能组合引擎核心 | Skill工程(25%) | 4天 | Footprint Ladder决策阶梯 |
| P0 | GOAI-013 | SDD规范驱动开发技能集 | 场景价值(25%) | 3天 | 借鉴CodeArts SDD机制 |
| P0 | GOAI-014 | 全栈代码生成闭环 | 场景价值(25%) | 3天 | 复用crudgen/crudweb/loaddbinfo |
| P1 | GOAI-006 | Agent间上下文传递与结果验证 | 多Agent协同(25%) | 3天 | 协同技能：context-pass、result-merge |
| P1 | GOAI-007 | 记忆持久化与跨会话共享 | 多Agent协同(25%) | 4天 | MemoryProvider接口 |
| P1 | GOAI-008 | AgentLoop观测评估飞轮 | 工程落地(20%) | 4天 | 确定性优先：观测用代码，调优用AI |
| P1 | GOAI-009 | 审批与回滚机制 | 工程落地(20%) | 3天 | 复用HITL，扩展审批记录 |
| P1 | GOAI-010 | 技能组合模板与依赖解析 | Skill工程(25%) | 3天 | COMPOSITION.yaml配置驱动 |
| P1 | GOAI-015 | 技能自进化闭环 | Skill工程(25%) | 4天 | 借鉴Hermes Curator |
| P1 | GOAI-016 | 协同技能集 | 多Agent协同(25%) | 4天 | AI推理决策替代固定程序 |
| P1 | GOAI-017 | 验证证据账本 | 工程落地(20%) | 2天 | 借鉴Hermes verification_evidence |
| P1 | GOAI-018 | Agent Kanban任务队列 | 多Agent协同(25%) | 3天 | 借鉴Hermes Kanban |
| P2 | GOAI-011 | 错误恢复与自愈系统 | 工程落地(20%) | 4天 | 四级错误分类 |
| P2 | GOAI-012 | 开源计划与社区建设 | 开源贡献(5%) | 1天 | - |
| P2 | GOAI-019 | 记忆提供者插件体系 | 多Agent协同(25%) | 4天 | Hermes MemoryProvider ABC |
| P2 | GOAI-020 | 上下文多层压缩管道 | 工程落地(20%) | 3天 | Claude Code 5层压缩 |
| P2 | GOAI-021 | 提示缓存机制 | 工程落地(20%) | 3天 | Hermes prompt caching |

### 13.3 更新后的实施路线图

#### 阶段一：初赛准备（7月23日 - 8月16日）

**目标**：完成初赛方案PPT，展示设计思路和核心架构

| 任务 | 工时 | 交付物 | 关键亮点 |
|------|------|--------|---------|
| 完善AgentTeams架构设计 | 2天 | 架构设计文档 | 可配置引擎+协同技能 |
| 编写Demo场景方案 | 2天 | 场景方案文档 | SDD流程+全栈代码生成 |
| 制作初赛PPT | 2天 | 方案PPT | 突出差异化优势 |
| 整理开源计划 | 1天 | ROADMAP.md | 技能自进化路线图 |

**PPT重点突出**：
1. **"双驱动"架构**：AI驱动+确定性框架，有AI是AI驱动，无AI仍是完备框架
2. **"可配置引擎"设计**：不硬编码业务功能，所有功能可配置
3. **"技能自进化"闭环**：从经验中创建技能，在使用中改进技能
4. **"全栈代码生成"闭环**：从需求到部署的完整AI驱动开发流程
5. **"仓颉+Agent"国产自主可控基座**：唯一使用仓颉语言实现的参赛作品

#### 阶段二：核心功能开发（8月17日 - 9月3日）

**目标**：完成复赛可执行代码包和可运行Demo

| 周次 | 任务 | 交付物 | 设计原则 |
|------|------|--------|---------|
| 第1周 | GOAI-001 AgentTeams + GOAI-013 SDD技能集 + GOAI-014 全栈代码生成 | 可运行的AgentTeams + SDD流程 | 可配置引擎+复用已有基础设施 |
| 第2周 | GOAI-002 DAG编排 + GOAI-003 证据链 + GOAI-017 验证证据 | DAG调度 + 审计系统 | 可配置引擎+验证证据账本 |
| 第3周 | GOAI-004 Demo场景 + GOAI-005 技能组合 + GOAI-016 协同技能 | 完整Demo | SDD流程+协同技能+全栈代码生成 |
| 第4周 | GOAI-006 上下文传递 + GOAI-007 记忆持久化 + GOAI-015 技能自进化 + GOAI-018 Kanban | 记忆+自进化+看板 | MemoryProvider+Curator+Kanban |

#### 阶段三：决赛准备（9月4日 - 9月22日）

**目标**：完善Demo、准备答辩材料

| 任务 | 工时 | 交付物 |
|------|------|--------|
| GOAI-008 AgentLoop + GOAI-009 审批回滚 | 5天 | 观测评估+审批回滚 |
| GOAI-010 组合模板 + GOAI-020 上下文压缩 | 5天 | 组合模板库+压缩管道 |
| Demo优化和稳定性测试 | 3天 | 稳定可演示的Demo |
| 答辩PPT和视频准备 | 3天 | 答辩材料 |

---

## 14. 更新后的差异化竞争优势

### 14.1 相比其他参赛团队的核心优势（更新）

| 优势 | 说明 | 对标维度 | 新增/增强 |
|------|------|---------|----------|
| 仓颉语言实现 | 国产自主可控技术栈，与赛事"新智基座"定位高度吻合 | 全部维度 | 原有 |
| AI驱动开发框架 | 独特的"双驱动"定位：有AI是AI驱动，无AI仍是完备框架 | 场景价值(25%) | **增强**：明确"确定性优先，AI增强"原则 |
| 技能是一等公民 | 以技能为核心的设计理念，天然支持Skill工程化和复用 | Skill工程(25%) | **增强**：增加技能自进化闭环 |
| 可配置引擎 | 不硬编码业务功能，所有功能通过配置动态调整 | 全部维度 | **新增**：明确设计原则和实现范式 |
| 全栈代码生成闭环 | crudgen+crudweb+loaddbinfo形成从需求到部署的完整闭环 | 场景价值(25%) | **新增**：整合已有基础设施 |
| SDD规范驱动开发 | 借鉴CodeArts SDD机制，实现spec→design→tasks→code→test流程 | 场景价值(25%) | **新增**：AI驱动开发全流程 |
| 协同技能 | AI推理驱动的Agent协同，替代固定程序 | 多Agent协同(25%) | **新增**：大模型自行决策如何协同 |
| 企业级安全 | RBAC权限、WASM沙箱、JWT认证、审批机制 | 安全审计(20%) | 原有 |
| 全栈数据同构 | UMI设计，后端PO↔前端ORM模型自动同构 | 工程落地(20%) | 原有 |
| 智能体互联国标 | 支持GB/Z 185-2026智能体互联国家标准 | 工程落地(20%) | 原有 |

### 14.2 需要重点突出的差异化亮点（更新）

1. **"仓颉+Agent"国产自主可控基座**：唯一使用仓颉语言实现的参赛作品，体现国产技术栈的Agent基础设施能力
2. **"双驱动"架构新物种**：不是通用Agent平台，也不是纯Harness，而是"确定性优先，AI增强"的AI驱动开发框架
3. **"可配置引擎"设计哲学**：不硬编码业务功能，所有功能通过配置动态调整，与"技能是一等公民"理念一脉相承
4. **"技能自进化"闭环**：从经验中创建技能，在使用中改进技能，实现AgentLoop的自进化调优
5. **"全栈代码生成"闭环**：crudgen+crudweb+loaddbinfo形成从需求到部署的完整AI驱动开发流程
6. **"SDD规范驱动"开发流程**：spec→design→tasks→code→test的标准化AI驱动软件开发流程
7. **"协同技能"AI推理决策**：大模型自行推理决策如何协同，替代固定程序的协作模式
8. **"通模一体"全栈同构**：后端PO↔前端ORM模型自动同构，确保AI驱动开发的数据一致性

---

## 15. 更新后的风险与对策

| 风险 | 影响 | 概率 | 对策 | 新增/更新 |
|------|------|------|------|----------|
| 仓颉语言生态不够成熟 | 开发效率受限 | 中 | 复用已有基础设施，AI辅助开发（Metis已验证可行） | 更新：Metis验证降低风险 |
| DAG编排引擎实现复杂 | 可能延期 | 高 | 先实现简化版MVP，通过配置驱动而非硬编码 | 更新：可配置引擎降低复杂度 |
| Demo稳定性不足 | 答辩演示风险 | 中 | 提前录制Demo视频作为备份 | 原有 |
| AgentTeams架构与赛事要求不完全匹配 | 评分受影响 | 低 | 仔细研究赛事AgentTeams规范，确保对齐 | 原有 |
| 多Agent协作调试困难 | 开发效率受限 | 高 | 完善日志和观测系统，Kanban看板可视化 | 更新：Kanban降低调试难度 |
| 协同技能AI推理不稳定 | 协同效果不可控 | 中 | 保持关键路径确定性，AI推理仅用于非关键决策 | 新增 |
| 技能自进化误操作 | 归档有用技能 | 低 | 参照Hermes：永不自动删除，只归档，Pinned技能豁免 | 新增 |
| 全栈代码生成质量不足 | Demo效果不佳 | 中 | cangjie-coder技能二次优化，验证证据账本检查 | 新增 |

---

## 16. 总结（更新版）

agentskills-runtime项目在Agent框架、技能系统、安全机制等方面已有扎实基础，通过整合Hermes项目的skills自进化机制、CodeArts的SDD规范驱动开发理念、以及架构师的"确定性优先，AI增强"原则，可以形成以下夺冠策略：

**核心策略**：
1. **快速实现AgentTeams分层架构**（可配置引擎方式），这是赛事的必选基点
2. **构建SDD规范驱动+全栈代码生成的完整Demo**，体现场景价值和行业可复制性
3. **实现技能自进化闭环**，区别于其他参赛作品的独特Skill工程能力
4. **用协同技能替代固定程序**，展示AI推理驱动的多Agent协同
5. **突出差异化优势**：仓颉语言、双驱动架构、可配置引擎、全栈代码生成、技能自进化

**关键设计原则**：
- **确定性优先，AI增强**：确定性代码做确定的事，AI做推理决策
- **可配置引擎优先于硬编码程序**：所有功能通过配置动态调整
- **复用和优化已有基础设施**：crudgen/crudweb/loaddbinfo/cangjie-coder
- **技能是一等公民**：新功能优先通过技能实现

时间紧迫，应优先实现P0需求（GOAI-001~005, GOAI-013~014），确保复赛提交时有可运行的AgentTeams代码包、SDD规范驱动的完整Demo、和技能自进化闭环的演示。

---

## 17. Coding Agent方向增强：专用语言多Skills编排协作架构

### 17.1 背景与动机

agentskills-runtime的作者在仓颉编程语言社区提出了"采用大模型通用能力，生成高质量仓颉代码"的方案，核心思路是**专用语言多Agent协作架构**：每个subagent负责编写特定语言的代码，专用subagent加载此编程语言的相关资料和编程规范等作为上下文，然后通过特定工作流生成此编程语言的代码。

随着agentskills标准广泛采用，该架构已进化为**专用语言多Skills编排协作**：

```
专用语言多Agent协作架构 → 专用语言多Skills编排协作
    (subagent+工作流)         (skills+SOP+agents子目录)
```

**进化历程**：
1. **阶段一**：专用subagent + 硬编码工作流 → 每个subagent加载特定语言上下文
2. **阶段二**：专用skills + SOP编排 → CangjieSkills静态文档型技能 + cangjie-coder动态SOP技能
3. **阶段三（目标）**：专用skills + agents子目录 + 多skills编排协作 → 完整的coding agent能力

**已验证的实证结果**：采用以上方案已实现用大模型通用能力生成高质量仓颉代码，这是agentskills-runtime作为coding agent的核心差异化能力。

### 17.2 当前cangjie-coder技能现状分析

#### 17.2.1 现有能力

当前cangjie-coder技能（v2.1.0）已实现：
- **四步工作流程**：查阅(Consult) → 检索(Retrieval) → 编辑(Editing) → 写入(Writing)
- **依赖声明**：dependencies字段声明了cangjie-language-guide和cangjie-full-docs
- **代码片段检索**：从CangjieMagic/resource目录搜索现有代码片段
- **文档查阅**：从CangjieSkills技能路径查阅官方文档和语言规范
- **编辑适配**：基于文档规范修改代码，应用最佳实践
- **文件写入**：将修改后的代码写入正确的文件位置

#### 17.2.2 关键差距

| 差距项 | 说明 | 影响 |
|--------|------|------|
| **缺少agents子目录** | skill-creator已有agents子目录（analyzer.md、comparator.md、grader.md），但cangjie-coder没有 | 无法声明subagent进行技能的分工执行 |
| **缺少scripts子目录** | skill-creator已有scripts子目录（9个Python脚本），但cangjie-coder没有 | 无法执行确定性代码操作（编译验证、语法检查等） |
| **缺少references子目录** | CangjieSkills有references/子目录，但cangjie-coder未整合 | 大量文档需要在SKILL.md中内联，导致文件过长 |
| **缺少编译验证能力** | 无法调用cjpm build验证生成的代码 | 代码质量无法自动验证 |
| **缺少测试生成能力** | 无法自动生成仓颉单元测试 | 代码可靠性无法保障 |
| **缺少错误修复闭环** | 编译错误无法自动修复 | 需要人工介入处理编译错误 |
| **SOP工作流是静态描述** | 四步工作流写在SKILL.md中，由大模型自行遵循 | 执行一致性依赖模型能力，无法保证 |

### 17.3 skill-creator的subagent机制分析

skill-creator技能已成功实现了agents子目录模式，是cangjie-coder完善的重要参考：

#### 17.3.1 agents子目录结构

```
skill-creator/
├── SKILL.md                    # 主技能定义
├── agents/                     # subagent定义
│   ├── analyzer.md             # 事后分析Agent（盲比较结果深度分析）
│   ├── comparator.md           # 盲比较Agent（不知技能身份的盲评）
│   └── grader.md               # 评分Agent（期望断言评分）
├── scripts/                    # 确定性脚本
│   ├── aggregate_benchmark.py  # 基准测试聚合
│   ├── generate_report.py      # 报告生成
│   ├── improve_description.py  # 描述优化
│   ├── package_skill.py        # 技能打包
│   ├── quick_validate.py       # 快速验证
│   ├── run_eval.py             # 评估运行
│   ├── run_loop.py             # 循环运行
│   └── utils.py                # 工具函数
├── assets/                     # 资源文件
├── references/                 # 参考文档
└── eval-viewer/                # 评估查看器
```

#### 17.3.2 subagent声明模式

每个agent通过YAML frontmatter声明：

```yaml
---
name: analyzer
agent_type: sub              # sub表示子Agent
description: 事后分析Agent...
version: 1.0.0
author: System
tools:                       # 声明可使用的工具
  - file_read
  - file_write
model: claude-3-sonnet       # 可指定模型
maxTurns: 100
memory: session
background: false
parent_id: MainAgent         # 声明父Agent
permissions:                 # 权限声明
  - database.uctoo.agents:read
  - database.uctoo.agent_tasks:read
  - database.uctoo.agent_tasks:write
---
```

#### 17.3.3 协作模式

skill-creator的三个subagent形成串行/并行协作：

```
MainAgent → [GraderAgent, ComparatorAgent] → AnalyzerAgent → Result
```

- GraderAgent：对每个技能输出独立评分
- ComparatorAgent：对两个输出进行盲比较
- AnalyzerAgent：基于比较结果进行深度分析

**关键设计原则**：
1. **职责单一**：每个subagent只负责一个明确的任务
2. **输入输出标准化**：通过文件路径传递输入输出
3. **协作链式**：前一个Agent的输出是后一个Agent的输入
4. **权限最小化**：每个subagent只声明必要的权限

### 17.4 cangjie-coder agents子目录设计

基于skill-creator的subagent机制和专用语言多skills编排协作架构，为cangjie-coder设计以下agents子目录：

#### 17.4.1 目标结构

```
cangjie-coder/
├── SKILL.md                    # 主技能定义（编排器）
├── agents/                     # subagent定义
│   ├── doc-consultant.md       # 文档查阅Agent
│   ├── code-searcher.md        # 代码检索Agent
│   ├── code-editor.md          # 代码编辑Agent
│   └── code-verifier.md        # 代码验证Agent
├── scripts/                    # 确定性脚本
│   ├── cangjie_syntax_check.py # 仓颉语法检查
│   ├── cangjie_compile.py      # 编译验证
│   ├── cangjie_test_runner.py  # 测试运行
│   └── cangjie_fix_suggest.py  # 修复建议
├── references/                 # 参考文档索引
│   ├── language_guide_index.md # 语言指南索引
│   └── code_patterns.md        # 代码模式库
└── assets/                     # 资源文件
    └── templates/              # 代码模板
```

#### 17.4.2 Subagent定义

**doc-consultant.md** — 文档查阅Agent：

```yaml
---
name: doc-consultant
agent_type: sub
description: 仓颉语言文档查阅Agent，负责从CangjieSkills技能中检索和提取与当前编码任务相关的语言规范、API文档和最佳实践
version: 1.0.0
tools:
  - file_read
  - file_search
model: deepseek
maxTurns: 50
memory: session
parent_id: MainAgent
permissions:
  - database.uctoo.agents:read
---
```

**code-searcher.md** — 代码检索Agent：

```yaml
---
name: code-searcher
agent_type: sub
description: 仓颉代码片段检索Agent，负责从代码片段库中搜索可复用的代码基础，按相关性排序并返回最佳匹配
version: 1.0.0
tools:
  - file_read
  - file_search
  - directory_list
model: deepseek
maxTurns: 50
memory: session
parent_id: MainAgent
permissions:
  - database.uctoo.agents:read
---
```

**code-editor.md** — 代码编辑Agent：

```yaml
---
name: code-editor
agent_type: sub
description: 仓颉代码编辑Agent，负责根据文档规范和代码片段编辑适配代码，应用最佳实践，确保符合仓颉语法规范
version: 1.0.0
tools:
  - file_read
  - file_write
  - file_edit
model: deepseek
maxTurns: 100
memory: session
parent_id: MainAgent
permissions:
  - database.uctoo.agents:read
  - database.uctoo.agent_tasks:write
---
```

**code-verifier.md** — 代码验证Agent：

```yaml
---
name: code-verifier
agent_type: sub
description: 仓颉代码验证Agent，负责编译验证、语法检查、测试运行和错误修复建议，确保生成的代码可编译且符合规范
version: 1.0.0
tools:
  - file_read
  - cli_execute
  - file_edit
model: deepseek
maxTurns: 100
memory: session
parent_id: MainAgent
permissions:
  - database.uctoo.agents:read
  - database.uctoo.agent_tasks:write
  - database.uctoo.agent_tasks:execute
---
```

#### 17.4.3 协作编排模式

cangjie-coder的四个subagent形成**串行+反馈闭环**的协作：

```
用户请求 → cangjie-coder(编排器)
  → doc-consultant: 查阅文档，提取规范和API
  → code-searcher: 检索代码片段，返回最佳匹配
  → code-editor: 编辑适配代码，应用最佳实践
  → code-verifier: 编译验证，检查语法
    → 如果验证失败 → code-editor: 修复错误 → code-verifier: 重新验证
    → 如果验证通过 → 输出最终代码
```

**关键设计**：
- 编排器（cangjie-coder SKILL.md）负责协调四个subagent的执行顺序
- 验证失败时形成自动修复闭环（最多3次重试）
- 每个subagent的输出通过标准化文件路径传递给下一个subagent
- 符合"专用语言多skills编排协作"架构

### 17.5 已有代码生成内置工具的增强与落地

#### 17.5.1 现有工具盘点

agentskills-runtime已有三个代码生成内置工具：

| 工具 | 路径 | 功能 | 当前状态 |
|------|------|------|---------|
| **crudgen** | `src/app/tools/crudgen/` | 后端CRUD代码生成（Model/DAO/Service/Controller/Route） | 已实现，有模板引擎 |
| **crudweb** | `src/app/tools/crudweb/` | 前端Web页面生成（Vue 3+OpenTiny） | 已实现，有模板引擎 |
| **loaddbinfo** | `src/app/tools/loaddbinfo/` | 数据库信息加载（从information_schema到db_info表） | 已实现 |

**关键发现**：
- crudgen和crudweb已有完整的模板引擎（TemplateEngine.cj）
- crudgen有5层代码生成：Model → DAO → Service → Controller → Route
- crudweb有前端页面模板（Vue 3 + OpenTiny Vue组件）
- loaddbinfo是crudgen和crudweb的前置依赖
- 三个工具已通过RESTful API暴露为服务（CrudGenService.cj、WebCrudGenService.cj）

#### 17.5.2 增强方向

**方向一：代码生成工具作为Skills编排的一等公民**

当前crudgen/crudweb/loaddbinfo是内置工具（硬编码），应增强为可通过Skills编排调用的能力：

| 增强项 | 说明 | 优先级 |
|--------|------|--------|
| 创建crud-generator技能 | 将CrudGenService和WebCrudGenService封装为SKILL.md格式 | P0 |
| 创建loaddbinfo技能 | 将数据库信息加载封装为SKILL.md格式 | P0 |
| 技能组合模板 | 定义code-gen-optimize组合模板（loaddbinfo→crudgen→crudweb→cangjie-coder） | P0 |
| Agent动态配置 | CoderWorker通过技能组合模板调用代码生成工具 | P1 |

**方向二：代码生成工具的Agent化增强**

| 增强项 | 说明 | 优先级 |
|--------|------|--------|
| 智能表选择 | Agent根据需求自动选择需要生成代码的数据库表 | P1 |
| 代码风格配置 | 支持Agent动态配置生成模板和代码风格 | P2 |
| 增量代码生成 | 支持在已有代码基础上增量生成，不覆盖自定义代码 | P1 |
| 编译验证集成 | 代码生成后自动调用cjpm build验证 | P1 |

**方向三：代码生成工具的闭环验证**

```
loaddbinfo → crudgen → crudweb → cangjie-coder → cjpm build → 测试验证
     ↑                                                        │
     └────────────── 验证失败时反馈修改 ←──────────────────────┘
```

### 17.6 通用Agent在测试时动态生成测试脚本的能力

#### 17.6.1 需求分析

在AI驱动开发全流程Demo中，QA Agent需要能够动态生成测试脚本来验证生成的代码。这是赛事"自主闭环能力"的关键体现。

**当前差距**：
- agentskills-runtime没有内置的测试生成能力
- 没有动态生成JS/Python测试脚本的机制
- 没有将测试脚本执行结果反馈到代码修复的闭环

#### 17.6.2 设计方案

**测试脚本动态生成技能**（test-generator）：

```
test-generator/
├── SKILL.md                    # 测试生成技能定义
├── agents/
│   ├── test-planner.md         # 测试规划Agent（分析代码，规划测试用例）
│   ├── test-writer.md          # 测试编写Agent（生成测试脚本）
│   └── test-runner.md          # 测试执行Agent（运行测试，收集结果）
├── scripts/
│   ├── run_python_test.py      # Python测试运行器
│   ├── run_js_test.js          # JS测试运行器
│   └── parse_test_result.py    # 测试结果解析
└── references/
    ├── test_patterns.md        # 测试模式库
    └── assertion_library.md    # 断言库
```

**支持的测试类型**：

| 测试类型 | 语言 | 场景 |
|---------|------|------|
| API接口测试 | Python (requests/pytest) | 验证RESTful API的正确性 |
| 数据库测试 | Python (psycopg2/pytest) | 验证CRUD操作的正确性 |
| 前端UI测试 | JavaScript (Playwright) | 验证Web页面的交互 |
| 仓颉单元测试 | 仓颉 (unittest) | 验证仓颉代码逻辑 |
| 集成测试 | Python/JS混合 | 验证前后端集成 |

**动态生成流程**：

```
QA Agent接收验证任务
  → test-planner: 分析待验证代码，规划测试用例
  → test-writer: 根据测试用例生成Python/JS测试脚本
  → test-runner: 执行测试脚本，收集结果
    → 如果测试通过 → 输出验证报告
    → 如果测试失败 → 反馈给code-editor修复 → 重新测试
```

**关键设计**：
- 测试脚本通过skills的scripts目录生成和执行
- 支持Python（pytest）和JavaScript（Playwright）两种测试框架
- 测试结果通过标准化格式反馈给代码修复闭环
- 符合"确定性优先"原则：测试脚本执行是确定性的，测试用例规划由AI驱动

### 17.7 Skills的script目录生成技能需要用到的程序工具的能力

#### 17.7.1 需求分析

当前skill-creator已有scripts子目录（9个Python脚本），但这些脚本是预置的。在coding agent场景中，需要支持**动态生成**技能需要用到的程序工具。

**场景示例**：
- cangjie-coder需要生成仓颉语法检查脚本
- test-generator需要生成特定项目的测试运行脚本
- crud-generator需要生成数据库迁移脚本

#### 17.7.2 设计方案

**技能脚本动态生成机制**：

1. **SKILL.md中声明脚本需求**：

```yaml
---
name: cangjie-coder
scripts:
  - name: cangjie_syntax_check
    description: 仓颉语法检查脚本
    language: python
    generates: on_demand    # 首次使用时生成
  - name: cangjie_compile
    description: 编译验证脚本
    language: python
    generates: on_demand
---
```

2. **脚本生成Agent**：

当技能首次使用时，如果scripts目录中不存在声明的脚本，由script-generator subagent自动生成：

```
技能触发 → 检查scripts目录 → 脚本不存在
  → script-generator: 根据脚本描述生成脚本代码
  → 写入scripts目录 → 执行脚本
```

3. **脚本沙箱执行**：

生成的脚本在WASM沙箱或受限环境中执行，确保安全性：
- Python脚本：通过WASM沙箱执行
- JavaScript脚本：通过Node.js子进程执行
- 仓颉脚本：通过cjpm run执行

4. **脚本版本管理**：

- 脚本与技能版本绑定
- 技能升级时脚本自动更新
- 支持脚本的手动覆盖和自定义

### 17.8 从OpenClaude和OpenCode项目借鉴的优秀理念和设计

#### 17.8.1 OpenClaude项目调研总结

**项目定位**：开源coding-agent CLI，支持多云和本地模型提供商

**核心架构**：
- TypeScript + React/Ink终端UI
- 58+工具（Bash、文件操作、Agent、Skill、MCP、Web等）
- 内置AgentTool：支持subagent创建、后台执行、worktree隔离
- 内置SkillTool：支持SKILL.md加载、MCP技能集成
- 多Provider适配：OpenAI、Gemini、Ollama、Codex等20+提供商

**可借鉴的优秀设计**：

| 设计 | 说明 | 借鉴到agentskills-runtime |
|------|------|--------------------------|
| **AgentTool subagent系统** | 支持subagent_type选择、后台执行、worktree隔离、模型覆盖 | cangjie-coder的agents子目录应支持类似的subagent配置 |
| **SkillTool渐进式加载** | 三级加载（元数据→SKILL.md体→bundled资源），与agentskills的ProgressiveSkillLoader一致 | 验证了渐进式加载的正确性，应继续坚持 |
| **RepoMap代码库智能** | 基于PageRank的代码库结构地图，自动注入上下文 | 可借鉴为cangjie-coder的代码检索增强 |
| **后台会话管理** | `--bg`模式运行长任务，`openclaude ps`查看状态 | 可借鉴为Agent的后台执行模式 |
| **会话恢复和分支** | `--resume`和`--fork-session`支持会话恢复和分支 | 可借鉴为Agent的上下文恢复机制 |
| **Provider Profile** | 引导式Provider设置和保存配置 | 可借鉴为多模型适配的用户体验优化 |
| **Cost Tracker** | Token消耗追踪和成本计算 | 可借鉴为AgentLoop观测评估的Token统计 |
| **Buddy系统** | 像素艺术伴侣，增加趣味性 | 低优先级，但增加Demo演示的趣味性 |

**OpenClaude AgentTool关键特性深入分析**：

OpenClaude的AgentTool是其最核心的差异化能力之一，值得深入借鉴：

1. **多Agent类型**：支持subagent_type参数选择专用Agent
2. **后台执行**：`run_in_background`参数支持异步执行
3. **Worktree隔离**：每个Agent可在独立的git worktree中工作，避免文件冲突
4. **模型覆盖**：每个Agent可指定不同的模型
5. **进度追踪**：实时显示Agent执行进度
6. **结果聚合**：自动聚合多个Agent的执行结果

这些特性与agentskills-runtime的AgentTeams分层架构高度互补。

#### 17.8.2 OpenCode项目调研总结

**项目定位**：开源AI coding agent，支持桌面应用和CLI

**核心架构**：
- TypeScript + Effect（函数式编程框架）
- Monorepo结构：32个packages（core、opencode、tui、sdk、plugin等）
- Effect生态：使用Effect.ts进行函数式编程、依赖注入、错误处理
- 内置Agent：build（全权限）、plan（只读）、general（子Agent）、explore（代码探索）
- Skill系统：SKILL.md标准，支持技能发现和加载
- Drizzle ORM + SQLite：本地数据持久化
- V2 Session Core：持久化会话、可恢复执行

**可借鉴的优秀设计**：

| 设计 | 说明 | 借鉴到agentskills-runtime |
|------|------|--------------------------|
| **双Agent模式（build+plan）** | build Agent全权限开发，plan Agent只读分析 | 可借鉴为cangjie-coder的doc-consultant（只读）和code-editor（读写）模式 |
| **explore子Agent** | 快速代码探索Agent，支持thoroughness级别配置 | 可借鉴为cangjie-coder的code-searcher Agent |
| **Agent动态生成** | `Agent.generate()`方法，通过LLM动态生成Agent配置 | 可借鉴为AgentTeams的动态组队能力 |
| **Skill发现机制** | `Skill.discovery`自动发现和加载技能 | 与agentskills的ProgressiveSkillLoader一致 |
| **Effect函数式架构** | 使用Effect.ts进行依赖注入、错误处理、资源管理 | 可借鉴为agentskills-runtime的架构优化方向（长期） |
| **V2 Session Core** | 持久化会话、可恢复执行、安全边界 | 可借鉴为Agent的跨会话记忆和执行恢复 |
| **Permission系统** | 细粒度权限控制（allow/ask/deny），per-Agent权限配置 | 与agentskills的RBAC权限体系互补 |
| **Plugin系统** | 支持插件扩展Agent能力 | 可借鉴为技能的插件化扩展 |
| **LSP集成** | 语言服务器协议集成，提供代码智能 | 可借鉴为cangjie-coder的代码验证增强 |
| **System Context** | 上下文源注册表，支持多种上下文提供者 | 可借鉴为Agent的上下文管理 |

**OpenCode Effect架构深入分析**：

OpenCode使用Effect.ts函数式编程框架，其架构设计值得长期借鉴：

1. **Context.Service模式**：每个服务通过Effect Context定义，支持依赖注入
2. **InstanceState模式**：每个目录/项目独立的状态实例，自动清理
3. **Layer组合**：服务层通过Layer组合，支持测试替换
4. **Schema验证**：使用Effect Schema进行输入输出验证
5. **错误处理**：TaggedError分类处理，不使用try/catch

这些模式虽然与仓颉语言的OOP范式不同，但其设计思想（依赖注入、状态隔离、类型安全）可以借鉴到仓颉实现中。

#### 17.8.3 综合借鉴优先级

| 借鉴项 | 来源 | 优先级 | 预估工时 | 对标赛事维度 |
|--------|------|--------|---------|------------|
| Agent subagent配置（type/model/background） | OpenClaude | P0 | 2天 | 多Agent协同(25%) |
| 双Agent模式（只读+读写） | OpenCode | P0 | 1天 | 安全审计(20%) |
| Agent动态生成 | OpenCode | P1 | 3天 | 多Agent协同(25%) |
| RepoMap代码库智能 | OpenClaude | P1 | 3天 | Skill工程(25%) |
| 后台会话管理 | OpenClaude | P1 | 2天 | 工程落地(20%) |
| 会话恢复和分支 | OpenClaude | P2 | 3天 | 工程落地(20%) |
| LSP集成 | OpenCode | P2 | 4天 | Skill工程(25%) |
| Plugin系统 | OpenCode | P2 | 4天 | Skill工程(25%) |
| Effect函数式架构 | OpenCode | P3 | 长期 | 工程落地(20%) |

### 17.9 Coding Agent方向新增需求

基于以上调研和分析，新增以下coding agent方向的需求：

| 优先级 | 需求编号 | 需求名称 | 对标维度 | 预估工时 | 依赖 | 来源 |
|--------|---------|---------|---------|---------|------|------|
| P0 | GOAI-022 | cangjie-coder agents子目录完善 | Skill工程(25%) | 3天 | 无 | skill-creator subagent机制 |
| P0 | GOAI-023 | 代码生成工具Skills化封装 | Skill工程(25%) | 2天 | 无 | crudgen/crudweb/loaddbinfo |
| P0 | GOAI-024 | 专用语言多Skills编排协作架构 | 多Agent协同(25%) | 3天 | GOAI-022 | 专用语言多Agent协作进化 |
| P1 | GOAI-025 | 测试脚本动态生成技能 | 工程落地(20%) | 3天 | GOAI-022 | QA Agent测试验证 |
| P1 | GOAI-026 | 技能脚本动态生成机制 | Skill工程(25%) | 2天 | GOAI-022 | skills的script目录能力 |
| P1 | GOAI-027 | 代码生成闭环验证 | 工程落地(20%) | 2天 | GOAI-023 | crudgen+crudweb验证闭环 |
| P1 | GOAI-028 | Agent subagent配置增强 | 多Agent协同(25%) | 2天 | GOAI-022 | OpenClaude AgentTool |
| P2 | GOAI-029 | RepoMap代码库智能 | Skill工程(25%) | 3天 | 无 | OpenClaude RepoMap |
| P2 | GOAI-030 | Agent动态生成能力 | 多Agent协同(25%) | 3天 | GOAI-028 | OpenCode Agent.generate |

#### GOAI-022: cangjie-coder agents子目录完善

**对标维度**: Skill工程体系与生态复用(25%)

**需求描述**: 为cangjie-coder技能创建agents子目录，参考skill-creator的subagent机制，实现专用语言多skills编排协作的核心能力。

**核心能力**:
1. **doc-consultant subagent**: 从CangjieSkills技能中检索和提取语言规范、API文档和最佳实践
2. **code-searcher subagent**: 从代码片段库中搜索可复用的代码基础
3. **code-editor subagent**: 根据文档规范和代码片段编辑适配代码
4. **code-verifier subagent**: 编译验证、语法检查、测试运行和错误修复建议
5. **编排器**: cangjie-coder SKILL.md作为编排器，协调四个subagent的执行顺序
6. **自动修复闭环**: 验证失败时自动修复（最多3次重试）

**与现有系统的关系**:
- 复用skill-creator的agents子目录声明模式
- 复用CangjieSkills的cangjie-language-guide和cangjie-full-docs技能
- 复用CangjieMagic/resource代码片段库
- 复用现有file_read/file_write/file_search工具

**验收标准**:
- [ ] cangjie-coder/agents/目录包含4个subagent定义文件
- [ ] 每个subagent有完整的YAML frontmatter和职责描述
- [ ] 编排器正确协调四个subagent的执行顺序
- [ ] 验证失败时自动修复闭环正常工作
- [ ] 生成的仓颉代码通过cjpm build编译验证

---

#### GOAI-023: 代码生成工具Skills化封装

**对标维度**: Skill工程体系与生态复用(25%)

**需求描述**: 将crudgen、crudweb、loaddbinfo三个内置工具封装为SKILL.md格式的技能，使其可通过Skills编排调用。

**核心能力**:
1. **crud-generator技能**: 封装CrudGenService和WebCrudGenService为SKILL.md格式
2. **loaddbinfo技能**: 封装数据库信息加载为SKILL.md格式
3. **技能组合模板**: 定义code-gen-optimize组合模板（loaddbinfo→crudgen→crudweb→cangjie-coder）
4. **Agent调用接口**: CoderWorker通过技能组合模板调用代码生成工具

**与现有系统的关系**:
- 复用现有CrudGenService.cj和WebCrudGenService.cj
- 复用现有RESTful API接口
- 复用现有模板引擎

**验收标准**:
- [ ] crud-generator技能可通过SKILL.md格式加载和触发
- [ ] loaddbinfo技能可通过SKILL.md格式加载和触发
- [ ] code-gen-optimize组合模板可正确执行
- [ ] CoderWorker可通过技能调用代码生成工具

---

#### GOAI-024: 专用语言多Skills编排协作架构

**对标维度**: 多Agent协同与自主闭环能力(25%)

**需求描述**: 实现专用语言多Skills编排协作架构，支持不同编程语言的专用skills编排协作，是agentskills-runtime作为coding agent的核心差异化能力。

**核心能力**:
1. **语言专用技能集**: 每种编程语言一组专用技能（文档查阅、代码检索、代码编辑、代码验证）
2. **编排协作引擎**: 根据编程语言自动选择和编排对应的技能集
3. **语言上下文注入**: 自动加载编程语言的相关资料和编程规范作为上下文
4. **跨语言协作**: 支持多语言项目的跨语言skills编排（如仓颉后端+Vue前端）
5. **SOP工作流引擎**: 将静态SOP描述转化为可执行的编排流程

**架构设计**:

```
专用语言多Skills编排协作架构:

                    ┌─────────────────────┐
                    │  编排协作引擎        │
                    │  (Orchestrator)      │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────▼──────┐ ┌──────▼─────────┐ ┌────▼───────────┐
    │ 仓颉技能集      │ │ TypeScript技能集│ │ Python技能集   │
    │ cangjie-coder  │ │ ts-coder       │ │ python-coder   │
    ├────────────────┤ ├────────────────┤ ├────────────────┤
    │ doc-consultant │ │ doc-consultant │ │ doc-consultant │
    │ code-searcher  │ │ code-searcher  │ │ code-searcher  │
    │ code-editor    │ │ code-editor    │ │ code-editor    │
    │ code-verifier  │ │ code-verifier  │ │ code-verifier  │
    └────────────────┘ └────────────────┘ └────────────────┘
```

**与现有系统的关系**:
- 复用GOAI-005技能组合引擎核心
- 复用GOAI-022 cangjie-coder agents子目录
- 复用现有SKILL.md标准和ProgressiveSkillLoader

**验收标准**:
- [ ] 仓颉技能集可正确编排执行
- [ ] 编排协作引擎根据编程语言自动选择技能集
- [ ] 语言上下文正确注入到subagent
- [ ] 跨语言协作（仓颉后端+Vue前端）可正确执行
- [ ] SOP工作流从静态描述转化为可执行流程

---

#### GOAI-025: 测试脚本动态生成技能

**对标维度**: 工程落地与运行验证及安全审计(20%)

**需求描述**: 实现测试脚本动态生成技能，支持QA Agent在测试时动态生成JS/Python测试脚本，验证生成的代码。

**核心能力**:
1. **test-planner subagent**: 分析待验证代码，规划测试用例
2. **test-writer subagent**: 根据测试用例生成Python/JS测试脚本
3. **test-runner subagent**: 执行测试脚本，收集结果
4. **多框架支持**: Python (pytest)、JavaScript (Playwright)、仓颉 (unittest)
5. **测试结果反馈**: 测试失败时反馈给代码修复闭环

**验收标准**:
- [ ] test-planner正确分析代码并规划测试用例
- [ ] test-writer生成可执行的Python/JS测试脚本
- [ ] test-runner正确执行测试脚本并收集结果
- [ ] 测试失败时反馈到代码修复闭环
- [ ] 支持API接口测试、数据库测试、前端UI测试

---

#### GOAI-026: 技能脚本动态生成机制

**对标维度**: Skill工程体系与生态复用(25%)

**需求描述**: 实现技能脚本动态生成机制，支持技能在首次使用时自动生成需要的程序工具脚本。

**核心能力**:
1. **脚本需求声明**: SKILL.md中声明scripts需求（名称、描述、语言、生成策略）
2. **脚本生成Agent**: 根据脚本描述自动生成脚本代码
3. **沙箱执行**: 生成的脚本在WASM沙箱或受限环境中执行
4. **版本管理**: 脚本与技能版本绑定，技能升级时脚本自动更新

**验收标准**:
- [ ] SKILL.md可声明脚本需求
- [ ] 首次使用时自动生成声明的脚本
- [ ] 生成的脚本在沙箱中安全执行
- [ ] 脚本版本与技能版本正确绑定

---

#### GOAI-027: 代码生成闭环验证

**对标维度**: 工程落地与运行验证及安全审计(20%)

**需求描述**: 实现代码生成工具的闭环验证，确保crudgen/crudweb生成的代码可编译、可运行、符合业务规则。

**核心能力**:
1. **编译验证**: 代码生成后自动调用cjpm build验证
2. **API验证**: 自动调用生成的API接口验证CRUD操作
3. **前端验证**: 自动检查生成的Vue页面可正常渲染
4. **业务规则验证**: 验证生成的代码符合业务规则（如字段约束、权限控制）
5. **错误反馈闭环**: 验证失败时自动反馈到代码修复

**验收标准**:
- [ ] crudgen生成的代码通过cjpm build编译
- [ ] 生成的API接口可通过HTTP请求验证
- [ ] 生成的Vue页面可正常渲染
- [ ] 业务规则验证正确执行
- [ ] 验证失败时自动反馈到代码修复

---

#### GOAI-028: Agent subagent配置增强

**对标维度**: 多Agent协同与自主闭环能力(25%)

**需求描述**: 增强Agent的subagent配置能力，借鉴OpenClaude的AgentTool设计，支持subagent类型选择、模型覆盖、后台执行等。

**核心能力**:
1. **subagent_type配置**: 支持在agents/子目录中声明subagent类型
2. **模型覆盖**: 每个subagent可指定不同的模型
3. **后台执行**: 支持subagent在后台异步执行
4. **进度追踪**: 实时显示subagent执行进度
5. **结果聚合**: 自动聚合多个subagent的执行结果

**与现有系统的关系**:
- 复用现有agents.md的YAML frontmatter声明模式
- 复用现有AgentExecutor的react/plan-react模式
- 借鉴OpenClaude AgentTool的subagent配置

**验收标准**:
- [ ] agents/子目录中的subagent类型正确识别和创建
- [ ] 每个subagent可使用指定的模型
- [ ] subagent可在后台异步执行
- [ ] subagent执行进度实时可追踪
- [ ] 多个subagent的执行结果正确聚合

---

#### GOAI-029: RepoMap代码库智能

**对标维度**: Skill工程体系与生态复用(25%)

**需求描述**: 实现基于PageRank的代码库结构地图，自动注入到Agent上下文中，提升代码检索和理解的准确性。

**核心能力**:
1. **代码库结构分析**: 分析项目目录结构、文件依赖关系
2. **PageRank排序**: 基于文件引用关系计算重要性排序
3. **上下文注入**: 自动将代码库结构地图注入到Agent上下文
4. **增量更新**: 文件变更时增量更新代码库地图

**验收标准**:
- [ ] 代码库结构正确分析
- [ ] PageRank排序反映文件重要性
- [ ] 代码库地图正确注入到Agent上下文
- [ ] 文件变更时地图增量更新

---

#### GOAI-030: Agent动态生成能力

**对标维度**: 多Agent协同与自主闭环能力(25%)

**需求描述**: 实现Agent的动态生成能力，借鉴OpenCode的Agent.generate()设计，支持通过LLM动态生成Agent配置。

**核心能力**:
1. **Agent配置生成**: 通过LLM根据任务描述生成Agent配置
2. **配置验证**: 验证生成的Agent配置的合法性
3. **动态注册**: 生成的Agent配置动态注册到Agent系统
4. **配置持久化**: 生成的Agent配置持久化到数据库

**验收标准**:
- [ ] 根据任务描述正确生成Agent配置
- [ ] 生成的配置通过合法性验证
- [ ] Agent配置正确注册到系统
- [ ] Agent配置持久化到数据库

---

### 17.10 更新后的完整需求优先级矩阵

整合coding agent方向的新增需求，更新完整优先级矩阵：

| 优先级 | 需求编号 | 需求名称 | 对标维度 | 预估工时 | 关键设计原则 |
|--------|---------|---------|---------|---------|------------|
| P0 | GOAI-001 | AgentTeams分层协作架构 | 多Agent协同(25%) | 5天 | 可配置引擎：YAML定义角色和层级 |
| P0 | GOAI-002 | 任务分解与DAG编排引擎 | 多Agent协同(25%) | 5天 | 可配置引擎：DAG配置定义执行计划 |
| P0 | GOAI-003 | 执行证据链与审计系统 | 工程落地(20%) | 3天 | 扩展operate_log，增加验证证据 |
| P0 | GOAI-004 | AI驱动开发全流程Demo场景 | 场景价值(25%) | 5天 | SDD流程+全栈代码生成闭环 |
| P0 | GOAI-005 | 技能组合引擎核心 | Skill工程(25%) | 4天 | Footprint Ladder决策阶梯 |
| P0 | GOAI-013 | SDD规范驱动开发技能集 | 场景价值(25%) | 3天 | 借鉴CodeArts SDD机制 |
| P0 | GOAI-014 | 全栈代码生成闭环 | 场景价值(25%) | 3天 | 复用crudgen/crudweb/loaddbinfo |
| P0 | GOAI-022 | cangjie-coder agents子目录完善 | Skill工程(25%) | 3天 | 专用语言多skills编排协作 |
| P0 | GOAI-023 | 代码生成工具Skills化封装 | Skill工程(25%) | 2天 | 内置工具→技能化封装 |
| P0 | GOAI-024 | 专用语言多Skills编排协作架构 | 多Agent协同(25%) | 3天 | 专用语言多Agent协作进化 |
| P1 | GOAI-006 | Agent间上下文传递与结果验证 | 多Agent协同(25%) | 3天 | 协同技能：context-pass、result-merge |
| P1 | GOAI-007 | 记忆持久化与跨会话共享 | 多Agent协同(25%) | 4天 | MemoryProvider接口 |
| P1 | GOAI-008 | AgentLoop观测评估飞轮 | 工程落地(20%) | 4天 | 确定性优先：观测用代码，调优用AI |
| P1 | GOAI-009 | 审批与回滚机制 | 工程落地(20%) | 3天 | 复用HITL，扩展审批记录 |
| P1 | GOAI-010 | 技能组合模板与依赖解析 | Skill工程(25%) | 3天 | COMPOSITION.yaml配置驱动 |
| P1 | GOAI-015 | 技能自进化闭环 | Skill工程(25%) | 4天 | 借鉴Hermes Curator |
| P1 | GOAI-016 | 协同技能集 | 多Agent协同(25%) | 4天 | AI推理决策替代固定程序 |
| P1 | GOAI-017 | 验证证据账本 | 工程落地(20%) | 2天 | 借鉴Hermes verification_evidence |
| P1 | GOAI-018 | Agent Kanban任务队列 | 多Agent协同(25%) | 3天 | 借鉴Hermes Kanban |
| P1 | GOAI-025 | 测试脚本动态生成技能 | 工程落地(20%) | 3天 | QA Agent测试验证 |
| P1 | GOAI-026 | 技能脚本动态生成机制 | Skill工程(25%) | 2天 | skills的script目录能力 |
| P1 | GOAI-027 | 代码生成闭环验证 | 工程落地(20%) | 2天 | crudgen+crudweb验证闭环 |
| P1 | GOAI-028 | Agent subagent配置增强 | 多Agent协同(25%) | 2天 | OpenClaude AgentTool借鉴 |
| P2 | GOAI-011 | 错误恢复与自愈系统 | 工程落地(20%) | 4天 | 四级错误分类 |
| P2 | GOAI-012 | 开源计划与社区建设 | 开源贡献(5%) | 1天 | - |
| P2 | GOAI-019 | 记忆提供者插件体系 | 多Agent协同(25%) | 4天 | Hermes MemoryProvider ABC |
| P2 | GOAI-020 | 上下文多层压缩管道 | 工程落地(20%) | 3天 | Claude Code 5层压缩 |
| P2 | GOAI-021 | 提示缓存机制 | 工程落地(20%) | 3天 | Hermes prompt caching |
| P2 | GOAI-029 | RepoMap代码库智能 | Skill工程(25%) | 3天 | OpenClaude RepoMap |
| P2 | GOAI-030 | Agent动态生成能力 | 多Agent协同(25%) | 3天 | OpenCode Agent.generate |

### 17.11 更新后的差异化竞争优势（Coding Agent方向增强）

#### 17.11.1 新增核心优势

| 优势 | 说明 | 对标维度 | 来源 |
|------|------|---------|------|
| **专用语言多Skills编排协作** | 每种编程语言一组专用技能（文档查阅→代码检索→代码编辑→代码验证），通过编排协作引擎自动选择和执行 | Skill工程(25%)+多Agent协同(25%) | 仓颉社区方案进化 |
| **cangjie-coder agents子目录** | 参考skill-creator的subagent机制，实现cangjie-coder的四Agent协作（doc-consultant→code-searcher→code-editor→code-verifier） | Skill工程(25%) | skill-creator实践验证 |
| **代码生成工具Skills化** | 将crudgen/crudweb/loaddbinfo从硬编码工具封装为可编排的技能，实现代码生成的一等公民化 | Skill工程(25%) | 已有基础设施复用 |
| **测试脚本动态生成** | QA Agent在测试时动态生成JS/Python测试脚本，实现代码验证的自主闭环 | 工程落地(20%) | coding agent核心能力 |
| **技能脚本动态生成** | 技能在首次使用时自动生成需要的程序工具脚本，实现技能的自完备性 | Skill工程(25%) | skills的script目录能力 |

#### 17.11.2 更新后的差异化亮点

1. **"仓颉+Agent"国产自主可控基座**：唯一使用仓颉语言实现的参赛作品
2. **"双驱动"架构新物种**：确定性优先，AI增强
3. **"可配置引擎"设计哲学**：不硬编码业务功能，所有功能通过配置动态调整
4. **"专用语言多Skills编排协作"**：每种编程语言一组专用技能，通过编排协作引擎自动选择和执行——这是coding agent的核心差异化能力
5. **"技能自进化"闭环**：从经验中创建技能，在使用中改进技能
6. **"全栈代码生成"闭环**：crudgen+crudweb+loaddbinfo形成从需求到部署的完整AI驱动开发流程
7. **"SDD规范驱动"开发流程**：spec→design→tasks→code→test的标准化AI驱动软件开发流程
8. **"测试脚本动态生成"自主闭环**：QA Agent动态生成测试脚本，实现代码验证的自主闭环
9. **"通模一体"全栈同构**：后端PO↔前端ORM模型自动同构

### 17.12 更新后的实施路线图（Coding Agent方向增强）

#### 阶段一：初赛准备（7月23日 - 8月16日）

**新增任务**：

| 任务 | 工时 | 交付物 | 关键亮点 |
|------|------|--------|---------|
| cangjie-coder agents子目录设计 | 1天 | agents子目录设计文档 | 专用语言多skills编排协作 |
| 代码生成工具Skills化方案 | 1天 | Skills化封装方案 | crudgen/crudweb/loaddbinfo技能化 |

**PPT新增重点**：
- **"专用语言多Skills编排协作"架构**：从专用语言多Agent协作进化到多Skills编排协作
- **"cangjie-coder四Agent协作"**：doc-consultant→code-searcher→code-editor→code-verifier
- **"代码生成工具Skills化"**：从硬编码工具到可编排技能
- **"测试脚本动态生成"**：QA Agent自主生成测试脚本

#### 阶段二：核心功能开发（8月17日 - 9月3日）

**更新后的周计划**：

| 周次 | 任务 | 交付物 | 设计原则 |
|------|------|--------|---------|
| 第1周 | GOAI-001 AgentTeams + GOAI-022 cangjie-coder agents + GOAI-023 代码生成工具Skills化 | 可运行的AgentTeams + cangjie-coder四Agent协作 + 代码生成技能 | 专用语言多skills编排+复用已有基础设施 |
| 第2周 | GOAI-002 DAG编排 + GOAI-003 证据链 + GOAI-024 专用语言多Skills编排协作架构 | DAG调度 + 审计系统 + 编排协作引擎 | 可配置引擎+编排协作 |
| 第3周 | GOAI-004 Demo场景 + GOAI-005 技能组合 + GOAI-013 SDD技能集 + GOAI-014 全栈代码生成 | 完整Demo | SDD流程+全栈代码生成+专用语言编排 |
| 第4周 | GOAI-025 测试脚本生成 + GOAI-027 代码生成验证 + GOAI-028 subagent配置增强 | 测试验证闭环 + subagent增强 | 测试动态生成+验证闭环 |

#### 阶段三：决赛准备（9月4日 - 9月22日）

**新增任务**：

| 任务 | 工时 | 交付物 |
|------|------|--------|
| GOAI-026 技能脚本动态生成 | 2天 | 脚本动态生成机制 |
| GOAI-029 RepoMap代码库智能 | 3天 | 代码库智能 |
| Demo优化（重点coding agent场景） | 2天 | 稳定可演示的coding agent Demo |

### 17.13 Coding Agent方向的核心价值总结

agentskills-runtime作为coding agent的核心差异化价值在于：

1. **已验证的专用语言代码生成方案**：仓颉社区已实证"采用大模型通用能力，生成高质量仓颉代码"的方案可行，这是其他参赛作品不具备的实证基础
2. **从多Agent协作到多Skills编排协作的进化**：不是简单的Agent编排，而是基于技能的编排协作，更符合"技能是一等公民"的设计哲学
3. **cangjie-coder的四Agent协作模式**：doc-consultant→code-searcher→code-editor→code-verifier，是专用语言多Skills编排协作的最佳实践
4. **代码生成工具的Skills化**：将crudgen/crudweb/loaddbinfo从硬编码工具封装为可编排技能，实现代码生成的一等公民化
5. **测试脚本动态生成**：QA Agent在测试时动态生成测试脚本，实现代码验证的自主闭环，体现"自主闭环能力"
6. **全栈代码生成闭环**：从需求分析→数据建模→后端代码生成→前端页面生成→测试验证→部署发布的完整闭环

这些能力与赛事的五个评审维度高度对齐：
- **场景价值(25%)**：AI驱动软件开发全流程是真实、有行业价值的场景
- **多Agent协同(25%)**：专用语言多Skills编排协作是独特的多Agent协同模式
- **Skill工程(25%)**：cangjie-coder agents子目录、代码生成工具Skills化、技能脚本动态生成
- **工程落地(20%)**：测试脚本动态生成、代码生成闭环验证、编译验证
- **开源贡献(5%)**：专用语言多Skills编排协作架构可贡献给开源社区