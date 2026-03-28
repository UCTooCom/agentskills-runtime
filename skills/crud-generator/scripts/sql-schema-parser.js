/**
 * SQL Schema Parser - 从uctooDB.sql解析PostgreSQL表结构
 * 
 * 功能：
 * 1. 解析CREATE TABLE语句
 * 2. 提取字段名、类型、约束
 * 3. 识别主键、外键、索引
 * 4. 支持PostgreSQL特有语法
 */

import fs from 'fs'
import path from 'path'

/**
 * 解析uctooDB.sql文件，提取指定表的结构
 * @param {string} sqlFilePath - uctooDB.sql文件路径
 * @param {string} tableName - 要解析的表名
 * @returns {Object} 表结构信息
 */
export function parseTableFromSQL(sqlFilePath, tableName) {
    const sqlContent = fs.readFileSync(sqlFilePath, 'utf-8')
    
    // 查找表的CREATE TABLE语句
    const tableStart = sqlContent.indexOf(`CREATE TABLE "public"."${tableName}"`)
    if (tableStart === -1) {
        throw new Error(`Table ${tableName} not found in ${sqlFilePath}`)
    }
    
    // 找到左括号位置
    const parenStart = sqlContent.indexOf('(', tableStart)
    
    // 找到匹配的右括号
    let parenCount = 1
    let parenEnd = parenStart + 1
    while (parenCount > 0 && parenEnd < sqlContent.length) {
        const char = sqlContent[parenEnd]
        if (char === '(') parenCount++
        else if (char === ')') parenCount--
        parenEnd++
    }
    
    // 提取字段定义部分
    const fieldsStr = sqlContent.substring(parenStart + 1, parenEnd - 1)
    const fields = []
    let primaryKey = null
    
    // 解析字段
    const lines = fieldsStr.split('\n')
    for (const line of lines) {
        const trimmedLine = line.trim()
        
        // 跳过空行和约束
        if (!trimmedLine || trimmedLine.startsWith('CONSTRAINT') || 
            trimmedLine.startsWith('PRIMARY KEY') || trimmedLine.startsWith('FOREIGN KEY')) {
            continue
        }
        
        // 解析字段定义
        // 格式: "field_name" type COLLATE "pg_catalog"."default" NOT NULL DEFAULT value,
        const fieldMatch = trimmedLine.match(
            /"(\w+)"\s+(\w+)(?:\([^)]*\))?(?:\s+COLLATE\s+"[^"]+"\."[^"]+")?\s*(NOT NULL|NULL)?\s*(?:DEFAULT\s+(.+?))?,?$/
        )
        
        if (fieldMatch) {
            const [, name, type, nullable, defaultValue] = fieldMatch
            
            // 映射PostgreSQL类型到通用类型
            const mappedType = mapPostgreSQLType(type)
            
            fields.push({
                name: name,
                dbName: name,
                camelName: convertToCamelCase(name),
                type: mappedType.type,
                isOptional: nullable !== 'NOT NULL',
                isPrimaryKey: false, // 后续识别
                defaultValue: parseDefaultValue(defaultValue, mappedType.type),
                comment: '' // 从COMMENT ON COLUMN提取
            })
        }
    }
    
    // 提取主键（从PRIMARY KEY约束或字段标记）
    const pkMatch = fieldsStr.match(/PRIMARY KEY\s*\(([^)]+)\)/i)
    if (pkMatch) {
        const pkFields = pkMatch[1].split(',').map(f => f.trim().replace(/"/g, ''))
        for (const pkField of pkFields) {
            const field = fields.find(f => f.name === pkField)
            if (field) {
                field.isPrimaryKey = true
                if (!primaryKey) primaryKey = pkField
            }
        }
    }
    
    // 提取字段注释
    const commentRegex = new RegExp(
        `COMMENT ON COLUMN "public"."${tableName}"."(\\w+)" IS '([^']+)';`,
        'g'
    )
    let commentMatch
    while ((commentMatch = commentRegex.exec(sqlContent)) !== null) {
        const [, fieldName, comment] = commentMatch
        const field = fields.find(f => f.name === fieldName)
        if (field) {
            field.comment = comment
        }
    }
    
    return {
        tableName,
        fields,
        primaryKey,
        database: 'uctoo'
    }
}

/**
 * PostgreSQL类型映射
 */
function mapPostgreSQLType(pgType) {
    const typeMap = {
        'uuid': { type: 'String', prismaType: 'String' },
        'text': { type: 'String', prismaType: 'String' },
        'varchar': { type: 'String', prismaType: 'String' },
        'int4': { type: 'Int', prismaType: 'Int' },
        'int8': { type: 'Int', prismaType: 'Int' },
        'float8': { type: 'Float', prismaType: 'Float' },
        'bool': { type: 'Boolean', prismaType: 'Boolean' },
        'timestamptz': { type: 'DateTime', prismaType: 'DateTime' },
        'timestamp': { type: 'DateTime', prismaType: 'DateTime' },
        'date': { type: 'DateTime', prismaType: 'DateTime' },
        'jsonb': { type: 'String', prismaType: 'String' },
        'json': { type: 'String', prismaType: 'String' }
    }
    
    return typeMap[pgType.toLowerCase()] || { type: 'String', prismaType: 'String' }
}

/**
 * 解析默认值
 */
function parseDefaultValue(defaultValue, type) {
    if (!defaultValue) return null
    
    // 移除类型转换
    defaultValue = defaultValue.replace(/::.+$/, '')
    
    switch (type) {
        case 'String':
            if (defaultValue === 'gen_random_uuid()') return 'gen_random_uuid()'
            return defaultValue.replace(/'/g, '')
        case 'Int':
            return parseInt(defaultValue) || 0
        case 'Float':
            return parseFloat(defaultValue) || 0.0
        case 'Boolean':
            return defaultValue === 'true'
        case 'DateTime':
            if (defaultValue === 'CURRENT_TIMESTAMP') return 'now()'
            return defaultValue
        default:
            return defaultValue
    }
}

/**
 * 下划线转驼峰
 */
function convertToCamelCase(str) {
    return str.replace(/_([a-z])/g, (match, letter) => letter.toUpperCase())
}

/**
 * 获取所有表名
 * @param {string} sqlFilePath - uctooDB.sql文件路径
 * @returns {Array} 表名列表
 */
export function getAllTables(sqlFilePath) {
    const sqlContent = fs.readFileSync(sqlFilePath, 'utf-8')
    const tableRegex = /CREATE TABLE "public"."(\w+)"/g
    const tables = []
    let match
    
    while ((match = tableRegex.exec(sqlContent)) !== null) {
        tables.push(match[1])
    }
    
    return tables
}

/**
 * 批量解析多个表
 * @param {string} sqlFilePath - uctooDB.sql文件路径（可选，使用默认路径）
 * @param {Array} tableNames - 表名列表
 * @returns {Array} 表结构列表
 */
export function parseMultipleTables(sqlFilePath, tableNames) {
    const filePath = sqlFilePath || DEFAULT_SQL_PATH
    return tableNames.map(tableName => parseTableFromSQL(filePath, tableName))
}

// 默认SQL文件路径
const DEFAULT_SQL_PATH = 'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/sql/uctooDB.sql'

/**
 * 便捷方法：解析表（使用默认路径）
 */
export function parseTable(tableName) {
    return parseTableFromSQL(DEFAULT_SQL_PATH, tableName)
}

/**
 * 便捷方法：获取所有表（使用默认路径）
 */
export function listAllTables() {
    return getAllTables(DEFAULT_SQL_PATH)
}
