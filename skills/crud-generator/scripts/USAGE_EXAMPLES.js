/**
 * CRUD Generator 使用示例
 * 
 * 展示如何使用通用生成脚本 generate-from-template.ts 来生成不同表的CRUD模块
 * 
 * 使用方式：
 * 1. 准备表的字段定义
 * 2. 配置生成参数
 * 3. 调用 generateModule() 函数
 */

// ==================== 示例1：生成entity模块 ====================

const entityFields = [
  { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
  { name: 'link', dbName: 'link', camelName: 'link', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'privacy_level', dbName: 'privacy_level', camelName: 'privacyLevel', type: 'Int', isPrimaryKey: false, isOptional: false },
  { name: 'stars', dbName: 'stars', camelName: 'stars', type: 'Float', isPrimaryKey: false, isOptional: false },
  { name: 'description', dbName: 'description', camelName: 'description', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'group_id', dbName: 'group_id', camelName: 'groupId', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'picture', dbName: 'picture', camelName: 'picture', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'images', dbName: 'images', camelName: 'images', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'content', dbName: 'content', camelName: 'content', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'json', dbName: 'json', camelName: 'json', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'city', dbName: 'city', camelName: 'city', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'price', dbName: 'price', camelName: 'price', type: 'Float', isPrimaryKey: false, isOptional: true },
  { name: 'birthday', dbName: 'birthday', camelName: 'birthday', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'owner', dbName: 'owner', camelName: 'owner', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'creator', dbName: 'creator', camelName: 'creator', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'created_at', dbName: 'created_at', camelName: 'createdAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'updated_at', dbName: 'updated_at', camelName: 'updatedAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'deleted_at', dbName: 'deleted_at', camelName: 'deletedAt', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'end_time', dbName: 'end_time', camelName: 'endTime', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'start_time', dbName: 'start_time', camelName: 'startTime', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'status', dbName: 'status', camelName: 'status', type: 'String', isPrimaryKey: false, isOptional: true }
];

// ==================== 示例2：生成uctoo_user模块 ====================

const uctooUserFields = [
  { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
  { name: 'name', dbName: 'name', camelName: 'name', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'username', dbName: 'username', camelName: 'username', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'email', dbName: 'email', camelName: 'email', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'password', dbName: 'password', camelName: 'password', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'avatar', dbName: 'avatar', camelName: 'avatar', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'created_at', dbName: 'created_at', camelName: 'createdAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'last_login', dbName: 'last_login', camelName: 'lastLogin', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'auth_provider', dbName: 'auth_provider', camelName: 'authProvider', type: 'Int', isPrimaryKey: false, isOptional: false },
  { name: 'creator', dbName: 'creator', camelName: 'creator', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'deleted_at', dbName: 'deleted_at', camelName: 'deletedAt', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'last_login_ip', dbName: 'last_login_ip', camelName: 'lastLoginIp', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'last_login_time', dbName: 'last_login_time', camelName: 'lastLoginTime', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'remember_token', dbName: 'remember_token', camelName: 'rememberToken', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'status', dbName: 'status', camelName: 'status', type: 'Int', isPrimaryKey: false, isOptional: false },
  { name: 'updated_at', dbName: 'updated_at', camelName: 'updatedAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'access_token', dbName: 'access_token', camelName: 'accessToken', type: 'String', isPrimaryKey: false, isOptional: true }
];

// ==================== 使用方式 ====================

/**
 * 方式一：直接调用 generateModule()
 * 
 * import { generateModule } from './scripts/generate-from-template.js'
 * 
 * // 生成entity模块
 * await generateModule({
 *   tableName: 'entity',
 *   dbName: 'uctoo',
 *   fields: entityFields,
 *   outputDir: './src/app'
 * })
 * 
 * // 生成uctoo_user模块
 * await generateModule({
 *   tableName: 'uctoo_user',
 *   dbName: 'uctoo',
 *   fields: uctooUserFields,
 *   outputDir: './src/app'
 * })
 */

/**
 * 方式二：通过技能交互
 * 
 * 用户: "为 entity 表生成 CRUD"
 * 技能: 自动调用 generateModule({ tableName: 'entity', ... })
 * 
 * 用户: "为 uctoo_user 表生成 CRUD"
 * 技能: 自动调用 generateModule({ tableName: 'uctoo_user', ... })
 */

/**
 * 方式三：批量生成多个表
 * 
 * const tables = [
 *   { tableName: 'entity', fields: entityFields },
 *   { tableName: 'uctoo_user', fields: uctooUserFields },
 *   // ... 其他表
 * ]
 * 
 * for (const table of tables) {
 *   await generateModule({
 *     tableName: table.tableName,
 *     dbName: 'uctoo',
 *     fields: table.fields,
 *     outputDir: './src/app'
 *   })
 * }
 */

// ==================== 字段定义说明 ====================

/**
 * 字段定义格式：
 * 
 * {
 *   name: 'field_name',        // 字段名（Prisma中的名称）
 *   dbName: 'field_name',      // 数据库列名（通常与name相同）
 *   camelName: 'fieldName',    // 驼峰命名（用于Cangjie代码）
 *   type: 'String',            // Prisma类型（String, Int, Float, Boolean, DateTime）
 *   isPrimaryKey: false,       // 是否主键
 *   isOptional: false          // 是否可选（对应Prisma中的?）
 * }
 * 
 * 类型映射：
 * - String → String / ?String
 * - Int → Int32 / ?Int32
 * - Float → Float64 / ?Float64
 * - Boolean → Bool / ?Bool
 * - DateTime → DateTime / ?DateTime
 */

console.log('CRUD Generator 使用示例');
console.log('请参考文件中的注释了解如何使用通用生成脚本');
