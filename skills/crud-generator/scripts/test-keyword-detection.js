/**
 * 测试关键字检测功能
 */
import { generateModule } from './generate-from-template-v2.js'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

/**
 * 从schema.prisma解析表字段
 */
function parseSchemaFields(schemaContent, tableName) {
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
        
        if (!trimmed || 
            trimmed.startsWith('//') || 
            trimmed.startsWith('@@') ||
            trimmed.includes('@relation') ||
            trimmed.includes('fields:') ||
            trimmed.includes('references:')) {
            continue
        }
        
        const fieldMatch = trimmed.match(/^(\w+)\s+(\w+)(\??)(.*)$/)
        if (fieldMatch) {
            const [, fieldName, fieldType, optional, annotations] = fieldMatch
            
            if (fieldType[0] === fieldType[0].toUpperCase() && fieldType !== 'String' && fieldType !== 'Int' && fieldType !== 'Float' && fieldType !== 'Boolean' && fieldType !== 'DateTime') {
                continue
            }
            
            const camelName = fieldName.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
            
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
            
            const isPrimaryKey = annotations.includes('@id')
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
    
    // 测试permissions表（包含type关键字）
    const testTables = ['permissions']
    
    console.log('================================================================================')
    console.log('关键字检测功能测试')
    console.log('================================================================================')
    console.log(`测试表: ${testTables.join(', ')}`)
    console.log('================================================================================')
    
    const schemaContent = fs.readFileSync(schemaPath, 'utf-8')
    
    for (const tableName of testTables) {
        console.log(`\n测试 ${tableName} 表...`)
        try {
            const fields = parseSchemaFields(schemaContent, tableName)
            console.log(`  解析到 ${fields.length} 个字段`)
            
            // 检查是否有type字段
            const typeField = fields.find(f => f.name === 'type')
            if (typeField) {
                console.log(`  ✅ 发现 'type' 字段（仓颉关键字）`)
            }
            
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
    console.log('✅ 测试完成！')
    console.log('================================================================================')
}

main().catch(console.error)
