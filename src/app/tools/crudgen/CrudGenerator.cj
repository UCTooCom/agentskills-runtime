package magic.app.tools.crudgen

import std.collection.*
import std.fs.*
import std.time.DateTime
import std.convert
import f_orm.*
import f_orm.macros.*
import f_orm.sql.*
import f_util.UUID
import magic.app.services.uctoo.DbInfoService
import magic.app.models.uctoo.DbInfoPO
import magic.app.models.uctoo.PermissionsPO
import magic.app.models.uctoo.I18PO

// ==================== 仓颉保留关键字列表 ====================
// 基于官方文档：kernel/source_zh_cn/Appendix/keyword.md
// 共70个官方关键字
private let CJ_KEYWORDS = HashSet<String>([
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

/**
 * 检查是否为仓颉保留关键字
 */
private func isKeyword(name: String): Bool {
    CJ_KEYWORDS.contains(name)
}

/**
 * 处理关键字（为关键字添加后缀）
 */
private func handleKeyword(fieldName: String): String {
    match (fieldName) {
        case "abstract" => "abstractVal"
        case "as" => "asVal"
        case "Bool" => "boolVal"
        case "break" => "breakVal"
        case "case" => "caseVal"
        case "catch" => "catchVal"
        case "class" => "classVal"
        case "const" => "constVal"
        case "continue" => "continueVal"
        case "do" => "doVal"
        case "else" => "elseVal"
        case "enum" => "enumVal"
        case "extend" => "extendVal"
        case "false" => "falseVal"
        case "finally" => "finallyVal"
        case "Float16" => "float16Val"
        case "Float32" => "float32Val"
        case "Float64" => "float64Val"
        case "for" => "forVal"
        case "foreign" => "foreignVal"
        case "func" => "funcVal"
        case "if" => "ifVal"
        case "import" => "importVal"
        case "in" => "inVal"
        case "init" => "initVal"
        case "Int16" => "int16Val"
        case "Int32" => "int32Val"
        case "Int64" => "int64Val"
        case "Int8" => "int8Val"
        case "IntNative" => "intNativeVal"
        case "interface" => "interfaceVal"
        case "is" => "isVal"
        case "let" => "letVar"
        case "macro" => "macroVal"
        case "main" => "mainVal"
        case "match" => "matchVal"
        case "mut" => "mutVal"
        case "Nothing" => "nothingVal"
        case "open" => "openVal"
        case "operator" => "operatorVal"
        case "override" => "overrideVal"
        case "package" => "packageVal"
        case "private" => "privateVal"
        case "prop" => "propVal"
        case "protected" => "protectedVal"
        case "public" => "publicVal"
        case "quote" => "quoteVal"
        case "redef" => "redefVal"
        case "return" => "returnVal"
        case "Rune" => "runeVal"
        case "spawn" => "spawnVal"
        case "static" => "staticVal"
        case "struct" => "structVal"
        case "super" => "superObj"
        case "synchronized" => "synchronizedVal"
        case "this" => "thisObj"
        case "This" => "ThisVal"
        case "throw" => "throwVal"
        case "true" => "trueVal"
        case "try" => "tryVal"
        case "type" => "typeVal"
        case "UInt16" => "uInt16Val"
        case "UInt32" => "uInt32Val"
        case "UInt64" => "uInt64Val"
        case "UInt8" => "uInt8Val"
        case "UIntNative" => "uIntNativeVal"
        case "Unit" => "unitVal"
        case "unsafe" => "unsafeVal"
        case "var" => "variable"
        case "VArray" => "vArrayVal"
        case "where" => "whereVal"
        case "while" => "whileVal"
        case _ => fieldName
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
    
    return handleKeyword(result)
}

/**
 * 首字母大写
 */
private func capitalizeFirst(str: String): String {
    if (str.size == 0) {
        return str
    }
    str[0..1].toAsciiUpper() + str[1..str.size]
}

/**
 * 生成安全的字段名（避免关键字冲突）
 * 策略：如果是关键字，添加表名单数前缀
 * 例如：type → dbConnectionType (db_connection表)
 * 特殊处理：tableName → dbTableName (避免与宏生成的tableName()方法冲突)
 */
private func generateSafeFieldName(dbFieldName: String, tableName: String): String {
    let camelName = toCamelCase(dbFieldName)
    
    // 特殊处理：tableName字段会与宏生成的tableName()方法冲突
    if (camelName == "tableName") {
        return "dbTableName"
    }
    
    if (isKeyword(camelName)) {
        // 移除表名中的下划线并转为驼峰，然后移除复数形式
        var tablePrefix = toCamelCase(tableName)
        // 移除复数s：permissions → permission
        if (tablePrefix.endsWith("s") && tablePrefix.size > 1) {
            tablePrefix = tablePrefix[0..tablePrefix.size - 1]
        }
        // 添加表名前缀：type → dbConnectionType
        return tablePrefix + capitalizeFirst(camelName)
    } else {
        return camelName
    }
}

/**
 * 生成安全的局部变量名（用于Controller的mapToEntity方法）
 * 策略：如果是关键字，添加Value后缀
 * 例如：type → typeValue
 */
private func generateSafeLocalVarName(fieldName: String): String {
    if (isKeyword(fieldName)) {
        fieldName + "Value"
    } else {
        fieldName
    }
}

/// SQL参数处理函数 - 用于setSql模板字符串中
/// @param value 参数值
/// @return 格式化后的参数字符串
private func arg<T>(value: T): String where T <: ToString {
    let str = value.toString()
    if (str == "None") {
        return "NULL"
    }
    // 检查是否是 Some(xxx) 格式
    if (str.size > 6 && str.startsWith("Some(")) {
        // 提取括号内的值
        var content = ""
        let startPos = 5
        let endPos = str.size - 1
        var i = startPos
        while (i < endPos) {
            let ch = str[i]
            // 将 UInt8 字符转换为对应的字符
            let charArr = Array<UInt8>(1, repeat: ch)
            content = content + String.fromUtf8(charArr)
            i += 1
        }
        // 检查是否为数字类型
        var isNumber = true
        var hasDot = false
        for (ch in content) {
            if (ch == 46 && !hasDot) { // '.' 的 ASCII 值是 46
                hasDot = true
            } else if (ch < 48 || ch > 57) { // '0'-'9' 的 ASCII 值范围
                isNumber = false
                break
            }
        }
        if (isNumber) {
            return content
        }
        // 检查是否为布尔类型
        if (content == "true" || content == "false") {
            return content
        }
        // 检查是否为 DateTime 类型（包含 T 和 + 等字符）
        var isDateTime = false
        for (ch in content) {
            if (ch == 84 || ch == 43 || ch == 45) { // 'T', '+', '-' 的 ASCII 值
                isDateTime = true
                break
            }
        }
        if (isDateTime) {
            return "'${content}'"
        }
        // 其他情况当作字符串处理（包括 UUID）
        return "'${content}'"
    }
    // 非 Optional 值，直接返回
    return "'${str}'"
}

private func optArg<T>(value: T): String where T <: ToString {
    let str = value.toString()
    if (str == "None") {
        return "NULL"
    }
    // 检查是否是 Some(xxx) 格式
    if (str.size > 6 && str.startsWith("Some(")) {
        // 提取括号内的值
        var content = ""
        let startPos = 5
        let endPos = str.size - 1
        var i = startPos
        while (i < endPos) {
            let ch = str[i]
            // 将 UInt8 字符转换为对应的字符
            let charArr = Array<UInt8>(1, repeat: ch)
            content = content + String.fromUtf8(charArr)
            i += 1
        }
        // 检查是否为数字类型（简单的数字格式检查）
        var isNumber = true
        var hasDot = false
        for (ch in content) {
            if (ch == 46 && !hasDot) { // '.' 的 ASCII 值是 46
                hasDot = true
            } else if (ch < 48 || ch > 57) { // '0'-'9' 的 ASCII 值范围
                isNumber = false
                break
            }
        }
        if (isNumber) {
            return content
        }
        // 检查是否为布尔类型
        if (content == "true" || content == "false") {
            return content
        }
        // 检查是否为 DateTime 类型（包含 T 和 + 等字符）
        var isDateTime = false
        for (ch in content) {
            if (ch == 84 || ch == 43 || ch == 45) { // 'T', '+', '-' 的 ASCII 值
                isDateTime = true
                break
            }
        }
        if (isDateTime) {
            return "'${content}'"
        }
        // 其他情况当作字符串处理（包括 UUID）
        return "'${content}'"
    }
    // 非 Optional 值，直接返回
    return "'${str}'"
}

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
            field.ordinalPosition = match (dbInfo.ordinalPosition) {
                case Some(v) => v
                case None => 0
            }
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
    
    /// 生成权限节点（幂等版本，不更新已存在的节点）
    /// 为指定的表生成权限节点，包括数据库权限节点和表权限节点
    /// 权限结构：database -> database.{dbName} -> database.{dbName}.{tableName}
    ///
    /// 幂等性保证：
    /// 1. 如果节点已存在且未删除：跳过
    /// 2. 如果节点被软删除：恢复该节点
    /// 3. 如果节点不存在：创建新节点
    ///
    /// @param dbName 数据库名称
    /// @param tableName 表名称
    /// @return 生成成功返回true，失败返回false
    public func generatePermissionNodes(dbName: String, tableName: String): Bool {
        generatePermissionNodesWithOption(dbName, tableName, false)
    }
    
    /// 生成权限节点（幂等版本，可选择更新已存在的节点）
    /// 为指定的表生成权限节点，包括数据库权限节点和表权限节点
    /// 权限结构：database -> database.{dbName} -> database.{dbName}.{tableName}
    ///
    /// 幂等性保证：
    /// 1. 如果节点已存在且未删除：可选更新
    /// 2. 如果节点被软删除：恢复该节点
    /// 3. 如果节点不存在：创建新节点
    ///
    /// @param dbName 数据库名称
    /// @param tableName 表名称
    /// @param updateIfExists 如果节点已存在是否更新（true=更新，false=跳过）
    /// @return 生成成功返回true，失败返回false
    public func generatePermissionNodesWithOption(dbName: String, tableName: String, updateIfExists: Bool): Bool {
        try {
            let executor = ORM.executor()
            let tablePermissionName = "database.${dbName}.${tableName}"
            
            // 1. 获取或创建 database 父节点（处理软删除）
            let (databaseParentId, parentCreator) = ensureDatabaseParentNode(executor)
            
            // 2. 获取或创建 database.{dbName} 节点（处理软删除）
            let dbNodeId = ensureDatabaseNode(executor, dbName, databaseParentId, parentCreator)
            
            // 3. 检查表权限节点是否存在（包括软删除的）
            let existingTable = executor.setSql('''
                SELECT * FROM permissions
                WHERE permission_name = ${arg(tablePermissionName)}
            ''').first<PermissionsPO>()
            
            let now = DateTime.now()
            
            match (existingTable) {
                case Some(table) =>
                    if (table.deletedAt.isNone()) {
                        if (updateIfExists) {
                            executor.setSql('''
                                UPDATE permissions
                                SET title = ${arg("menu.${tablePermissionName}")},
                                    path = ${arg(tableName)},
                                    parent_id = ${arg(dbNodeId)},
                                    updated_at = NOW()
                                WHERE id = ${arg(table.id)}
                            ''').update
                            println("已更新表权限节点: ${tablePermissionName}")
                        } else {
                            println("表权限节点已存在: ${tablePermissionName}")
                        }
                    } else {
                        executor.setSql('''
                            UPDATE permissions
                            SET deleted_at = NULL,
                                updated_at = NOW(),
                                title = ${arg("menu.${tablePermissionName}")},
                                path = ${arg(tableName)},
                                parent_id = ${arg(dbNodeId)}
                            WHERE id = ${arg(table.id)}
                        ''').update
                        println("已恢复软删除的表权限节点: ${tablePermissionName}")
                    }
                case None =>
                    let tablePermission = PermissionsPO()
                    tablePermission.permissionName = tablePermissionName
                    tablePermission.permissionType = 1
                    tablePermission.hidden = 1
                    tablePermission.weight = 1
                    tablePermission.creator = parentCreator
                    tablePermission.createdAt = now
                    tablePermission.updatedAt = now
                    tablePermission.path = tableName
                    tablePermission.title = tableName
                    tablePermission.parentId = dbNodeId
                    tablePermission.menuType = "normal"
                    tablePermission.locale = "menu.database.${dbName}.${tableName}"
                    tablePermission.component = "database/${dbName}/${tableName}/index"
                    
                    executor.setSql('''
                        INSERT INTO permissions(
                            id, permission_name, level, icon, module, component, redirect,
                            type, hidden, weight, creator, created_at, updated_at,
                            deleted_at, keepalive, path, title, parent_id, meta,
                            method, menu_type, locale
                        ) VALUES (
                            gen_random_uuid(),
                            ${arg(tablePermission.permissionName)},
                            ${optArg(tablePermission.level)},
                            ${optArg(tablePermission.icon)},
                            ${optArg(tablePermission.module)},
                            ${optArg(tablePermission.component)},
                            ${optArg(tablePermission.redirect)},
                            ${optArg(tablePermission.permissionType)},
                            ${optArg(tablePermission.hidden)},
                            ${optArg(tablePermission.weight)},
                            '505cf909-5e0e-4dde-b215-74274d2cc548',
                            NOW(),
                            NOW(),
                            null,
                            1,
                            ${arg(tablePermission.path)},
                            ${arg(tablePermission.title)},
                            ${arg(dbNodeId)},
                            ${optArg(tablePermission.meta)},
                            ${optArg(tablePermission.method)},
                            ${arg(tablePermission.menuType)},
                            ${arg(tablePermission.locale)}
                        )
                    ''').update
                    
                    println("已生成表权限节点: ${tablePermissionName}")
                    
                    // 插入 i18 多语言数据
                    match (tablePermission.locale) {
                        case Some(localeKey) => insertI18Data(executor, localeKey, tableName)
                        case None => println("locale 为空，跳过 i18 数据插入")
                    }
            }
            
            return true
        } catch (e: Exception) {
            println("生成权限节点失败: ${e.message}")
            return false
        }
    }
    
    /// 确保 database 父节点存在（幂等版本）
    /// 处理软删除的节点：优先恢复而非创建新节点
    /// @return (parentId, creator) - 返回父节点ID和creator值
    private func ensureDatabaseParentNode(executor: SqlExecutor): (String, String) {
        let databasePermissionName = "database"
        
        let existing = executor.setSql('''
            SELECT * FROM permissions
            WHERE permission_name = ${arg(databasePermissionName)} AND deleted_at IS NULL
        ''').first<PermissionsPO>()
        
        match (existing) {
            case Some(node) =>
                let creator = match (node.creator) {
                    case Some(c) => c
                    case None => "505cf909-5e0e-4dde-b215-74274d2cc548"
                }
                return (node.id, creator)
            case None =>
                let softDeleted = executor.setSql('''
                    SELECT * FROM permissions
                    WHERE permission_name = ${arg(databasePermissionName)} AND deleted_at IS NOT NULL
                    ORDER BY updated_at DESC
                    LIMIT 1
                ''').first<PermissionsPO>()
                
                match (softDeleted) {
                    case Some(deletedNode) =>
                        executor.setSql('''
                            UPDATE permissions
                            SET deleted_at = NULL, updated_at = NOW()
                            WHERE id = ${arg(deletedNode.id)}
                        ''').update
                        println("已恢复软删除的权限节点: ${databasePermissionName}")
                        let creator = match (deletedNode.creator) {
                            case Some(c) => c
                            case None => "505cf909-5e0e-4dde-b215-74274d2cc548"
                        }
                        return (deletedNode.id, creator)
                    case None =>
                        let creator = "505cf909-5e0e-4dde-b215-74274d2cc548"
                        
                        executor.setSql('''
                            INSERT INTO permissions(
                                id, permission_name, level, icon, module, component, redirect,
                                type, hidden, weight, creator, created_at, updated_at,
                                deleted_at, keepalive, path, title, parent_id, meta,
                                method, menu_type, locale
                            ) VALUES (
                                gen_random_uuid(),
                                ${arg(databasePermissionName)},
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                1,
                                1,
                                1,
                                ${arg(creator)},
                                NOW(),
                                NOW(),
                                null,
                                1,
                                ${arg(databasePermissionName)},
                                ${arg(databasePermissionName)},
                                NULL,
                                NULL,
                                NULL,
                                'normal',
                                ${arg("menu.${databasePermissionName}")}
                            )
                        ''').update
                        
                        println("已生成权限节点: ${databasePermissionName}")
                        
                        let newNode = executor.setSql('''
                            SELECT * FROM permissions
                            WHERE permission_name = ${arg(databasePermissionName)} AND deleted_at IS NULL
                        ''').first<PermissionsPO>()
                        
                        match (newNode) {
                            case Some(n) => return (n.id, creator)
                            case None => return ("505cf909-5e0e-4dde-b215-74274d2cc548", creator)
                        }
                }
        }
    }
    
    /// 确保 database.{dbName} 节点存在（幂等版本）
    /// 处理软删除的节点：优先恢复而非创建新节点
    /// @return dbNodeId - 返回数据库节点ID
    private func ensureDatabaseNode(executor: SqlExecutor, dbName: String, parentId: String, creator: String): String {
        let dbPermissionName = "database.${dbName}"
        
        let existing = executor.setSql('''
            SELECT * FROM permissions
            WHERE permission_name = ${arg(dbPermissionName)} AND deleted_at IS NULL
        ''').first<PermissionsPO>()
        
        match (existing) {
            case Some(node) =>
                return node.id
            case None =>
                let softDeleted = executor.setSql('''
                    SELECT * FROM permissions
                    WHERE permission_name = ${arg(dbPermissionName)} AND deleted_at IS NOT NULL
                    ORDER BY updated_at DESC
                    LIMIT 1
                ''').first<PermissionsPO>()
                
                match (softDeleted) {
                    case Some(deletedNode) =>
                        let now = DateTime.now()
                        executor.setSql('''
                            UPDATE permissions
                            SET deleted_at = NULL,
                                updated_at = NOW(),
                                parent_id = ${arg(parentId)}
                            WHERE id = ${arg(deletedNode.id)}
                        ''').update
                        println("已恢复软删除的数据库节点: ${dbPermissionName}")
                        return deletedNode.id
                    case None =>
                        let now = DateTime.now()
                        
                        executor.setSql('''
                            INSERT INTO permissions(
                                id, permission_name, level, icon, module, component, redirect,
                                type, hidden, weight, creator, created_at, updated_at,
                                deleted_at, keepalive, path, title, parent_id, meta,
                                method, menu_type, locale
                            ) VALUES (
                                gen_random_uuid(),
                                ${arg(dbPermissionName)},
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                1,
                                1,
                                1,
                                ${arg(creator)},
                                NOW(),
                                NOW(),
                                null,
                                1,
                                ${arg(dbName)},
                                ${arg(dbName)},
                                ${arg(parentId)},
                                NULL,
                                NULL,
                                'normal',
                                ${arg("menu.${dbPermissionName}")}
                            )
                        ''').update
                        
                        println("已生成数据库节点: ${dbPermissionName}")
                        
                        let newNode = executor.setSql('''
                            SELECT * FROM permissions
                            WHERE permission_name = ${arg(dbPermissionName)} AND deleted_at IS NULL
                        ''').first<PermissionsPO>()
                        
                        match (newNode) {
                            case Some(n) => return n.id
                            case None => return "505cf909-5e0e-4dde-b215-74274d2cc548"
                        }
                }
        }
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
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            let originalCamelName = toCamelCase(field.columnName)
            let cjType = mapDataType(field.dataType, field.isNullable)
            let defaultValue = getDefaultValue(field.dataType, field.isNullable)
            
            // 如果字段被重命名，添加注释说明
            if (fieldName != originalCamelName) {
                sb.append("        // 注意: 数据库列名 '${field.columnName}' 是关键字，已重命名为 '${fieldName}'\n")
            }
            
            sb.append("        @ORMField['${field.columnName}']\n")
            sb.append("    public var ${fieldName}: ${cjType} = ${defaultValue}\n\n")
        }
        
        // 无参构造函数
        sb.append("    public init() {}\n\n")
        
        // 全参构造函数
        sb.append("    public init(\n")
        var first = true
        for (field in tableInfo.fields) {
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            let cjType = mapDataType(field.dataType, field.isNullable)
            
            if (!first) {
                sb.append(",\n")
            }
            sb.append("                ${fieldName}: ${cjType}")
            first = false
        }
        sb.append("\n    ) {\n")
        
        for (field in tableInfo.fields) {
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            sb.append("                this.${fieldName} = ${fieldName}\n")
        }
        sb.append("    }\n\n")
        
        // toJsonValue方法
        sb.append("    /// 序列化为 JsonValue\n")
        sb.append("    public func toJsonValue(): JsonValue {\n")
        sb.append("        var map = HashMap<String, JsonValue>()\n")
        
        for (field in tableInfo.fields) {
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
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
        sb.append("        }")
                sb.append("\n")
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

        return replaceVariablesInTemplate(template, variables)
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
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            if (!first) {
                sb.append(",\n                ")
            }
            sb.append("\${arg(entity.${fieldName})}")
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
            if (field.columnName == "id" || field.columnName == "created_at" || field.columnName == "updated_at") {
                continue
            }
            if (!first) {
                sb.append(",\n")
            }
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            sb.append("                ${field.columnName} = \${arg(entity.${fieldName})}")
            first = false
        }
        if (!first) {
            sb.append(",")
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

        return replaceVariablesInTemplate(template, variables)
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
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            let cjType = mapDataType(field.dataType, field.isNullable)

            if (cjType.startsWith("Option<")) {
                sb.append("            if (entity.${fieldName}.isSome()) {\n")
                sb.append("                existingEntity.${fieldName} = entity.${fieldName}\n")
                sb.append("            }")
                    sb.append("\n")
            } else if (cjType == "String") {
                sb.append("            if (entity.${fieldName}.size > 0) {\n")
                sb.append("                existingEntity.${fieldName} = entity.${fieldName}\n")
                sb.append("            }")
                    sb.append("\n")
            } else {
                sb.append("            existingEntity.${fieldName} = entity.${fieldName}\n")
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
        
        // 构建导出方法代码
        let exportCode = buildExportCode(tableInfo)

        // 使用变量映射表进行替换
        let variables = HashMap<String, String>()
        variables.add("dbName", tableInfo.dbName)
        variables.add("tableName", tableInfo.tableName)
        variables.add("className", tableInfo.className)
        variables.add("fieldMappingCode", fieldMappingCode)
        variables.add("exportCode", exportCode)

        // 读取Controller模板
        let templatePath = "./src/app/tools/crudgen/templates/Controller.cj.tpl"
        let template = loadTemplateContent(templatePath)

        // 替换变量
        return replaceVariablesInTemplate(template, variables)
    }
    
    /**
     * 构建字段映射代码
     */
    private func buildFieldMappingCode(tableInfo: TableInfo): String {
        let sb = StringBuilder()
        
        sb.append("    private func mapToEntity(map: Map<String, Any>): ${tableInfo.className}PO {")
        sb.append("\n")
        sb.append("        let entity = ${tableInfo.className}PO()")
        sb.append("\n")
        
        for (field in tableInfo.fields) {
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            let localVarName = generateSafeLocalVarName(fieldName)
            let cjType = mapDataType(field.dataType, field.isNullable)
            
            // 特殊处理时间戳字段
            if (field.columnName == "created_at" || field.columnName == "updated_at") {
                sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                sb.append("\n")
                sb.append("        }")
                sb.append("\n")
            } else if (field.columnName == "deleted_at" || field.columnName == "birthday" || field.columnName == "end_time" || field.columnName == "start_time") {
                sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                sb.append("\n")
                sb.append("            // DateTime类型, 由数据库处理")
                sb.append("\n")
                sb.append("        }")
                sb.append("\n")
            } else if (cjType.startsWith("Option<")) {
                let innerType = cjType[7..cjType.size - 1]
                
                if (innerType == "String") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Str = ${localVarName} as String")
                    sb.append("\n")
                    sb.append("            if (let Some(s) <- ${localVarName}Str) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = Some<String>(s)")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (innerType == "Int32") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Int = ${localVarName} as Int64")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Int) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = Some<Int32>(Int32(v))")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (innerType == "Int64") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Int = ${localVarName} as Int64")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Int) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = Some<Int64>(v)")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (innerType == "Float64") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            if (${localVarName} is Int64) {")
                    sb.append("\n")
                    sb.append("                let ${localVarName}Int = ${localVarName} as Int64")
                    sb.append("\n")
                    sb.append("                if (let Some(v) <- ${localVarName}Int) {")
                    sb.append("\n")
                    sb.append("                    entity.${fieldName} = Some<Float64>(Float64(v))")
                    sb.append("\n")
                    sb.append("                }")
                    sb.append("\n")
                    sb.append("            } else if (${localVarName} is Float64) {")
                    sb.append("\n")
                    sb.append("                let ${localVarName}Float = ${localVarName} as Float64")
                    sb.append("\n")
                    sb.append("                if (let Some(v) <- ${localVarName}Float) {")
                    sb.append("\n")
                    sb.append("                    entity.${fieldName} = Some<Float64>(v)")
                    sb.append("\n")
                    sb.append("                }")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (innerType == "Bool") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Bool = ${localVarName} as Bool")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Bool) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = Some<Bool>(v)")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (innerType == "DateTime") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            // DateTime类型, 由数据库处理")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Val = ${localVarName} as ${innerType}")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Val) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = Some<${innerType}>(v)")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                }
            } else {
                if (cjType == "String") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Str = ${localVarName} as String")
                    sb.append("\n")
                    sb.append("            if (let Some(s) <- ${localVarName}Str) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = s")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (cjType == "Int32") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Int = ${localVarName} as Int64")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Int) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = Int32(v)")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (cjType == "Int64") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Int = ${localVarName} as Int64")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Int) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = v")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (cjType == "Float64") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            if (${localVarName} is Int64) {")
                    sb.append("\n")
                    sb.append("                let ${localVarName}Int = ${localVarName} as Int64")
                    sb.append("\n")
                    sb.append("                if (let Some(v) <- ${localVarName}Int) {")
                    sb.append("\n")
                    sb.append("                    entity.${fieldName} = Float64(v)")
                    sb.append("\n")
                    sb.append("                }")
                    sb.append("\n")
                    sb.append("            } else if (${localVarName} is Float64) {")
                    sb.append("\n")
                    sb.append("                let ${localVarName}Float = ${localVarName} as Float64")
                    sb.append("\n")
                    sb.append("                if (let Some(v) <- ${localVarName}Float) {")
                    sb.append("\n")
                    sb.append("                    entity.${fieldName} = v")
                    sb.append("\n")
                    sb.append("                }")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (cjType == "Bool") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Bool = ${localVarName} as Bool")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Bool) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = v")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else if (cjType == "DateTime") {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            // DateTime类型, 由数据库处理")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                } else {
                    sb.append("        if (let Some(${localVarName}) <- map.get(\"${field.columnName}\")) {")
                    sb.append("\n")
                    sb.append("            let ${localVarName}Val = ${localVarName} as ${cjType}")
                    sb.append("\n")
                    sb.append("            if (let Some(v) <- ${localVarName}Val) {")
                    sb.append("\n")
                    sb.append("                entity.${fieldName} = v")
                    sb.append("\n")
                    sb.append("            }")
                    sb.append("\n")
                    sb.append("        }")
                    sb.append("\n")
                }
            }
        }
        
        sb.append("        return entity")
        sb.append("\n")
        sb.append("    }")
        sb.append("\n")
        
        sb.toString()
    }
    
    /**
     * 构建导出方法代码
     */
    private func buildExportCode(tableInfo: TableInfo): String {
        let sb = StringBuilder()

        sb.append("    public func export(req: HttpRequest, res: HttpResponse): Unit {")
        sb.append("\n")
        sb.append("        try {")
        sb.append("\n")
        sb.append("            // 获取所有" + tableInfo.tableName + "数据")
        sb.append("\n")
        sb.append("            let (entities, _) = service.getList(1, 1000)")
        sb.append("\n")
        sb.append("")
        sb.append("\n")
        sb.append("            // 构建CSV内容")
        sb.append("\n")
        sb.append("            let sb = StringBuilder()")
        sb.append("\n")
        sb.append("            // 写入CSV头部")
        sb.append("\n")

        let headerParts = ArrayList<String>()
        for (field in tableInfo.fields) {
            headerParts.add(field.columnName)
        }
        let headerSb = StringBuilder()
        for (i in 0..headerParts.size) {
            if (i > 0) {
                headerSb.append(",")
            }
            headerSb.append(headerParts[i])
        }
        let headerStr = headerSb.toString()
        sb.append("            sb.append(\"" + headerStr + "\\n\")")
        sb.append("\n")

        sb.append("")
        sb.append("\n")
        sb.append("            // 写入数据行")
        sb.append("\n")
        sb.append("            for (entity in entities) {")
        sb.append("\n")

        for (field in tableInfo.fields) {
            let fieldName = generateSafeFieldName(field.columnName, tableInfo.tableName)
            let cjType = mapDataType(field.dataType, field.isNullable)

            if (cjType.startsWith("Option<")) {
                let innerType = cjType[7..cjType.size - 1]
                if (innerType == "String") {
                    sb.append("                sb.append(if (let Some(v) <- entity." + fieldName + ") { \"\\\"\" + v + \"\\\",\" } else { \"\" })")
                    sb.append("\n")
                } else if (innerType == "DateTime") {
                    sb.append("                sb.append(if (let Some(v) <- entity." + fieldName + ") { \"\\\"\" + v.toString() + \"\\\",\" } else { \"\" })")
                    sb.append("\n")
                } else if (innerType == "Float64" || innerType == "Float32" || innerType == "Int32" || innerType == "Int64") {
                    sb.append("                sb.append(if (let Some(v) <- entity." + fieldName + ") { \"\\\"\" + v.toString() + \"\\\",\" } else { \"\" })")
                    sb.append("\n")
                } else {
                    sb.append("                sb.append(if (let Some(v) <- entity." + fieldName + ") { \"\\\"\" + v + \"\\\",\" } else { \"\" })")
                    sb.append("\n")
                }
            } else if (cjType == "String") {
                sb.append("                sb.append(\"\\\"\" + \"\${entity." + fieldName + "}\" + \",\")")
                sb.append("\n")
            } else if (cjType == "DateTime") {
                sb.append("                sb.append(\"\\\"\" + \"\${entity." + fieldName + ".toString()}\" + \",\")")
                sb.append("\n")
            } else {
                sb.append("                sb.append(\"\${entity." + fieldName + "}\")")
                sb.append("\n")
                sb.append("                sb.append(\",\")")
                sb.append("\n")
            }
        }

        sb.append("                sb.append(\"\\n\")")
        sb.append("\n")
        sb.append("            }")
        sb.append("\n")

        sb.append("")
        sb.append("\n")
        sb.append("            // 设置响应头")
        sb.append("\n")
        sb.append("            res.header(\"Content-Type\", \"text/csv\")")
        sb.append("\n")
        sb.append("            res.header(\"Content-Disposition\", \"attachment; filename=" + tableInfo.tableName + "_export.csv\")")
        sb.append("\n")
        sb.append("            res.status(200).send(sb.toString())")
        sb.append("\n")
        sb.append("        } catch (e: Exception) {")
        sb.append("\n")
        sb.append("            res.status(500).json(\"{\\\"errno\\\":\\\"50000\\\",\\\"errmsg\\\":\\\"\" + e.message + \"\\\"}\")")
        sb.append("\n")
        sb.append("        }")
        sb.append("\n")
        sb.append("    }")
        sb.append("\n")

        sb.toString()
    }
    
    /**
     * 构建Route层代码
     */
    private func buildRouteCode(tableInfo: TableInfo): String {
        let variables = HashMap<String, String>()
        variables.add("dbName", tableInfo.dbName)
        variables.add("tableName", tableInfo.tableName)
        variables.add("className", tableInfo.className)

        let templatePath = "./src/app/tools/crudgen/templates/Route.cj.tpl"
        let template = loadTemplateContent(templatePath)

        return replaceVariablesInTemplate(template, variables)
    }
    
    /**
     * 映射数据库类型到仓颉类型
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
     * 转换为帕斯卡命名（首字母大写的驼峰命名）
     */
    private func toPascalCase(str: String): String {
        let camelCase = toCamelCase(str)
        if (camelCase.size == 0) {
            return camelCase
        }
        camelCase[0..1].toAsciiUpper() + camelCase[1..camelCase.size]
    }
    
    /**
     * 加载模板文件内容
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
     * 替换模板中的变量
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
     * 插入 i18 多语言数据
     */
    private func insertI18Data(executor: SqlExecutor, key: String, content: String): Unit {
        try {
            let existing = executor.setSql('''
                SELECT * FROM i18
                WHERE key = ${arg(key)} AND deleted_at IS NULL
            ''').first<I18PO>()
            
            match (existing) {
                case Some(i18) =>
                    println("i18 数据已存在: ${key}")
                case None =>
                    let softDeleted = executor.setSql('''
                        SELECT * FROM i18
                        WHERE key = ${arg(key)} AND deleted_at IS NOT NULL
                        ORDER BY updated_at DESC
                        LIMIT 1
                    ''').first<I18PO>()
                    
                    match (softDeleted) {
                        case Some(deletedI18) =>
                            executor.setSql('''
                                UPDATE i18
                                SET deleted_at = NULL,
                                    content = ${arg(content)},
                                    updated_at = NOW()
                                WHERE id = ${arg(deletedI18.id)}
                            ''').update
                            println("已恢复软删除的 i18 数据: ${key}")
                        case None =>
                            executor.setSql('''
                                INSERT INTO i18(
                                    id, key, content, lang_id, creator, created_at, updated_at, deleted_at
                                ) VALUES (
                                    gen_random_uuid(),
                                    ${arg(key)},
                                    ${arg(content)},
                                    '00000000-0000-0000-0000-000000000002',
                                    NULL,
                                    NOW(),
                                    NOW(),
                                    NULL
                                )
                            ''').update
                            println("已生成 i18 数据: ${key}")
                    }
            }
        } catch (e: Exception) {
            println("插入 i18 数据失败: ${e.message}")
        }
    }
}
