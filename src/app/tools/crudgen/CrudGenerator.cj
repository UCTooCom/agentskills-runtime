package magic.app.tools.crudgen

import std.collection.*
import std.fs.*
import std.time.DateTime
import std.convert
import f_orm.*
import magic.app.services.uctoo.DbInfoService
import magic.app.models.uctoo.DbInfoPO

/**
 * 表字段信息
 */
public class FieldInfo {
    public var columnName: String = ""
    public var dataType: String = ""
    public var isNullable: String = ""
    public var columnDefault: ?String = None<String>
    public var ordinalPosition: Int32 = 0
    
    public init() {}
}

/**
 * 表信息
 */
public class TableInfo {
    public var tableName: String = ""
    public var dbName: String = ""
    public var className: String = ""  // 帕斯卡命名
    public var fields: ArrayList<FieldInfo> = ArrayList<FieldInfo>()
    
    public init() {}
}

/**
 * CRUD代码生成器 - 基于模板复制方案
 * 
 * 核心思路:
 * 1. 从标准CRUD模块代码复制模板
 * 2. 只替换表名、类名等关键变量
 * 3. 确保生成的代码与标准代码格式完全一致
 */
public class CrudGenerator {
    private var outputDir: String = "./src/app"
    private var dbInfoService: DbInfoService
    private var templateEngine: TemplateEngine
    
    public init() {
        this.outputDir = "./src/app"
        this.dbInfoService = DbInfoService()
        this.templateEngine = TemplateEngine()
    }
    
    public init(outputDir: String) {
        this.outputDir = outputDir
        this.dbInfoService = DbInfoService()
        this.templateEngine = TemplateEngine()
    }
    
    /**
     * 从数据库读取表结构信息
     */
    public func readTableInfo(dbName: String, tableName: String): TableInfo {
        let tableInfo = TableInfo()
        tableInfo.tableName = tableName
        tableInfo.dbName = dbName
        tableInfo.className = toPascalCase(tableName)
        
        // 直接使用ORM查询db_info表
        let executor = ORM.executor()
        let sql = """
            SELECT *
            FROM db_info
            WHERE table_catalog = '${dbName}' AND table_name = '${tableName}'
            ORDER BY ordinal_position
        """
        
        let results = executor.setSql(sql).list<DbInfoPO>()
        
        // 将DbInfoPO转换为FieldInfo
        for (dbInfo in results) {
            let field = FieldInfo()
            field.columnName = dbInfo.columnName
            field.dataType = dbInfo.dataType ?? ""
            field.isNullable = dbInfo.isNullable
            field.columnDefault = dbInfo.columnDefault
            field.ordinalPosition = dbInfo.ordinalPosition ?? 0
            tableInfo.fields.add(field)
        }
        
        return tableInfo
    }
    
    /**
     * 读取数据库中所有表名
     */
    public func readAllTables(dbName: String): ArrayList<String> {
        let tables = ArrayList<String>()
        
        // 直接使用ORM查询db_info表
        let executor = ORM.executor()
        let sql = """
            SELECT DISTINCT table_name
            FROM db_info
            WHERE table_catalog = '${dbName}'
            ORDER BY table_name
        """
        
        let results = executor.setSql(sql).list<DbInfoPO>()
        
        for (dbInfo in results) {
            tables.add(dbInfo.dbTableName)
        }
        
        return tables
    }
    
    /**
     * 生成所有层的代码
     */
    public func generateAllLayers(tableInfo: TableInfo): Unit {
        generateModel(tableInfo)
        generateDAO(tableInfo)
        generateService(tableInfo)
        generateController(tableInfo)
        generateRoute(tableInfo)
    }
    
    /**
     * 生成Model层代码
     */
    public func generateModel(tableInfo: TableInfo): Unit {
        let code = buildModelCode(tableInfo)
        let outputPath = "${outputDir}/models/${tableInfo.dbName}/${tableInfo.className}PO.cj"
        templateEngine.updateFile(outputPath, code)
    }
    
    /**
     * 生成DAO层代码
     */
    public func generateDAO(tableInfo: TableInfo): Unit {
        let code = buildDAOCode(tableInfo)
        let outputPath = "${outputDir}/dao/${tableInfo.dbName}/${tableInfo.className}DAO.cj"
        templateEngine.updateFile(outputPath, code)
    }
    
    /**
     * 生成Service层代码
     */
    public func generateService(tableInfo: TableInfo): Unit {
        let code = buildServiceCode(tableInfo)
        let outputPath = "${outputDir}/services/${tableInfo.dbName}/${tableInfo.className}Service.cj"
        templateEngine.updateFile(outputPath, code)
    }
    
    /**
     * 生成Controller层代码
     */
    public func generateController(tableInfo: TableInfo): Unit {
        let code = buildControllerCode(tableInfo)
        let outputPath = "${outputDir}/controllers/${tableInfo.dbName}/${tableInfo.tableName}/${tableInfo.className}Controller.cj"
        templateEngine.updateFile(outputPath, code)
    }
    
    /**
     * 生成Route层代码
     */
    public func generateRoute(tableInfo: TableInfo): Unit {
        let code = buildRouteCode(tableInfo)
        let outputPath = "${outputDir}/routes/${tableInfo.dbName}/${tableInfo.tableName}/${tableInfo.className}Route.cj"
        templateEngine.updateFile(outputPath, code)
    }
    
    /**
     * 构建Model层代码
     */
    private func buildModelCode(tableInfo: TableInfo): String {
        let sb = StringBuilder()
        
        // 版权声明和package
        sb.append("/*\n")
        sb.append(" * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.\n")
        sb.append(" */\n")
        sb.append("package magic.app.models.${tableInfo.dbName}\n\n")
        sb.append("//#region AutoCreateCode\n\n")
        
        // Import语句
        sb.append("import std.time.DateTime\n")
        sb.append("import f_orm.macros.{QueryMappersGenerator, ORMField}\n")
        sb.append("import f_data.macros.DataAssist\n")
        sb.append("import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}\n")
        sb.append("import f_orm.*\n")
        sb.append("import json4cj.JsonValueSerializable\n")
        sb.append("import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}\n\n")
        
        // 类注释
        sb.append("/**\n")
        sb.append(" * ${tableInfo.className}PO - ${tableInfo.tableName}表持久化对象\n")
        sb.append(" * \n")
        sb.append(" * 对应数据库表: ${tableInfo.tableName}\n")
        sb.append(" * 遵循UCTOO V4 ORM规范\n")
        sb.append(" */\n")
        
        // 类定义
        sb.append("@DataAssist[fields]\n")
        sb.append("@QueryMappersGenerator[\"${tableInfo.tableName}\"]\n")
        sb.append("public class ${tableInfo.className}PO {\n")
        
        // 字段定义
        for (field in tableInfo.fields) {
            let fieldName = toCamelCase(field.columnName)
            let cjType = mapDataType(field.dataType, field.isNullable)
            let defaultValue = getDefaultValue(field.dataType, field.isNullable)
            
            sb.append("        @ORMField['${field.columnName}']\n")
            sb.append("    public var ${fieldName}: ${cjType} = ${defaultValue}\n\n")
        }
        
        // 无参构造函数
        sb.append("    public init() {}\n\n")
        
        // 全参构造函数
        sb.append("    public init(\n")
        var first = true
        for (field in tableInfo.fields) {
            let fieldName = toCamelCase(field.columnName)
            let cjType = mapDataType(field.dataType, field.isNullable)
            
            if (!first) {
                sb.append(",\n")
            }
            sb.append("                ${fieldName}: ${cjType}")
            first = false
        }
        sb.append("\n    ) {\n")
        
        for (field in tableInfo.fields) {
            let fieldName = toCamelCase(field.columnName)
            sb.append("                this.${fieldName} = ${fieldName}\n")
        }
        sb.append("    }\n\n")
        
        // toJsonValue方法
        sb.append("    /// 序列化为 JsonValue\n")
        sb.append("    public func toJsonValue(): JsonValue {\n")
        sb.append("        var map = HashMap<String, JsonValue>()\n")
        
        for (field in tableInfo.fields) {
            let fieldName = toCamelCase(field.columnName)
            let cjType = mapDataType(field.dataType, field.isNullable)
            
            if (cjType.startsWith("Option<")) {
                sb.append("        map.add(\"${field.columnName}\", optionToJsonValue(this.${fieldName}))\n")
            } else {
                sb.append("        map.add(\"${field.columnName}\", this.${fieldName}.toJsonValue())\n")
            }
        }
        
        sb.append("        return JsonObject(map)\n")
        sb.append("    }\n\n")
        
        // optionToJsonValue方法
        sb.append("    /// 辅助方法：将 Option<T> 转换为 JsonValue\n")
        sb.append("    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {\n")
        sb.append("        if (let Some(v) <- opt) {\n")
        sb.append("            return v.toJsonValue()\n")
        sb.append("        } else {\n")
        sb.append("            return JsonNull()\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
        
        // toJson方法
        sb.append("    /// 序列化为 JSON 字符串\n")
        sb.append("    public func toJson(): String {\n")
        sb.append("        return this.toJsonValue().toString()\n")
        sb.append("    }\n\n")
        
        sb.append("//#endregion AutoCreateCode\n")
        sb.append("}\n")
        
        return sb.toString()
    }
    
    /**
     * 构建DAO层代码
     */
    private func buildDAOCode(tableInfo: TableInfo): String {
        let variables = HashMap<String, String>()
        variables.add("dbName", tableInfo.dbName)
        variables.add("tableName", tableInfo.tableName)
        variables.add("className", tableInfo.className)
        variables.add("insertColumns", buildInsertColumns(tableInfo))
        variables.add("insertValues", buildInsertValues(tableInfo))
        variables.add("updateSets", buildUpdateSets(tableInfo))

        let templatePath = "./src/app/tools/crudgen/templates/DAO.cj.tpl"
        let template = loadTemplateContent(templatePath)

        replaceVariablesInTemplate(template, variables)
    }

    /**
     * 构建插入列
     */
    private func buildInsertColumns(tableInfo: TableInfo): String {
        let sb = StringBuilder()
        var first = true
        for (field in tableInfo.fields) {
            if (field.columnName == "id") {
                continue
            }
            if (!first) {
                sb.append(",\n")
            }
            sb.append("                ${field.columnName}")
            first = false
        }
        sb.toString()
    }

    /**
     * 构建插入值
     */
    private func buildInsertValues(tableInfo: TableInfo): String {
        let sb = StringBuilder()
        var first = true
        for (field in tableInfo.fields) {
            if (field.columnName == "id") {
                continue
            }
            let camelName = toCamelCase(field.columnName)
            if (!first) {
                sb.append(",\n                ")
            }
            sb.append("\${arg(entity.${camelName})}")
            first = false
        }
        sb.toString()
    }

    /**
     * 构建更新SET子句
     */
    private func buildUpdateSets(tableInfo: TableInfo): String {
        let sb = StringBuilder()
        var first = true
        for (field in tableInfo.fields) {
            if (field.columnName == "id" || field.columnName == "created_at") {
                continue
            }
            if (!first) {
                sb.append(",\n")
            }
            let camelName = toCamelCase(field.columnName)
            if (field.columnName == "updated_at") {
                sb.append("                ${field.columnName} = \${arg(DateTime.now())}")
            } else {
                sb.append("                ${field.columnName} = \${arg(entity.${camelName})}")
            }
            first = false
        }
        sb.toString()
    }
    
    /**
     * 构建Service层代码
     */
    private func buildServiceCode(tableInfo: TableInfo): String {
        let variables = HashMap<String, String>()
        variables.add("dbName", tableInfo.dbName)
        variables.add("tableName", tableInfo.tableName)
        variables.add("className", tableInfo.className)
        variables.add("fieldMergeCode", buildFieldMergeCode(tableInfo))

        let templatePath = "./src/app/tools/crudgen/templates/Service.cj.tpl"
        let template = loadTemplateContent(templatePath)

        replaceVariablesInTemplate(template, variables)
    }

    /**
     * 构建字段合并代码
     */
    private func buildFieldMergeCode(tableInfo: TableInfo): String {
        let sb = StringBuilder()

        for (field in tableInfo.fields) {
            if (field.columnName == "id" || field.columnName == "created_at" || field.columnName == "updated_at") {
                continue
            }
            let camelName = toCamelCase(field.columnName)
            let cjType = mapDataType(field.dataType, field.isNullable)

            if (cjType.startsWith("Option<")) {
                sb.append("            if (entity.${camelName}.isSome()) {\n")
                sb.append("                existingEntity.${camelName} = entity.${camelName}\n")
                sb.append("            }\n")
            } else if (cjType == "String") {
                sb.append("            if (entity.${camelName}.size > 0) {\n")
                sb.append("                existingEntity.${camelName} = entity.${camelName}\n")
                sb.append("            }\n")
            } else {
                sb.append("            existingEntity.${camelName} = entity.${camelName}\n")
            }
        }

        sb.toString()
    }
    
    /**
     * 构建Controller层代码
     */
    private func buildControllerCode(tableInfo: TableInfo): String {
        // 构建字段映射代码
        let fieldMappingCode = buildFieldMappingCode(tableInfo)

        // 使用变量映射表进行替换
        let variables = HashMap<String, String>()
        variables.add("dbName", tableInfo.dbName)
        variables.add("tableName", tableInfo.tableName)
        variables.add("className", tableInfo.className)
        variables.add("fieldMappingCode", fieldMappingCode)

        // 读取Controller模板
        let templatePath = "./src/app/tools/crudgen/templates/Controller.cj.tpl"
        let template = loadTemplateContent(templatePath)

        // 替换变量
        replaceVariablesInTemplate(template, variables)
    }
    
    /**
     * 构建字段映射代码
     */
    private func buildFieldMappingCode(tableInfo: TableInfo): String {
        let sb = StringBuilder()
        
        sb.append("    private func mapToEntity(map: Map<String, Any>): ${tableInfo.className}PO {\n")
        sb.append("        let entity = ${tableInfo.className}PO()\n")
        
        for (field in tableInfo.fields) {
            let fieldName = toCamelCase(field.columnName)
            let cjType = mapDataType(field.dataType, field.isNullable)
            
            sb.append("        if (let Some(${fieldName}) <- map.get(\"${field.columnName}\")) {\n")
            
            if (cjType.startsWith("Option<")) {
                // Option类型
                let innerType = cjType[7..cjType.size - 1] // 去掉 "Option<" 和 ">"
                if (innerType == "String") {
                    sb.append("            let ${fieldName}Str = ${fieldName} as String\n")
                    sb.append("            if (let Some(s) <- ${fieldName}Str) {\n")
                    sb.append("                entity.${fieldName} = Some<String>(s)\n")
                    sb.append("            }\n")
                } else if (innerType == "Float64") {
                    sb.append("            if (${fieldName} is Int64) {\n")
                    sb.append("                let ${fieldName}Int = ${fieldName} as Int64\n")
                    sb.append("                if (let Some(v) <- ${fieldName}Int) {\n")
                    sb.append("                    entity.${fieldName} = Some<Float64>(Float64(v))\n")
                    sb.append("                }\n")
                    sb.append("            } else if (${fieldName} is Float64) {\n")
                    sb.append("                let ${fieldName}Float = ${fieldName} as Float64\n")
                    sb.append("                if (let Some(v) <- ${fieldName}Float) {\n")
                    sb.append("                    entity.${fieldName} = Some<Float64>(v)\n")
                    sb.append("                }\n")
                    sb.append("            }\n")
                } else if (innerType == "DateTime") {
                    sb.append("            // DateTime类型, 由数据库处理\n")
                } else {
                    sb.append("            let ${fieldName}Str = ${fieldName} as String\n")
                    sb.append("            if (let Some(s) <- ${fieldName}Str) {\n")
                    sb.append("                entity.${fieldName} = Some<${innerType}>(s)\n")
                    sb.append("            }\n")
                }
            } else if (cjType == "String") {
                sb.append("            let ${fieldName}Str = ${fieldName} as String\n")
                sb.append("            if (let Some(s) <- ${fieldName}Str) {\n")
                sb.append("                entity.${fieldName} = s\n")
                sb.append("            }\n")
            } else if (cjType == "Int32") {
                sb.append("            let ${fieldName}Int = ${fieldName} as Int64\n")
                sb.append("            if (let Some(v) <- ${fieldName}Int) {\n")
                sb.append("                entity.${fieldName} = Int32(v)\n")
                sb.append("            }\n")
            } else if (cjType == "Float64") {
                sb.append("            if (${fieldName} is Int64) {\n")
                sb.append("                let ${fieldName}Int = ${fieldName} as Int64\n")
                sb.append("                if (let Some(v) <- ${fieldName}Int) {\n")
                sb.append("                    entity.${fieldName} = Float64(v)\n")
                sb.append("                }\n")
                sb.append("            } else if (${fieldName} is Float64) {\n")
                sb.append("                let ${fieldName}Float = ${fieldName} as Float64\n")
                sb.append("                if (let Some(v) <- ${fieldName}Float) {\n")
                sb.append("                    entity.${fieldName} = v\n")
                sb.append("                }\n")
                sb.append("            }\n")
            } else if (cjType == "Bool") {
                sb.append("            let ${fieldName}Bool = ${fieldName} as Bool\n")
                sb.append("            if (let Some(v) <- ${fieldName}Bool) {\n")
                sb.append("                entity.${fieldName} = v\n")
                sb.append("            }\n")
            }
            
            sb.append("        }\n")
        }
        
        sb.append("        return entity\n")
        sb.append("    }\n")
        
        return sb.toString()
    }
    
    /**
     * 加载模板内容
     */
    private func loadTemplateContent(templatePath: String): String {
        try {
            let bytes = File.readFrom(templatePath)
            let content = String.fromUtf8(bytes)
            content
        } catch (e: Exception) {
            ""
        }
    }
    
    /**
     * 替换模板变量
     */
    private func replaceVariablesInTemplate(template: String, variables: HashMap<String, String>): String {
        var result = template
        
        for ((key, value) in variables) {
            let placeholder = "{{" + key + "}}"
            result = result.replace(placeholder, value)
        }
        
        result
    }
    
    /**
     * 构建Route层代码
     */
    private func buildRouteCode(tableInfo: TableInfo): String {
        // 使用变量映射表进行替换
        let variables = HashMap<String, String>()
        variables.add("dbName", tableInfo.dbName)
        variables.add("tableName", tableInfo.tableName)
        variables.add("className", tableInfo.className)

        // 读取Route模板
        let templatePath = "./src/app/tools/crudgen/templates/Route.cj.tpl"
        let template = loadTemplateContent(templatePath)

        // 替换变量
        replaceVariablesInTemplate(template, variables)
    }
    
    /**
     * 数据类型映射
     */
    private func mapDataType(dataType: String, isNullable: String): String {
        let baseType = match (dataType.toAsciiLower()) {
            case "uuid" => "String"
            case "text" => "String"
            case "character varying" => "String"
            case "varchar" => "String"
            case "integer" => "Int32"
            case "smallint" => "Int32"
            case "bigint" => "Int64"
            case "numeric" => "Float64"
            case "real" => "Float32"
            case "double precision" => "Float64"
            case "boolean" => "Bool"
            case "timestamp with time zone" => "DateTime"
            case "timestamp" => "DateTime"
            case "date" => "DateTime"
            case "time" => "DateTime"
            case "json" => "String"
            case "jsonb" => "String"
            case _ => "String"
        }
        
        if (isNullable == "YES") {
            "Option<${baseType}>"
        } else {
            baseType
        }
    }
    
    /**
     * 获取默认值
     */
    private func getDefaultValue(dataType: String, isNullable: String): String {
        if (isNullable == "YES") {
            let baseType = mapDataType(dataType, "NO")
            "None<${baseType}>"
        } else {
            match (dataType.toAsciiLower()) {
                case "integer" | "smallint" => "0"
                case "bigint" => "0"
                case "numeric" | "real" | "double precision" => "0.0"
                case "boolean" => "false"
                case "timestamp" | "timestamp with time zone" | "date" | "time" => "DateTime.now()"
                case _ => "\"\""
            }
        }
    }
    
    /**
     * 转换为驼峰命名
     */
    private func toCamelCase(str: String): String {
        let parts = str.split("_")
        var result = ""
        
        for (i in 0..parts.size) {
            let part = parts[i]
            if (i == 0) {
                result = result + part.toAsciiLower()
            } else {
                result = result + part[0..1].toAsciiUpper() + part[1..part.size].toAsciiLower()
            }
        }
        
        return result
    }
    
    /**
     * 转换为帕斯卡命名（首字母大写）
     */
    private func toPascalCase(str: String): String {
        let parts = str.split("_")
        var result = ""
        
        for (part in parts) {
            result = result + part[0..1].toAsciiUpper() + part[1..part.size].toAsciiLower()
        }
        
        return result
    }
}
