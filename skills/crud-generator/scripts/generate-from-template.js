/**
 * CRUD Generator - 模板生成脚本 (JavaScript版本)
 * 
 * 参考batchCreateModuleFromDb.ts实现，采用模板替换方式生成完整代码
 * 确保生成的代码与entity标准模块完全一致
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

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

/**
 * 主生成函数
 */
export async function generateModule(config) {
  const { tableName, dbName, fields, outputDir } = config
  
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
  await generateModel(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir)
  await generateDAO(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir)
  await generateService(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir)
  await generateController(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir)
  await generateRoute(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir)
  
  console.log('='.repeat(80))
  console.log('✅ 所有文件生成完成！')
  console.log('='.repeat(80))
}

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
 * 生成DAO文件
 */
async function generateDAO(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
  const templatePath = path.join(__dirname, '../templates/dao-full.cj.tpl')
  const template = fs.readFileSync(templatePath, 'utf-8')
  
  // 生成INSERT字段列表
  const insertFields = generateInsertFields(fields)
  
  // 生成INSERT值列表
  const insertValues = generateInsertValues(fields)
  
  // 生成UPDATE SET部分
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
 * 生成Service文件
 */
async function generateService(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
  const templatePath = path.join(__dirname, '../templates/service-full.cj.tpl')
  const template = fs.readFileSync(templatePath, 'utf-8')
  
  // 生成字段合并逻辑
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
 * 生成Controller文件
 */
async function generateController(tableName, tableNameCamel, tableNamePascal, dbName, fields, outputDir) {
  const templatePath = path.join(__dirname, '../templates/controller-full.cj.tpl')
  const template = fs.readFileSync(templatePath, 'utf-8')
  
  // 生成mapToEntity方法
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

// ==================== 字段生成辅助函数 ====================

/**
 * 生成字段合并逻辑（用于update方法）
 * 只更新entity中非默认值的字段
 */
function generateMergeFieldsLogic(fields, entityName) {
  const mergeStatements = []
  
  for (const f of fields) {
    // 跳过id、created_at、updated_at字段
    if (f.name === 'id' || f.name === 'created_at' || f.name === 'updated_at') {
      continue
    }
    
    const type = TYPE_MAPPING[f.type]
    const camelName = f.camelName
    
    // 判断是否为Option包装的数值字段
    const isOptionNumber = !f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')
    
    if (f.isOptional || isOptionNumber) {
      // Option类型：检查是否为Some
      mergeStatements.push(`            if (entity.${camelName}.isSome()) {
                existingEntity.${camelName} = entity.${camelName}
            }`)
    } else {
      // 非Option类型：检查是否为非默认值
      if (f.type === 'String') {
        // 字符串类型：检查是否不为空字符串
        mergeStatements.push(`            if (entity.${camelName}.size > 0) {
                existingEntity.${camelName} = entity.${camelName}
            }`)
      } else if (f.type === 'Bool') {
        // 布尔类型：直接更新（布尔值没有"未设置"的概念）
        mergeStatements.push(`            existingEntity.${camelName} = entity.${camelName}`)
      }
    }
  }
  
  return mergeStatements.join('\n')
}

/**
 * 生成Model字段定义
 */
function generateModelFields(fields) {
  return fields.map(f => {
    const type = TYPE_MAPPING[f.type]
    const annotation = f.isPrimaryKey 
      ? `    @ORMField[true '${f.dbName}']` 
      : `    @ORMField['${f.dbName}']`
    
    // 对于非主键的数值字段，使用Option包装（用于区分"未传递"和"传递了0"）
    let fieldType, defaultValue
    if (!f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')) {
      fieldType = type.optional
      defaultValue = type.optionalDefault
    } else {
      fieldType = f.isOptional ? type.optional : type.cjType
      defaultValue = f.isOptional ? type.optionalDefault : type.defaultValue
    }
    
    return `${annotation}\n    private var ${f.camelName}: ${fieldType} = ${defaultValue}`
  }).join('\n\n    ')
}

/**
 * 生成构造函数参数
 */
function generateConstructorParams(fields) {
  return fields.map(f => {
    const type = TYPE_MAPPING[f.type]
    // 对于非主键的数值字段，使用Option包装
    let fieldType
    if (!f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')) {
      fieldType = type.optional
    } else {
      fieldType = f.isOptional ? type.optional : type.cjType
    }
    return `        ${f.camelName}: ${fieldType}`
  }).join(',\n')
}

/**
 * 生成构造函数赋值
 */
function generateConstructorAssignments(fields) {
  return fields.map(f => {
    return `        this.${f.camelName} = ${f.camelName}`
  }).join('\n')
}

/**
 * 生成toJson字段序列化
 * 注意：这里需要特殊处理Cangjie的字符串插值
 */
function generateToJsonFields(fields) {
  const parts = []
  
  for (let i = 0; i < fields.length; i++) {
    const f = fields[i]
    const isLast = i === fields.length - 1
    
    if (f.isOptional) {
      const comma = isLast ? '' : ','
      // 对于可选字段，生成if-else语句
      parts.push('        if (let Some(v) <- ' + f.camelName + ') {\n' +
                 '            sb.append("\\"' + f.dbName + '\\":\\"${v}\\"' + comma + '")\n' +
                 '        } else {\n' +
                 '            sb.append("\\"' + f.dbName + '\\":\\"\\"' + comma + '")\n' +
                 '        }')
    } else {
      const comma = isLast ? '' : ','
      if (f.type === 'Int' || f.type === 'Float') {
        // 数值类型不需要引号
        parts.push('        sb.append("\\"' + f.dbName + '\\":${' + f.camelName + '}' + comma + '")')
      } else {
        // 字符串和DateTime类型需要引号
        parts.push('        sb.append("\\"' + f.dbName + '\\":\\"${' + f.camelName + '}\\"' + comma + '")')
      }
    }
  }
  
  return parts.join('\n')
}

/**
 * 生成INSERT字段列表
 */
function generateInsertFields(fields) {
  const nonIdFields = fields.filter(f => f.name !== 'id')
  return nonIdFields.map(f => f.dbName).join(',\n                ')
}

/**
 * 生成INSERT值列表
 */
function generateInsertValues(fields) {
  const nonIdFields = fields.filter(f => f.name !== 'id')
  return nonIdFields.map(f => '${arg(entity.' + f.camelName + ')}').join(',\n                ')
}

/**
 * 生成UPDATE SET部分
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
    f.dbName + ' = ${arg(entity.' + f.camelName + ')}'
  ).join(',\n                ')
}

/**
 * 生成mapToEntity方法
 */
function generateMapToEntityMethod(fields, entityName) {
  const mappings = fields.map(f => {
    if (f.type === 'DateTime') {
      return `        // ${f.camelName} is DateTime type, handled by database`
    }
    
    const type = TYPE_MAPPING[f.type]
    const castType = f.type === 'Int' ? 'Int32' : (f.type === 'Float' ? 'Float64' : type.cjType)
    
    // 判断是否为Option包装的数值字段
    const isOptionNumber = !f.isPrimaryKey && !f.isOptional && (f.type === 'Int' || f.type === 'Float')
    
    if (f.isOptional || isOptionNumber) {
      if (castType === 'String') {
        // 对于Option<String>类型，保留空字符串（可以清空字段）
        return `        if (let Some(${f.camelName}) <- map.get("${f.dbName}")) {\n            let ${f.camelName}Str = ${f.camelName} as String\n            if (let Some(s) <- ${f.camelName}Str) {\n                entity.${f.camelName} = Some<String>(s)\n            }\n        }`
      } else if (castType === 'Int32') {
        // Option<Int32>：jsonValueToAny返回Int64，需要先转Int64再转Int32
        return `        if (let Some(${f.camelName}) <- map.get("${f.dbName}")) {\n            let ${f.camelName}Int64 = ${f.camelName} as Int64\n            if (let Some(s) <- ${f.camelName}Int64) {\n                entity.${f.camelName} = Some<Int32>(Int32(s))\n            }\n        }`
      } else if (castType === 'Float64') {
        // Option<Float64>
        return `        if (let Some(${f.camelName}) <- map.get("${f.dbName}")) {\n            let ${f.camelName}Float64 = ${f.camelName} as Float64\n            if (let Some(s) <- ${f.camelName}Float64) {\n                entity.${f.camelName} = Some<Float64>(s)\n            }\n        }`
      } else {
        return `        if (let Some(${f.camelName}) <- map.get("${f.dbName}")) {\n            let ${f.camelName}${castType} = ${f.camelName} as ${castType}\n            if (let Some(s) <- ${f.camelName}${castType}) {\n                entity.${f.camelName} = Some<${type.cjType}>(s)\n            }\n        }`
      }
    } else {
      if (castType === 'Int32') {
        // jsonValueToAny返回Int64，需要先转Int64再转Int32
        return `        if (let Some(${f.camelName}) <- map.get("${f.dbName}")) {\n            let ${f.camelName}Int64 = ${f.camelName} as Int64\n            if (let Some(s) <- ${f.camelName}Int64) {\n                entity.${f.camelName} = Int32(s)\n            }\n        }`
      } else {
        return `        if (let Some(${f.camelName}) <- map.get("${f.dbName}")) {\n            let ${f.camelName}${castType === 'String' ? 'Str' : castType} = ${f.camelName} as ${castType}\n            if (let Some(s) <- ${f.camelName}${castType === 'String' ? 'Str' : castType}) {\n                entity.${f.camelName} = s\n            }\n        }`
      }
    }
  }).join('\n')
  
  return `private func mapToEntity(map: Map<String, Any>): ${entityName}PO {\n        let entity = ${entityName}PO()\n        ${mappings}\n        return entity\n    }`
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
    
    if (customImportStartIdx > -1 && customImportEndIdx > customImportStartIdx) {
      // 保留头部自定义引入区域
      const beforeCustomImport = existingContent.slice(0, customImportStartIdx)
      const customImportSection = existingContent.slice(customImportStartIdx, customImportEndIdx + customImportEnd.length)
      
      // 从模板中提取自动生成代码区域
      const tplCustomImportEndIdx = content.indexOf(customImportEnd)
      const tplAfterCustomImport = content.slice(tplCustomImportEndIdx + customImportEnd.length)
      
      if (autoCodeStartIdx > -1 && autoCodeEndIdx > autoCodeStartIdx) {
        // 同时保留尾部定制代码
        const afterAutoCode = existingContent.slice(autoCodeEndIdx)
        
        const tplAutoCodeStartIdx = tplAfterCustomImport.indexOf(AUTO_CODE_START)
        const tplAutoCodeEndIdx = tplAfterCustomImport.indexOf(AUTO_CODE_END)
        const tplAutoCodeSection = tplAfterCustomImport.slice(tplAutoCodeStartIdx, tplAutoCodeEndIdx)
        
        content = `${beforeCustomImport}${customImportSection}\n${tplAutoCodeSection}${afterAutoCode}`
      } else {
        content = `${beforeCustomImport}${customImportSection}\n${tplAfterCustomImport}`
      }
    } else if (autoCodeStartIdx > -1 && autoCodeEndIdx > autoCodeStartIdx) {
      // 只保留尾部定制代码
      const headStr = existingContent.slice(0, autoCodeStartIdx)
      const footStr = existingContent.slice(autoCodeEndIdx)
      
      const tplStartIdx = content.indexOf(AUTO_CODE_START)
      const tplEndIdx = content.indexOf(AUTO_CODE_END)
      const middleStr = content.slice(tplStartIdx, tplEndIdx)
      
      content = `${headStr}${middleStr}${footStr}`
    }
  }
  
  fs.writeFileSync(filePath, content)
  console.log(`✅ Generated ${fileType}: ${path.basename(filePath)}`)
}
