# 系统配置管理 - 编码任务清单

**版本**: v1.0.0
**创建日期**: 2026-07-18
**关联需求**: spec.md v1.0.0
**关联设计**: design.md v1.0.0

---

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

## 1. 数据库结构变更

**目标**：为 config 表新增 .env 同步相关字段，注册权限菜单和国际化数据，为后续后端模块开发提供数据基础。

### 1.1 config 表扩展字段

- [ ] 创建增量 SQL 文件 `sql/incremental/config_table_extension.sql`，为 config 表新增 10 个字段：env_key、config_group、config_type、is_sensitive、default_value、validation_rule、description、display_order、editable、last_synced_at
- [ ] 为 env_key 创建唯一索引（仅对非 NULL 值生效）：`CREATE UNIQUE INDEX idx_config_env_key ON config(env_key) WHERE env_key IS NOT NULL`
- [ ] 为 config_group 创建普通索引：`CREATE INDEX idx_config_group ON config(config_group)`
- [ ] 执行增量 SQL 并验证 config 表结构变更成功，确认现有数据不受影响

### 1.2 权限与菜单注册

- [ ] 创建增量 SQL 文件 `sql/incremental/config_permissions.sql`，注册"系统管理"一级菜单（id: a0000000-0000-0000-0000-000000000001）
- [ ] 注册"系统配置"二级菜单（id: a0000000-0000-0000-0000-000000000002），parent_id 指向系统管理菜单，path=/system/config，component=system/config/index，locale=menu.systemManager.systemConfig
- [ ] 注册配置读取 API 权限（config:read）：GET /api/v1/uctoo/config
- [ ] 注册配置写入 API 权限（config:write）：PUT /api/v1/uctoo/config/:key
- [ ] 注册批量配置写入 API 权限：PUT /api/v1/uctoo/config/batch
- [ ] 注册配置元数据 API 权限：GET /api/v1/uctoo/config/metadata
- [ ] 注册导出/导入 API 权限：GET /api/v1/uctoo/config/export、POST /api/v1/uctoo/config/import
- [ ] 将所有新增权限分配给管理员角色（从 uctoo_role 表查询 admin 角色）
- [ ] 执行增量 SQL 并验证权限数据注册成功

### 1.3 i18n 国际化注册

- [ ] 创建增量 SQL 文件 `sql/incremental/config_i18n.sql`，注册菜单国际化 key：menu.systemManager（系统管理/System）、menu.systemManager.systemConfig（系统配置/System Config）
- [ ] 注册配置分组国际化 key：config.group.logging、config.group.environment、config.group.database、config.group.ssl、config.group.model、config.group.api_key、config.group.skill、config.group.mail、config.group.storage、config.group.token、config.group.other
- [ ] 执行增量 SQL 并验证 i18n 数据注册成功

---

## 2. 后端基础模块开发

**目标**：开发 ConfigPO 模型、ConfigDAO、EnvFileService、ConfigValidator 四个基础模块，为 ConfigService 提供数据访问和工具支撑。

### 2.1 ConfigPO 模型

- [ ] 使用 crudgen 从扩展后的 config 表生成 ConfigPO 模型文件 `src/app/models/uctoo/ConfigPO.cj`，包含现有字段（id/name/parentId/component/key/value/status/creator/createdAt/updatedAt/deletedAt）和新增字段（envKey/configGroup/configType/isSensitive/defaultValue/validationRule/description/displayOrder/editable/lastSyncedAt）
- [ ] 验证 ConfigPO 的 @DataAssist、@QueryMappersGenerator["config"]、@ORMField 注解正确性
- [ ] 验证 ConfigPO 的 toJsonValue()/fromJsonValue() 序列化方法包含所有新增字段

### 2.2 ConfigDAO 数据访问

- [ ] 使用 crudgen 生成 ConfigDAO 文件 `src/app/dao/uctoo/ConfigDAO.cj`，包含标准 CRUD 方法：findConfigById/insertConfig/updateConfig/deleteConfigById/softDeleteConfigById/restoreConfigById/findAllConfigPage/findConfigByCondition/batchDeleteConfig/batchSoftDeleteConfig
- [ ] 在自定义引入区域添加 `findConfigByEnvKey(envKey: String): Option<ConfigPO>` 方法，按 .env 键名查询配置项
- [ ] 在自定义引入区域添加 `findConfigsByGroup(configGroup: String): ArrayList<ConfigPO>` 方法，按分组查询配置项列表
- [ ] 在自定义引入区域添加 `findAllEnvConfigs(): ArrayList<ConfigPO>` 方法，查询所有有 env_key 的配置项（env_key IS NOT NULL）
- [ ] 在自定义引入区域添加 `upsertByEnvKey(entity: ConfigPO): Int64` 方法，按 env_key 执行 upsert（INSERT ON CONFLICT UPDATE）

### 2.3 EnvFileService .env 文件读写服务

- [ ] 新建 `src/app/services/uctoo/EnvFileService.cj`，实现 `getEnvFilePath(): String` 方法，解析 .env 文件路径（支持环境变量 ENV_FILE_PATH 覆盖、跨平台路径适配）
- [ ] 实现 `parseEnvFile(content: String): ArrayList<EnvLine>` 方法，将 .env 文件内容解析为行列表（保留注释行、空行、键值行），复用 EnvWrapper 的正则 `^\s*([\w.]+)\s*=\s*("[^"]*"|'[^']*'|[^#]*)\s*(?:#.*)?$`
- [ ] 实现 `serializeEnvFile(lines: ArrayList<EnvLine>): String` 方法，将行列表序列化为 .env 文件内容
- [ ] 实现 `readAllEnvValues(path: String): HashMap<String, String>` 方法，读取 .env 文件所有键值对
- [ ] 实现 `readEnvValue(path: String, key: String): Option<String>` 方法，读取 .env 文件指定键名的值
- [ ] 实现 `writeEnvKeyValue(path: String, key: String, value: String): Bool` 方法，写入单个键值对（保持注释和格式不变，采用先写临时文件再 rename 的原子写入策略）
- [ ] 实现 `writeEnvKeyValues(path: String, items: HashMap<String, String>): Bool` 方法，批量写入键值对
- [ ] 实现 `backupEnvFile(path: String): Option<String>` 方法，备份 .env 文件（生成 .env.backup-{timestamp}）
- [ ] 实现 `restoreBackup(backupPath: String, targetPath: String): Bool` 方法，从备份恢复 .env 文件
- [ ] 定义 EnvLine 数据结构（lineType: Enum(Comment/Blank/KeyValue)、key: Option<String>、value: Option<String>、rawLine: String）

### 2.4 ConfigValidator 配置验证引擎

- [ ] 新建 `src/app/services/uctoo/ConfigValidator.cj`，定义 ValidationResult 数据结构（isValid: Bool、errorMessage: Option<String>）
- [ ] 实现 `validate(configType: String, validationRule: Option<String>, value: String): ValidationResult` 综合验证入口方法
- [ ] 实现 `validateString(value: String): ValidationResult` 字符串类型验证（非空）
- [ ] 实现 `validateInt(value: String): ValidationResult` 整数类型验证（可解析为 Int32）
- [ ] 实现 `validateBool(value: String): ValidationResult` 布尔类型验证（true/false）
- [ ] 实现 `validateUrl(value: String): ValidationResult` URL 类型验证（格式合法性）
- [ ] 实现 `validatePassword(value: String): ValidationResult` 密码类型验证（仅非空）
- [ ] 实现 `validatePath(value: String): ValidationResult` 路径类型验证
- [ ] 实现 `validateJson(value: String): ValidationResult` JSON 类型验证（可解析为合法 JSON）
- [ ] 实现 `validateByRule(rule: String, value: String): ValidationResult` 自定义规则验证（支持 port:1-65535、url、bool:true|false、not_empty、path:exists）

---

## 3. 后端核心服务开发

**目标**：开发 ConfigService、ConfigController、ConfigRoute、ConfigSyncHandler 四个核心模块，实现配置的读写、验证、同步、审计等完整业务逻辑。

### 3.1 ConfigService 配置服务

- [ ] 使用 crudgen 生成 ConfigService 文件 `src/app/services/uctoo/ConfigService.cj`，包含标准 CRUD 方法（create/update/delete/getById/getList/getListWithFilter 及带权限版本）
- [ ] 实现 `getConfigByKey(envKey: String): APIResult<ConfigPO>` 方法，按 .env 键名读取配置项，敏感项脱敏后返回
- [ ] 实现 `getConfigsByGroup(group: String): APIResult<ArrayList<ConfigPO>>` 方法，按分组读取配置项列表，敏感项脱敏后返回
- [ ] 实现 `getAllConfigs(): APIResult<ArrayList<ConfigPO>>` 方法，全量读取配置项，敏感项脱敏后返回
- [ ] 实现 `getConfigMetadata(): APIResult<ArrayList<ConfigMetadataVO>>` 方法，获取所有配置项的元数据（不含 value，用于前端表单渲染）
- [ ] 实现 `updateConfigByKey(envKey: String, value: String, operatorId: String, channel: String): APIResult<ConfigPO>` 方法，按 .env 键名写入配置项，完整流程：验证 → 备份 → 写 .env → 同步 config 表 → 审计日志
- [ ] 实现 `batchUpdateConfigs(items: ArrayList<ConfigUpdateItem>, operatorId: String, channel: String): APIResult<ArrayList<ConfigPO>>` 方法，批量写入配置项（≤50项）
- [ ] 实现 `exportConfig(format: String): APIResult<String>` 方法，导出配置（JSON 或 .env 格式）
- [ ] 实现 `importConfig(data: String, format: String, operatorId: String): APIResult<Bool>` 方法，导入配置
- [ ] 实现 `maskSensitiveValue(value: String): String` 方法，敏感值脱敏（前4后4，中间 * 替代，不足8位全部脱敏）
- [ ] 实现 `syncFromEnvFile(): APIResult<Bool>` 方法，手动触发从 .env 文件同步到 config 表
- [ ] 定义 ConfigMetadataVO 数据结构（envKey/name/configGroup/configType/isSensitive/defaultValue/validationRule/description/displayOrder/editable）
- [ ] 定义 ConfigUpdateItem 数据结构（envKey/value）

### 3.2 ConfigController 控制器

- [ ] 使用 crudgen 生成 ConfigController 文件 `src/app/controllers/uctoo/config/ConfigController.cj`，包含标准 CRUD 方法（add/edit/delete/getSingle/getManyWithPathParams/getManyWithSkip/export）
- [ ] 在自定义引入区域实现 `getConfigs(req, res)` 方法，处理 GET /api/v1/uctoo/config 请求，支持 queryParam `group` 过滤
- [ ] 在自定义引入区域实现 `getConfigByKey(req, res)` 方法，处理 GET /api/v1/uctoo/config/:key 请求
- [ ] 在自定义引入区域实现 `updateConfigByKey(req, res)` 方法，处理 PUT /api/v1/uctoo/config/:key 请求
- [ ] 在自定义引入区域实现 `batchUpdateConfigs(req, res)` 方法，处理 PUT /api/v1/uctoo/config/batch 请求
- [ ] 在自定义引入区域实现 `getConfigMetadata(req, res)` 方法，处理 GET /api/v1/uctoo/config/metadata 请求
- [ ] 在自定义引入区域实现 `exportConfig(req, res)` 方法，处理 GET /api/v1/uctoo/config/export 请求
- [ ] 在自定义引入区域实现 `importConfig(req, res)` 方法，处理 POST /api/v1/uctoo/config/import 请求
- [ ] 在所有 RESTful 扩展方法中添加权限校验：GET 方法检查 config:read 权限，PUT/POST 方法检查 config:write 权限

### 3.3 ConfigRoute 路由注册

- [ ] 使用 crudgen 生成 ConfigRoute 文件 `src/app/routes/uctoo/config/ConfigRoute.cj`，包含标准路由注册（add/edit/del/:id/:limit/:page）
- [ ] 在 `registerCustomRoutes()` 中注册 RESTful 扩展路由，**确保固定路径路由在动态路由 :key 之前注册**，注册顺序：GET /metadata → GET /export → PUT /batch → POST /import → GET /:key → PUT /:key
- [ ] 在 AutoRouteConfig.cj 中注册 ConfigRoute，确保路由在应用启动时正确加载

### 3.4 ConfigSyncHandler 配置同步处理器

- [ ] 新建 `src/app/services/uctoo/ConfigSyncHandler.cj`，定义 SyncResult 数据结构（totalCount/successCount/failedCount/details: ArrayList<SyncDetail>）
- [ ] 定义 SyncDetail 数据结构（envKey/envValue/dbValue/syncAction/success/errorMessage）
- [ ] 实现 `startupSync(): SyncResult` 方法，启动时全量同步：读取 .env 全部键值对 → 遍历每个键值对 upsert 到 config 表 → 更新 last_synced_at
- [ ] 实现 `dualWrite(envKey: String, value: String): SyncResult` 方法，API 写入时双写：.env + config 表
- [ ] 实现 `scheduledSync(): SyncResult` 方法，定时增量同步：检测 .env 文件修改时间 → 比较差异 → 增量同步到 config 表
- [ ] 实现 `manualSyncFromEnv(): SyncResult` 方法，手动触发从 .env 文件同步到 config 表
- [ ] 实现 `resolveConflict(envKey: String, envValue: String, dbValue: String): String` 方法，冲突解决：始终以 .env 值为准
- [ ] 在 Application.init() 中注册启动同步调用（与 SyncManager.initialize() 并行执行，spawn 异步）
- [ ] 在 CrontabScheduler 中注册定时同步任务（任务名：config-env-sync，Cron 表达式：0 */5 * * * *，每5分钟执行）

---

## 4. 命令行配置通道开发

**目标**：实现 config_cli 命令行工具，提供运维人员和自动化脚本的配置操作通道。

### 4.1 config_cli 命令行工具

- [ ] 新建 `src/cli/config_cli.cj`，遵循 runtime 项目 CLI 规范（参考 crontab_cli.cj），实现 `execute(args: Array<String>)` 入口方法
- [ ] 实现 `config get <key>` 命令，通过 HTTP GET /api/v1/uctoo/config/:key 读取单个配置项，输出格式化的配置信息
- [ ] 实现 `config list [--group <group>] [--json]` 命令，通过 HTTP GET /api/v1/uctoo/config 列出配置项，支持分组过滤和 JSON 输出
- [ ] 实现 `config set <key> <value>` 命令，通过 HTTP PUT /api/v1/uctoo/config/:key 写入配置项
- [ ] 实现 `config unset <key>` 命令，标记配置项为禁用（调用 PUT API 传入空值）
- [ ] 实现 `config export [--format json|env]` 命令，通过 HTTP GET /api/v1/uctoo/config/export 导出配置
- [ ] 实现 `config import --file <path> [--format json|env]` 命令，通过 HTTP POST /api/v1/uctoo/config/import 导入配置
- [ ] 实现认证凭据传递：从环境变量 CONFIG_CLI_TOKEN 或命令行 --token 参数获取 Token，构造 Authorization: Bearer <token> 请求头
- [ ] 实现 `printUsage()` 帮助信息输出
- [ ] 在 `src/cli/main.cj` 中注册 config 命令入口

---

## 5. 前端数据模型与 API 对接

**目标**：开发 config pinia-orm Model，建立前端与后端 API 的数据通道。

### 5.1 config pinia-orm Model

- [ ] 新建 `apps/web-admin/web/src/store/models/uctoo/config.ts`，定义 config Model 类，继承 Model，entity 名为 'config'
- [ ] 定义 Model 字段：@Uid id、@Str name、@Str parentId、@Str component、@Str key、@Str value、@Num status、@Str creator、@Attr createdAt、@Attr updatedAt、@Attr deletedAt、@Str envKey、@Str('other') configGroup、@Str('string') configType、@Bool(false) isSensitive、@Str defaultValue、@Str validationRule、@Str description、@Num(0) displayOrder、@Bool(true) editable、@Attr lastSyncedAt
- [ ] 实现标准 CRUD API actions：getConfigList、getConfig、addConfig、editConfig、deleteConfig
- [ ] 实现 RESTful 扩展 API actions：getAllConfigs（GET /api/v1/uctoo/config）、getConfigByKey（GET /api/v1/uctoo/config/{key}）、updateConfigByKey（PUT /api/v1/uctoo/config/{key}）、batchUpdateConfigs（PUT /api/v1/uctoo/config/batch）、getConfigMetadata（GET /api/v1/uctoo/config/metadata）
- [ ] 所有 API 请求携带 Authorization: Bearer <accessToken> 请求头，baseURL 从 import.meta.env.VITE_BACKEND_URL 读取

---

## 6. 前端可视化配置界面开发

**目标**：开发系统配置管理页面，实现分组 Tab 布局的配置表单、元数据驱动的表单渲染、敏感项脱敏显示等可视化功能。

### 6.1 系统配置主页面

- [ ] 新建 `apps/web-admin/web/src/views/system/config/index.vue`，实现页面主容器，加载元数据和配置值
- [ ] 实现分组 Tab 布局，分组包括：日志配置、环境配置、数据库配置、SSL配置、模型配置、API密钥配置、技能配置、邮件配置、存储配置、Token配置、其他
- [ ] 实现页面头部操作区：导出按钮（调用 exportConfig API）、导入按钮（调用 importConfig API）
- [ ] 实现页面底部操作区：恢复默认按钮、保存按钮（调用 batchUpdateConfigs API）
- [ ] 实现页面加载流程：先调用 getConfigMetadata() 获取元数据 → 再调用 getAllConfigs() 获取配置值 → 根据 configGroup 分组渲染 Tab → 每个分组内按 displayOrder 排序渲染表单项

### 6.2 ConfigFormItem 配置项表单控件

- [ ] 新建 `apps/web-admin/web/src/views/system/config/components/ConfigFormItem.vue`，根据 configType 渲染不同表单控件：string → t-input、int → t-input-number、bool → t-switch、url → t-input、password → t-input type="password"、path → t-input、json → t-textarea
- [ ] 实现敏感配置项脱敏显示：isSensitive=true 时使用密码输入框，显示脱敏值
- [ ] 实现只读配置项禁用：editable=false 时表单控件设为 disabled
- [ ] 实现前端表单验证：基于 configType 和 validationRule 进行输入验证
- [ ] 实现配置项描述展示：在表单控件旁显示 description 说明文字

### 6.3 路由注册

- [ ] 新建或扩展 `apps/web-admin/web/src/router/routes/modules/system.ts`，注册"系统管理"一级路由（path: 'system'）和"系统配置"二级路由（path: 'config'，component: system/config/index.vue）
- [ ] 路由 meta 配置：locale='menu.systemManager.systemConfig'、requiresAuth=true、roles=[RoleType.admin]

### 6.4 i18n 国际化前端配置

- [ ] 在前端 i18n 资源文件中添加菜单国际化 key：menu.systemManager（系统管理/System）、menu.systemManager.systemConfig（系统配置/System Config）
- [ ] 添加配置分组国际化 key：config.group.logging、config.group.environment、config.group.database 等 11 个分组的中英文翻译

---

## 7. 集成测试与验证

**目标**：验证系统配置管理功能的完整性、正确性和可靠性，确保所有需求场景覆盖。

### 7.1 后端 API 测试

- [ ] 编写 Python 测试脚本，验证标准 CRUD API：POST /add、POST /edit、POST /del、GET /:id、GET /:limit/:page
- [ ] 验证 RESTful 扩展 API：GET /api/v1/uctoo/config（全量/分组读取）、GET /api/v1/uctoo/config/:key（按键名读取）、PUT /api/v1/uctoo/config/:key（按键名写入）、PUT /api/v1/uctoo/config/batch（批量写入）、GET /api/v1/uctoo/config/metadata（元数据查询）
- [ ] 验证导出/导入 API：GET /api/v1/uctoo/config/export（JSON 和 .env 格式）、POST /api/v1/uctoo/config/import
- [ ] 验证权限校验：无 config:read 权限时 GET 请求返回 403，无 config:write 权限时 PUT/POST 请求返回 403
- [ ] 验证敏感配置项脱敏：is_sensitive=true 的配置项在 API 响应中值被脱敏（前4后4中间*替代）
- [ ] 验证配置项验证：非法 URL 格式返回 400，非法端口号返回 400，非法布尔值返回 400

### 7.2 .env 文件读写与同步测试

- [ ] 验证 EnvFileService 读写：写入键值对后 .env 文件注释和格式保持不变
- [ ] 验证 .env 文件备份与恢复：写入前自动备份，写入失败自动恢复备份
- [ ] 验证启动同步：runtime 启动后 .env 文件中的配置项自动同步到 config 表
- [ ] 验证双写同步：通过 API 写入配置项后，.env 文件和 config 表同时更新
- [ ] 验证定时同步：手动修改 .env 文件后，5分钟内 config 表自动同步更新
- [ ] 验证冲突解决：.env 文件与 config 表值不一致时，以 .env 值为准

### 7.3 命令行通道测试

- [ ] 验证 config get <key> 命令：正确读取配置项并格式化输出
- [ ] 验证 config list 命令：列出所有配置项，支持 --group 和 --json 参数
- [ ] 验证 config set <key> <value> 命令：正确写入配置项
- [ ] 验证 config export/import 命令：正确导出和导入配置
- [ ] 验证认证失败场景：未提供 Token 时返回认证错误

### 7.4 前端界面测试

- [ ] 验证系统配置页面加载：元数据和配置值正确加载，分组 Tab 正确渲染
- [ ] 验证配置项表单渲染：string/int/bool/url/password/path/json 类型对应正确的表单控件
- [ ] 验证敏感配置项显示：is_sensitive=true 的配置项使用密码框，显示脱敏值
- [ ] 验证配置保存：修改配置项后点击保存，调用 batchUpdateConfigs API 成功
- [ ] 验证权限控制：无 config:read 权限的用户无法看到"系统配置"菜单

### 7.5 异常场景测试

- [ ] 验证 .env 文件不存在时：API 返回 CONFIG_ENV_FILE_NOT_FOUND 错误
- [ ] 验证 .env 文件写入失败时：自动恢复备份，返回 CONFIG_WRITE_FAILED 错误
- [ ] 验证配置值验证失败时：返回 CONFIG_VALIDATION_FAILED 错误和具体验证信息
- [ ] 验证并发写入冲突：多个请求同时修改同一配置项时，后写入者覆盖先写入者
- [ ] 验证同步失败场景：.env 写入成功但 config 表写入失败时，记录同步失败日志

---

## 8. 部署与配置

**目标**：确保系统配置管理功能可正确部署上线，包含环境配置、数据迁移和监控。

### 8.1 环境配置

- [ ] 确认生产环境 .env 文件路径解析逻辑：支持 ENV_FILE_PATH 环境变量覆盖默认路径
- [ ] 确认 .env 文件系统权限设置：确保运行时用户有读写权限，其他用户无读取权限
- [ ] 确认定时同步任务配置：CrontabScheduler 中 config-env-sync 任务的 Cron 表达式和执行参数

### 8.2 数据迁移

- [ ] 验证增量 SQL 执行顺序：先 config_table_extension.sql → 再 config_permissions.sql → 最后 config_i18n.sql
- [ ] 验证现有 config 表数据兼容性：新增字段均有默认值，现有数据不受影响
- [ ] 验证权限数据不冲突：使用 ON CONFLICT DO NOTHING 避免重复插入

### 8.3 监控与日志

- [ ] 确认配置同步日志记录到 sync_log 表，包含同步方向、变更项数量、成功/失败数
- [ ] 确认配置变更审计日志通过 OperateLogService 记录，包含操作者、时间、变更前后值
- [ ] 确认 .env 文件读写异常日志输出到应用日志，便于排查问题