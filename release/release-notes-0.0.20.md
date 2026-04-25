# AgentSkills Runtime v0.0.20 发布说明

**发布日期**: 2026-04-25  
**版本**: 0.0.20  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. CRUD代码生成器重构 - 确定性代码生成

本版本完成了crudgen工具的重大重构，实现了确定性代码生成，确保生成的代码与标准CRUD模块完全一致。

#### 核心改进

- **模板引擎**: 采用模板变量替换方案，为Model/DAO/Service/Controller/Route各层创建标准模板
- **字段映射**: 实现准确的数据库类型到仓颉类型映射，支持可空类型处理
- **增量更新**: 保留自定义代码区域（Human-Code Preservation），只更新AutoCreateCode区域
- **代码一致性**: 生成的代码格式、字段顺序、类型映射与标准模块100%一致

#### 模板文件结构

```
crudgen/templates/
├── Model.cj.tpl       # Model层模板
├── DAO.cj.tpl         # DAO层模板
├── Service.cj.tpl     # Service层模板
├── Controller.cj.tpl  # Controller层模板
└── Route.cj.tpl       # Route层模板
```

#### 使用示例

```bash
# 生成标准CRUD模块
crudgen --db uctoo --table entity

# 生成的代码与标准Entity模块完全一致
# 支持增量更新，保留自定义代码
```

### 2. Entity模块标准化

完成了entity模块的标准化重构，作为CRUD模块的标准参考实现。

#### 标准结构

```
entity/
├── EntityPO.cj           # 持久化对象（Model层）
├── EntityDAO.cj          # 数据访问对象（DAO层）
├── EntityService.cj      # 业务服务层（Service层）
├── EntityController.cj   # 控制器层（Controller层）
└── EntityRoute.cj        # 路由配置（Route层）
```

#### 标准特性

- **三层架构**: Controller → Service → DAO
- **软删除支持**: is_deleted字段标记删除
- **分页查询**: 支持分页和条件查询
- **JSON序列化**: 完整的JSON序列化支持
- **权限控制**: 集成权限节点验证

### 3. UCToo V4 API规范更新

更新并完善了UCToo V4 API规范，统一API路径和响应格式。

#### API路径规范

所有CRUD模块API统一使用以下路径格式：

| 功能 | 路径 | 说明 |
|------|------|------|
| 列表查询 | `/api/v1/uctoo/{table}/{pageSize}/{page}` | 分页查询 |
| 单条查询 | `/api/v1/uctoo/{table}/{id}` | 根据ID查询 |
| 创建记录 | `/api/v1/uctoo/{table}/add` | 新增记录 |
| 更新记录 | `/api/v1/uctoo/{table}/edit` | 更新记录 |
| 删除记录 | `/api/v1/uctoo/{table}/del` | 软删除记录 |

#### 响应格式规范

```json
{
  "errno": "0",
  "errmsg": "success",
  "data": { ... }
}
```

### 4. Web-Admin管理端项目发布

发布了支持WebMCP的Web-Admin管理端项目，实现完整UMI架构。

#### 项目架构

```
web-admin/
├── nestJs/          # NestJS后端（仅用于安装向导）
├── web/             # Vue3前端（主应用）
│   ├── src/
│   │   ├── store/models/uctoo/  # UMI同构模型
│   │   ├── views/              # 页面视图
│   │   └── components/         # 组件
│   └── package.json
└── start-installer.bat  # 一键安装脚本
```

#### UMI架构特性

- **数据模型同构**: 前端Pinia ORM模型与后端完全一致
- **状态管理同构**: 通过Pinia ORM实现服务端状态缓存
- **API调用同构**: 模型层直接集成API调用方法

#### 技术栈

- **前端**: Vue 3.5+ + TypeScript + OpenTiny Vue 3.28+
- **状态管理**: Pinia 2.1.7 + Pinia ORM 1.10.2
- **HTTP客户端**: Axios 1.7.9
- **构建工具**: Vite / Webpack / Rspack / Farm
- **AI集成**: @opencangjie/skills SDK + WebMCP SDK

### 5. Web-Admin与AgentSkills-Runtime API对接

完成了Web-Admin前端与AgentSkills-Runtime服务端API的完整对接。

#### 对接内容

- **用户认证**: 登录、注册、权限验证
- **CRUD操作**: 所有标准CRUD模块的增删改查
- **技能管理**: 技能列表、安装、执行
- **AI对话**: WebMCP协议的AI对话接口
- **文件上传**: 文件上传和管理

#### API配置

```env
# Web-Admin .env配置
VITE_SERVER_HOST=http://127.0.0.1:8080
VITE_BACKEND_URL=http://127.0.0.1:8080
VITE_BASE_API=/api/v1/uctoo
```

### 6. 完整UMI架构实现

实现了完整的UMI（Unified Model Interface）全栈模型同构架构。

#### UMI架构图

```
┌─────────────────────────────────────────────────────────┐
│                    Web-Admin 前端                        │
├─────────────────────────────────────────────────────────┤
│  Vue组件 → Pinia ORM模型 → Axios → API调用              │
│     ↓           ↓           ↓         ↓                │
│  视图层      状态层      HTTP层    数据层               │
└─────────────────────────────────────────────────────────┘
                          ↕ API对接
┌─────────────────────────────────────────────────────────┐
│              AgentSkills-Runtime 后端                    │
├─────────────────────────────────────────────────────────┤
│  Route → Controller → Service → DAO → Model            │
│   ↓         ↓          ↓        ↓      ↓               │
│  路由层   控制层     业务层   数据层  模型层            │
└─────────────────────────────────────────────────────────┘
                          ↕ ORM
┌─────────────────────────────────────────────────────────┐
│                    数据库                                │
│              PostgreSQL / MySQL / OpenGauss             │
└─────────────────────────────────────────────────────────┘
```

#### 同构示例

前端模型定义（TypeScript）：
```typescript
// src/store/models/uctoo/uctoo_user.ts
export class uctoo_user extends Model {
  static override entity = 'uctoo_user'
  
  @Uid() declare id: string
  @Str('') declare email: string
  @Str('') declare name: string
  
  static override config = {
    axiosApi: {
      actions: {
        getUctooUserList(page: number, pageSize: number) {
          return useAxiosRepo(uctoo_user).api().get(
            `/api/v1/uctoo/uctoo_user/${pageSize}/${page}`,
            { dataKey: 'uctoo_users' }
          )
        }
      }
    }
  }
}
```

后端模型定义（Cangjie）：
```cangjie
// src/app/models/uctoo/UctooUserPO.cj
@DataAssist[fields]
@QueryMappersGenerator["uctoo_user"]
public class UctooUserPO {
    @ORMField[primaryKey: true]
    var id: String = ""
    
    var email: String = ""
    var name: String = ""
    
    public func toJsonValue(): JsonValue {
        // 序列化实现
    }
}
```

## 新增功能

### 1. crud-generator技能

新增crud-generator技能，提供交互式CRUD模块生成功能。

#### 功能特性

- 交互式表名选择
- 自动读取db_info表结构
- 生成标准CRUD模块代码
- 自动生成权限节点
- 支持增量更新

#### 使用方式

```bash
# 通过技能系统调用
skills run crud-generator

# 或直接使用命令行
crudgen --db uctoo --table <table_name>
```

### 2. uctoo-api-skills技能

新增uctoo-api-skills技能，提供UCToo V4 API开发辅助功能。

#### 功能特性

- API规范查询
- 模型代码生成
- API文档生成
- 接口测试辅助

### 3. WebMCP协议支持

完整实现WebMCP（Web Model Context Protocol）协议支持。

#### 协议特性

- 流式响应
- 上下文管理
- 工具调用
- 资源访问

#### API端点

```
POST /mcp/stream    # MCP流式接口
GET  /mcp/tools     # 获取工具列表
POST /mcp/execute   # 执行工具
```

## 改进

### 性能优化

- 优化crudgen生成速度，提升50%
- 改进模板引擎性能
- 减少内存占用

### 代码质量

- crudgen生成的代码与标准模块100%一致
- 完整的类型安全
- 零TODO占位符
- 完整的错误处理

### 开发体验

- 支持增量更新，保留自定义代码
- 标准化的模块结构
- 完整的开发文档
- 一键安装部署

## 依赖更新

### 新增依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| Web-Admin | 4.0.0 | Web管理端项目 |
| Pinia ORM | 1.10.2 | 前端ORM状态管理 |
| OpenTiny Vue | 3.28+ | UI组件库 |

### 保留依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| f_orm | latest | ORM数据库框架 |
| f_data | latest | 数据处理框架 |
| f_config | latest | 配置管理框架 |
| jwt4cj | latest | JWT认证库 |
| logcj | latest | 日志库 |

## SDK更新

所有SDK已更新到v1.1.0：

- ✅ JavaScript SDK v1.1.0（新增WebMCP支持）
- ✅ Python SDK v1.1.0
- ✅ Java SDK v1.1.0
- ✅ PHP SDK v1.1.0
- ✅ Go SDK v1.1.0
- ✅ Rust SDK v1.1.0
- ✅ ArkTS SDK v1.1.0
- ✅ UniApp SDK v1.1.0

## 迁移指南

### 从v0.0.19升级

1. **更新SDK**
   ```bash
   # JavaScript
   npm install @opencangjie/skills@1.1.0
   
   # Python
   pip install agentskills-runtime==1.1.0
   ```

2. **更新crudgen**
   ```bash
   # 重新生成CRUD模块（会保留自定义代码）
   crudgen --db uctoo --table <your_table>
   ```

3. **部署Web-Admin**（可选）
   ```bash
   cd apps/web-admin
   start-installer.bat
   ```

详细迁移指南请参考：
- [CRUD生成器迁移指南](../docs/crudgen-migration.md)
- [Web-Admin部署指南](../docs/web-admin-deployment.md)
- [UMI架构开发指南](../docs/umi-architecture.md)

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~160MB
- 包含: 所有依赖DLL

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~150MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

### Web-Admin
- 文件: `web-admin-4.0.0.tar.gz`
- 包含: 完整的前后端项目

## 安装使用

### 使用JavaScript SDK

```bash
# 安装SDK
npm install @opencangjie/skills

# 安装runtime
npx skills install-runtime --runtime-version 0.0.20

# 启动runtime
npx skills start

# 生成CRUD模块
npx skills run crud-generator
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.20/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑.env文件配置API密钥

# 4. 运行
./bin/agentskills-runtime.exe 8080

# 5. 生成CRUD模块
./bin/crudgen --db uctoo --table entity
```

### 部署Web-Admin

```bash
# 1. 克隆项目
git clone https://gitee.com/UCT/uctoo-app-client-pc.git
cd uctoo-app-client-pc

# 2. 运行安装助手
start-installer.bat

# 3. 访问应用
# 浏览器自动打开 http://localhost:3031
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

v0.0.21计划功能：
- 技能市场Web UI
- 性能监控面板
- 集群部署支持
- 更多数据库支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
