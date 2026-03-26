/**
 * 从schema.prisma生成auth相关表的标准CRUD模块
 * 不需要连接数据库，直接解析schema.prisma文件
 */
import { generateModule } from './generate-from-template.js'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

/**
 * 从schema.prisma解析表字段
 */
function parseSchemaFields(schemaContent, tableName) {
  // 查找model定义
  const modelRegex = new RegExp(`model\\s+${tableName}\\s*\\{([^}]+)\\}`, 's')
  const match = schemaContent.match(modelRegex)
  
  if (!match) {
    throw new Error(`Table ${tableName} not found in schema`)
  }
  
  const modelContent = match[1]
  const lines = modelContent.split('\n')
  const fields = []
  
  for (const line of lines) {
    const trimmed = line.trim()
    
    // 跳过空行、注释、索引定义、关系定义
    if (!trimmed || 
        trimmed.startsWith('//') || 
        trimmed.startsWith('@@') ||
        trimmed.includes('@relation') ||
        trimmed.includes('fields:') ||
        trimmed.includes('references:')) {
      continue
    }
    
    // 解析字段: fieldName Type @annotations
    const fieldMatch = trimmed.match(/^(\w+)\s+(\w+)(\??)(.*)$/)
    if (fieldMatch) {
      const [, fieldName, fieldType, optional, annotations] = fieldMatch
      
      // 跳过关系字段（首字母大写的类型）
      if (fieldType[0] === fieldType[0].toUpperCase() && fieldType !== 'String' && fieldType !== 'Int' && fieldType !== 'Float' && fieldType !== 'Boolean' && fieldType !== 'DateTime') {
        continue
      }
      
      // 转换为驼峰命名
      const camelName = fieldName.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
      
      // 类型映射
      let type = 'String'
      if (fieldType === 'Int') {
        type = 'Int'
      } else if (fieldType === 'Float') {
        type = 'Float'
      } else if (fieldType === 'Boolean') {
        type = 'Bool'
      } else if (fieldType === 'DateTime') {
        type = 'DateTime'
      }
      
      // 判断是否为主键
      const isPrimaryKey = annotations.includes('@id')
      
      // 判断是否为可选字段
      const isOptional = optional === '?' || annotations.includes('?')
      
      fields.push({
        name: fieldName,
        dbName: fieldName,
        camelName: camelName,
        type: type,
        isPrimaryKey: isPrimaryKey,
        isOptional: isOptional
      })
    }
  }
  
  return fields
}

async function main() {
  const outputDir = 'D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\app'
  const dbName = 'uctoo'
  const schemaPath = 'D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\backend\\prisma\\uctoo\\schema.prisma'
  
  // auth相关表列表
  const authTables = [
    'permissions',
    'user_group',
    'group_has_permission',
    'user_has_account',
    'user_has_group'
  ]
  
  console.log('================================================================================')
  console.log('CRUD Generator - 从schema.prisma生成 auth 相关模块')
  console.log('================================================================================')
  console.log(`数据库: ${dbName}`)
  console.log(`输出目录: ${outputDir}`)
  console.log(`Schema文件: ${schemaPath}`)
  console.log(`表列表: ${authTables.join(', ')}`)
  console.log('================================================================================')
  
  // 读取schema.prisma文件
  const schemaContent = fs.readFileSync(schemaPath, 'utf-8')
  
  for (const tableName of authTables) {
    console.log(`\n生成 ${tableName} 模块...`)
    try {
      const fields = parseSchemaFields(schemaContent, tableName)
      console.log(`  解析到 ${fields.length} 个字段`)
      
      const config = {
        tableName: tableName,
        dbName: dbName,
        fields: fields,
        outputDir: outputDir
      }
      await generateModule(config)
      console.log(`✅ ${tableName} 模块生成成功！`)
    } catch (error) {
      console.error(`❌ ${tableName} 模块生成失败:`, error.message)
    }
  }
  
  console.log('================================================================================')
  console.log('✅ 所有 auth 模块生成完成！')
  console.log('================================================================================')
}

main().catch(console.error)
