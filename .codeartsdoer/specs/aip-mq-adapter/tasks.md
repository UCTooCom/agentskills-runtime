# MQ消息分发适配器 - 编码任务规划

**版本**: v1.1.0  
**创建日期**: 2026-07-10  
**最后更新**: 2026-07-11
**关联需求**: aip-mq-adapter spec.md v1.1.0  
**关联设计**: aip-mq-adapter design.md v1.0.0  
**技术栈**: 仓颉语言 / cjpm / activemq4cj / hyperion / f_orm  
**项目根目录**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime`

---

## 任务依赖关系图

```
Phase 1: 本地依赖集成
  1.1 复制 activemq4cj/hyperion 到 libs/ ────┐
  1.2 修改 cjpm.toml（项目+libs内部） ────────┤
  1.3 hyperion 仓颉1.0.4版本适配 ─────────────┤
  1.4 activemq4cj 仓颉1.0.4版本适配 ─────────┤
  1.5 集成编译验证 ───────────────────────────┤
  1.6 编写 VERSION_ADAPTATION.md ─────────────┘
                                              ↓
Phase 2: AcpsMqAdapter 核心实现
  2.1 MQ 数据模型（6个文件） ────────────────┐
  2.2 AcpsMqAdapter 骨架 ────────────────────┤
  2.3 MqConnectionManager ───────────────────┤
  2.4 MqAuthClient ──────────────────────────┤
  2.5 MqGroupChannelManager ─────────────────┤
  2.6 MqMessageDispatcher ───────────────────┤
  2.7 MqMessageCallback ─────────────────────┘
                                              ↓
Phase 3: 集成与扩展
  3.1 AipInteractionService 集成 MQ ─────────┐
  3.2 AipModeManager 集成 MQ ────────────────┤
  3.3 AipConfigService 集成 MQ ──────────────┤
  3.4 编译验证 ──────────────────────────────┤
  3.5 集成测试 ──────────────────────────────┘
```

---

## 关键约定

1. **cangjie-coder 技能**：所有仓颉代码的编写、修改和适配工作，必须使用 cangjie-coder 技能的四步工作流程执行（Consult→Retrieval→Editing→Writing），禁止直接生成仓颉代码
2. **日志规范**：统一使用 `magic.log.LogUtils`
3. **命名规范**：数据库列名 snake_case，仓颉代码 camelCase
4. **JsonObject 构造**：`JsonObject` 没有 `add` 方法，必须用 `HashMap<String, JsonValue>` 收集后构造
5. **Option 类型**：使用 `?T` 别名代替 `Option<T>`
6. **DAO 方法**：DAO 方法不在 SqlExecutor 上直接可用，必须 import 对应 DAO 接口
7. **编译验证**：需通知人工执行 `cjpm build`
8. **版本适配原则**：仅修改因仓颉 SDK 版本差异导致编译不通过的代码，不进行功能增强或重构
9. **复用原则**：优先复用和完善已有基础设施，不重新开发

---

## 1. 本地依赖集成 [Phase 1]

### 1.1 复制 activemq4cj/hyperion 源码到 libs/ [Phase 1 | 必须 | 0.5h] ✅
- [x] 将 `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\CangjieMagic\resource\TPC\activemq4cj` 整个目录复制到 `libs/activemq4cj/`
- [x] 将 `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\CangjieMagic\resource\TPC\hyperion` 整个目录复制到 `libs/hyperion/`
- [x] 确认 `libs/activemq4cj/` 包含完整源码（src/ 目录）、cjpm.toml、LICENSE、README.md
- [x] 确认 `libs/hyperion/` 包含完整源码（src/ 目录）、cjpm.toml、LICENSE、README.md
- [x] 保留原始 TPC 项目的 .git 目录或记录来源信息（上游仓库 gitcode.com/Cangjie-TPC/activemq4cj 分支 main 版本 1.0.0；gitcode.com/Cangjie-TPC/hyperion 分支 master 版本 3.0.0）
- **依赖**: 无
- **cangjie-coder**: Consult：无需；Retrieval：无需
- **输入**: design.md §2.4.1 libs 目录结构
- **输出**: `libs/activemq4cj/`、`libs/hyperion/` 完整目录
- **验收**: libs/ 目录下存在 activemq4cj/ 和 hyperion/ 目录，各包含 src/、cjpm.toml、LICENSE、README.md

### 1.2 修改 cjpm.toml 依赖声明 [Phase 1 | 必须 | 0.5h] ✅
- [x] 修改项目根目录 `cjpm.toml`，在 `[dependencies]` 部分新增：
  - `activemq4cj = { path = "./libs/activemq4cj", compile-option = "-Woff unused" }`
  - `hyperion = { path = "./libs/hyperion", compile-option = "-Woff unused" }`
- [x] 修改 `libs/activemq4cj/cjpm.toml`：
  - 将 `cjc-version` 从 `"1.0.0"` 更新为 `"1.0.4"`
  - 将 hyperion 依赖从 git 远程方式改为 `hyperion = { path = "../hyperion" }`
  - 保留或新增 `override-compile-option = "-Woff unused"`
  - 确认 `output-type = "static"`
- [x] 修改 `libs/hyperion/cjpm.toml`：
  - 将 `cjc-version` 从 `"1.0.0"` 更新为 `"1.0.4"`
  - 确认 `output-type = "static"`
- [x] 确认 `CANGJIE_STDX_PATH` 环境变量已正确配置（activemq4cj 的 cjpm.toml [target] 配置依赖此变量）
- **依赖**: 1.1
- **cangjie-coder**: Consult：查阅 cjpm.toml 配置语法；Retrieval：检索现有 libs/fountain 的 cjpm.toml 作为参考
- **输入**: design.md §2.4.2 cjpm.toml 依赖声明、§2.4.3 CANGJIE_STDX_PATH
- **输出**: 修改后的 `cjpm.toml`、`libs/activemq4cj/cjpm.toml`、`libs/hyperion/cjpm.toml`
- **验收**: 项目 cjpm.toml 包含 activemq4cj 和 hyperion 的 path 依赖；libs 内部 cjpm.toml 的 cjc-version 为 "1.0.4"；activemq4cj 的 hyperion 依赖为 path 方式

### 1.3 hyperion 仓颉1.0.4版本适配 [Phase 1 | 必须 | 2-4h] ✅
- [x] 在 `libs/hyperion/` 目录下执行编译（通知人工执行 `cjpm build`），记录编译错误
- [x] 使用 cangjie-coder 技能逐个修复编译错误，遵循最小化修改原则：
  - 仅修改因仓颉 SDK 版本差异导致编译不通过的代码
  - 不进行功能增强、重构或优化
  - 不修改公共 API 签名
- [x] 每修复一个编译错误，在 `libs/hyperion/VERSION_ADAPTATION.md` 中记录变更（修改文件、修改内容、适配原因、变更日期）
- [x] 重复编译-修复-记录流程，直到 hyperion 编译通过
- [x] 处理编译警告：通过 `override-compile-option` 抑制已知警告或修改代码消除
- **依赖**: 1.2
- **cangjie-coder**: Consult：查阅仓颉 SDK 1.0.4 API 变更文档；Retrieval：检索 hyperion 源码中的编译错误位置
- **输入**: design.md §2.4.4 版本适配策略、§5.7 版本适配业务规则
- **输出**: 修改后的 `libs/hyperion/src/` 下的文件、`libs/hyperion/VERSION_ADAPTATION.md`
- **验收**: hyperion 在仓颉 SDK 1.0.4 下编译通过，无编译错误；VERSION_ADAPTATION.md 记录所有变更

### 1.4 activemq4cj 仓颉1.0.4版本适配 [Phase 1 | 必须 | 2-4h] ✅
- [x] 在 `libs/activemq4cj/` 目录下执行编译（通知人工执行 `cjpm build`），记录编译错误
- [x] 使用 cangjie-coder 技能逐个修复编译错误，遵循最小化修改原则：
  - 仅修改因仓颉 SDK 版本差异导致编译不通过的代码
  - 不进行功能增强、重构或优化
  - 不修改公共 API 签名
- [x] 每修复一个编译错误，在 `libs/activemq4cj/VERSION_ADAPTATION.md` 中记录变更
- [x] 重复编译-修复-记录流程，直到 activemq4cj 编译通过
- [x] 处理编译警告：通过 `override-compile-option` 抑制已知警告或修改代码消除
- **依赖**: 1.3（hyperion 必须先编译通过，activemq4cj 依赖 hyperion）
- **cangjie-coder**: Consult：查阅仓颉 SDK 1.0.4 API 变更文档；Retrieval：检索 activemq4cj 源码中的编译错误位置
- **输入**: design.md §2.4.4 版本适配策略、§5.7 版本适配业务规则
- **输出**: 修改后的 `libs/activemq4cj/src/` 下的文件、`libs/activemq4cj/VERSION_ADAPTATION.md`
- **验收**: activemq4cj 在仓颉 SDK 1.0.4 下编译通过，无编译错误；VERSION_ADAPTATION.md 记录所有变更

### 1.5 集成编译验证 [Phase 1 | 必须 | 1h] ✅
- [x] 在项目根目录执行 `cjpm build`（通知人工执行），验证 activemq4cj 和 hyperion 与 agentskills-runtime 集成编译通过
- [x] 确认项目现有功能不受影响（编译无新增错误）
- [x] 确认 activemq4cj 的 import 路径可被项目代码正确解析（如 `import activemq4cj.cjms.CJMSContext`）
- [x] 如编译失败，根据错误信息定位问题并修复
- **依赖**: 1.4
- **cangjie-coder**: Consult：查阅 cjpm 构建系统文档；Retrieval：检索编译错误涉及的依赖关系
- **输入**: 全部 Phase 1 修改后的文件
- **输出**: 编译通过确认
- **验收**: `cjpm build` 成功，无错误输出；activemq4cj/hyperion 的 import 可正常解析

### 1.6 编写版本适配变更日志 [Phase 1 | 必须 | 0.5h] ✅
- [x] 确认 `libs/hyperion/VERSION_ADAPTATION.md` 已创建，包含：
  - 上游信息：仓库 gitcode.com/Cangjie-TPC/hyperion，分支 master，版本 3.0.0
  - 适配目标：仓颉 SDK 1.0.4
  - 所有变更记录（修改文件、修改内容、适配原因、变更日期）
- [x] 确认 `libs/activemq4cj/VERSION_ADAPTATION.md` 已创建，包含：
  - 上游信息：仓库 gitcode.com/Cangjie-TPC/activemq4cj，分支 main，版本 1.0.0
  - 适配目标：仓颉 SDK 1.0.4
  - 所有变更记录（修改文件、修改内容、适配原因、变更日期）
- [x] 确认每条变更记录均有明确的版本兼容性原因，无功能性变更
- **依赖**: 1.3, 1.4
- **cangjie-coder**: Consult：无需；Retrieval：无需
- **输入**: design.md §2.4.4 VERSION_ADAPTATION.md 格式
- **输出**: `libs/hyperion/VERSION_ADAPTATION.md`、`libs/activemq4cj/VERSION_ADAPTATION.md`
- **验收**: 两个 VERSION_ADAPTATION.md 文件格式规范，内容完整，所有变更可追溯

---

## 2. AcpsMqAdapter 核心实现 [Phase 2]

### 2.1 新增 MQ 数据模型 [Phase 2 | 必须 | 1h] ✅
- [x] 创建 `src/app/services/aip/model/MqConnectionState.cj`：MQ 连接状态枚举
  - 枚举值：`Disconnected | Connecting | Connected | Reconnecting | Unavailable`
  - 使用仓颉枚举语法（`|` 分隔枚举值）
- [x] 创建 `src/app/services/aip/model/MqGroupChannelInfo.cj`：群组通道信息数据类
  - 字段：sessionId(String), topicName(String), producer(?CJMSProducer), consumers(HashMap<String, CJMSConsumer>), durableSubscriptions(ArrayList<String>), createdAt(DateTime)
- [x] 创建 `src/app/services/aip/model/MqAuthRequest.cj`：MQ 鉴权请求数据类
  - 字段：requesterAic(String), operation(String), groupId(String), targetAic(?String)
- [x] 创建 `src/app/services/aip/model/MqAuthResult.cj`：MQ 鉴权结果数据类
  - 字段：allowed(Bool), reason(?String)
- [x] 创建 `src/app/services/aip/model/MqGroupChannelResult.cj`：群组通道创建结果数据类
  - 字段：sessionId(String), topicName(String), subscribedMembers(ArrayList<String>), failedMembers(ArrayList<String>)
- [x] 创建 `src/app/services/aip/model/MqConnectionConfig.cj`：MQ 连接配置数据类
  - 字段：brokerUrl(String), username(String), password(String), tlsEnabled(Bool), maxReconnectAttempts(Int64), reconnectDelay(Int64)
- [x] 在 `src/app/services/aip/model/pkg.cj` 中添加新文件的 public 声明
- **依赖**: 1.5
- **cangjie-coder**: Consult：查阅仓颉 enum/class 语法；Retrieval：检索现有 model 文件（如 AipMode.cj、AcsDescription.cj）作为参考
- **输入**: design.md §2.3.2 模型实现、§2.8.1 新增文件
- **输出**: 6 个新文件 + 修改后的 `pkg.cj`
- **验收**: 6 个数据模型文件编译通过，枚举和类定义符合仓颉语法规范

### 2.2 AcpsMqAdapter 骨架实现 [Phase 2 | 必须 | 1h] ✅
- [x] 创建 `src/app/services/aip/acps/AcpsMqAdapter.cj`，实现以下公共方法骨架：
  - `createGroupChannel(sessionId, requesterAic, memberAics, durable): APIResult<MqGroupChannelResult>` — 创建群组通道
  - `publishGroupMessage(sessionId, messageId, senderAic, senderRole, dataItems, deliveryMode, timeToLive): APIResult<Bool>` — 发布群组消息
  - `subscribeGroupChannel(sessionId, subscriberAic, durable): APIResult<Bool>` — 订阅群组通道
  - `unsubscribeGroupChannel(sessionId, subscriberAic): APIResult<Bool>` — 退订群组通道
  - `destroyGroupChannel(sessionId): APIResult<Bool>` — 销毁群组通道
  - `releaseAllResources(): APIResult<Bool>` — 释放所有 MQ 资源
  - `checkConnectivity(): Bool` — 检查 MQ 连通性
  - `getConnectionState(): MqConnectionState` — 获取连接状态
  - `setMessageCallback(callback): Unit` — 注册消息回调
- [x] 实现模式检查方法 `ensureInterconnectionMode()`：检查当前是否为互联模式，本地模式下所有公共方法返回降级提示
- [x] 实现本地模式降级兼容：每个公共方法开头调用 `ensureInterconnectionMode()`，本地模式返回对应降级提示
  - createGroupChannel/publishGroupMessage/subscribeGroupChannel/unsubscribeGroupChannel → 返回 APIResult 失败提示
  - destroyGroupChannel/releaseAllResources → 返回 APIResult 成功（无需操作）
  - checkConnectivity → 返回 false
  - getConnectionState → 返回 MqConnectionState.Disconnected
- [x] 定义内部状态变量：
  - `connectionState: MqConnectionState = MqConnectionState.Disconnected`
  - `groupChannels: HashMap<String, MqGroupChannelInfo>`
  - `jmsContext: ?CJMSContext`
  - `messageCallback: ?MqMessageCallbackFunc`
- [x] 在 `src/app/services/aip/acps/pkg.cj` 中添加 AcpsMqAdapter 的 public 声明
- **依赖**: 2.1
- **cangjie-coder**: Consult：查阅仓颉 class 语法；Retrieval：检索 AcpsRegistryAdapter.cj 作为适配器模式参考
- **输入**: design.md §2.5.1 类结构、§2.5.6 本地模式降级兼容设计、§2.2.2 接口清单
- **输出**: `src/app/services/aip/acps/AcpsMqAdapter.cj`、修改后的 `pkg.cj`
- **验收**: AcpsMqAdapter 编译通过；本地模式下所有公共方法返回正确的降级提示

### 2.3 MqConnectionManager 连接管理实现 [Phase 2 | 必须 | 3h] ✅
- [x] 在 AcpsMqAdapter 中实现连接管理内部方法：
  - `establishConnection(): APIResult<Bool>` — 建立 JMS 连接
    1. 检查当前模式（仅互联模式允许）
    2. 检查连接状态（已连接则直接返回成功）
    3. 更新状态为 Connecting
    4. 调用 `loadConnectionConfig()` 加载连接配置
    5. 构建 `ActiveMQConnectionFactory(brokerURL)`（Failover 格式直接嵌入 brokerURL）
    6. 使用 `factory.createContext(userName, password, AcknowledgeMode.AUTO_ACKNOWLEDGE)` 创建 CJMSContext
    7. 更新状态为 Connected，保存 jmsContext 引用
    8. 连接失败时更新状态为 Unavailable，返回错误码 AIP-MQ-002
    9. 认证失败时返回错误码 AIP-MQ-001
  - `closeConnection(): Unit` — 关闭 JMS 连接
    1. 关闭所有群组通道的 Producer 和 Consumer
    2. 关闭 CJMSContext
    3. 清空 jmsContext 引用
    4. 更新状态为 Disconnected
  - `loadConnectionConfig(): Option<MqConnectionConfig>` — 加载连接配置
    1. 优先从环境变量获取：AIP_MQ_ENDPOINT、AIP_MQ_USERNAME、AIP_MQ_PASSWORD、AIP_MQ_TLS_ENABLED、AIP_MQ_MAX_RECONNECT_ATTEMPTS、AIP_MQ_RECONNECT_DELAY
    2. 环境变量缺失时从 aip_service_config 表获取（service_type='mq'）
    3. 必填项（brokerUrl/username/password）缺失时返回 None 并记录错误
  - `handleConnectionException(exception): Unit` — 处理连接异常
    1. 记录异常日志
    2. 更新状态为 Reconnecting
    3. Failover 机制由 activemq4cj 内部处理
    4. 所有 broker 不可用时更新状态为 Unavailable
- [x] 修改 `createGroupChannel()` 骨架：在创建群组通道前先调用 `establishConnection()` 确保 MQ 连接可用
- [x] 修改 `releaseAllResources()` 骨架：调用 `closeConnection()` 关闭所有 MQ 资源
- [x] import activemq4cj 相关类型：
  - `import activemq4cj.cjms.CJMSContext`
  - `import activemq4cj.cjms.AcknowledgeMode`
  - `import activemq4cj.client.ActiveMQConnectionFactory`
- **依赖**: 2.2
- **cangjie-coder**: Consult：查阅 activemq4cj API 文档（ActiveMQConnectionFactory/CJMSContext/AcknowledgeMode）；Retrieval：检索现有 AcpsRegistryAdapter 的 getEnv 和 HttpUtils 通信模式
- **输入**: design.md §2.5.2 MQ 连接管理设计、§2.10.3 activemq4cj API 使用规范
- **输出**: 修改后的 `AcpsMqAdapter.cj`
- **验收**: establishConnection() 可根据环境变量配置创建 CJMSContext；连接失败时返回正确错误码；本地模式下不建立连接

### 2.4 MqAuthClient 鉴权客户端实现 [Phase 2 | 必须 | 1.5h] ✅
- [x] 在 AcpsMqAdapter 中实现鉴权管理内部方法：
  - `checkAcl(authRequest: MqAuthRequest): APIResult<MqAuthResult>` — ACL 鉴权校验
    1. 获取鉴权服务 URL（`getAuthUrl()`）
    2. 鉴权服务 URL 未配置时返回错误码 AIP-MQ-013
    3. 构建 HTTP 请求体（requesterAic/operation/groupId/targetAic）
    4. 使用 HttpUtils.post() 调用 mq-auth-server 的 ACL 校验接口
    5. 解析鉴权响应，返回 MqAuthResult
    6. 鉴权失败时返回错误码 AIP-MQ-005
    7. 鉴权服务不可用时返回错误码 AIP-MQ-013
  - `getAuthUrl(): String` — 获取鉴权服务 URL
    1. 优先从环境变量 AIP_MQ_AUTH_URL 获取
    2. 其次从 aip_service_config 表获取
- [x] 在 `createGroupChannel()` 中集成 ACL 鉴权：创建群组通道前调用 `checkAcl(create_group)`
- [x] 在 `publishGroupMessage()` 中集成 ACL 鉴权：发布消息前调用 `checkAcl(publish_message)`
- [x] 在 `subscribeGroupChannel()` 中集成 ACL 鉴权：订阅前调用 `checkAcl(subscribe_group)`
- [x] 在 `unsubscribeGroupChannel()` 中集成 ACL 鉴权：退订前调用 `checkAcl(unsubscribe_group)`
- **依赖**: 2.2
- **cangjie-coder**: Consult：查阅 HttpUtils API；Retrieval：检索 AcpsRegistryAdapter.cj 的 buildHeaders/submitRegistration 方法作为 HTTP 通信模式参考
- **输入**: design.md §2.5.5 MQ 鉴权集成设计、§2.4.2 鉴权请求格式
- **输出**: 修改后的 `AcpsMqAdapter.cj`
- **验收**: ACL 鉴权校验可调用 mq-auth-server；鉴权失败返回 AIP-MQ-005；鉴权服务不可用返回 AIP-MQ-013

### 2.5 MqGroupChannelManager 群组通道管理实现 [Phase 2 | 必须 | 3h] ✅
- [x] 在 AcpsMqAdapter 中实现群组通道管理内部方法：
  - `createTopicAndConsumers(sessionId, memberAics, durable): APIResult<MqGroupChannelResult>` — 创建 Topic 和 Consumer
    1. 通过 `context.createTopic("aip.group.${sessionId}")` 创建 Topic
    2. 通过 `context.createProducer()` 创建 CJMSProducer
    3. 配置 Producer：`setDeliveryMode(DeliveryMode.PERSISTENT)`、`setTimeToLive(0)`
    4. 为每个 memberAic 创建 CJMSConsumer：
       - 非持久订阅：`context.createConsumer(topic)`
       - 持久订阅：`context.createDurableConsumer(topic, "aip.sub.${memberAic}.${sessionId}", null, false)`
    5. 为每个 Consumer 注册 MessageListener（调用 MqMessageCallback 的 onMessage）
    6. 创建 MqGroupChannelInfo 缓存到 groupChannels
    7. 返回 MqGroupChannelResult（包含已订阅和失败的成员列表）
  - `closeTopicAndConsumers(sessionId): APIResult<Bool>` — 关闭 Topic 的 Consumer 和 Producer
    1. 从 groupChannels 获取 MqGroupChannelInfo
    2. 关闭所有 CJMSConsumer
    3. 关闭 CJMSProducer
    4. 从 groupChannels 移除
    5. 关闭失败时记录警告 AIP-MQ-008
  - `addConsumer(sessionId, subscriberAic, durable): APIResult<Bool>` — 为指定智能体添加 Consumer
  - `removeConsumer(sessionId, subscriberAic): APIResult<Bool>` — 移除指定智能体的 Consumer
- [x] 完善 `createGroupChannel()` 实现：调用 `checkAcl()` → `establishConnection()` → `createTopicAndConsumers()`
- [x] 完善 `subscribeGroupChannel()` 实现：调用 `checkAcl()` → `addConsumer()`
- [x] 完善 `unsubscribeGroupChannel()` 实现：调用 `checkAcl()` → `removeConsumer()`
- [x] 完善 `destroyGroupChannel()` 实现：调用 `closeTopicAndConsumers()`
- [x] import activemq4cj 相关类型：
  - `import activemq4cj.cjms.CJMSProducer`
  - `import activemq4cj.cjms.CJMSConsumer`
  - `import activemq4cj.cjms.Topic`
  - `import activemq4cj.cjms.DeliveryMode`
- **依赖**: 2.3, 2.4
- **cangjie-coder**: Consult：查阅 activemq4cj API 文档（Topic/CJMSConsumer/CJMSProducer/DeliveryMode/createDurableConsumer）；Retrieval：检索现有 Consumer 创建代码参考
- **输入**: design.md §2.5.3 群组通道管理设计、§2.10.3 activemq4cj API 使用规范
- **输出**: 修改后的 `AcpsMqAdapter.cj`
- **验收**: 群组通道可创建 Topic 和 Consumer；持久订阅可正确创建；群组通道信息缓存到 groupChannels；销毁时资源正确释放

### 2.6 MqMessageDispatcher 消息分发实现 [Phase 2 | 必须 | 2h] ✅
- [x] 在 AcpsMqAdapter 中实现消息分发内部方法：
  - `publishToTopic(sessionId, messageId, senderAic, senderRole, dataItems, deliveryMode, timeToLive): APIResult<Bool>` — 发布消息到 Topic
    1. 从 groupChannels 获取群组通道信息
    2. 群组通道不存在时返回错误码 AIP-MQ-009
    3. 构建符合 GB/Z 185.6 的消息体（JSON 格式），包含 messageId/sessionId/senderAic/senderRole/dataItems/taskId
    4. 通过 `context.createTextMessage(jsonBody)` 创建 TextMessage
    5. 设置 JMS 属性：`message.setStringProperty("messageId", messageId)`、`message.setStringProperty("sessionId", sessionId)`、`message.setStringProperty("senderAic", senderAic)`、`message.setStringProperty("senderRole", senderRole)`
    6. 配置 Producer 的投递模式和 TTL：
       - deliveryMode="PERSISTENT" → `producer.setDeliveryMode(DeliveryMode.PERSISTENT)`
       - deliveryMode="NON_PERSISTENT" → `producer.setDeliveryMode(DeliveryMode.NON_PERSISTENT)`
       - timeToLive > 0 → `producer.setTimeToLive(timeToLive)`
    7. 通过 `producer.send(topic, message)` 发送消息
    8. 发送失败时返回错误码 AIP-MQ-009
- [x] 完善 `publishGroupMessage()` 实现：调用 `checkAcl(publish_message)` → `publishToTopic()`
- [x] import activemq4cj 相关类型：
  - `import activemq4cj.cjms.TextMessage`
  - `import activemq4cj.cjms.Message`
- **依赖**: 2.5
- **cangjie-coder**: Consult：查阅 activemq4cj API 文档（CJMSProducer/TextMessage/DeliveryMode）；Retrieval：检索现有消息格式转换代码参考
- **输入**: design.md §2.5.4 群组消息分发设计、§2.10.3 activemq4cj API 使用规范
- **输出**: 修改后的 `AcpsMqAdapter.cj`
- **验收**: 消息可发布到 Topic；消息格式符合 GB/Z 185.6 标准；JMS 属性正确设置；投递模式和 TTL 可配置

### 2.7 MqMessageCallback 消息接收回调实现 [Phase 2 | 必须 | 2h] ✅
- [x] 创建 `src/app/services/aip/model/MqMessageCallbackFunc.cj`：消息回调函数类型定义
  - `public type MqMessageCallbackFunc = (String, String, String, String, String, ?String) -> APIResult<Bool>`
  - 参数：sessionId, messageId, senderAic, senderRole, dataItems, taskId?
- [x] 在 AcpsMqAdapter 中创建内部类 `MqMessageListener`，实现 `MessageListener` 接口：
  - `private let callback: ?MqMessageCallbackFunc`
  - `private let processedIds: HashSet<String>` — 消息去重缓存（容量上限 1000 条）
  - `public func onMessage(message: Message): Unit` — 消息监听回调
    1. 检查 message 是否为 TextMessage 实例
    2. 从 TextMessage 获取 body（`textMsg.getText()`）
    3. 从 JMS 属性获取 messageId/sessionId/senderAic/senderRole（`message.getStringProperty("messageId")`）
    4. 基于 messageId 去重检查（processedIds 中已存在则跳过）
    5. 去重缓存满时淘汰最早的条目（FIFO）
    6. 调用注册的 callback 函数
    7. 回调成功后将 messageId 加入 processedIds
    8. 回调异常时记录错误日志 AIP-MQ-010
- [x] 在 AcpsMqAdapter 中完善 `setMessageCallback()` 实现：
  - 保存回调函数引用到 `messageCallback`
  - 为所有已存在的 Consumer 重新注册 MessageListener
- [x] 在 `createTopicAndConsumers()` 中集成：为每个新创建的 Consumer 注册 MqMessageListener
- [x] import activemq4cj 相关类型：
  - `import activemq4cj.cjms.MessageListener`
  - `import activemq4cj.cjms.Message`
  - `import activemq4cj.cjms.TextMessage`
- **依赖**: 2.5, 2.1
- **cangjie-coder**: Consult：查阅 activemq4cj API 文档（MessageListener/Message/TextMessage）；Retrieval：检索现有回调实现代码参考
- **输入**: design.md §2.5.4 消息接收流程、§2.3.2 消息回调类型定义、§2.10.3 MessageListener 接口
- **输出**: `src/app/services/aip/model/MqMessageCallbackFunc.cj`、修改后的 `AcpsMqAdapter.cj`
- **验收**: MessageListener 可接收 MQ 消息；消息去重基于 messageId 生效；回调函数可正确调用；去重缓存满时 FIFO 淘汰

---

## 3. 集成与扩展 [Phase 3]

### 3.1 AipInteractionService 集成 MQ 群组交互 [Phase 3 | 必须 | 2h] ✅
- [x] 修改 `src/app/services/aip/AipInteractionService.cj`，在 `createInterconnectionSession()` 方法中扩展：
  - 在创建 aip_interaction_session 记录后，检查是否为互联模式且 interactionMode == "group"
  - 若是，调用 `AcpsMqAdapter.createGroupChannel(sessionId, requesterAic, memberAics, durable)`
  - MQ 创建失败时记录日志，不影响会话创建（数据库写入优先）
  - import `magic.app.services.aip.acps.AcpsMqAdapter`
- [x] 修改 `sendInterconnectionMessage()` 方法，在双写 aip_interaction_message + agent_messages 后扩展：
  - 检查是否为互联模式且 MQ 连接可用
  - 若是，调用 `AcpsMqAdapter.publishGroupMessage(sessionId, messageId, senderAic, senderRole, dataItems, "PERSISTENT", 0)`
  - MQ 发布失败时记录日志，不影响数据库写入（数据库写入优先）
- [x] 修改 `closeInterconnectionSession()` 方法，在更新 session_status = "closed" 前扩展：
  - 检查是否为互联模式
  - 若是，调用 `AcpsMqAdapter.destroyGroupChannel(sessionId)`
  - MQ 销毁失败时记录日志，不影响会话关闭
- [x] 新增 `handleMqMessage()` 方法：
  - `handleMqMessage(sessionId: String, messageId: String, senderAic: String, senderRole: String, dataItems: String, taskId: Option<String>): APIResult<Bool>`
  - 1. 基于 messageId 去重检查（查询 aip_interaction_message 表是否已存在）
  - 2. 写入 aip_interaction_message 表
  - 3. 写入 agent_messages 表
  - 4. 返回处理结果
  - 处理异常时返回错误码 AIP-MQ-010
- [x] 在 AipInteractionService 初始化时注册 MQ 消息回调：
  - 创建 AcpsMqAdapter 实例
  - 调用 `mqAdapter.setMessageCallback(handleMqMessage)` 注册回调
- **依赖**: 2.7
- **cangjie-coder**: Consult：查阅仓颉方法扩展语法；Retrieval：检索 AipInteractionService.cj 现有方法实现
- **输入**: design.md §2.6.1 与 AipInteractionService 集成
- **输出**: 修改后的 `AipInteractionService.cj`
- **验收**: 互联模式下创建群组会话时自动创建 MQ 群组通道；发送消息时自动发布到 Topic；关闭会话时自动销毁群组通道；MQ 消息接收后可回调双写；MQ 操作失败不阻塞数据库写入

### 3.2 AipModeManager 集成 MQ 降级和连通性 [Phase 3 | 必须 | 1h] ✅
- [x] 修改 `src/app/services/aip/AipModeManager.cj`，在 `degradeToLocal()` 方法中扩展：
  - 在切换 currentMode = Local 之前，调用 `AcpsMqAdapter.releaseAllResources()`
  - MQ 资源释放失败时记录警告 AIP-MQ-014，继续降级（不阻塞降级流程）
  - import `magic.app.services.aip.acps.AcpsMqAdapter`
- [x] 修改 `checkAcpsConnectivity()` 方法扩展：
  - 新增 MQ 连通性检查：`AcpsMqAdapter.checkConnectivity()`
  - 将结果写入 `result.mqReachable`
  - MQ 不影响 overallAvailable 判定（仅 registry + ca 决定 overallAvailable）
- [x] 扩展 `AcpsConnectivityResult` 类，新增字段：
  - `public var mqReachable: Bool = false`
- [x] 修改 `upgradeToInterconnection()` 方法：
  - 升级成功后不立即建立 MQ 连接（按需建立）
  - 仅标记 MQ 可用
- **依赖**: 2.7
- **cangjie-coder**: Consult：查阅仓颉类扩展语法；Retrieval：检索 AipModeManager.cj 现有方法实现
- **输入**: design.md §2.6.2 与 AipModeManager 集成
- **输出**: 修改后的 `AipModeManager.cj`
- **验收**: 降级时自动释放 MQ 资源；MQ 资源释放失败不阻塞降级；AcpsConnectivityResult 包含 mqReachable 字段；MQ 不影响 overallAvailable

### 3.3 AipConfigService 集成 MQ 健康检查 [Phase 3 | 必须 | 0.5h] ✅
- [x] 修改 `src/app/services/aip/AipConfigService.cj`，在 `healthCheckInterconnection()` 方法中扩展：
  - 替换当前 mqService 的 "not yet integrated" 逻辑
  - 调用 `AcpsMqAdapter.checkConnectivity()` 获取真实 MQ 连通性状态
  - MQ 可用时 mqService 状态为 "healthy"
  - MQ 不可用时 mqService 状态为 "unhealthy"，但 overallStatus 为 "degraded"（而非 "unhealthy"，因为 MQ 为可选依赖）
  - import `magic.app.services.aip.acps.AcpsMqAdapter`
- **依赖**: 2.7
- **cangjie-coder**: Consult：查阅仓颉方法扩展语法；Retrieval：检索 AipConfigService.cj 现有 healthCheckInterconnection 方法
- **输入**: design.md §2.6.3 与 AipConfigService/AipHealthController 集成
- **输出**: 修改后的 `AipConfigService.cj`
- **验收**: 互联健康检查返回真实的 MQ 连通性状态；MQ 不可用时 overallStatus 为 "degraded"

### 3.4 编译验证 [Phase 3 | 必须 | 1h] ✅
- [x] 通知人工执行 `cjpm build`，验证所有新增和修改文件编译通过
- [x] 验证 import 引用完整：
  - AcpsMqAdapter 中的 activemq4cj 相关 import
  - AipInteractionService 中的 AcpsMqAdapter import
  - AipModeManager 中的 AcpsMqAdapter import
  - AipConfigService 中的 AcpsMqAdapter import
- [x] 验证 MqMessageListener 的 MessageListener 接口实现正确
- [x] 验证 MqConnectionState 枚举在所有使用处正确匹配
- [x] 验证 MqGroupChannelInfo/MqAuthRequest/MqAuthResult 等数据类字段类型正确
- [x] 如编译失败，使用 cangjie-coder 技能修复编译错误
- **依赖**: 3.1, 3.2, 3.3
- **cangjie-coder**: Consult：查阅仓颉编译错误修复文档；Retrieval：检索编译错误涉及的代码位置
- **输入**: 全部新增和修改文件
- **输出**: 编译通过确认
- **验收**: `cjpm build` 成功，无错误输出

### 3.5 集成测试 [Phase 3 | 必须 | 2h]
- [x] 验证本地模式降级兼容：本地模式下调用 AcpsMqAdapter 所有方法返回降级提示
- [x] 验证 MQ 连接管理：
  - 配置 AIP_MQ_ENDPOINT/AIP_MQ_USERNAME/AIP_MQ_PASSWORD 环境变量
  - 调用 createGroupChannel() 触发按需连接建立
  - 验证 getConnectionState() 返回 Connected
- [x] 验证群组通道管理：
  - 创建群组通道 → Topic 名称格式为 `aip.group.{sessionId}`
  - 订阅群组通道 → Consumer 创建成功
  - 退订群组通道 → Consumer 关闭
  - 销毁群组通道 → 资源释放
- [x] 验证群组消息分发：
  - 发布群组消息 → 消息发送到 Topic
  - 消息接收回调 → handleMqMessage() 双写消息
  - 消息去重 → 重复 messageId 不重复处理
- [x] 验证 MQ 鉴权集成：
  - ACL 鉴权通过 → 群组操作成功
  - ACL 鉴权失败 → 返回 AIP-MQ-005
  - 鉴权服务不可用 → 返回 AIP-MQ-013
- [x] 验证模式降级 MQ 资源释放：
  - 互联模式降级为本地模式 → MQ 资源释放，连接状态变为 Disconnected
  - 降级后再升级 → 首次群组交互时按需建立连接
- [x] 验证健康检查：
  - 互联健康检查返回 MQ 连通性状态
  - MQ 不可用时 overallStatus 为 "degraded"
- [x] 验证错误码体系：AIP-MQ-001~014 在对应场景下正确返回
- **依赖**: 3.4
- **cangjie-coder**: Consult：无需；Retrieval：无需
- **输入**: 全部 Phase 1-3 功能
- **输出**: 集成测试报告
- **验收**: 所有测试场景验证通过

---

## 需求覆盖追踪

| spec.md 核心能力 | Phase 1 任务 | Phase 2 任务 | Phase 3 任务 | 覆盖状态 |
|-----------------|-------------|-------------|-------------|----------|
| 5.1 MQ连接管理 | 1.1~1.6（前置依赖） | 2.3 | 3.2 | ✅ |
| 5.2 群组通道管理 | | 2.5 | 3.1 | ✅ |
| 5.3 群组消息分发 | | 2.6, 2.7 | 3.1 | ✅ |
| 5.4 MQ鉴权集成 | | 2.4 | | ✅ |
| 5.5 本地模式降级兼容 | | 2.2 | 3.1, 3.2 | ✅ |
| 5.6 本地依赖管理 | 1.1, 1.2 | | | ✅ |
| 5.7 版本适配 | 1.3, 1.4, 1.5, 1.6 | | | ✅ |
| 错误码 AIP-MQ-001~014 | | 2.3, 2.4, 2.5, 2.6, 2.7 | 3.1, 3.2 | ✅ |
| 健康检查 MQ 组件 | | 2.2 | 3.3 | ✅ |
| AcpsConnectivityResult 扩展 | | | 3.2 | ✅ |