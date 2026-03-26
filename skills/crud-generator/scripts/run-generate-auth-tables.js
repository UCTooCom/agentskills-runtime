/**
 * 生成auth相关表的标准CRUD模块
 */
import { generateModule } from './generate-from-template.js'
import pg from 'pg'

const { Client } = pg

/**
 * 从数据库查询表结构
 */
async function getTableFields(tableName, dbName) {
  const client = new Client({
    connectionString: 'postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo'
  })
  
  await client.connect()
  
  const query = `
    SELECT 
      column_name,
      data_type,
      is_nullable,
      column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = $1
    ORDER BY ordinal_position
  `
  
  const result = await client.query(query, [tableName])
  await client.end()
  
  const fields = result.rows.map(row => {
    const columnName = row.column_name
    const camelName = columnName.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
    
    // 类型映射
    let type = 'String'
    const dataType = row.data_type.toLowerCase()
    if (dataType.includes('int')) {
      type = 'Int'
    } else if (dataType.includes('timestamp') || dataType.includes('date')) {
      type = 'DateTime'
    } else if (dataType.includes('float') || dataType.includes('double') || dataType.includes('decimal')) {
      type = 'Float'
    } else if (dataType === 'boolean') {
      type = 'Bool'
    }
    
    return {
      name: columnName,
      dbName: columnName,
      camelName: camelName,
      type: type,
      isPrimaryKey: columnName === 'id',
      isOptional: row.is_nullable === 'YES'
    }
  })
  
  return fields
}

async function main() {
  const outputDir = 'D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\app'
  const dbName = 'uctoo'

  // auth相关表列表
  const authTables = [
    'permissions',
    'user_group',
    'group_has_permission',
    'user_has_account',
    'user_has_group'
  ]

  console.log('================================================================================')
  console.log('CRUD Generator - 生成 auth 相关模块')
  console.log('================================================================================')
  console.log(`数据库: ${dbName}`)
  console.log(`输出目录: ${outputDir}`)
  console.log(`表列表: ${authTables.join(', ')}`)
  console.log('================================================================================')

  for (const tableName of authTables) {
    console.log(`\n生成 ${tableName} 模块...`)
    try {
      const fields = await getTableFields(tableName, dbName)
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
