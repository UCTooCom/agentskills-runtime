/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import std.collection.ArrayList

/**
 * FieldCodeBuilder - 模板动态变量构建器（PS-T013）
 *
 * 把表字段列表构建为各层模板的代码片段变量
 * （fieldDefinitions / insertColumns / fieldMappingCode 等），
 * 构建逻辑与 crudgen 同源（成熟先例），输出适配插件模板。
 */
public class FieldCodeBuilder {
    private let rules = NameRules()

    public init() {}

    /// Model 层：字段定义（@ORMField + var 声明）
    public func fieldDefinitions(fields: ArrayList<FieldInfo>, tableName: String): String {
        let sb = StringBuilder()
        for (field in fields) {
            let fieldName = rules.safeFieldName(field.columnName, tableName)
            let cjType = rules.mapDataType(field.dataType, field.isNullable)
            let dv = rules.defaultValue(field.dataType, field.isNullable)
            sb.append("    @ORMField['${field.columnName}']\n")
            sb.append("    public var ${fieldName}: ${cjType} = ${dv}\n\n")
        }
        return sb.toString()
    }

    /// Model 层：全参构造函数参数列表
    public func constructorParams(fields: ArrayList<FieldInfo>, tableName: String): String {
        let sb = StringBuilder()
        var first = true
        for (field in fields) {
            let fieldName = rules.safeFieldName(field.columnName, tableName)
            let cjType = rules.mapDataType(field.dataType, field.isNullable)
            if (!first) {
                sb.append(",\n")
            }
            sb.append("        ${fieldName}: ${cjType}")
            first = false
        }
        return sb.toString()
    }

    /// Model 层：构造函数赋值语句
    public func constructorAssignments(fields: ArrayList<FieldInfo>, tableName: String): String {
        let sb = StringBuilder()
        for (field in fields) {
            let fieldName = rules.safeFieldName(field.columnName, tableName)
            sb.append("        this.${fieldName} = ${fieldName}\n")
        }
        return sb.toString()
    }

    /// Model 层：toJsonValue 字段映射
    public func toJsonMappings(fields: ArrayList<FieldInfo>, tableName: String): String {
        let sb = StringBuilder()
        for (field in fields) {
            let fieldName = rules.safeFieldName(field.columnName, tableName)
            let cjType = rules.mapDataType(field.dataType, field.isNullable)
            if (cjType.startsWith("Option<")) {
                sb.append("        map.add(\"${field.columnName}\", optionToJsonValue(this.${fieldName}))\n")
            } else {
                sb.append("        map.add(\"${field.columnName}\", this.${fieldName}.toJsonValue())\n")
            }
        }
        return sb.toString()
    }

    /// DAO 层：insert 列清单（排除 id）
    public func insertColumns(fields: ArrayList<FieldInfo>): String {
        let sb = StringBuilder()
        var first = true
        for (field in fields) {
            if (field.columnName == "id") {
                continue
            }
            if (!first) {
                sb.append(",\n")
            }
            sb.append("                ${rules.escapeColumnName(field.columnName)}")
            first = false
        }
        return sb.toString()
    }

    /// DAO 层：insert 值清单（排除 id）
    public func insertValues(fields: ArrayList<FieldInfo>, tableName: String): String {
        let sb = StringBuilder()
        var first = true
        for (field in fields) {
            if (field.columnName == "id") {
                continue
            }
            let fieldName = rules.safeFieldName(field.columnName, tableName)
            if (!first) {
                sb.append(",\n                ")
            }
            sb.append("\${arg(entity.${fieldName})}")
            first = false
        }
        return sb.toString()
    }

    /// DAO 层：select 列清单（PG 关键字 coalesce 兜底）
    public func selectColumns(fields: ArrayList<FieldInfo>): String {
        let sb = StringBuilder()
        var first = true
        for (field in fields) {
            if (!first) {
                sb.append(", ")
            }
            let escaped = rules.escapeColumnName(field.columnName)
            if (rules.isPostgresKeyword(field.columnName)) {
                sb.append("coalesce(${escaped}, '') as ${escaped}")
            } else {
                sb.append(escaped)
            }
            first = false
        }
        return sb.toString()
    }

    /// DAO 层：update SET 子句（排除 id/created_at/updated_at）
    public func updateSets(fields: ArrayList<FieldInfo>, tableName: String): String {
        let sb = StringBuilder()
        var first = true
        for (field in fields) {
            if (field.columnName == "id" || field.columnName == "created_at" ||
                field.columnName == "updated_at") {
                continue
            }
            if (!first) {
                sb.append(",\n")
            }
            let fieldName = rules.safeFieldName(field.columnName, tableName)
            sb.append("                ${rules.escapeColumnName(field.columnName)} = \${arg(entity.${fieldName})}")
            first = false
        }
        if (!first) {
            sb.append(",")
        }
        return sb.toString()
    }

    /// Service 层：creator 缺省回填代码
    public func creatorCheckCode(fields: ArrayList<FieldInfo>): String {
        for (field in fields) {
            if (field.columnName == "creator") {
                let cjType = rules.mapDataType(field.dataType, field.isNullable)
                if (cjType.startsWith("Option<")) {
                    return "if (entity.creator.isNone()) {\n                entity.creator = Some(creatorId)\n            }"
                }
                return "if (entity.creator.isEmpty()) {\n                entity.creator = creatorId\n            }"
            }
        }
        return ""
    }

    /// Service 层：更新合并字段代码
    public func fieldMergeCode(fields: ArrayList<FieldInfo>, tableName: String): String {
        let sb = StringBuilder()
        for (field in fields) {
            if (field.columnName == "id" || field.columnName == "created_at" ||
                field.columnName == "updated_at") {
                continue
            }
            let fieldName = rules.safeFieldName(field.columnName, tableName)
            let cjType = rules.mapDataType(field.dataType, field.isNullable)
            if (cjType.startsWith("Option<")) {
                sb.append("            if (entity.${fieldName}.isSome()) {\n")
                sb.append("                existingEntity.${fieldName} = entity.${fieldName}\n")
                sb.append("            }\n")
            } else if (cjType == "String") {
                sb.append("            if (entity.${fieldName}.size > 0) {\n")
                sb.append("                existingEntity.${fieldName} = entity.${fieldName}\n")
                sb.append("            }\n")
            } else {
                sb.append("            existingEntity.${fieldName} = entity.${fieldName}\n")
            }
        }
        return sb.toString()
    }

    /// Controller 层：mapToEntity 字段映射代码
    public func fieldMappingCode(fields: ArrayList<FieldInfo>, tableName: String, className: String): String {
        let sb = StringBuilder()
        sb.append("    private func mapToEntity(map: Map<String, Any>): ${className}PO {\n")
        sb.append("        let entity = ${className}PO()\n")
        for (field in fields) {
            appendFieldMapping(sb, field, tableName)
        }
        sb.append("        return entity\n")
        sb.append("    }\n")
        return sb.toString()
    }

    /// 单字段映射（时间戳字段由数据库处理，其余按类型 as 转换）
    private func appendFieldMapping(sb: StringBuilder, field: FieldInfo, tableName: String): Unit {
        let fieldName = rules.safeFieldName(field.columnName, tableName)
        let localVar = rules.safeLocalVarName(fieldName)
        let cjType = rules.mapDataType(field.dataType, field.isNullable)
        let isTimestamp = field.columnName == "created_at" || field.columnName == "updated_at" ||
            field.columnName == "deleted_at" || cjType == "DateTime" || cjType == "Option<DateTime>"

        if (isTimestamp) {
            sb.append("        if (let Some(${localVar}) <- map.get(\"${field.columnName}\")) {\n")
            sb.append("            // DateTime 类型由数据库处理\n")
            sb.append("        }\n")
            return
        }
        if (cjType.startsWith("Option<")) {
            appendOptionalMapping(sb, field.columnName, fieldName, localVar, cjType[7..cjType.size - 1])
        } else {
            appendPlainMapping(sb, field.columnName, fieldName, localVar, cjType)
        }
    }

    /// Option<T> 字段映射
    private func appendOptionalMapping(sb: StringBuilder, column: String, fieldName: String,
        localVar: String, innerType: String): Unit {
        sb.append("        if (let Some(${localVar}) <- map.get(\"${column}\")) {\n")
        match (innerType) {
            case "String" =>
                sb.append("            let ${localVar}Str = ${localVar} as String\n")
                sb.append("            if (let Some(s) <- ${localVar}Str) {\n")
                sb.append("                entity.${fieldName} = Some<String>(s)\n")
                sb.append("            }\n")
            case "Int32" =>
                sb.append("            let ${localVar}Int = ${localVar} as Int64\n")
                sb.append("            if (let Some(v) <- ${localVar}Int) {\n")
                sb.append("                entity.${fieldName} = Some<Int32>(Int32(v))\n")
                sb.append("            }\n")
            case "Int64" =>
                sb.append("            let ${localVar}Int = ${localVar} as Int64\n")
                sb.append("            if (let Some(v) <- ${localVar}Int) {\n")
                sb.append("                entity.${fieldName} = Some<Int64>(v)\n")
                sb.append("            }\n")
            case "Float64" =>
                sb.append("            if (${localVar} is Int64) {\n")
                sb.append("                let ${localVar}Int = ${localVar} as Int64\n")
                sb.append("                if (let Some(v) <- ${localVar}Int) {\n")
                sb.append("                    entity.${fieldName} = Some<Float64>(Float64(v))\n")
                sb.append("                }\n")
                sb.append("            } else if (${localVar} is Float64) {\n")
                sb.append("                let ${localVar}Float = ${localVar} as Float64\n")
                sb.append("                if (let Some(v) <- ${localVar}Float) {\n")
                sb.append("                    entity.${fieldName} = Some<Float64>(v)\n")
                sb.append("                }\n")
                sb.append("            }\n")
            case "Bool" =>
                sb.append("            let ${localVar}Bool = ${localVar} as Bool\n")
                sb.append("            if (let Some(v) <- ${localVar}Bool) {\n")
                sb.append("                entity.${fieldName} = Some<Bool>(v)\n")
                sb.append("            }\n")
            case _ =>
                sb.append("            let ${localVar}Val = ${localVar} as ${innerType}\n")
                sb.append("            if (let Some(v) <- ${localVar}Val) {\n")
                sb.append("                entity.${fieldName} = Some<${innerType}>(v)\n")
                sb.append("            }\n")
        }
        sb.append("        }\n")
    }

    /// 非 Option 字段映射
    private func appendPlainMapping(sb: StringBuilder, column: String, fieldName: String,
        localVar: String, cjType: String): Unit {
        sb.append("        if (let Some(${localVar}) <- map.get(\"${column}\")) {\n")
        match (cjType) {
            case "String" =>
                sb.append("            let ${localVar}Str = ${localVar} as String\n")
                sb.append("            if (let Some(s) <- ${localVar}Str) {\n")
                sb.append("                entity.${fieldName} = s\n")
                sb.append("            }\n")
            case "Int32" =>
                sb.append("            let ${localVar}Int = ${localVar} as Int64\n")
                sb.append("            if (let Some(v) <- ${localVar}Int) {\n")
                sb.append("                entity.${fieldName} = Int32(v)\n")
                sb.append("            }\n")
            case "Int64" =>
                sb.append("            let ${localVar}Int = ${localVar} as Int64\n")
                sb.append("            if (let Some(v) <- ${localVar}Int) {\n")
                sb.append("                entity.${fieldName} = v\n")
                sb.append("            }\n")
            case "Float64" =>
                sb.append("            if (${localVar} is Int64) {\n")
                sb.append("                let ${localVar}Int = ${localVar} as Int64\n")
                sb.append("                if (let Some(v) <- ${localVar}Int) {\n")
                sb.append("                    entity.${fieldName} = Float64(v)\n")
                sb.append("                }\n")
                sb.append("            } else if (${localVar} is Float64) {\n")
                sb.append("                let ${localVar}Float = ${localVar} as Float64\n")
                sb.append("                if (let Some(v) <- ${localVar}Float) {\n")
                sb.append("                    entity.${fieldName} = v\n")
                sb.append("                }\n")
                sb.append("            }\n")
            case "Bool" =>
                sb.append("            let ${localVar}Bool = ${localVar} as Bool\n")
                sb.append("            if (let Some(v) <- ${localVar}Bool) {\n")
                sb.append("                entity.${fieldName} = v\n")
                sb.append("            }\n")
            case _ =>
                sb.append("            let ${localVar}Val = ${localVar} as ${cjType}\n")
                sb.append("            if (let Some(v) <- ${localVar}Val) {\n")
                sb.append("                entity.${fieldName} = v\n")
                sb.append("            }\n")
        }
        sb.append("        }\n")
    }
}
