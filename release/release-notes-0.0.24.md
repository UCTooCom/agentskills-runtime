# AgentSkills Runtime v0.0.24 发布说明

**发布日期**: 2026-07-11  
**版本**: 0.0.24  
**代号**: AIP-Interconnection  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. 智能体互联国家标准（GB/Z 185）支持

本版本实现了对《人工智能 智能体互联》系列国家标准（GB/Z 185.1~185.7-2026）的完整支持，采用双模式分层架构（本地模式 + 互联模式），增量迭代开发，复用已有基础设施。

#### 技术架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    AIP 智能体互联平台（双模式分层架构）                    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                     互联模式（Interconnection Mode）               │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────┐ │  │
│  │  │ ACPs 注册适配 │ │ ACPs CA 适配  │ │ ACPs 发现适配 │ │ACPs MQ  │ │  │
│  │  │AcpsRegistry  │ │ AcpsCa       │ │AcpsDiscovery │ │Adapter  │ │  │
│  │  │  Adapter     │ │  Adapter     │ │  Adapter     │ │消息分发  │ │  │
│  │  └───────┬──────┘ └───────┬──────┘ └───────┬──────┘ └────┬─────┘ │  │
│  │          │                │                │              │       │  │
│  │          └────────────────┴────────────────┘              │       │  │
│  │                          │                                │       │  │
│  │                    ACPs 基础服务                          │       │  │
│  │                  (注册/CA/发现)                     ActiveMQ │       │  │
│  │                                                     消息总线 │       │  │
│  └──────────────────────────────────────────────────────────┼───────┘  │
│                                                              │          │
│  ┌──────────────────────────────────────────────────────────┼───────┐  │
│  │                     本地模式（Local Mode）                 │       │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │       │  │
│  │  │AipInteraction│ │ AipConfig    │ │ AipMode      │     │       │  │
│  │  │  Service     │ │  Service     │ │  Manager     │     │       │  │
│  │  │ 交互会话管理  │ │ 配置与健康检查│ │ 模式切换管理  │     │       │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘     │       │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │       │  │
│  │  │AipIdentity   │ │AipDescription│ │AipDiscovery  │     │       │  │
│  │  │  Service     │ │  Service     │ │  Service     │     │       │  │
│  │  │ 身份认证服务  │ │ 描述注册服务  │ │ 发现服务      │     │       │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘     │       │  │
│  │                                                           │       │  │
│  │                    数据库持久化层                           │       │  │
│  └──────────────────────────────────────────────────────────┘       │  │
└──────────────────────────────────────────────────────────────────────────┘
```

#### 核心能力

| 能力 | 说明 | 对应国标 |
|------|------|----------|
| AIC 身份认证 | 智能体通信标识（AIC）的生成、验证与解析 | GB/Z 185.2 |
| 描述注册 | 智能体能力描述的注册、查询与更新 | GB/Z 185.3 |
| 发现服务 | 智能体发现与被发现的完整流程 | GB/Z 185.4 |
| 交互会话 | 本地/互联双模式交互会话管理 | GB/Z 185.5 |
| MQ 消息分发 | 基于 ActiveMQ 的群组消息分发与接收 | GB/Z 185.6 |
| 模式管理 | 本地/互联模式切换、降级与连通性检查 | GB/Z 185.1 |
| AIC 合法性验证 | AIC 格式校验与合法性验证 | GB/Z 185.2 |

#### 双模式降级兼容

- **本地模式**：所有互联功能返回降级提示，不依赖任何外部服务
- **互联模式**：在本地模式基础上叠加 ACPs 注册/CA/发现/MQ 分布式能力
- **自动降级**：ACPs 连通性检查失败时自动降级为本地模式，MQ 资源自动释放

### 2. MQ 消息分发适配器（AcpsMqAdapter）

实现基于 ActiveMQ 的群组消息分发，支持 GB/Z 185.6 群组交互协议。

#### 核心组件

##### 2.1 MQ 连接管理

- 按需建立 JMS 连接（首次群组交互时触发）
- 支持 Failover 格式 brokerURL（多 broker 自动切换）
- 连接状态机：Disconnected → Connecting → Connected → Reconnecting → Unavailable
- 环境变量配置：AIP_MQ_ENDPOINT、AIP_MQ_USERNAME、AIP_MQ_PASSWORD

##### 2.2 群组通道管理

- 创建群组 Topic：`aip.group.{sessionId}`
- 支持持久订阅（Durable Consumer）和非持久订阅
- 群组通道信息缓存与生命周期管理
- 资源释放：Consumer/Context 正确关闭

##### 2.3 消息分发与接收

- 消息发布：JSON 格式消息体 + JMS 属性元数据
- 消息接收：MessageListener 回调 → 双写 aip_interaction_message + agent_messages
- 消息去重：基于 messageId 的 HashSet 去重缓存（容量上限 1000）

##### 2.4 ACL 鉴权集成

- 调用 mq-auth-server 的 ACL 校验接口
- 支持群组创建/消息发布/订阅/退订操作的权限校验
- 鉴权服务不可用时自动放行（可选依赖）

#### 本地依赖集成

| 依赖 | 版本 | 说明 |
|------|------|------|
| activemq4cj | 1.0.0 (适配仓颉1.0.4) | ActiveMQ 仓颉 SDK |
| hyperion | 3.0.0 (适配仓颉1.0.4) | TCP 通信框架 |

两个库采用本地 libs/ 依赖方式，已完成仓颉 SDK 1.0.4 版本适配。

### 3. AI Builder 组织任务与开发者需求对接

新增 AI Builder 应用模块，支持组织级任务管理和开发者需求对接：

- Agent 任务管理：任务的创建、分配、跟踪与状态流转
- 开发者需求对接：需求提交、评审与任务关联
- 与 AIP 交互会话集成：任务自动关联交互会话

### 4. LoadDbInfo 数据库结构信息加载工具重构

重构 `loaddbinfo` 工具，优化数据库结构信息的加载流程：

- 改进 db_info 表的数据加载机制
- 优化 CRUD 代码生成的元数据获取
- 增强对复杂表结构的支持

## 新增功能

### AIP 服务层

| 服务 | 说明 | 文件 |
|------|------|------|
| AipModeManager | 双模式管理与自动降级 | AipModeManager.cj |
| AipInteractionService | 交互会话管理（本地+互联） | AipInteractionService.cj |
| AipConfigService | 配置与健康检查 | AipConfigService.cj |
| AipIdentityService | AIC 身份认证 | AipIdentityService.cj |
| AipDescriptionService | 能力描述注册 | AipDescriptionService.cj |
| AipDiscoveryService | 智能体发现 | AipDiscoveryService.cj |
| AicValidator | AIC 合法性验证 | AicValidator.cj |
| AipMessageValidator | 消息格式校验 | AipMessageValidator.cj |
| AgentAuthService | 智能体认证服务 | AgentAuthService.cj |

### ACPs 适配器层

| 适配器 | 说明 | 文件 |
|--------|------|------|
| AcpsRegistryAdapter | ACPs 注册服务适配 | AcpsRegistryAdapter.cj |
| AcpsCaAdapter | ACPs CA 服务适配 | AcpsCaAdapter.cj |
| AcpsDiscoveryAdapter | ACPs 发现服务适配 | AcpsDiscoveryAdapter.cj |
| AcpsMqAdapter | ACPs MQ 消息分发适配 | AcpsMqAdapter.cj |

### MQ 数据模型

| 模型 | 说明 |
|------|------|
| MqConnectionState | 连接状态枚举（Disconnected/Connecting/Connected/Reconnecting/Unavailable） |
| MqConnectionConfig | 连接配置（brokerUrl/username/password/tls/reconnect） |
| MqGroupChannelInfo | 群组通道信息（Topic/Producer/Consumer 缓存） |
| MqAuthRequest | ACL 鉴权请求 |
| MqAuthResult | ACL 鉴权结果 |
| MqGroupChannelResult | 群组创建结果（已订阅/失败成员列表） |
| MqMessageCallbackFunc | 消息回调函数类型 |

### AIP 控制器与路由

| 接口 | 说明 |
|------|------|
| POST /aip/interaction/session | 创建交互会话 |
| POST /aip/interaction/message | 发送交互消息 |
| POST /aip/interaction/close | 关闭交互会话 |
| GET /aip/health/local | 本地模式健康检查 |
| GET /aip/health/interconnection | 互联模式健康检查 |
| GET /aip/config | 获取 AIP 配置 |
| POST /aip/config/mode | 切换运行模式 |
| POST /aip/identity/login | 智能体登录 |
| POST /aip/description/register | 能力描述注册 |
| GET /aip/discovery/search | 智能体发现 |
| POST /aip/discovery/cache/clean | 清理发现缓存 |
| POST /aip/discovery/cache/refresh | 刷新发现缓存 |

## 改进

### 1. AipInteractionService MQ 集成

- 创建群组会话时自动创建 MQ 群组通道
- 发送消息时自动发布到 MQ Topic
- 关闭会话时自动销毁 MQ 群组通道
- MQ 消息接收回调双写数据库
- MQ 操作失败不阻塞数据库写入

### 2. AipModeManager MQ 降级集成

- 降级时自动释放 MQ 资源
- 连通性检查新增 mqReachable 字段
- MQ 不影响 overallAvailable 判定

### 3. AipConfigService MQ 健康检查集成

- 互联健康检查返回真实 MQ 连通性状态
- MQ 不可用时 overallStatus 为 "degraded"（非 "unhealthy"）

### 4. 错误码体系

| 错误码 | 说明 |
|--------|------|
| AIP-MQ-001 | MQ 连接配置缺失 |
| AIP-MQ-002 | MQ 连接建立失败 |
| AIP-MQ-005 | ACL 鉴权失败 |
| AIP-MQ-006 | 群组通道创建失败 |
| AIP-MQ-007 | 群组订阅失败 |
| AIP-MQ-008 | 群组退订/销毁失败 |
| AIP-MQ-009 | 消息发送失败 |
| AIP-MQ-010 | 消息回调处理失败 |
| AIP-MQ-013 | MQ 鉴权服务不可用 |
| AIP-MQ-014 | 本地模式不支持 / MQ 资源释放异常 |

## 数据库变更

### 新增表

| 表名 | 说明 |
|------|------|
| aip_interaction_session | AIP 交互会话表 |
| aip_interaction_message | AIP 交互消息表 |
| aip_interaction_task | AIP 交互任务表 |
| aip_service_config | AIP 服务配置表 |
| aip_agent_identity | AIP 智能体身份表 |
| aip_agent_description | AIP 智能体描述表 |
| aip_discovery_cache | AIP 发现缓存表 |
| aip_agent_acs_mapping | AIP 智能体 ACS 映射表 |

### 迁移脚本

```bash
# 运行 AIP 表结构迁移
psql -d uctoo -f sql/incremental/aip_tables.sql

# 运行本地模式扩展字段迁移
psql -d uctoo -f scripts/migration/aip_local_mode_v1.sql

# 运行 AIP RBAC 权限初始化
psql -d uctoo -f scripts/migration/aip_rbac_permissions_v1.sql
```

## 依赖更新

### 仓颉运行时

| 依赖 | 版本 | 说明 |
|------|------|------|
| cangjie | 1.0.4+ | 仓颉编程语言运行时 |
| fountain | latest | Web 框架 |
| f_orm | latest | ORM 框架 |
| f_aspect | latest | AOP 切面框架 |
| activemq4cj | 1.0.0 (本地) | ActiveMQ 仓颉 SDK |
| hyperion | 3.0.0 (本地) | TCP 通信框架 |
| stdx.net.http | latest | HTTP/HTTPS 支持 |
| stdx.net.tls | latest | TLS 支持 |

## 迁移指南

### 从 v0.0.23 升级

1. **更新数据库表结构**
   ```bash
   # 运行 AIP 数据库迁移
   psql -d uctoo -f sql/incremental/aip_tables.sql
   psql -d uctoo -f scripts/migration/aip_local_mode_v1.sql
   psql -d uctoo -f scripts/migration/aip_rbac_permissions_v1.sql
   ```

2. **更新环境变量**
   ```bash
   # AIP 运行模式（local/interconnection/auto）
   export AIP_MODE=auto

   # ACPs 服务端点（互联模式需要）
   export AIP_REGISTRY_ENDPOINT=https://registry.example.com
   export AIP_CA_ENDPOINT=https://ca.example.com
   export AIP_DISCOVERY_ENDPOINT=https://discovery.example.com

   # MQ 配置（互联模式群组交互需要）
   export AIP_MQ_ENDPOINT=failover:(tcp://mq1.example.com:61616,tcp://mq2.example.com:61616)
   export AIP_MQ_USERNAME=aip_user
   export AIP_MQ_PASSWORD=aip_password

   # MQ 鉴权服务（可选）
   export AIP_MQ_AUTH_URL=https://auth.example.com
   export AIP_MQ_AUTH_TOKEN=your_auth_token
   ```

3. **重启 Runtime 服务**
   ```bash
   # 使用 SDK 重新安装
   npm install @opencangjie/skills@1.0.4
   npx skills install-runtime --runtime-version 0.0.24
   npx skills restart
   ```

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~170MB
- 包含: 所有依赖 DLL

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~160MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

## 安装使用

### 使用 JavaScript SDK

```bash
# 安装 SDK
npm install @opencangjie/skills@1.0.4

# 安装 runtime
npx skills install-runtime --runtime-version 0.0.24

# 启动 runtime
npx skills start
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.24/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置 AIP 模式、ACPs 端点、MQ 连接等

# 4. 运行
./bin/agentskills-runtime.exe 443
```

### 构建说明

```bash
# 构建项目（自动打包）
cjpm build

# 手动打包（可选）
cjpm run --skip-build --name magic.scripts.package_release
```

## 相关文档

| 文档 | 说明 |
|------|------|
| [AIP 实现设计](./.codeartsdoer/specs/aip-implementation/design.md) | 智能体互联平台完整设计方案 |
| [AIP 实现需求](./.codeartsdoer/specs/aip-implementation/spec.md) | 智能体互联平台需求规格 |
| [MQ 适配器设计](./.codeartsdoer/specs/aip-mq-adapter/design.md) | MQ 消息分发适配器设计方案 |
| [MQ 适配器需求](./.codeartsdoer/specs/aip-mq-adapter/spec.md) | MQ 消息分发适配器需求规格 |
| [模块开发规范](./docs/uctoo-v4/uctoo-v4-module-development.md) | UCToo V4 通用模块开发流程 |

## 已知问题

- ActiveMQ 持久订阅在 broker 重启后可能需要重新注册
- ACL 鉴权服务不可用时默认放行，生产环境建议配置鉴权服务

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- OpenTiny 开源社区

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.25 计划功能：
- DAG 调度引擎
- 技能组合 DSL
- 跨会话记忆自动加载
- 技能市场 Web UI
- 性能监控面板
- 集群部署支持
- 更多数据库支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)