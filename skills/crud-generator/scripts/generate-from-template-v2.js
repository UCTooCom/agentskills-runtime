/**
 * CRUD Generator - 模板生成脚本 (改进版 - 支持关键字检测和自动路由注册)
 * 
 * 新增功能：
 * 1. 仓颉关键字检测机制
 * 2. 自动字段重命名策略
 * 3. 局部变量命名优化
 * 4. 自动更新 AutoRouteConfig.cj
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { updateAutoRouteConfig } from './update-auto-route-config.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// ==================== 仓颉保留关键字列表 ====================
// 基于官方文档：kernel/source_zh_cn/Appendix/keyword.md
// 共70个官方关键字
const CJ_KEYWORDS = new Set([
    // 官方关键字列表（按字母排序）
    'abstract', 'as', 'Bool', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'do', 'else', 'enum',
    'extend', 'false', 'finally', 'Float16', 'Float32', 'Float64',
    'for', 'foreign', 'func', 'if', 'import', 'in',
    'init', 'Int16', 'Int32', 'Int64', 'Int8', 'IntNative',
    'interface', 'is', 'let', 'macro', 'main', 'match',
    'mut', 'Nothing', 'open', 'operator', 'override', 'package',
    'private', 'prop', 'protected', 'public', 'quote', 'redef',
    'return', 'Rune', 'spawn', 'static', 'struct', 'super',
    'synchronized', 'this', 'This', 'throw', 'true', 'try',
    'type', 'UInt16', 'UInt32', 'UInt64', 'UInt8', 'UIntNative',
    'Unit', 'unsafe', 'var', 'VArray', 'where', 'while'
])

// 字段类型映射
const TYPE_MAPPING = {
    'String': { cjType: 'String', defaultValue: '""', optional: '?String', optionalDefault: 'None<String>' },
    'Int': { cjType: 'Int32', defaultValue: '0', optional: '?Int32', optionalDefault: 'None<Int32>' },
    'Float': { cjType: 'Float64', defaultValue: '0.0', optional: '?Float64', optionalDefault: 'None<Float64>' },
    'Boolean': { cjType: 'Bool', defaultValue: 'false', optional: '?Bool', optionalDefault: 'None<Bool>' },
    'DateTime': { cjType: 'DateTime', defaultValue: 'DateTime.now()', optional: '?DateTime', optionalDefault: 'None<DateTime>' }
}

// 代码区域标识
const AUTO_CODE_START = "//#region AutoCreateCode"
const AUTO_CODE_END = "//#endregion AutoCreateCode"

// ==================== 关键字检测和处理函数 ====================

/**
 * 检查是否为仓颉保留关键字
 */
function isKeyword(name) {
    return CJ_KEYWORDS.has(name)
}

/**
 * 生成安全的字段名（避免关键字冲突）
 * 策略：如果是关键字，添加表名单数前缀
 * 例如：type → permissionType (permissions表)
 * 特殊处理：tableName → dbTableName (避免与宏生成的tableName()方法冲突)
 */
function generateSafeFieldName(dbFieldName, tableName) {
    const camelName = convertToCamelCase(dbFieldName)
    
    // 特殊处理：tableName字段会与宏生成的tableName()方法冲突
    if (camelName === 'tableName') {
        return 'dbTableName'
    }
    
    if (isKeyword(camelName)) {
        // 移除表名中的下划线并转为驼峰，然后移除复数形式
        let tablePrefix = convertToCamelCase(tableName)
        // 移除复数s：permissions → permission
        if (tablePrefix.endsWith('s') && tablePrefix.length > 1) {
            tablePrefix = tablePrefix.slice(0, -1)
        }
        // 添加表名前缀：type → permissionType
        return `${tablePrefix}${capitalizeFirst(camelName)}`
    }
    
    return camelName
}

/**
 * 生成安全的局部变量名（用于Controller的mapToEntity方法）
 * 策略：如果是关键字，添加Value后缀
 * 例如：type → typeValue
 */
function generateSafeLocalVarName(fieldName) {
    if (isKeyword(fieldName)) {
        return `${fieldName}Value`
    }
    return fieldName
}

/**
 * 处理字段列表，添加安全名称信息
 */
function processFields(fields, tableName) {
    return fields.map(field => {
        const safeName = generateSafeFieldName(field.name, tableName)
        const isRenamed = safeName !== field.camelName
        
        return {
            ...field,
            safeName: safeName,
            isRenamed: isRenamed,
            localVarName: generateSafeLocalVarName(field.camelName)
        }
    })
}

// ==================== 主生成函数 ====================

/**
 * 主生成函数
 */
export async function generateModule(config) {
    const { tableName, dbName, fields, outputDir } = config
    
    // 处理字段，添加安全名称
    const processedFields = processFields(fields, tableName)
    
    // 检测并报告关键字冲突
    const renamedFields = processedFields.filter(f => f.isRenamed)
    if (renamedFields.length > 0) {
        console.log('⚠️  检测到关键字冲突，已自动重命名字段：')
        renamedFields.forEach(f => {
            console.log(`   ${f.camelName} → ${f.safeName} (数据库列: ${f.dbName})`)
        })
        console.log()
    }
    
    // 生成命名变量
    const tableNameCamel = convertToCamelCase(tableName)
    const tableNamePascal = capitalizeFirst(tableNameCamel)
    
    console.log('='.repeat(80))
    console.log(`CRUD Generator - 生成 ${tableName} 模块`)
    console.log('='.repeat(80))
    console.log(`表名: ${tableName}`)
    console.log(`数据库: ${dbName}`)
    console.log(`输出目录: ${outputDir}`)
    console.log()
    
    // 生成各层代码
    await generateModel(tableName, tableNameCamel, tableNamePascal, dbName, processedFields, outputDir)
    await generateDAO(tableName, tableNameCamel, tableNamePascal, dbName, processedFields, outputDir)
    await generateService(tableName, tableNameCamel, tableNamePascal, dbName, processedFields, outputDir)
    await generateController(tableName, tableNameCamel, tableNamePascal, dbName, processedFields, outputDir)
    await generateRoute(tableName, tableNameCamel, tableNamePascal, dbName, processedFields, outputDir)
    
    console.log('='.repeat(80))
    console.log('✅ 所有文件生成完成！')
    console.log('='.repeat(80))
    
    // 自动更新 AutoRouteConfig.cj
    console.log()
    console.log('📝 自动更新路由配置...')
    console.log('─'.repeat(80))
    
    try {
        // 检测是否为复合主键表
        const primaryKeyFields = processedFields.filter(f => f.isPrimaryKey)
        const isCompositeKey = primaryKeyFields.length > 1
        
        updateAutoRouteConfig({
            tableName,
            tableNameCamel,
            tableNamePascal,
            dbName,
            outputDir,
            isCompositeKey
        })
        
        console.log('─'.repeat(80))
        console.log()
        console.log('✅ 路由已自动注册到 AutoRouteConfig.cj')
        console.log('   无需手动修改 AutoRouteRegistry.cj')
    } catch (e) {
        console.log('⚠️  自动更新路由配置失败:', e.message)
        console.log('   请手动在 AutoRouteConfig.cj 中添加路由配置')
    }
}

// ==================== Model生成 ====================

/**
 * 生成Model文件
 */
async function generateModel(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
    const templatePath = path.join(__dirname, '../templates/model-full.cj.tpl')
    const template = fs.readFileSync(templatePath, 'utf-8')
    
    // 生成字段定义
    const fieldsSection = generateModelFields(fields)
    
    // 生成构造函数参数
    const constructorParams = generateConstructorParams(fields)
    
    // 生成构造函数赋值
    const constructorAssignments = generateConstructorAssignments(fields)
    
    // 生成toJson方法
    const toJsonFields = generateToJsonFields(fields)
    
    // 替换模板变量
    let content = template
        .replace(/{DATABASE_NAME}/g, dbName)
        .replace(/{TABLE_NAME}/g, tableName)
        .replace(/{TABLE_NAME_CAMEL}/g, tableNameCamel)
        .replace(/{TABLE_NAME_PASCAL}/g, tableNamePascal)
        .replace(/{FIELDS_SECTION}/g, fieldsSection)
        .replace(/{CONSTRUCTOR_PARAMS}/g, constructorParams)
        .replace(/{CONSTRUCTOR_ASSIGNMENTS}/g, constructorAssignments)
        .replace(/{TO_JSON_FIELDS}/g, toJsonFields)
    
    // 写入文件
    const outputPath = path.join(outputDir, 'models', dbName, `${tableNamePascal}PO.cj`)
    writeFileSync(outputPath, content, 'Model')
}

/**
 * 生成Model字段定义（使用安全字段名）
 */
function generateModelFields(fields) {
    return fields.map(f => {
        const type = TYPE_MAPPING[f.type]
        const annotation = f.isPrimaryKey 
            ? `    @ORMField[true '${f.dbName}']` 
            : `    @ORMField['${f.dbName}']`
        
        // 使用安全字段名
        const fieldName = f.safeName
        
        // 对于非主键的数值字段，使用Option包装
        let fieldType, defaultValue
        if (!f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')) {
            fieldType = type.optional
            defaultValue = type.optionalDefault
        } else {
            fieldType = f.isOptional ? type.optional : type.cjType
            defaultValue = f.isOptional ? type.optionalDefault : type.defaultValue
        }
        
        // 如果字段被重命名，添加注释说明
        const comment = f.isRenamed ? `    // 注意: 数据库列名 '${f.dbName}' 是关键字，已重命名为 '${fieldName}'\n` : ''
        
        return `${comment}${annotation}\n    public var ${fieldName}: ${fieldType} = ${defaultValue}`
    }).join('\n\n    ')
}

/**
 * 生成构造函数参数（使用安全字段名）
 */
function generateConstructorParams(fields) {
    return fields.map(f => {
        const type = TYPE_MAPPING[f.type]
        const fieldName = f.safeName
        
        // 对于非主键的数值字段，使用Option包装
        let fieldType
        if (!f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')) {
            fieldType = type.optional
        } else {
            fieldType = f.isOptional ? type.optional : type.cjType
        }
        return `        ${fieldName}: ${fieldType}`
    }).join(',\n')
}

/**
 * 生成构造函数赋值（使用安全字段名）
 */
function generateConstructorAssignments(fields) {
    return fields.map(f => {
        const fieldName = f.safeName
        return `        this.${fieldName} = ${fieldName}`
    }).join('\n')
}

/**
 * 生成toJson字段序列化（使用安全字段名）
 */
function generateToJsonFields(fields) {
    const parts = []
    
    for (let i = 0; i < fields.length; i++) {
        const f = fields[i]
        const isLast = i === fields.length - 1
        const fieldName = f.safeName
        
        if (f.isOptional) {
            const comma = isLast ? '' : ','
            // 判断是否为数值类型（Int 或 Float）
            if (f.type === 'Int' || f.type === 'Float') {
                // 数值类型的 Optional 字段：输出 null 或数值
                parts.push('        if (let Some(v) <- ' + fieldName + ') {\n' +
                           '            sb.append("\\"' + f.dbName + '\\":${v}' + comma + '")\n' +
                           '        } else {\n' +
                           '            sb.append("\\"' + f.dbName + '\\":null' + comma + '")\n' +
                           '        }')
            } else {
                // 字符串类型的 Optional 字段：输出空字符串或字符串
                parts.push('        if (let Some(v) <- ' + fieldName + ') {\n' +
                           '            sb.append("\\"' + f.dbName + '\\":\\"${v}\\"' + comma + '")\n' +
                           '        } else {\n' +
                           '            sb.append("\\"' + f.dbName + '\\":\\"\\"' + comma + '")\n' +
                           '        }')
            }
        } else {
            const comma = isLast ? '' : ','
            if (f.type === 'Int' || f.type === 'Float') {
                parts.push('        sb.append("\\"' + f.dbName + '\\":${' + fieldName + '}' + comma + '")')
            } else {
                parts.push('        sb.append("\\"' + f.dbName + '\\":\\"${' + fieldName + '}\\"' + comma + '")')
            }
        }
    }
    
    return parts.join('\n')
}

// ==================== DAO生成 ====================

/**
 * 生成DAO文件
 */
async function generateDAO(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
    const templatePath = path.join(__dirname, '../templates/dao-full.cj.tpl')
    const template = fs.readFileSync(templatePath, 'utf-8')
    
    // 生成INSERT字段列表
    const insertFields = generateInsertFields(fields)
    
    // 生成INSERT值列表（使用安全字段名）
    const insertValues = generateInsertValues(fields)
    
    // 生成UPDATE SET部分（使用安全字段名）
    const updateSets = generateUpdateSets(fields)
    
    // 替换模板变量
    let content = template
        .replace(/{DATABASE_NAME}/g, dbName)
        .replace(/{TABLE_NAME}/g, tableName)
        .replace(/{TABLE_NAME_CAMEL}/g, tableNameCamel)
        .replace(/{TABLE_NAME_PASCAL}/g, tableNamePascal)
        .replace(/{INSERT_FIELDS}/g, insertFields)
        .replace(/{INSERT_VALUES}/g, insertValues)
        .replace(/{UPDATE_SETS}/g, updateSets)
    
    // 写入文件
    const outputPath = path.join(outputDir, 'dao', dbName, `${tableNamePascal}DAO.cj`)
    writeFileSync(outputPath, content, 'DAO')
}

/**
 * 生成INSERT字段列表
 */
function generateInsertFields(fields) {
    const nonIdFields = fields.filter(f => f.name !== 'id')
    return nonIdFields.map(f => f.dbName).join(',\n                ')
}

/**
 * 生成INSERT值列表（使用安全字段名）
 */
function generateInsertValues(fields) {
    const nonIdFields = fields.filter(f => f.name !== 'id')
    return nonIdFields.map(f => '${arg(entity.' + f.safeName + ')}').join(',\n                ')
}

/**
 * 生成UPDATE SET部分（使用安全字段名）
 */
function generateUpdateSets(fields) {
    const updateFields = fields.filter(f => 
        !f.isPrimaryKey && 
        f.name !== 'id' && 
        f.name !== 'created_at' && 
        f.name !== 'creator' &&
        f.name !== 'updated_at'
    )
    
    return updateFields.map(f => 
        f.dbName + ' = ${arg(entity.' + f.safeName + ')}'
    ).join(',\n                ')
}

// ==================== Service生成 ====================

/**
 * 生成Service文件
 */
async function generateService(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
    const templatePath = path.join(__dirname, '../templates/service-full.cj.tpl')
    const template = fs.readFileSync(templatePath, 'utf-8')
    
    // 生成字段合并逻辑（使用安全字段名）
    const mergeFieldsLogic = generateMergeFieldsLogic(fields, tableNamePascal)
    
    // 替换模板变量
    let content = template
        .replace(/{DATABASE_NAME}/g, dbName)
        .replace(/{TABLE_NAME}/g, tableName)
        .replace(/{TABLE_NAME_CAMEL}/g, tableNameCamel)
        .replace(/{TABLE_NAME_PASCAL}/g, tableNamePascal)
        .replace(/{MERGE_FIELDS_LOGIC}/g, mergeFieldsLogic)
    
    // 写入文件
    const outputPath = path.join(outputDir, 'services', dbName, `${tableNamePascal}Service.cj`)
    writeFileSync(outputPath, content, 'Service')
}

/**
 * 生成字段合并逻辑（用于update方法，使用安全字段名）
 */
function generateMergeFieldsLogic(fields, entityName) {
    const mergeStatements = []
    
    for (const f of fields) {
        if (f.name === 'id' || f.name === 'created_at' || f.name === 'updated_at') {
            continue
        }
        
        const type = TYPE_MAPPING[f.type]
        const fieldName = f.safeName
        
        const isOptionNumber = !f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')
        
        if (f.isOptional || isOptionNumber) {
            mergeStatements.push(`            if (entity.${fieldName}.isSome()) {
                existingEntity.${fieldName} = entity.${fieldName}
            }`)
        } else {
            if (f.type === 'String') {
                mergeStatements.push(`            if (entity.${fieldName}.size > 0) {
                existingEntity.${fieldName} = entity.${fieldName}
            }`)
            } else if (f.type === 'Bool') {
                mergeStatements.push(`            existingEntity.${fieldName} = entity.${fieldName}`)
            }
        }
    }
    
    return mergeStatements.join('\n')
}

// ==================== Controller生成 ====================

/**
 * 生成Controller文件
 */
async function generateController(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
    const templatePath = path.join(__dirname, '../templates/controller-full.cj.tpl')
    const template = fs.readFileSync(templatePath, 'utf-8')
    
    // 生成mapToEntity方法（使用安全字段名和局部变量名）
    const mapToEntityMethod = generateMapToEntityMethod(fields, tableNamePascal)
    
    // 替换模板变量
    let content = template
        .replace(/{DATABASE_NAME}/g, dbName)
        .replace(/{TABLE_NAME}/g, tableName)
        .replace(/{TABLE_NAME_CAMEL}/g, tableNameCamel)
        .replace(/{TABLE_NAME_PASCAL}/g, tableNamePascal)
        .replace(/{MAP_TO_ENTITY_METHOD}/g, mapToEntityMethod)
    
    // 写入文件
    const outputPath = path.join(outputDir, 'controllers', dbName, tableName, `${tableNamePascal}Controller.cj`)
    writeFileSync(outputPath, content, 'Controller')
}

/**
 * 生成mapToEntity方法（使用安全字段名和局部变量名）
 */
function generateMapToEntityMethod(fields, entityName) {
    const mappings = fields.map(f => {
        if (f.type === 'DateTime') {
            return `        // ${f.safeName} is DateTime type, handled by database`
        }
        
        const type = TYPE_MAPPING[f.type]
        const castType = f.type === 'Int' ? 'Int32' : (f.type === 'Float' ? 'Float64' : type.cjType)
        const fieldName = f.safeName
        const localVarName = f.localVarName
        
        const isOptionNumber = !f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')
        
        if (f.isOptional || isOptionNumber) {
            if (castType === 'String') {
                return `        if (let Some(${localVarName}) <- map.get("${f.dbName}")) {
            let ${localVarName}Str = ${localVarName} as String
            if (let Some(s) <- ${localVarName}Str) {
                entity.${fieldName} = Some<String>(s)
            }
        }`
            } else if (castType === 'Int32') {
                return `        if (let Some(${localVarName}) <- map.get("${f.dbName}")) {
            let ${localVarName}Int64 = ${localVarName} as Int64
            if (let Some(s) <- ${localVarName}Int64) {
                entity.${fieldName} = Some<Int32>(Int32(s))
            }
        }`
            } else if (castType === 'Float64') {
                return `        if (let Some(${localVarName}) <- map.get("${f.dbName}")) {
            let ${localVarName}Float64 = ${localVarName} as Float64
            if (let Some(s) <- ${localVarName}Float64) {
                entity.${fieldName} = Some<Float64>(s)
            }
        }`
            } else {
                return `        if (let Some(${localVarName}) <- map.get("${f.dbName}")) {
            let ${localVarName}${castType} = ${localVarName} as ${castType}
            if (let Some(s) <- ${localVarName}${castType}) {
                entity.${fieldName} = Some<${type.cjType}>(s)
            }
        }`
            }
        } else {
            if (castType === 'Int32') {
                return `        if (let Some(${localVarName}) <- map.get("${f.dbName}")) {
            let ${localVarName}Int64 = ${localVarName} as Int64
            if (let Some(s) <- ${localVarName}Int64) {
                entity.${fieldName} = Int32(s)
            }
        }`
            } else {
                return `        if (let Some(${localVarName}) <- map.get("${f.dbName}")) {
            let ${localVarName}${castType === 'String' ? 'Str' : castType} = ${localVarName} as ${castType}
            if (let Some(s) <- ${localVarName}${castType === 'String' ? 'Str' : castType}) {
                entity.${fieldName} = s
            }
        }`
            }
        }
    }).join('\n')
    
    return `private func mapToEntity(map: Map<String, Any>): ${entityName}PO {
        let entity = ${entityName}PO()
        ${mappings}
        return entity
    }`
}

// ==================== Route生成 ====================

/**
 * 生成Route文件
 */
async function generateRoute(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
    const templatePath = path.join(__dirname, '../templates/route-full.cj.tpl')
    const template = fs.readFileSync(templatePath, 'utf-8')
    
    // 替换模板变量
    let content = template
        .replace(/{DATABASE_NAME}/g, dbName)
        .replace(/{TABLE_NAME}/g, tableName)
        .replace(/{TABLE_NAME_CAMEL}/g, tableNameCamel)
        .replace(/{TABLE_NAME_PASCAL}/g, tableNamePascal)
    
    // 写入文件
    const outputPath = path.join(outputDir, 'routes', dbName, tableName, `${tableNamePascal}Route.cj`)
    writeFileSync(outputPath, content, 'Route')
}

// ==================== 工具函数 ====================

/**
 * 转换为驼峰命名
 */
function convertToCamelCase(str) {
    return str.toLowerCase().replace(/_(.)/g, (match, group1) => {
        return group1.toUpperCase()
    })
}

/**
 * 首字母大写
 */
function capitalizeFirst(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
}

/**
 * 写入文件（处理区域标识）
 */
function writeFileSync(filePath, content, fileType) {
    // 确保目录存在
    const dir = path.dirname(filePath)
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true })
    }
    
    // 检查文件是否存在
    if (fs.existsSync(filePath)) {
        const existingContent = fs.readFileSync(filePath, 'utf-8')
        
        // 检查是否有头部自定义引入区域
        const customImportStart = "// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）=========="
        const customImportEnd = "// ========== 自动生成代码区域（以下代码会被自动生成覆盖）=========="
        
        const customImportStartIdx = existingContent.indexOf(customImportStart)
        const customImportEndIdx = existingContent.indexOf(customImportEnd)
        
        // 检查是否有自动生成代码区域标识
        const autoCodeStartIdx = existingContent.indexOf(AUTO_CODE_START)
        const autoCodeEndIdx = existingContent.indexOf(AUTO_CODE_END)
        
        // 从模板中提取各个区域
        const tplCustomImportEndIdx = content.indexOf(customImportEnd)
        const tplAutoCodeStartIdx = content.indexOf(AUTO_CODE_START)
        const tplAutoCodeEndIdx = content.indexOf(AUTO_CODE_END)
        
        if (customImportStartIdx > -1 && customImportEndIdx > customImportStartIdx) {
            // 文件有自定义引入区域标识
            
            // 1. 保留文件头（版权声明、package等）
            const beforeCustomImport = existingContent.slice(0, customImportStartIdx)
            
            // 2. 保留自定义引入区域
            const customImportSection = existingContent.slice(customImportStartIdx, customImportEndIdx + customImportEnd.length)
            
            // 3. 从模板提取类声明（在customImportEnd和AutoCreateCode之间）
            const tplClassDeclaration = content.slice(tplCustomImportEndIdx + customImportEnd.length, tplAutoCodeStartIdx)
            
            if (autoCodeStartIdx > -1 && autoCodeEndIdx > autoCodeStartIdx) {
                // 文件有AutoCreateCode区域标识，保留尾部定制代码
                const afterAutoCode = existingContent.slice(autoCodeEndIdx)
                
                // 从模板提取自动生成代码区域
                const tplAutoCodeSection = content.slice(tplAutoCodeStartIdx, tplAutoCodeEndIdx)
                
                content = `${beforeCustomImport}${customImportSection}\n${tplClassDeclaration}${tplAutoCodeSection}${afterAutoCode}`
            } else {
                // 文件没有AutoCreateCode区域标识，使用模板的完整内容
                const tplAutoCodeSection = content.slice(tplAutoCodeStartIdx, tplAutoCodeEndIdx)
                const tplAfterAutoCode = content.slice(tplAutoCodeEndIdx)
                
                content = `${beforeCustomImport}${customImportSection}\n${tplClassDeclaration}${tplAutoCodeSection}${tplAfterAutoCode}`
            }
        } else if (autoCodeStartIdx > -1 && autoCodeEndIdx > autoCodeStartIdx) {
            // 文件没有自定义引入区域，但有AutoCreateCode区域标识
            const headStr = existingContent.slice(0, autoCodeStartIdx)
            const footStr = existingContent.slice(autoCodeEndIdx)
            
            const middleStr = content.slice(tplAutoCodeStartIdx, tplAutoCodeEndIdx)
            
            content = `${headStr}${middleStr}${footStr}`
        }
        // 如果文件既没有自定义引入区域，也没有AutoCreateCode区域，直接使用模板内容
    }
    
    fs.writeFileSync(filePath, content)
    console.log(`✅ Generated ${fileType}: ${path.basename(filePath)}`)
}
