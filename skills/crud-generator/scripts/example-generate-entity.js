/**
 * 示例：使用通用生成脚本生成entity模块
 * 
 * 这个脚本展示了如何使用 generate-from-template-v2.js 来生成CRUD模块
 * 使用SQL解析器从uctooDB.sql文件解析表结构
 */

import { generateModule } from './generate-from-template-v2.js'
import { parseTable } from './sql-schema-parser.js'

console.log('='.repeat(80))
console.log('使用通用生成脚本 generate-from-template-v2.js 生成entity模块')
console.log('='.repeat(80))
console.log()

// 解析表结构（从uctooDB.sql文件）
console.log('📋 解析entity表结构...')
const tableInfo = parseTable('entity')

if (!tableInfo || !tableInfo.fields || tableInfo.fields.length === 0) {
  console.error('❌ 无法解析entity表结构')
  process.exit(1)
}

console.log(`✅ 解析成功，共${tableInfo.fields.length}个字段`)
console.log()

// 生成配置
const config = {
  tableName: 'entity',
  dbName: 'uctoo',
  fields: tableInfo.fields,
  outputDir: 'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/src/app'
}

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
