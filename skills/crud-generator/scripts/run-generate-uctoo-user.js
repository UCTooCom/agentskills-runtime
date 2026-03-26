/**
 * 使用crud-generator生成uctoo_user模块
 */

import { generateModule } from './generate-from-template.js'

// UctooUser表的字段定义（从Prisma schema提取）
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
]

// 生成配置
const config = {
  tableName: 'uctoo_user',
  dbName: 'uctoo',
  fields: uctooUserFields,
  outputDir: 'D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\app'
}

// 调用生成函数
generateModule(config)
  .then(() => {
    console.log('\n✅ uctoo_user模块生成成功！')
  })
  .catch(error => {
    console.error('❌ 生成失败:', error)
    process.exit(1)
  })
