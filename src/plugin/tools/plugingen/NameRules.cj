/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import std.collection.HashSet

/**
 * NameRules - 插件生成器命名与类型规则（PS-T013）
 *
 * 复刻 crudgen 的成熟命名策略（关键字避让、驼峰转换、类型映射、PG 列名转义），
 * 供 PluginGenerator 与 FieldCodeBuilder 复用；本文件不依赖宿主 src/app 任何代码。
 */

// ==================== 仓颉保留关键字（官方 70 个） ====================
let CJ_KEYWORDS = HashSet<String>([
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

/// PostgreSQL 关键字/函数名集合（列名转义用）
let PG_KEYWORDS = HashSet<String>([
    'group', 'order', 'by', 'select', 'from', 'where', 'and', 'or',
    'not', 'null', 'true', 'false', 'default', 'primary', 'foreign',
    'key', 'unique', 'check', 'constraint', 'references', 'on',
    'delete', 'update', 'set', 'insert', 'into', 'values', 'returning',
    'create', 'table', 'alter', 'drop', 'add', 'column', 'index',
    'if', 'exists', 'case', 'when', 'then', 'else', 'end', 'cast',
    'as', 'distinct', 'limit', 'offset', 'fetch', 'first', 'next',
    'rows', 'only', 'for', 'of', 'no', 'with', 'recursive',
    'union', 'intersect', 'except', 'all', 'some', 'any', 'in',
    'like', 'ilike', 'between', 'is', 'nullif', 'coalesce', 'greatest',
    'least', 'min', 'max', 'sum', 'avg', 'count', 'having', 'window',
    'partition', 'over', 'asc', 'desc', 'nulls',
    'now', 'current_date', 'current_time', 'current_timestamp',
    'interval', 'date_trunc', 'extract', 'date_part', 'age', 'rank',
    'upper', 'lower', 'initcap', 'length', 'substring', 'trim',
    'concat', 'concat_ws', 'replace', 'position', 'strpos',
    'left', 'right', 'repeat', 'reverse', 'split_part',
    'md5', 'sha256', 'encode', 'decode'
])

/// 插件目录保留名（src/plugins/ 下手工维护的示例插件，禁止生成同名技能插件）
let RESERVED_PLUGIN_NAMES = HashSet<String>(["hello", "doc_helper", "doc-helper"])

public class NameRules {
    public init() {}

    /// 是否为仓颉保留关键字
    public func isKeyword(name: String): Bool {
        CJ_KEYWORDS.contains(name)
    }

    /// 是否为 PostgreSQL 关键字
    public func isPostgresKeyword(name: String): Bool {
        PG_KEYWORDS.contains(name.toAsciiLower())
    }

    /// PostgreSQL 列名转义（关键字加双引号）
    public func escapeColumnName(columnName: String): String {
        if (this.isPostgresKeyword(columnName)) {
            "\"${columnName}\""
        } else {
            columnName
        }
    }

    /// 下划线命名转小驼峰（db_connection → dbConnection）
    public func toCamelCase(str: String): String {
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

    /// 首字母大写
    public func capitalizeFirst(str: String): String {
        if (str.size == 0) {
            return str
        }
        return str[0..1].toAsciiUpper() + str[1..str.size]
    }

    /// 转帕斯卡命名（db_connection → DbConnection）
    public func toPascalCase(str: String): String {
        return this.capitalizeFirst(this.toCamelCase(str))
    }

    /**
     * 生成安全字段名（关键字避让，与 crudgen 策略一致）
     * - tableName → dbTableName（避开宏生成的 tableName() 方法）
     * - 其他关键字加表名单数前缀：type → dbConnectionType
     */
    public func safeFieldName(dbFieldName: String, tableName: String): String {
        let camelName = this.toCamelCase(dbFieldName)
        if (camelName == "tableName") {
            return "dbTableName"
        }
        if (this.isKeyword(camelName)) {
            var tablePrefix = this.toCamelCase(tableName)
            if (tablePrefix.endsWith("s") && tablePrefix.size > 1) {
                tablePrefix = tablePrefix[0..tablePrefix.size - 1]
            }
            return tablePrefix + this.capitalizeFirst(camelName)
        }
        return camelName
    }

    /// 生成安全局部变量名（关键字加 Value 后缀）
    public func safeLocalVarName(fieldName: String): String {
        if (this.isKeyword(fieldName)) {
            return fieldName + "Value"
        }
        return fieldName
    }

    /**
     * 规范化插件名（包名段）：连字符转下划线、转小写
     * 返回 (规范名, 是否发生了替换)
     */
    public func normalizePluginName(raw: String): (String, Bool) {
        let normalized = raw.replace("-", "_").toAsciiLower()
        return (normalized, normalized != raw)
    }

    /// 校验插件名是否为合法包名段（小写字母/数字/下划线，且不以数字开头）
    public func isValidPluginName(name: String): Bool {
        if (name.size == 0) {
            return false
        }
        let runes = name.toRuneArray()
        let first = runes[0]
        if (!((first >= r'a' && first <= r'z') || first == r'_')) {
            return false
        }
        for (ch in runes) {
            let ok = (ch >= r'a' && ch <= r'z') || (ch >= r'0' && ch <= r'9') || ch == r'_'
            if (!ok) {
                return false
            }
        }
        return true
    }

    /// 是否为 build-sync 保留名（与 src/plugins/ 示例插件冲突）
    public func isReservedName(name: String): Bool {
        RESERVED_PLUGIN_NAMES.contains(name)
    }

    /// 数据库类型映射到仓颉类型（与 crudgen 一致）
    public func mapDataType(dataType: String, isNullable: String): String {
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
            return "Option<${baseType}>"
        }
        return baseType
    }

    /// 字段默认值（与 crudgen 一致）
    public func defaultValue(dataType: String, isNullable: String): String {
        if (isNullable == "YES") {
            let baseType = this.mapDataType(dataType, "NO")
            return "None<${baseType}>"
        }
        return match (dataType.toAsciiLower()) {
            case "integer" | "smallint" | "bigint" => "0"
            case "numeric" | "real" | "double precision" => "0.0"
            case "boolean" => "false"
            case "timestamp" | "timestamp with time zone" | "date" | "time" => "DateTime.now()"
            case _ => "\"\""
        }
    }
}
