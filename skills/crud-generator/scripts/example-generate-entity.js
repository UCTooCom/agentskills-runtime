/**
 * 示例：使用通用生成脚本生成entity模块
 * 
 * 这个脚本展示了如何使用 generate-from-template-v2.js 来生成CRUD模块
 */

import { generateModule } from './generate-from-template-v2.js'

// Entity表的字段定义（从Prisma schema提取）
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
]

// 生成配置
const config = {
  tableName: 'entity',
  dbName: 'uctoo',
  fields: entityFields,
  outputDir: 'D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\app'
}

console.log('='.repeat(80))
console.log('使用通用生成脚本 generate-from-template-v2.js 生成entity模块')
console.log('='.repeat(80))
console.log()

// 调用通用生成函数
generateModule(config)
  .then(() => {
    console.log()
    console.log('='.repeat(80))
    console.log('✅ 生成完成！')
    console.log('='.repeat(80))
  })
  .catch(error => {
    console.error('❌ 生成失败:', error)
    process.exit(1)
  })
