# AgentSkills Runtime v0.0.19 发布说明

**发布日期**: 2026-03-26  
**版本**: 0.0.19  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 架构升级：统一到 uctoo v4 标准

本版本完成了从 `magic.api` 模块到 `magic.app` 模块的完整迁移，采用三层架构设计，统一 API 路径到 uctoo v4 标准。

#### 新架构特性

- **三层架构**: Controller → Service → Repository
- **自定义 HTTP 框架**: 封装 stdx.net.http，支持中间件
- **统一 API 路径**: 所有 API 使用 `/api/v1/uctoo` 前缀
- **完整中间件链**: 认证、日志、错误处理

### API 架构说明

本版本包含两组独立的 API：

#### 1. 文件系统技能 API（`/skills` 路径）

这组 API 对应 agentskills-runtime 文件系统中真实的 skills 文件目录：

| 功能 | 路径 | 说明 |
|------|------|------|
| 获取技能列表 | `/skills` | 列出文件系统中安装的技能 |
| 获取技能详情 | `/skills/:id` | 获取技能详细信息 |
| 安装技能 | `/skills/add` | 从 Git 或本地安装技能到文件系统 |
| 编辑技能 | `/skills/edit` | 编辑技能配置 |
| 删除技能 | `/skills/del` | 从文件系统删除技能 |
| 执行技能 | `/skills/execute` | 执行指定技能 |
| 搜索技能 | `/skills/search` | 搜索可安装的技能 |

#### 2. 数据库技能管理 API（`/api/v1/uctoo/agent_skills` 路径）

这组 API 是 agent_skills 数据库表的标准 CRUD 模块 API：

| 功能 | 路径 | 说明 |
|------|------|------|
| 获取技能列表 | `/api/v1/uctoo/agent_skills` | 数据库中的技能记录 |
| 获取技能详情 | `/api/v1/uctoo/agent_skills/:id` | 数据库技能详情 |
| 创建技能记录 | `/api/v1/uctoo/agent_skills/add` | 添加数据库记录 |
| 编辑技能记录 | `/api/v1/uctoo/agent_skills/edit` | 更新数据库记录 |
| 删除技能记录 | `/api/v1/uctoo/agent_skills/del` | 删除数据库记录 |

#### 重要说明

- **两组 API 是独立的**：`/skills` 路径和 `/agent_skills` 路径的 API 是两组独立的 API，不存在替代关系
- **SDK 对应关系**：各语言 SDK 中的 API 与 `/skills` 路径的文件系统真实安装的技能相匹配，不需要与 `/agent_skills` 这组 API 有关联
- **数据同步**：如何将文件系统的信息（`/skills` 这组 API 的数据）和数据库的信息（`/agent_skills` 这组 API 的数据）进行同步，是 agentskills-runtime 还未设计和实现的功能

#### 其他 API

| 功能 | 路径 | 说明 |
|------|------|------|
| 健康检查 | `/hello` | 服务健康检查 |
| WebSocket 聊天 | `/ws/chat` | WebSocket 聊天接口 |
| MCP 流式接口 | `/mcp/stream` | MCP 协议流式传输 |

## 新增功能

### 1. 数据库支持（f_orm）

- 集成 Fountain ORM 框架
- 支持数据库连接池
- 提供 EntityService 进行实体管理
- 支持多种数据库（MySQL、PostgreSQL、SQLite、OpenGauss）

### 2. 数据处理框架（f_data）

- 数据验证和转换
- 数据格式化处理
- 数据序列化支持

### 3. 配置管理（f_config）

- 多环境配置支持
- 配置文件热加载
- 环境变量集成

### 4. 字符编码支持（charset4cj）

- 支持多种字符编码转换
- 多语言文本处理
- 国际化支持

### 5. JWT 认证（jwt4cj）

- JWT Token 生成和验证
- API 认证中间件
- 安全的用户认证

### 6. 结构化日志（logcj）

- 分级日志（ERROR、INFO、DEBUG、TRACE）
- 结构化日志输出
- 日志文件轮转

### 7. OpenGauss 数据库支持

- 集成 OpenGauss 数据库驱动
- 支持国产数据库
- 企业级数据库连接

### 8. Blowfish 加密支持

- Blowfish 加密算法
- 数据加密解密
- 安全的数据传输

### 9. 完整的 Fountain 框架集成

集成以下 Fountain 模块：
- f_aspect - AOP 支持
- f_base - 基础组件
- f_bean - Bean 管理
- f_cache - 缓存支持
- f_cmd - 命令行工具
- f_collection - 集合工具
- f_concurrent - 并发工具
- f_config - 配置管理
- f_data - 数据处理
- f_exception - 异常处理
- f_http - HTTP 客户端
- f_io - IO 工具
- f_log - 日志工具
- f_macros - 宏支持
- f_mvc - MVC 框架
- f_pool - 对象池
- f_random - 随机数
- f_regex - 正则表达式
- f_ticktock - 时间工具
- f_time - 时间处理
- f_util - 工具类
- f_version - 版本管理

## 改进

### 性能优化

- 优化技能加载性能
- 改进内存使用
- 减少 DLL 加载时间

### 代码质量

- 零 TODO 占位符
- 完整的错误处理
- 商业产品级别代码

### 打包改进

- 自动包含所有依赖
- 动态生成 VERSION 文件
- 自动获取打包日期
- 完整的依赖管理

## 依赖更新

### 新增依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| f_orm | latest | ORM 数据库框架 |
| f_data | latest | 数据处理框架 |
| f_config | latest | 配置管理框架 |
| charset4cj | latest | 字符编码库 |
| jwt4cj | latest | JWT 认证库 |
| logcj | latest | 日志库 |
| opengauss | latest | OpenGauss 数据库驱动 |
| blowfish | latest | Blowfish 加密库 |

### 保留依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| yaml4cj | local | YAML 解析器 |
| commonmark4cj | local | Markdown 解析器 |
| cangjie-stdx | 1.0.0.1 | 仓颉扩展库 |

## SDK 更新

所有 SDK 已更新到 v1.0.0：

- ✅ JavaScript SDK v1.0.0
- ✅ Python SDK v1.0.0
- ✅ Java SDK v1.0.0
- ✅ PHP SDK v1.0.0
- ✅ Go SDK v1.0.0
- ✅ Rust SDK v1.0.0
- ✅ ArkTS SDK v1.0.0
- ✅ UniApp SDK v1.0.0

## 迁移指南

### 从 v0.0.18 升级

1. **更新 SDK**
   ```bash
   # JavaScript
   npm install @opencangjie/skills@1.0.0
   
   # Python
   pip install agentskills-runtime==1.0.0
   ```

2. **更新环境变量**
   ```bash
   export SKILL_RUNTIME_API_URL=http://127.0.0.1:8080
   ```

详细迁移指南请参考：
- [SDK 迁移指南](../sdk/MIGRATION_GUIDE.md)
- [JavaScript SDK 迁移](../sdk/javascript/MIGRATION.md)

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~150MB
- 包含: 所有依赖 DLL

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~140MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

## 安装使用

### 使用 JavaScript SDK

```bash
# 安装 SDK
npm install @opencangjie/skills

# 安装 runtime
npx skills install-runtime --runtime-version 0.0.19

# 启动 runtime
npx skills start

# 管理技能
npx skills list
npx skills add ./my-skill
npx skills run my-skill
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.19/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置 API 密钥

# 4. 运行
./bin/agentskills-runtime.exe 8080
```

## 已知问题

- 无

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/UCToo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/UCToo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.20 计划功能：
- 性能监控面板
- 技能市场 Web UI
- 更多数据库支持
- 集群部署支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
