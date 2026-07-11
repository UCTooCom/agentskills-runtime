# 文件系统与数据库同步需求规格

**版本**: v0.0.19  
**创建日期**: 2026-03-26  
**状态**: 待设计和实现

## 1. 背景说明

### 1.1 两组独立的 API

AgentSkills Runtime v0.0.19 包含两组独立的技能管理 API：

#### `/api/v1/uctoo/skills/*` - 文件系统技能管理 API

**用途**: 管理文件系统中真实安装的技能

**特点**:
- 直接操作文件系统
- 技能可以被实际执行
- 支持从 Git 仓库安装
- 支持热重载
- 与 SkillManager 直接交互

**API 端点**:
- `GET /api/v1/uctoo/skills` - 获取技能列表
- `GET /api/v1/uctoo/skills/:id` - 获取技能详情
- `POST /api/v1/uctoo/skills/add` - 安装技能
- `POST /api/v1/uctoo/skills/edit` - 更新技能
- `POST /api/v1/uctoo/skills/del` - 卸载技能
- `POST /api/v1/uctoo/skills/execute` - 执行技能
- `POST /api/v1/uctoo/skills/search` - 搜索技能

#### `/api/v1/uctoo/agent_skills/*` - 数据库 CRUD API

**用途**: 管理技能的元数据记录

**特点**:
- 标准 CRUD 操作
- 支持软删除
- 支持批量操作
- 遵循 UCTOO V4 规范
- 与前端管理系统配合使用

**API 端点**:
- `GET /api/v1/uctoo/agent_skills/:limit/:page` - 获取技能列表
- `GET /api/v1/uctoo/agent_skills/:id` - 获取技能详情
- `POST /api/v1/uctoo/agent_skills/add` - 创建技能记录
- `POST /api/v1/uctoo/agent_skills/edit` - 更新技能记录
- `POST /api/v1/uctoo/agent_skills/del` - 删除技能记录

### 1.2 当前问题

**两组 API 完全独立，没有同步机制**：

1. 通过 `/skills/add` 安装技能后，文件系统中有技能，但数据库中没有记录
2. 通过 `/agent_skills/add` 创建记录后，数据库中有记录，但文件系统中没有技能
3. 无法通过管理后台查看实际安装的技能状态
4. 无法通过管理后台控制技能的安装和卸载

## 2. 同步需求

### 2.1 核心需求

**目标**: 实现文件系统技能与数据库记录的自动同步

**同步方向**:
1. **文件系统 → 数据库**: 当技能被安装到文件系统时，自动在数据库中创建对应记录
2. **数据库 → 文件系统**: 当在数据库中创建技能记录时，可选择是否实际安装技能

### 2.2 功能需求

#### 2.2.1 自动同步（文件系统 → 数据库）

**触发时机**:
- 通过 `/skills/add` 安装技能成功后
- 通过 Git 克隆安装技能后
- 从本地路径安装技能后
- 热重载检测到新技能时

**同步内容**:
- 基本信息: name, description, version, author, license
- 来源信息: source_url, source_type, branch, tag, commit
- 安装信息: install_path
- 配置信息: parameters, instructions, config
- 时间戳: created_at, updated_at

**同步策略**:
- 如果数据库中已存在同名技能记录，更新记录
- 如果数据库中不存在，创建新记录
- 记录 `source_path` 字段，指向文件系统中的实际路径

#### 2.2.2 可选安装（数据库 → 文件系统）

**触发时机**:
- 通过 `/agent_skills/add` 创建技能记录时
- 通过管理后台添加技能时

**安装选项**:
```json
{
  "name": "skill-name",
  "source_url": "https://github.com/user/skill-repo",
  "auto_install": true,  // 是否自动安装到文件系统
  "install_path": "/custom/path"  // 可选的安装路径
}
```

**安装流程**:
1. 在数据库中创建技能记录
2. 如果 `auto_install` 为 true，调用 `/skills/add` 实际安装
3. 更新数据库记录的 `install_path` 和 `status` 字段

#### 2.2.3 状态同步

**同步字段**:
- `status`: installed, not_installed, error
- `runtime_status`: active, inactive, loading
- `validation_status`: valid, invalid, pending
- `install_path`: 文件系统中的实际路径
- `last_sync_at`: 最后同步时间

**同步时机**:
- 技能安装成功后
- 技能卸载后
- 技能执行失败后
- 定时同步任务（可选）

#### 2.2.4 统计同步

**同步字段**:
- `run_count`: 执行次数
- `success_count`: 成功次数
- `error_count`: 失败次数
- `avg_execution_time`: 平均执行时间
- `last_run_at`: 最后执行时间

**同步时机**:
- 每次技能执行后

### 2.3 非功能需求

#### 2.3.1 性能要求

- 同步操作不应阻塞主流程
- 批量同步应支持异步处理
- 同步失败不应影响技能的正常使用

#### 2.3.2 可靠性要求

- 同步操作应支持重试机制
- 记录同步日志，便于问题排查
- 支持手动触发同步

#### 2.3.3 兼容性要求

- 保持现有 API 的向后兼容
- 同步功能应可配置开关
- 支持部分同步（只同步指定字段）

## 3. 技术设计

### 3.1 同步服务设计

**服务名称**: `SkillSyncService`

**主要方法**:
```cangjie
public class SkillSyncService {
    // 文件系统 → 数据库同步
    public func syncFromFileSystem(skillId: String): Bool
    
    // 数据库 → 文件系统同步（安装）
    public func syncToFileSystem(skillRecord: AgentSkillsPO): Bool
    
    // 批量同步
    public func batchSync(direction: SyncDirection): Unit
    
    // 状态同步
    public func syncStatus(skillId: String, status: SkillStatus): Bool
    
    // 统计同步
    public func syncStatistics(skillId: String, stats: SkillStats): Bool
}
```

### 3.2 同步触发器设计

**安装后触发器**:
```cangjie
// 在 SkillRoutes.handleAddSkill 中
if (result.success) {
    // 重新加载技能
    progressiveSkillLoader.reloadSkills(skillManager)
    
    // 触发同步：文件系统 → 数据库
    skillSyncService.syncFromFileSystem(skillName)
    
    // 返回响应
    ...
}
```

**执行后触发器**:
```cangjie
// 在 SkillRoutes.handleExecuteSkill 中
let output = skill.execute(args)

// 触发统计同步
skillSyncService.syncStatistics(skillId, {
    run_count: 1,
    success_count: success ? 1 : 0,
    error_count: success ? 0 : 1,
    execution_time: executionTime
})
```

### 3.3 数据库字段扩展

**新增字段**:
```sql
ALTER TABLE agent_skills ADD COLUMN source_path VARCHAR(512);
ALTER TABLE agent_skills ADD COLUMN last_sync_at TIMESTAMP;
ALTER TABLE agent_skills ADD COLUMN sync_status VARCHAR(32);
```

**字段说明**:
- `source_path`: 文件系统中的实际路径
- `last_sync_at`: 最后同步时间
- `sync_status`: 同步状态 (synced, pending, error)

### 3.4 配置设计

**环境变量**:
```ini
# 同步功能开关
SKILL_SYNC_ENABLED=true

# 同步方向
SKILL_SYNC_DIRECTION=bidirectional  # filesystem_to_db, db_to_filesystem, bidirectional

# 自动安装开关
SKILL_AUTO_INSTALL=true

# 同步重试次数
SKILL_SYNC_RETRY_COUNT=3

# 定时同步间隔（秒）
SKILL_SYNC_INTERVAL=300
```

## 4. 实现计划

### 4.1 Phase 1: 基础同步功能

**目标**: 实现文件系统 → 数据库的单向同步

**任务**:
1. 创建 `SkillSyncService` 服务
2. 实现基本信息同步
3. 在技能安装后触发同步
4. 添加同步日志记录

**预计工作量**: 2-3 天

### 4.2 Phase 2: 双向同步

**目标**: 实现数据库 → 文件系统的同步

**任务**:
1. 实现自动安装功能
2. 扩展 `/agent_skills/add` API
3. 添加安装选项参数
4. 实现状态同步

**预计工作量**: 2-3 天

### 4.3 Phase 3: 高级功能

**目标**: 实现统计同步和定时同步

**任务**:
1. 实现统计同步
2. 添加定时同步任务
3. 实现批量同步
4. 添加同步管理 API

**预计工作量**: 2-3 天

### 4.4 Phase 4: 测试和优化

**目标**: 完善测试和性能优化

**任务**:
1. 编写单元测试
2. 编写集成测试
3. 性能优化
4. 文档完善

**预计工作量**: 2-3 天

## 5. API 扩展设计

### 5.1 同步管理 API

**新增端点**:

```
POST /api/v1/uctoo/skills/sync
```

**请求体**:
```json
{
  "direction": "filesystem_to_db",  // filesystem_to_db, db_to_filesystem, bidirectional
  "skill_id": "optional-skill-id",  // 可选，不指定则同步所有
  "force": false  // 是否强制同步（覆盖现有数据）
}
```

**响应**:
```json
{
  "success": true,
  "synced_count": 10,
  "error_count": 0,
  "details": [
    {
      "skill_id": "skill-1",
      "status": "synced",
      "message": "Successfully synced"
    }
  ]
}
```

### 5.2 同步状态查询 API

**新增端点**:

```
GET /api/v1/uctoo/skills/sync/status
```

**响应**:
```json
{
  "total_skills": 20,
  "synced_count": 15,
  "pending_count": 3,
  "error_count": 2,
  "last_sync_at": "2026-03-26T10:00:00Z"
}
```

## 6. SDK API 修正需求

### 6.1 当前问题

**JavaScript SDK 的 API 路径错误**:

| 方法 | 当前路径 | 正确路径 | 说明 |
|------|---------|---------|------|
| `listSkills()` | `/agent_skills` | `/skills` | 应该获取文件系统中的技能 |
| `getSkill()` | `/agent_skills/:id` | `/skills/:id` | 应该获取文件系统中的技能 |
| `uninstallSkill()` | `/agent_skills/del` | `/skills/del` | 应该卸载文件系统中的技能 |
| `updateSkill()` | `/agent_skills/edit` | `/skills/edit` | 应该更新文件系统中的技能 |
| `getSkillConfig()` | `/agent_skills/:id/config` | `/skills/:id/config` | 应该获取文件系统中的技能配置 |
| `setSkillConfig()` | `/agent_skills/:id/config` | `/skills/:id/config` | 应该设置文件系统中的技能配置 |
| `listSkillTools()` | `/agent_skills/:id/tools` | `/skills/:id/tools` | 应该列出文件系统中的技能工具 |

**正确的方法**:
- `installSkill()` → `/skills/install` ✅ 正确
- `executeSkill()` → `/skills/execute` ✅ 正确
- `searchSkills()` → `/skills/search` ✅ 正确

### 6.2 修正方案

**方案 1: 修正现有方法（推荐）**

将所有技能管理方法的路径从 `/agent_skills` 修正为 `/skills`。

**方案 2: 提供两组方法**

保留现有方法用于数据库操作，新增一组方法用于文件系统操作：

```typescript
// 文件系统操作
async listInstalledSkills(): Promise<SkillListResponse>
async getInstalledSkill(skillId: string): Promise<Skill>
async uninstallSkill(skillId: string): Promise<{ success: boolean }>

// 数据库操作
async listSkillRecords(): Promise<SkillListResponse>
async getSkillRecord(skillId: string): Promise<Skill>
async deleteSkillRecord(skillId: string): Promise<{ success: boolean }>
```

**推荐方案 1**，因为：
1. SDK 主要面向运行时使用，应该操作文件系统中的技能
2. 数据库操作通常由管理后台完成
3. 保持 API 简洁，避免混淆

### 6.3 其他语言 SDK

**需要检查和修正的 SDK**:
- Python SDK
- Java SDK
- PHP SDK
- UniApp SDK
- Go SDK（待实现）
- Rust SDK（待实现）
- ArkTS SDK（待实现）

## 7. 风险和挑战

### 7.1 技术风险

1. **数据一致性**: 文件系统和数据库可能出现不一致
   - 缓解措施：提供手动同步和修复功能

2. **性能影响**: 同步操作可能影响性能
   - 缓解措施：异步处理，批量优化

3. **并发冲突**: 多个同步操作可能冲突
   - 缓解措施：加锁机制，乐观锁

### 7.2 兼容性风险

1. **现有 API 兼容性**: 新功能不应破坏现有 API
   - 缓解措施：保持向后兼容，新功能通过可选参数提供

2. **SDK 兼容性**: 修正 SDK 可能影响现有用户
   - 缓解措施：版本升级，提供迁移指南

## 8. 验收标准

### 8.1 功能验收

- [ ] 通过 `/skills/add` 安装技能后，数据库中自动创建记录
- [ ] 通过 `/agent_skills/add` 创建记录并设置 `auto_install=true` 后，技能被实际安装
- [ ] 技能执行后，统计数据自动同步到数据库
- [ ] 提供手动同步 API
- [ ] 提供同步状态查询 API

### 8.2 性能验收

- [ ] 同步操作不阻塞技能执行
- [ ] 批量同步 100 个技能耗时 < 5 秒
- [ ] 单个技能同步耗时 < 100ms

### 8.3 可靠性验收

- [ ] 同步失败不影响技能正常使用
- [ ] 同步失败有重试机制
- [ ] 提供同步日志查询功能

## 9. 参考资料

### 9.1 相关文档

- [AgentSkills Runtime 架构设计](../../docs/architecture.md)
- [UCTOO V4 API 规范](https://gitee.com/uctoo/uctoo/blob/master/docs/api-spec.md)
- [技能管理服务设计](../../src/skill/application/README.md)

### 9.2 相关代码

- 文件系统技能路由: `src/app/routes/skill/SkillRoutes.cj`
- 数据库技能路由: `src/app/routes/uctoo/agent_skills/AgentSkillsRoute.cj`
- 技能管理服务: `src/skill/application/SkillManagementService.cj`
- JavaScript SDK: `sdk/javascript/src/index.ts`

---

**文档维护者**: UCToo Team  
**最后更新**: 2026-03-26
