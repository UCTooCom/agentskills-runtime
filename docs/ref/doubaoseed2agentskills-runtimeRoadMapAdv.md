# AgentSkills Runtime 演进路线图建议 - 结合Harness Engineering思路

## 目录

1. [执行摘要](#执行摘要)
2. [当前架构分析](#当前架构分析)
3. [Harness Engineering最佳实践借鉴](#harness-engineering最佳实践借鉴)
4. [演进路线图](#演进路线图)
5. [具体实施建议](#具体实施建议)
6. [风险评估与应对](#风险评估与应对)
7. [总结](#总结)

---

## 执行摘要

本文档基于对两种AI Agent思路的深度对比分析，结合Harness Engineering的最佳实践，为AgentSkills Runtime项目提出完整的演进路线图建议。

### 核心建议

1. **保留现有优势**：继续强化全栈框架、国产自主可控、多语言SDK等核心竞争力
2. **借鉴Harness思路**：引入编排循环、上下文管理、记忆系统、验证循环等Harness核心组件
3. **渐进式演进**：分阶段实施，避免大规模重构，确保平滑过渡
4. **差异化定位**：打造"具有企业级全栈能力的Harness运行时"独特定位

### 预期收益

- 更强大的Agent能力释放
- 更好的用户体验和可控性
- 保持国产自主可控优势
- 提升项目在AI Agent领域的竞争力

---

## 当前架构分析

### 现有优势

1. **完整的全栈框架**
   - 三层架构（Controller、Service、Repository）
   - 高性能HTTP/HTTPS服务器
   - 数据库连接池、缓存系统
   - 完整的RBAC权限体系

2. **国产自主可控**
   - 基于仓颉编程语言
   - 不依赖国外大模型厂商SDK
   - 支持华为云MaaS等国产模型

3. **多语言生态**
   - 6种语言SDK（JavaScript/TypeScript、Python、Java、Go、Rust、C#）
   - 渐进式集成能力
   - 传统系统+AI的友好接入

4. **标准化技能**
   - AgentSkills开放标准
   - SKILL.md文件格式
   - WASM安全沙箱

5. **内置工具丰富**
   - 文件系统工具（9个）
   - 网络工具（4个）
   - 技能工具（2个）
   - 代码生成工具（2个）
   - CLI工具（1个）

### 现有不足（从Harness角度看）

1. **缺少显式的Agent编排循环**
   - 没有明确的思考-行动-观察（TAO）循环
   - 工具调用链管理不完善
   - 缺少会话级状态管理

2. **上下文管理策略简单**
   - 缺少多层上下文压缩机制
   - 没有观察屏蔽、即时检索等策略
   - 容易出现上下文腐烂问题

3. **记忆系统不够完善**
   - 缺少短期/长期记忆分层
   - 没有轻量级索引机制
   - 跨会话记忆能力有限

4. **验证循环缺失**
   - 缺少基于规则的反馈机制
   - 没有LLM自评判能力
   - 静默失败风险高

5. **错误处理可以更精细**
   - 缺少错误分类（瞬时/可恢复/需要人工）
   - 重试策略不够智能
   - 没有把错误作为反馈给LLM的机制

6. **子Agent编排能力弱**
   - 缺少Fork、Teammate、Worktree模式
   - Agent协作机制不完善
   - 没有明确的移交机制

7. **提示词构建不够分层**
   - 系统提示、工具定义、记忆、对话历史混合
   - 缺少优先级管理
   - 提示词工程能力有限

---

## Harness Engineering最佳实践借鉴

### 1. 编排循环（TAO循环）

**Claude Code经验**：
- 「笨循环」设计，所有智能在模型里
- 收集-行动-验证循环
- 思考-行动-观察（TAO）模式

**建议**：
- 在现有架构中引入显式的AgentLoop组件
- 实现TAO循环机制
- 保持循环简单，智能留给模型和业务逻辑

### 2. 上下文管理

**Claude Code经验**：
- 五层上下文压缩：预算裁剪、历史修剪、微压缩、上下文折叠、自动摘要
- 观察屏蔽：隐藏旧工具输出，但保留调用可见
- 即时检索：动态加载数据而非完整加载
- 子Agent委托：只返回压缩摘要

**建议**：
- 实现多层上下文压缩策略
- 引入观察屏蔽机制
- 实现即时检索能力（如文件按需加载）
- 支持上下文优先级管理

### 3. 记忆系统

**Claude Code经验**：
- 三层记忆：轻量级索引（始终加载）、详细主题文件（按需拉取）、原始记录（只通过搜索）
- CLAUDE.md项目文件
- 自动生成的MEMORY.md文件
- git提交作为检查点

**建议**：
- 设计三层记忆架构
- 支持项目级记忆文件
- 利用现有数据库实现持久化记忆
- 引入检查点机制（可以利用数据库事务）

### 4. 验证循环

**Claude Code经验**：
- 三种验证方式：基于规则的反馈、视觉反馈、LLM作为评判者
- 给模型验证自身工作的方式能将质量提升2-3倍

**建议**：
- 引入验证循环组件
- 支持规则验证（利用现有的测试框架）
- 实现LLM自评判能力
- 建立验证反馈机制

### 5. 错误处理

**LangChain经验**：
- 四种错误分类：瞬时错误、LLM可恢复错误、用户可修复错误、意外错误
- 重试策略：带退避重试
- 错误反馈：将错误作为ToolMessage返回给模型

**建议**：
- 实现精细的错误分类
- 设计智能重试策略
- 建立错误反馈给LLM的机制
- 支持用户干预中断

### 6. 子Agent编排

**Claude Code经验**：
- 三种执行模型：Fork（字节级复制）、Teammate（独立终端，文件邮箱通信）、Worktree（独立git工作树）
- OpenAI方式：Agent作为工具、移交

**建议**：
- 设计子Agent机制
- 支持Agent作为工具调用
- 实现移交（Handover）机制
- 利用现有的技能系统实现子Agent

### 7. 安全护栏

**Claude Code经验**：
- 七层安全机制：工具预过滤、拒绝优先规则、权限模式、ML分类器、沙箱隔离、不继承旧权限、Hooks拦截
- 权限与推理分离：模型决定尝试什么，工具系统决定允许什么

**建议**：
- 强化现有的RBAC，引入工具预过滤
- 实现拒绝优先规则
- 保持权限与推理分离的设计
- 利用现有的WASM沙箱增强安全性

---

## 演进路线图

### 阶段一：基础Harness能力（v0.1.x - v0.2.x）

**目标**：引入核心Harness概念，不破坏现有架构

**关键任务**：
1. [ ] 设计并实现AgentLoop编排循环
2. [ ] 引入会话级状态管理
3. [ ] 实现基础的上下文管理策略
4. [ ] 增强错误处理机制
5. [ ] 补充单元测试和文档

**验收标准**：
- 支持基本的思考-行动-观察循环
- 会话状态正确持久化
- 上下文管理能处理中等长度对话
- 错误能正确反馈给用户和LLM

**预计时间**：1-2个月

---

### 阶段二：完善Harness组件（v0.3.x - v0.4.x）

**目标**：完善Harness核心组件，提升Agent能力

**关键任务**：
1. [ ] 实现三层记忆系统
2. [ ] 引入多层上下文压缩
3. [ ] 实现验证循环机制
4. [ ] 设计子Agent编排
5. [ ] 增强提示词构建（分层、优先级）
6. [ ] 性能优化和压力测试

**验收标准**：
- 记忆能跨会话持久化
- 上下文能有效压缩（减少50%+ token使用）
- 验证循环能发现并纠正错误
- 支持基本的子Agent协作
- 性能满足生产要求（并发1000+）

**预计时间**：2-3个月

---

### 阶段三：企业级增强（v0.5.x - v0.6.x）

**目标**：强化企业级特性，保持国产自主可控

**关键任务**：
1. [ ] 完善安全护栏（七层机制）
2. [ ] 增强可观测性（日志、指标、追踪）
3. [ ] 实现灰度发布和A/B测试
4. [ ] 优化多语言SDK集成Harness能力
5. [ ] 完整的文档和示例

**验收标准**：
- 安全机制通过审计
- 可观测性满足运维要求
- 多语言SDK能完整使用Harness能力
- 文档完善，示例丰富

**预计时间**：2-3个月

---

### 阶段四：生态与创新（v0.7.x - v1.0.x）

**目标**：建立生态，探索创新应用

**关键任务**：
1. [ ] 建立技能市场
2. [ ] 支持更多MCP服务器集成
3. [ ] 探索AI驱动开发的深度集成
4. [ ] 性能极致优化
5. [ ] 准备1.0正式发布

**验收标准**：
- 技能市场有一定数量的优质技能
- 与主流MCP服务器兼容
- 有创新的应用案例
- 性能达到业界领先水平
- 文档、测试、示例完整

**预计时间**：3-4个月

---

## 具体实施建议

### 1. AgentLoop编排循环实现

#### 设计思路

在现有架构中新增一个`magic.agent.loop`模块：

```
magic.agent.loop/
├── agent_loop.cj          # 主循环类
├── loop_state.cj          # 循环状态
├── step_context.cj        # 每步上下文
└── loop_listener.cj       # 循环监听器
```

#### 核心接口

```cangjie
public class AgentLoop {
    // 初始化循环
    public init(config: LoopConfig)
    
    // 执行单轮
    public runStep(input: UserInput): StepResult
    
    // 执行完整会话
    public runSession(input: UserInput): SessionResult
    
    // 暂停/恢复
    public pause(): void
    public resume(): void
    
    // 中断
    public interrupt(reason: String): void
}
```

#### TAO循环流程

```
1. 思考（Think）
   ├─ 组装提示词
   ├─ 调用LLM
   └─ 解析输出

2. 行动（Act）
   ├─ 检查工具调用
   ├─ 权限验证
   └─ 执行工具

3. 观察（Observe）
   ├─ 收集结果
   ├─ 格式化为LLM可读
   ├─ 更新上下文
   └─ 判断是否继续
```

#### 与现有架构集成

- **Controller层**：接收用户请求，启动AgentLoop
- **Service层**：协调Loop执行、工具调用、状态管理
- **Repository层**：持久化会话状态、记忆数据
- **复用现有组件**：工具调度器、权限检查器、WASM沙箱

---

### 2. 上下文管理实现

#### 五层压缩策略

```cangjie
public interface ContextCompressor {
    func compress(context: ConversationContext): CompressedContext
    func shouldTrigger(context: ConversationContext): Bool
}

// 1. 预算裁剪（始终生效）
public class BudgetTrimmer: ContextCompressor { ... }

// 2. 历史修剪（可选）
public class HistoryTrimmer: ContextCompressor { ... }

// 3. 微压缩
public class MicroCompressor: ContextCompressor { ... }

// 4. 上下文折叠（可选）
public class ContextCollapser: ContextCompressor { ... }

// 5. 自动摘要（默认开启）
public class AutoSummarizer: ContextCompressor { ... }
```

#### 观察屏蔽机制

```cangjie
public class ObservationMasker {
    // 隐藏旧工具输出，但保留调用可见
    public func maskOldObservations(context: ConversationContext): MaskedContext
    
    // 配置保留策略
    public func setRetentionPolicy(policy: RetentionPolicy): void
}
```

#### 即时检索

```cangjie
public class LazyContextLoader {
    // 按需加载文件内容
    public func loadFileOnDemand(path: String, query: String): String?
    
    // 轻量级标识符
    public func createFileReference(path: String): FileReference
}
```

---

### 3. 记忆系统实现

#### 三层记忆架构

```
memory/
├── index/              # 轻量级索引（始终加载）
│   ├── memory_index.cj
│   └── index_entry.cj
├── topic/              # 详细主题文件（按需拉取）
│   ├── topic_store.cj
│   └── topic_file.cj
└── raw/                # 原始记录（只通过搜索）
    ├── raw_store.cj
    └── raw_record.cj
```

#### 记忆管理接口

```cangjie
public class MemoryManager {
    // 短期记忆（当前会话）
    public var shortTermMemory: ShortTermMemory
    
    // 长期记忆（跨会话）
    public var longTermMemory: LongTermMemory
    
    // 写入记忆
    public func writeMemory(key: String, value: MemoryValue, level: MemoryLevel): void
    
    // 读取记忆
    public func readMemory(key: String, level: MemoryLevel?): MemoryValue?
    
    // 搜索记忆
    public func searchMemory(query: String, limit: Int): [MemorySearchResult]
    
    // 生成MEMORY.md
    public func generateMemorySummary(): String
}
```

#### 检查点机制

利用现有的数据库事务实现检查点：

```cangjie
public class CheckpointManager {
    // 创建检查点
    public func createCheckpoint(state: LoopState): Checkpoint
    
    // 恢复到检查点
    public func restoreToCheckpoint(checkpointId: String): LoopState
    
    // 时间旅行（列出可用检查点）
    public func listCheckpoints(sessionId: String): [Checkpoint]
}
```

---

### 4. 验证循环实现

#### 三种验证方式

```cangjie
public protocol Verifier {
    func verify(result: StepResult, context: VerificationContext): VerificationResult
}

// 1. 基于规则的验证
public class RuleBasedVerifier: Verifier {
    public func addRule(rule: VerificationRule): void
    public func verify(result: StepResult, context: VerificationContext): VerificationResult
}

// 2. LLM作为评判者
public class LLMEvaluatorVerifier: Verifier {
    public func verify(result: StepResult, context: VerificationContext): VerificationResult
}

// 3. 复合验证器
public class CompositeVerifier: Verifier {
    public func addVerifier(verifier: Verifier): void
    public func verify(result: StepResult, context: VerificationContext): VerificationResult
}
```

#### 验证循环集成

在AgentLoop中集成验证步骤：

```
思考 → 行动 → 验证 → 观察
              ↓
         验证失败？
              ↓
         返回给LLM重试
```

---

### 5. 错误处理增强

#### 错误分类

```cangjie
public enum ErrorType {
    case transient  // 瞬时错误，可重试
    case recoverableByLLM  // LLM可恢复
    case needsUserInput  // 需要用户输入
    case unexpected  // 意外错误，需要调试
}

public class AgentError: Error {
    public var type: ErrorType
    public var message: String
    public var retrySuggestion: RetrySuggestion?
    public var feedbackForLLM: String?
}
```

#### 智能重试策略

```cangjie
public class RetryStrategy {
    public var maxRetries: Int
    public var backoffPolicy: BackoffPolicy
    public var retryableErrorTypes: Set<ErrorType>
    
    public func shouldRetry(error: AgentError, attempt: Int): Bool
    public func getWaitTime(attempt: Int): Duration
}
```

#### 错误反馈机制

将错误格式化为LLM可读的ToolMessage：

```cangjie
public class ErrorFormatter {
    public func formatForLLM(error: AgentError): ToolMessage
    public func formatForUser(error: AgentError): UserMessage
}
```

---

### 6. 子Agent编排实现

#### 子Agent作为工具

```cangjie
@Tool(
    name = "spawn_agent",
    description = "创建子Agent处理子任务",
    parameters = [
        { name: "task", type: "string", required: true, description: "子任务描述" },
        { name: "context", type: "string", required: false, description: "子任务上下文" }
    ]
)
public func spawnAgent(task: String, context: String?) -> SubAgentResult {
    // 创建子Agent
    // 执行子任务
    // 返回压缩摘要
}
```

#### 移交机制

```cangjie
public class HandoverManager {
    // 移交控制权给另一个Agent
    public func handover(toAgentId: String, context: HandoverContext): HandoverResult
    
    // 接收移交
    public func acceptHandover(fromAgentId: String, context: HandoverContext): void
}
```

#### 三种执行模型

基于现有技能系统实现：

1. **Fork模式**：复制当前技能上下文
2. **Teammate模式**：独立技能实例，通过文件/数据库通信
3. **Worktree模式**：利用数据库事务隔离

---

### 7. 安全护栏增强

#### 七层安全机制

利用现有RBAC体系增强：

```cangjie
public class SecurityGuard {
    // 1. 工具预过滤
    private func prefilterTools(tools: [ToolDefinition], context: SecurityContext): [ToolDefinition]
    
    // 2. 拒绝优先规则
    private func checkDenyRules(request: ToolRequest): DenyResult?
    
    // 3. 权限模式检查
    private func checkPermissionPatterns(request: ToolRequest): PermissionResult
    
    // 4. ML分类器（可选）
    private func mlClassify(request: ToolRequest): ClassificationResult?
    
    // 5. 沙箱隔离（现有WASM沙箱）
    private func checkSandbox(request: ToolRequest): SandboxResult
    
    // 6. 不继承旧权限
    private func clearOldPermissions(): void
    
    // 7. Hooks拦截
    private func runHooks(request: ToolRequest): HookResult
    
    // 主检查入口
    public func checkToolRequest(request: ToolRequest): SecurityDecision
}
```

#### 权限与推理分离

保持现有设计：
- LLM决定尝试什么（推理）
- SecurityGuard决定允许什么（权限）

---

### 8. 多语言SDK增强

#### JavaScript SDK示例

```typescript
// 新的Harness相关API
class AgentLoop {
  constructor(config: LoopConfig);
  async runStep(input: UserInput): Promise<StepResult>;
  async runSession(input: UserInput): Promise<SessionResult>;
  pause(): void;
  resume(): void;
  interrupt(reason: string): void;
}

class MemoryManager {
  async write(key: string, value: any, level?: MemoryLevel): Promise<void>;
  async read(key: string, level?: MemoryLevel): Promise<any>;
  async search(query: string, limit?: number): Promise<MemorySearchResult[]>;
}

// 使用示例
const client = createClient({ baseUrl: 'http://localhost:8080' });
const loop = client.createAgentLoop({ 
  sessionId: 'my-session',
  enableMemory: true,
  enableVerification: true
});

const result = await loop.runSession({
  type: 'user_message',
  content: '帮我分析这个项目'
});
```

---

## 风险评估与应对

### 技术风险

| 风险 | 影响 | 概率 | 应对措施 |
|------|------|------|----------|
| 仓颉语言生态限制 | 高 | 中 | 充分测试，必要时用FFI集成成熟组件 |
| 性能不达标 | 高 | 中 | 早期进行性能测试，优化关键路径 |
| 与现有架构冲突 | 中 | 低 | 渐进式设计，保持向后兼容 |

**缓解策略**：
- 每个阶段都进行充分测试
- 保持核心API稳定
- 提供迁移指南和工具

---

### 进度风险

| 风险 | 影响 | 概率 | 应对措施 |
|------|------|------|----------|
| 功能开发延期 | 中 | 中 | 优先级排序，必要时裁剪功能 |
| 集成测试耗时超预期 | 中 | 中 | 提前规划测试资源，自动化测试 |

**缓解策略**：
- 采用敏捷开发，小步快跑
- 每个阶段都有可交付的版本
- 预留缓冲时间

---

### 市场风险

| 风险 | 影响 | 概率 | 应对措施 |
|------|------|------|----------|
| 竞品快速迭代 | 高 | 高 | 保持差异化定位，关注用户反馈 |
| 用户接受度低 | 中 | 中 | 充分调研，设计友好API，提供示例 |

**缓解策略**：
- 建立早期用户反馈渠道
- 提供丰富的文档和示例
- 打造成功案例

---

### 资源风险

| 风险 | 影响 | 概率 | 应对措施 |
|------|------|------|----------|
| 团队人手不足 | 高 | 中 | 优先级管理，必要时扩大团队 |
| 仓颉专家稀缺 | 中 | 中 | 知识分享，培养内部专家 |

**缓解策略**：
- 合理规划资源
- 建立知识库和文档
- 社区协作，接受外部贡献

---

## 总结

### 核心观点

1. **AgentSkills Runtime已经有很好的基础**：完整的全栈框架、国产自主可控、多语言SDK、标准化技能等都是核心竞争力

2. **借鉴Harness Engineering可以大幅提升Agent能力**：编排循环、上下文管理、记忆系统、验证循环等都是经过验证的最佳实践

3. **演进应该是渐进式的**：不追求一步到位，分阶段实施，每个阶段都有可交付的价值

4. **差异化定位是关键**：打造"具有企业级全栈能力的Harness运行时"，既不是纯Harness，也不是纯框架，而是两者的结合

### 下一步行动

1. **成立专项小组**：负责Harness能力的设计和实施
2. **技术验证**：快速验证关键技术点的可行性
3. **用户调研**：了解目标用户的需求和痛点
4. **制定详细计划**：将路线图细化为可执行的任务

### 愿景

通过渐进式的演进，将AgentSkills Runtime打造为：
- **国产自主可控**的AI Agent运行时
- **企业级**的全栈框架
- **Harness工程**最佳实践的集大成者
- **开发者友好**的AI原生开发平台

让AgentSkills Runtime成为连接传统软件系统与AI智能体的桥梁，推动AI技术在更多场景落地！

---

## 参考资料

1. [Harness Engineering vs AI驱动全栈开发框架对比分析](./doubaoseed2harnessVSAIinfra.md)
2. [Agent Harness 解析：智能体架构深度拆解](./harness.md)
3. [Claude Code源码分析](./claude-code.md)
4. [AgentSkills Runtime README](../README_cn.md)
5. [UCToo技术体系文档](../../../README.md)
6. LangChain/LangGraph文档
7. OpenAI Agents SDK文档
8. Claude Code官方文档

---

**文档版本**：v1.0  
**最后更新**：2026-05-19  
**作者**：DoubaoSeed AI Assistant
