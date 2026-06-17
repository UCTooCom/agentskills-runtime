package magic.app.tools.crudweb

import std.collection.*
import std.fs.{File, Directory, Path, exists}
import std.time.DateTime
import std.convert
import std.env.getVariable
import f_orm.*
import f_orm.macros.*
import f_orm.sql.*
import f_util.UUID
import magic.app.services.uctoo.DbInfoService
import magic.app.models.uctoo.DbInfoPO

// ==================== 需要手动维护的表列表 ====================
private let MANUAL_TABLES = HashSet<String>([
    "role_has_permission",
    "uctoo_user"
])

/**
 * 检查表是否需要手动维护
 */
private func isManualTable(tableName: String): Bool {
    MANUAL_TABLES.contains(tableName)
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
 * 首字母大写
 */
private func capitalizeFirst(str: String): String {
    if (str.size == 0) {
        return str
    }
    return str[0..1].toAsciiUpper() + str[1..str.size]
}

/**
 * 转换为帕斯卡命名
 */
private func toPascalCase(str: String): String {
    capitalizeFirst(toCamelCase(str))
}

/**
 * 转换为 kebab-case（下划线转连字符）
 */
private func toKebabCase(str: String): String {
    str.replace("_", "-")
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
    public var columnComment: String = ""
    
    public init() {}
}

/**
 * 表信息
 */
public class TableInfo {
    public var tableName: String = ""
    public var dbName: String = ""
    public var className: String = ""
    public var fields: ArrayList<FieldInfo> = ArrayList<FieldInfo>()
    
    public init() {}
}

/**
 * Web CRUD代码生成器 - 基于模板复制方案
 */
public class WebCrudGenerator {
    private var outputDir: String = "./web-admin"
    private var dbInfoService: DbInfoService
    private var templateDir: String
    
    public init() {
        let outputDirOpt = getVariable("WEB_CRUD_OUTPUT_DIR")
        if (outputDirOpt.isSome()) {
            this.outputDir = outputDirOpt.getOrThrow()
        } else {
            this.outputDir = "./web-admin"
        }
        this.dbInfoService = DbInfoService()
        this.templateDir = "./src/app/tools/crudweb/templates"
    }
    
    public init(outputDir: String) {
        this.outputDir = outputDir
        this.dbInfoService = DbInfoService()
        this.templateDir = "./src/app/tools/crudweb/templates"
    }
    
    /**
     * 从数据库读取表结构信息
     */
    public func readTableInfo(dbName: String, tableName: String): TableInfo {
        let tableInfo = TableInfo()
        tableInfo.tableName = tableName
        tableInfo.dbName = dbName
        tableInfo.className = toPascalCase(tableName)
        
        let executor = ORM.executor()
        let sql = "SELECT * FROM db_info WHERE table_catalog = '${dbName}' AND table_name = '${tableName}' ORDER BY ordinal_position"
        
        let results = executor.setSql(sql).list<DbInfoPO>()
        
        for (dbInfo in results) {
            let field = FieldInfo()
            field.columnName = dbInfo.columnName
            field.dataType = dbInfo.dataType ?? ""
            field.isNullable = dbInfo.isNullable
            field.columnDefault = dbInfo.columnDefault
            field.ordinalPosition = dbInfo.ordinalPosition
            field.columnComment = dbInfo.columnComment ?? dbInfo.columnName
            tableInfo.fields.add(field)
        }
        
        return tableInfo
    }
    
    /**
     * 读取数据库中所有表名
     */
    public func readAllTables(dbName: String): ArrayList<String> {
        let tables = ArrayList<String>()
        
        let executor = ORM.executor()
        let sql = "SELECT DISTINCT table_name FROM db_info WHERE table_catalog = '${dbName}' ORDER BY table_name"
        
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
        println("=== generateAllLayers 开始: tableName=${tableInfo.tableName}, dbName=${tableInfo.dbName} ===")
        
        if (isManualTable(tableInfo.tableName)) {
            println("跳过手动维护的表: ${tableInfo.tableName}")
            return
        }
        
        println("创建目录结构...")
        ensureDirectoryStructure(tableInfo)
        
        println("生成 index.vue...")
        generateIndexVue(tableInfo)
        
        println("生成 add-${tableInfo.tableName}.vue...")
        generateAddVue(tableInfo)
        
        println("生成 ${tableInfo.tableName}-table.vue...")
        generateTableVue(tableInfo)
        
        println("生成 edit-form.vue...")
        generateEditFormVue(tableInfo)
        
        println("生成 store model...")
        generateStoreModel(tableInfo)
        

        println("=== Web CRUD代码生成完成: ${tableInfo.tableName} ===")
    }
    
    /**
     * 确保目录结构存在
     */
    private func ensureDirectoryStructure(tableInfo: TableInfo): Unit {
        let basePath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}"
        let componentsPath = "${basePath}/components"
        let storeDir = "${outputDir}/web/src/store/models/${tableInfo.dbName}"
        
        if (!dirExists(basePath)) {
            Directory.create(basePath, recursive: true)
            println("创建目录: ${basePath}")
        }
        
        if (!dirExists(componentsPath)) {
            Directory.create(componentsPath, recursive: true)
            println("创建目录: ${componentsPath}")
        }
        
        if (!dirExists(storeDir)) {
            Directory.create(storeDir, recursive: true)
            println("创建目录: ${storeDir}")
        }
    }
    
    /**
     * 读取模板文件
     */
    private func readTemplate(templateName: String): String {
        let templatePath = "${templateDir}/${templateName}"
        try {
            let bytes = File.readFrom(templatePath)
            let content = String.fromUtf8(bytes)
            return content
        } catch (e: Exception) {
            println("读取模板失败 ${templatePath}: ${e.message}")
            return ""
        }
    }
    
    /**
     * 简单的模板变量替换
     */
    private func replaceVars(template: String, vars: HashMap<String, String>): String {
        var result = template
        for ((key, value) in vars) {
            result = result.replace("{{${key}}}", value)
        }
        return result
    }
    
    /**
     * 生成 index.vue
     */
    public func generateIndexVue(tableInfo: TableInfo): Unit {
        let template = readTemplate("index.vue.tpl")
        if (template.size == 0) {
            println("模板文件不存在，使用内置代码生成")
            let code = buildIndexVueCode(tableInfo)
            let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/index.vue"
            writeFile(outputPath, code)
            return
        }
        
        let vars = HashMap<String, String>()
        vars.add("table_name", tableInfo.tableName)
        vars.add("ClassName", tableInfo.className)
        vars.add("camelTableName", toCamelCase(tableInfo.tableName))
        vars.add("kebabTableName", toKebabCase(tableInfo.tableName))
        vars.add("db_name", tableInfo.dbName)
        
        let code = replaceVars(template, vars)
        let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/index.vue"
        writeFile(outputPath, code)
    }
    
    /**
     * 生成 add-{tableName}.vue
     */
    public func generateAddVue(tableInfo: TableInfo): Unit {
        let template = readTemplate("add-{{table_name}}.vue.tpl")
        let kebabName = toKebabCase(tableInfo.tableName)
        if (template.size == 0) {
            println("add模板文件不存在，使用内置代码生成")
            let code = buildAddVueCode(tableInfo)
            let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/components/add-${kebabName}.vue"
            writeFile(outputPath, code)
            return
        }
        
        let vars = HashMap<String, String>()
        vars.add("table_name", tableInfo.tableName)
        vars.add("ClassName", tableInfo.className)
        vars.add("camelTableName", toCamelCase(tableInfo.tableName))
        vars.add("kebabTableName", kebabName)
        vars.add("db_name", tableInfo.dbName)
        vars.add("handler_param", resolveHandlerParam(tableInfo))
        
        let firstField: String
        if (tableInfo.fields.size > 0) {
            firstField = tableInfo.fields[0].columnName
        } else {
            firstField = "id"
        }
        vars.add("first_field", firstField)
        
        let formModelSb = StringBuilder()
        let rulesSb = StringBuilder()
        let numberConversionSb = StringBuilder()
        let resetDefaultsSb = StringBuilder()
        let createHandlerParamsSb = StringBuilder()
        let setFormValuesSb = StringBuilder()
        
        var isFirstField = true
        for (field in tableInfo.fields) {
            if (field.columnName == "id" || field.columnName == "created_at" || field.columnName == "updated_at" || field.columnName == "deleted_at" || field.columnName == "creator") {
                continue
            }
            let defaultValue = getDefaultValue(field.dataType)
            formModelSb.append("  ${field.columnName}: ${defaultValue},\n")
            
            if (field.isNullable == "NO") {
                rulesSb.append("  ${field.columnName}: [\n")
                rulesSb.append("    {\n")
                rulesSb.append("      required: true,\n")
                rulesSb.append("      trigger: 'blur',\n")
                rulesSb.append("    },\n")
                rulesSb.append("  ],\n")
            }
            
            if (isNumberType(field.dataType)) {
                numberConversionSb.append("      if (submitData.${field.columnName} !== undefined) {\n")
                numberConversionSb.append("        submitData.${field.columnName} = Number(submitData.${field.columnName})\n")
                numberConversionSb.append("      }\n")
                resetDefaultsSb.append("          formModel.${field.columnName} = 0\n")
            }
            
            if (isFirstField) {
                createHandlerParamsSb.append(field.columnName)
                isFirstField = false
            } else {
                createHandlerParamsSb.append(",\n          ${field.columnName}")
            }
            
            setFormValuesSb.append("        formModel.${field.columnName} = ${field.columnName} || ${defaultValue}\n")
        }
        
        vars.add("form_model", "const formModel = reactive({\n${formModelSb.toString()}})")
        vars.add("validation_rules", "const rules = {\n${rulesSb.toString()}}")
        vars.add("number_conversion", numberConversionSb.toString())
        vars.add("reset_defaults", resetDefaultsSb.toString())
        vars.add("create_handler_params", createHandlerParamsSb.toString())
        vars.add("set_form_values", setFormValuesSb.toString())
        
        let fieldsSb = StringBuilder()
        let requiredFieldsSb = StringBuilder()
        let numberFieldsSb = StringBuilder()
        
        for (field in tableInfo.fields) {
            let defaultValue = getDefaultValue(field.dataType)
            fieldsSb.append("  ${field.columnName}: ${defaultValue},\n")
            
            if (field.isNullable == "NO" && field.columnName != "id") {
                requiredFieldsSb.append("  ${field.columnName}: [{\n")
                requiredFieldsSb.append("    required: true,\n")
                requiredFieldsSb.append("    trigger: 'blur',\n")
                requiredFieldsSb.append("  }],\n")
            }
            
            if (isNumberType(field.dataType)) {
                numberFieldsSb.append("          formModel.${field.columnName} = 0\n")
            }
        }
        
        vars.add("fields", fieldsSb.toString())
        vars.add("required_fields", requiredFieldsSb.toString())
        vars.add("number_fields", numberFieldsSb.toString())
        
        let formRowsSb = StringBuilder()
        var i = 0
        while (i < tableInfo.fields.size) {
            formRowsSb.append("        <TinyRow>\n")
            
            for (j in 0..2) {
                if (i >= tableInfo.fields.size) {
                    break
                }
                let field = tableInfo.fields[i]
                let inputType = getInputType(field.dataType)
                
                formRowsSb.append("          <TinyCol :span=\"12\">\n")
                formRowsSb.append("            <TinyFormItem label=\"${field.columnComment}\" prop=\"${field.columnName}\">\n")
                
                if (inputType == "textarea") {
                    formRowsSb.append("              <TinyInput\n")
                    formRowsSb.append("                v-model=\"formModel.${field.columnName}\"\n")
                    formRowsSb.append("                type=\"textarea\"\n")
                    formRowsSb.append("                :rows=\"3\"\n")
                    formRowsSb.append("                :placeholder=\"$t('page.PleaseInput')\"\n")
                    formRowsSb.append("              />\n")
                } else if (inputType == "number") {
                    formRowsSb.append("              <TinyInput v-model=\"formModel.${field.columnName}\" type=\"number\" :min=\"0\" />\n")
                } else if (inputType == "date") {
                    formRowsSb.append("              <TinyDatePicker\n")
                    formRowsSb.append("                v-model=\"formModel.${field.columnName}\"\n")
                    formRowsSb.append("                type=\"date\"\n")
                    formRowsSb.append("                value-format=\"yyyy-MM-dd\"\n")
                    formRowsSb.append("                :placeholder=\"$t('page.PleaseSelect')\"\n")
                    formRowsSb.append("              />\n")
                } else if (inputType == "datetime") {
                    formRowsSb.append("              <TinyDatePicker\n")
                    formRowsSb.append("                v-model=\"formModel.${field.columnName}\"\n")
                    formRowsSb.append("                type=\"datetime\"\n")
                    formRowsSb.append("                value-format=\"yyyy-MM-dd HH:mm:ss\"\n")
                    formRowsSb.append("                :placeholder=\"$t('page.PleaseSelect')\"\n")
                    formRowsSb.append("              />\n")
                } else {
                    formRowsSb.append("              <TinyInput v-model=\"formModel.${field.columnName}\" />\n")
                }
                
                formRowsSb.append("            </TinyFormItem>\n")
                formRowsSb.append("          </TinyCol>\n")
                
                i += 1
            }
            
            formRowsSb.append("        </TinyRow>\n")
        }
        
        vars.add("form_rows", formRowsSb.toString())
        
        let code = replaceVars(template, vars)
        let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/components/add-${kebabName}.vue"
        writeFile(outputPath, code)
    }
    
    /**
     * 生成 {tableName}-table.vue
     */
    public func generateTableVue(tableInfo: TableInfo): Unit {
        let template = readTemplate("{{table_name}}-table.vue.tpl")
        let kebabName = toKebabCase(tableInfo.tableName)
        if (template.size == 0) {
            println("table模板文件不存在，使用内置代码生成")
            let code = buildTableVueCode(tableInfo)
            let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/components/${kebabName}-table.vue"
            writeFile(outputPath, code)
            return
        }
        
        let vars = HashMap<String, String>()
        vars.add("table_name", tableInfo.tableName)
        vars.add("ClassName", tableInfo.className)
        vars.add("camelTableName", toCamelCase(tableInfo.tableName))
        vars.add("kebabTableName", kebabName)
        vars.add("db_name", tableInfo.dbName)
        vars.add("handler_param", resolveHandlerParam(tableInfo))
        let firstField: String
        if (tableInfo.fields.size > 0) {
            firstField = tableInfo.fields[0].columnName
        } else {
            firstField = "id"
        }
        vars.add("first_field", firstField)
        
        let availableFieldsSb = StringBuilder()
        let filterVariablesSb = StringBuilder()
        let filterParamsSb = StringBuilder()
        let returnFieldsSb = StringBuilder()
        let editFieldsSb = StringBuilder()
        let gridColumnsSb = StringBuilder()
        let queryParamsSb = StringBuilder()
        let setFilterConditionsSb = StringBuilder()
        let createParamsSb = StringBuilder()
        let createDataSb = StringBuilder()
        let stringFieldsList = ArrayList<String>()
        
        var isFirstFilterParam = true
        var isFirstQueryParam = true
        var isFirstCreateParam = true
        var isFirstCreateData = true
        
        for (field in tableInfo.fields) {
            let label = if (field.columnComment.size > 0) { field.columnComment } else { field.columnName }
            availableFieldsSb.append("  { label: '${label}', value: '${field.columnName}' },\n")
            
            if (isStringType(field.dataType) && field.columnName != "id" && field.columnName != "created_at" && field.columnName != "updated_at" && field.columnName != "deleted_at") {
                filterVariablesSb.append("  const ${field.columnName} = filters.${field.columnName}\n")
                filterVariablesSb.append("    ? filterInputValue2String(filters.${field.columnName}.value as InputFilterValue)\n")
                filterVariablesSb.append("    : undefined\n")
                stringFieldsList.add(field.columnName)
                
                if (isFirstFilterParam) {
                    filterParamsSb.append("${field.columnName}")
                    isFirstFilterParam = false
                } else {
                    filterParamsSb.append(", ${field.columnName}")
                }
            }
            
            returnFieldsSb.append("              ${field.columnName}: item.${field.columnName},\n")
            
            if (field.columnName != "id" && field.columnName != "created_at" && field.columnName != "updated_at" && field.columnName != "deleted_at") {
                editFieldsSb.append("      ${field.columnName}: row.${field.columnName},\n")
            }
            
            if (field.columnName != "id" && field.columnName != "created_at" && field.columnName != "updated_at" && field.columnName != "deleted_at" && field.columnName != "creator") {
                if (isFirstQueryParam) {
                    queryParamsSb.append("${field.columnName}")
                    isFirstQueryParam = false
                } else {
                    queryParamsSb.append(", ${field.columnName}")
                }
                
                setFilterConditionsSb.append("        if (${field.columnName}) {\n")
                setFilterConditionsSb.append("          filterConditions.value.push({\n")
                setFilterConditionsSb.append("            id: Date.now().toString(),\n")
                setFilterConditionsSb.append("            field: '${field.columnName}',\n")
                setFilterConditionsSb.append("            operator: 'equals',\n")
                setFilterConditionsSb.append("            value: ${field.columnName}\n")
                setFilterConditionsSb.append("          })\n")
                setFilterConditionsSb.append("        }\n")
                
                if (isFirstCreateParam) {
                    createParamsSb.append(field.columnName)
                    isFirstCreateParam = false
                } else {
                    createParamsSb.append(", ${field.columnName}")
                }
                
                if (isFirstCreateData) {
                    createDataSb.append("            ${field.columnName}")
                    isFirstCreateData = false
                } else {
                    createDataSb.append(",\n            ${field.columnName}")
                }
            }
            
            gridColumnsSb.append("    <TinyGridColumn\n")
            gridColumnsSb.append("      field=\"${field.columnName}\"\n")
            gridColumnsSb.append("      title=\"${label}\"\n")
            if (field.columnName != "id" && field.columnName != "created_at" && field.columnName != "updated_at" && field.columnName != "deleted_at") {
                gridColumnsSb.append("      :editor=\"{ component: 'input' }\"\n")
            }
            gridColumnsSb.append("    />\n")
        }
        
        vars.add("available_fields", availableFieldsSb.toString())
        vars.add("filter_variables", filterVariablesSb.toString())
        vars.add("filter_params", filterParamsSb.toString())
        vars.add("return_fields", returnFieldsSb.toString())
        vars.add("edit_fields", editFieldsSb.toString())
        vars.add("grid_columns", gridColumnsSb.toString())
        vars.add("query_params", queryParamsSb.toString())
        vars.add("set_filter_conditions", setFilterConditionsSb.toString())
        vars.add("create_params", createParamsSb.toString())
        vars.add("create_data", createDataSb.toString())
        
        let fieldsSb = StringBuilder()
        let stringFieldsSb = StringBuilder()
        let editableFieldsSb = StringBuilder()
        
        for (field in tableInfo.fields) {
            fieldsSb.append("  { label: '${field.columnComment}', value: '${field.columnName}' },\n")
            
            if (isStringType(field.dataType)) {
                stringFieldsSb.append("  const ${field.columnName} = filters.${field.columnName}\n")
                stringFieldsSb.append("    ? filterInputValue2String(filters.${field.columnName}.value as InputFilterValue)\n")
                stringFieldsSb.append("    : undefined\n")
            }
            
            if (field.columnName != "id" && field.columnName != "created_at" && field.columnName != "updated_at" && field.columnName != "deleted_at") {
                editableFieldsSb.append("      ${field.columnName}: row.${field.columnName},\n")
            }
        }
        
        vars.add("fields", fieldsSb.toString())
        vars.add("string_fields", stringFieldsSb.toString())
        vars.add("editable_fields", editableFieldsSb.toString())
        
        let code = replaceVars(template, vars)
        let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/components/${kebabName}-table.vue"
        writeFile(outputPath, code)
    }
    
    /**
     * 生成 edit-form.vue
     */
    public func generateEditFormVue(tableInfo: TableInfo): Unit {
        let template = readTemplate("edit-form.vue.tpl")
        if (template.size == 0) {
            println("edit-form模板文件不存在，使用内置代码生成")
            let code = buildEditFormVueCode(tableInfo)
            let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/components/edit-form.vue"
            writeFile(outputPath, code)
            return
        }
        
        let vars = HashMap<String, String>()
        vars.add("table_name", tableInfo.tableName)
        vars.add("ClassName", tableInfo.className)
        vars.add("camelTableName", toCamelCase(tableInfo.tableName))
        vars.add("kebabTableName", toKebabCase(tableInfo.tableName))
        vars.add("db_name", tableInfo.dbName)
        
        let editRulesSb = StringBuilder()
        let editFormDataSb = StringBuilder()
        let watchAssignmentsSb = StringBuilder()
        let numberFieldsConversionSb = StringBuilder()
        let statusOptionsSb = StringBuilder()
        let editFormRowsSb = StringBuilder()
        let camelTableName = toCamelCase(tableInfo.tableName)
        
        editRulesSb.append("const rules = computed(() => {\n")
        editRulesSb.append("  return {\n")
        
        editFormDataSb.append("const formData = reactive<Partial<${tableInfo.tableName}>>({\n")
        
        var hasStatusField = false
        for (field in tableInfo.fields) {
            if (field.columnName == "status") {
                hasStatusField = true
            }
            
            let defaultValue = getDefaultValue(field.dataType)
            
            if (field.columnName == "id") {
                editFormDataSb.append("  id: props.${camelTableName}Data.id,\n")
                watchAssignmentsSb.append("      id: newData.id,\n")
            } else {
                editFormDataSb.append("  ${field.columnName}: props.${camelTableName}Data.${field.columnName} || ${defaultValue},\n")
                watchAssignmentsSb.append("      ${field.columnName}: newData.${field.columnName} ?? ${defaultValue},\n")
            }
            
            if (field.isNullable == "NO" && field.columnName != "id") {
                editRulesSb.append("    ${field.columnName}: [rulesRequired")
                if (isNumberType(field.dataType)) {
                    editRulesSb.append(", rulesNumber")
                }
                editRulesSb.append("],\n")
            }
            
            if (isNumberType(field.dataType) && field.columnName != "id") {
                numberFieldsConversionSb.append("    ${field.columnName}: Number(formData.${field.columnName}),\n")
            }
        }
        
        editRulesSb.append("  }\n")
        editRulesSb.append("})\n")
        
        editFormDataSb.append("})\n")
        
        if (hasStatusField) {
            statusOptionsSb.append("const statusOptions = [\n")
            statusOptionsSb.append("  { label: '启用', value: 'active' },\n")
            statusOptionsSb.append("  { label: '禁用', value: 'inactive' },\n")
            statusOptionsSb.append("  { label: '待审核', value: 'pending' },\n")
            statusOptionsSb.append("]\n")
        }
        
        vars.add("edit_rules", editRulesSb.toString())
        vars.add("edit_form_data", editFormDataSb.toString())
        vars.add("watch_assignments", watchAssignmentsSb.toString())
        vars.add("number_fields_conversion", numberFieldsConversionSb.toString())
        vars.add("status_options", statusOptionsSb.toString())
        
        var i = 0
        while (i < tableInfo.fields.size) {
            editFormRowsSb.append("    <TinyRow class=\"flex flex-wrap\">\n")
            
            for (j in 0..2) {
                if (i >= tableInfo.fields.size) {
                    break
                }
                let field = tableInfo.fields[i]
                let inputType = getInputType(field.dataType)
                
                editFormRowsSb.append("      <TinyCol class=\"w-1/2 max-sm:w-full\">\n")
                editFormRowsSb.append("        <TinyFormItem label=\"${field.columnComment}\" prop=\"${field.columnName}\">\n")
                
                if (field.columnName == "id") {
                    editFormRowsSb.append("          <TinyInput v-model=\"formData.${field.columnName}\" disabled />\n")
                } else if (inputType == "number") {
                    editFormRowsSb.append("          <TinyInput v-model=\"formData.${field.columnName}\" type=\"number\" :min=\"0\" />\n")
                } else if (inputType == "price") {
                    editFormRowsSb.append("          <TinyInput v-model=\"formData.${field.columnName}\" type=\"number\" :min=\"0\" step=\"0.01\" />\n")
                } else if (inputType == "date") {
                    editFormRowsSb.append("          <TinyDatePicker\n")
                    editFormRowsSb.append("            v-model=\"formData.${field.columnName}\"\n")
                    editFormRowsSb.append("            type=\"date\"\n")
                    editFormRowsSb.append("            value-format=\"yyyy-MM-dd\"\n")
                    editFormRowsSb.append("            placeholder=\"请选择日期\"\n")
                    editFormRowsSb.append("          />\n")
                } else if (inputType == "datetime") {
                    editFormRowsSb.append("          <TinyDatePicker\n")
                    editFormRowsSb.append("            v-model=\"formData.${field.columnName}\"\n")
                    editFormRowsSb.append("            type=\"datetime\"\n")
                    editFormRowsSb.append("            value-format=\"yyyy-MM-dd HH:mm:ss\"\n")
                    editFormRowsSb.append("            placeholder=\"请选择时间\"\n")
                    editFormRowsSb.append("          />\n")
                } else if (field.columnName == "status") {
                    editFormRowsSb.append("          <TinySelect v-model=\"formData.${field.columnName}\" :options=\"statusOptions\" />\n")
                } else if (inputType == "textarea") {
                    editFormRowsSb.append("          <TinyInput\n")
                    editFormRowsSb.append("            v-model=\"formData.${field.columnName}\"\n")
                    editFormRowsSb.append("            type=\"textarea\"\n")
                    editFormRowsSb.append("            :rows=\"3\"\n")
                    editFormRowsSb.append("            placeholder=\"请输入${field.columnComment}\"\n")
                    editFormRowsSb.append("          />\n")
                } else {
                    editFormRowsSb.append("          <TinyInput v-model=\"formData.${field.columnName}\" />\n")
                }
                
                editFormRowsSb.append("        </TinyFormItem>\n")
                editFormRowsSb.append("      </TinyCol>\n")
                
                i += 1
            }
            
            editFormRowsSb.append("    </TinyRow>\n")
        }
        
        vars.add("edit_form_rows", editFormRowsSb.toString())
        
        let fieldsSb = StringBuilder()
        let requiredFieldsSb = StringBuilder()
        let numberFieldsSb = StringBuilder()
        let formRowsSb = StringBuilder()
        
        for (field in tableInfo.fields) {
            let defaultValue = getDefaultValue(field.dataType)
            fieldsSb.append("  ${field.columnName}: props.${camelTableName}Data.${field.columnName} || ${defaultValue},\n")
            
            if (field.isNullable == "NO" && field.columnName != "id") {
                requiredFieldsSb.append("    ${field.columnName}: [rulesRequired")
                if (isNumberType(field.dataType)) {
                    requiredFieldsSb.append(", rulesNumber")
                }
                requiredFieldsSb.append("],\n")
            }
            
            if (isNumberType(field.dataType)) {
                numberFieldsSb.append("    ${field.columnName}: Number(formData.${field.columnName}),\n")
            }
        }
        
        vars.add("fields", fieldsSb.toString())
        vars.add("required_fields", requiredFieldsSb.toString())
        vars.add("number_fields", numberFieldsSb.toString())
        vars.add("form_rows", formRowsSb.toString())
        
        let code = replaceVars(template, vars)
        let outputPath = "${outputDir}/web/src/views/database/${tableInfo.dbName}/${tableInfo.tableName}/components/edit-form.vue"
        writeFile(outputPath, code)
    }
    
    /**
     * 生成 store model
     */
    public func generateStoreModel(tableInfo: TableInfo): Unit {
        let template = readTemplate("{{table_name}}.ts.tpl")
        if (template.size == 0) {
            println("store model模板文件不存在，使用内置代码生成")
            let code = buildStoreModelCode(tableInfo)
            let storePath = "${outputDir}/web/src/store/models/${tableInfo.dbName}/${tableInfo.tableName}.ts"
            writeFile(storePath, code)
            updateStoreIndex(tableInfo.dbName, tableInfo.tableName)
            return
        }
        
        let vars = HashMap<String, String>()
        vars.add("table_name", tableInfo.tableName)
        vars.add("ClassName", tableInfo.className)
        vars.add("db_name", tableInfo.dbName)
        
        let fieldsSb = StringBuilder()
        for (field in tableInfo.fields) {
            let decorator = mapToDecorator(field.dataType, field.isNullable, field.columnName)
            let tsType = mapToTsType(field.dataType, field.isNullable)
            fieldsSb.append("  ${decorator} declare ${field.columnName}: ${tsType}\n")
        }
        
        vars.add("fields", fieldsSb.toString())
        
        let code = replaceVars(template, vars)
        let storePath = "${outputDir}/web/src/store/models/${tableInfo.dbName}/${tableInfo.tableName}.ts"
        writeFile(storePath, code)
        
        updateStoreIndex(tableInfo.dbName, tableInfo.tableName)
    }
    
    /**
     * 更新 store index.ts 导出
     */
    private func updateStoreIndex(dbName: String, tableName: String): Unit {
        let indexPath = "${outputDir}/web/src/store/models/${dbName}/index.ts"
        
        println("=== updateStoreIndex: dbName=${dbName}, tableName=${tableName}, indexPath=${indexPath} ===")
        
        if (!fileExists(indexPath)) {
            let content = "export * from './${tableName}';\n"
            println("创建新的 index.ts: ${indexPath}")
            writeFile(indexPath, content)
            return
        }
        
        println("index.ts 已存在，尝试读取: ${indexPath}")
        let existingContent: String
        try {
            let bytes = File.readFrom(indexPath)
            existingContent = String.fromUtf8(bytes)
            println("成功读取 index.ts，内容长度: ${existingContent.size}")
        } catch (e: Exception) {
            println("读取 index.ts 失败: ${e.message}")
            return
        }
        
        let exportLine = "export * from './${tableName}';"
        println("检查导出行: ${exportLine}")
        
        if (existingContent.contains(exportLine)) {
            println("导出行已存在，跳过")
            return
        }
        
        let newContent = existingContent + "\n" + exportLine + "\n"
        println("追加导出行到 index.ts")
        writeFile(indexPath, newContent)
    }
    

    // ==================== 辅助方法 ====================
    
    /**
     * 解析 handler 函数参数名，避免与数据库列名冲突
     * 默认使用 params，如果冲突则依次尝试 args、toolArgs、reqParams
     */
    private func resolveHandlerParam(tableInfo: TableInfo): String {
        let candidates = ArrayList<String>()
        candidates.add("params")
        candidates.add("args")
        candidates.add("toolArgs")
        candidates.add("reqParams")
        
        let columnNames = HashSet<String>()
        for (field in tableInfo.fields) {
            columnNames.add(field.columnName)
        }
        
        for (i in 0..candidates.size) {
            if (!columnNames.contains(candidates[i])) {
                return candidates[i]
            }
        }
        
        return "handlerInput"
    }
    
    /**
     * 获取默认值
     */
    private func getDefaultValue(dataType: String): String {
        let lowerType = dataType.toAsciiLower()
        
        if (lowerType.contains("int") || lowerType.contains("bigint") || lowerType.contains("smallint")) {
            return "0"
        } else if (lowerType.contains("float") || lowerType.contains("double") || lowerType.contains("numeric") || lowerType.contains("decimal")) {
            return "0"
        } else if (lowerType.contains("bool")) {
            return "false"
        } else {
            return "''"
        }
    }
    
    /**
     * 获取输入类型
     */
    private func getInputType(dataType: String): String {
        let lowerType = dataType.toAsciiLower()
        
        if (lowerType.contains("int") || lowerType.contains("bigint") || lowerType.contains("smallint")) {
            return "number"
        } else if (lowerType.contains("float") || lowerType.contains("double") || lowerType.contains("numeric") || lowerType.contains("decimal")) {
            if (lowerType.contains("price") || dataType.contains("money")) {
                return "price"
            }
            return "number"
        } else if (lowerType.contains("bool")) {
            return "checkbox"
        } else if (lowerType.contains("date") && !lowerType.contains("time")) {
            return "date"
        } else if (lowerType.contains("time") || lowerType.contains("timestamp")) {
            return "datetime"
        } else if (lowerType.contains("text") || lowerType.contains("json")) {
            return "textarea"
        } else {
            return "text"
        }
    }
    
    /**
     * 判断是否为数字类型
     */
    private func isNumberType(dataType: String): Bool {
        let lowerType = dataType.toAsciiLower()
        lowerType.contains("int") || lowerType.contains("float") || lowerType.contains("double") || lowerType.contains("numeric") || lowerType.contains("decimal")
    }
    
    /**
     * 判断是否为字符串类型
     */
    private func isStringType(dataType: String): Bool {
        let lowerType = dataType.toAsciiLower()
        lowerType.contains("char") || lowerType.contains("text") || lowerType.contains("varchar")
    }
    
    /**
     * 将数据库类型映射到 TypeScript 类型
     */
    private func mapToTsType(dataType: String, isNullable: String): String {
        let lowerType = dataType.toAsciiLower()
        let nullable = if (isNullable == "YES") { " | null" } else { "" }
        
        if (lowerType.contains("int") || lowerType.contains("bigint") || lowerType.contains("smallint")) {
            return "number${nullable}"
        } else if (lowerType.contains("float") || lowerType.contains("double") || lowerType.contains("numeric") || lowerType.contains("decimal")) {
            return "number${nullable}"
        } else if (lowerType.contains("bool")) {
            return "boolean${nullable}"
        } else if (lowerType.contains("date") || lowerType.contains("time") || lowerType.contains("timestamp")) {
            return "string${nullable}"
        } else if (lowerType.contains("json")) {
            return "any${nullable}"
        } else {
            return "string${nullable}"
        }
    }
    

    /**
     * 将数据库类型映射到 pinia-orm 装饰器
     */
    private func mapToDecorator(dataType: String, isNullable: String, columnName: String): String {
        let lowerType = dataType.toAsciiLower()
        
        if (columnName == "id") {
            return "@Uid()"
        }
        
        if (lowerType.contains("int") || lowerType.contains("bigint") || lowerType.contains("smallint")) {
            return "@Num(0)"
        } else if (lowerType.contains("float") || lowerType.contains("double") || lowerType.contains("numeric") || lowerType.contains("decimal")) {
            return "@Num(0)"
        } else if (lowerType.contains("bool")) {
            return "@Bool()"
        } else if (lowerType.contains("date") || lowerType.contains("time") || lowerType.contains("timestamp")) {
            return "@Attr('')"
        } else if (lowerType.contains("uuid") || columnName.endsWith("_id") || columnName == "creator") {
            return "@Uid()"
        } else if (lowerType.contains("json")) {
            return "@Str('')"
        } else {
            return "@Str('')"
        }
    }
    
    // ==================== 内置代码生成方法（模板不存在时使用）====================
    
    /**
     * 构建 index.vue 代码
     */
    private func buildIndexVueCode(tableInfo: TableInfo): String {
        let tableName = tableInfo.tableName
        let camelTableName = toCamelCase(tableName)
        let upperCamelTableName = capitalizeFirst(camelTableName)
        
        let sb = StringBuilder()
        sb.append("<script lang=\"ts\" setup>\n")
        sb.append("import { ref } from 'vue'\n")
        sb.append("import GeneralLayout from '@/layout/general-layout.vue'\n")
        sb.append("import add${upperCamelTableName} from './components/add-${tableName}.vue'\n")
        sb.append("import ${camelTableName}Table from './components/${tableName}-table.vue'\n")
        sb.append("\n")
        sb.append("const ${camelTableName}TableRef = ref()\n")
        sb.append("const isRecycleBin = ref(false)\n")
        sb.append("\n")
        sb.append("function onChange() {\n")
        sb.append("  ${camelTableName}TableRef.value.reload()\n")
        sb.append("}\n")
        sb.append("function onRemove() {\n")
        sb.append("  ${camelTableName}TableRef.value.batchRemove${upperCamelTableName}()\n")
        sb.append("}\n")
        sb.append("function onExport() {\n")
        sb.append("  ${camelTableName}TableRef.value.export${upperCamelTableName}()\n")
        sb.append("}\n")
        sb.append("\n")
        sb.append("function onRecycleBinChange(status: boolean) {\n")
        sb.append("  isRecycleBin.value = status\n")
        sb.append("}\n")
        sb.append("\n")
        sb.append("function onBatchRestore() {\n")
        sb.append("  ${camelTableName}TableRef.value.batchRestore${upperCamelTableName}()\n")
        sb.append("}\n")
        sb.append("\n")
        sb.append("function onEmptyRecycleBin() {\n")
        sb.append("  if (${camelTableName}TableRef.value && ${camelTableName}TableRef.value.emptyRecycleBin) {\n")
        sb.append("    ${camelTableName}TableRef.value.emptyRecycleBin()\n")
        sb.append("  }\n")
        sb.append("}\n")
        sb.append("\n")
        sb.append("function onBatchPermanentDelete() {\n")
        sb.append("  ${camelTableName}TableRef.value.batchRemove${upperCamelTableName}()\n")
        sb.append("}\n")
        sb.append("</script>\n")
        sb.append("\n")
        sb.append("<template>\n")
        sb.append("  <GeneralLayout :breadcrumb=\"['menu.database', '${tableInfo.dbName}.${tableName}']\">\n")
        sb.append("    <add-${tableName}\n")
        sb.append("      class=\"${tableName}-add-btn\"\n")
        sb.append("      @${tableName}-change=\"onChange\"\n")
        sb.append("      @batch-remove=\"onRemove\"\n")
        sb.append("      @export-${tableName}=\"onExport\"\n")
        sb.append("      @recycle-bin-change=\"onRecycleBinChange\"\n")
        sb.append("      @batch-restore=\"onBatchRestore\"\n")
        sb.append("      @empty-recycle-bin=\"onEmptyRecycleBin\"\n")
        sb.append("      @batch-permanent-delete=\"onBatchPermanentDelete\"\n")
        sb.append("    />\n")
        sb.append("    <${tableName}-table \n")
        sb.append("      ref=\"${camelTableName}TableRef\" \n")
        sb.append("      :recycle-bin-status=\"isRecycleBin\" \n")
        sb.append("    />\n")
        sb.append("  </GeneralLayout>\n")
        sb.append("</template>\n")
        sb.append("\n")
        sb.append("<style scoped lang=\"less\">\n")
        sb.append(".${tableName}-add-btn {\n")
        sb.append("  padding: 10px 0 24px 10px;\n")
        sb.append("}\n")
        sb.append("</style>\n")
        
        return sb.toString()
    }
    
    /**
     * 构建 add-{tableName}.vue 代码
     */
    private func buildAddVueCode(tableInfo: TableInfo): String {
        // 简化版实现
        let tableName = tableInfo.tableName
        let className = tableInfo.className
        
        let sb = StringBuilder()
        sb.append("<script lang=\"ts\" setup>\n")
        sb.append("import { ref, reactive } from 'vue'\n")
        sb.append("import { ${className} } from '@/store/models/${tableInfo.dbName}'\n")
        sb.append("import { useAxiosRepo } from '@pinia-orm/axios'\n")
        sb.append("// ... 其他导入\n")
        sb.append("</script>\n")
        sb.append("\n")
        sb.append("<template>\n")
        sb.append("  <div>add ${tableName}</div>\n")
        sb.append("</template>\n")
        
        return sb.toString()
    }
    
    /**
     * 构建 {tableName}-table.vue 代码
     */
    private func buildTableVueCode(tableInfo: TableInfo): String {
        // 简化版实现
        let tableName = tableInfo.tableName
        let className = tableInfo.className
        
        let sb = StringBuilder()
        sb.append("<script lang=\"ts\" setup>\n")
        sb.append("import { ${className} } from '@/store/models/${tableInfo.dbName}'\n")
        sb.append("import { useAxiosRepo } from '@pinia-orm/axios'\n")
        sb.append("// ... 其他导入\n")
        sb.append("</script>\n")
        sb.append("\n")
        sb.append("<template>\n")
        sb.append("  <div>${tableName} table</div>\n")
        sb.append("</template>\n")
        
        return sb.toString()
    }
    
    /**
     * 构建 edit-form.vue 代码
     */
    private func buildEditFormVueCode(tableInfo: TableInfo): String {
        // 简化版实现
        let tableName = tableInfo.tableName
        let className = tableInfo.className
        
        let sb = StringBuilder()
        sb.append("<script lang=\"ts\" setup>\n")
        sb.append("import { ${className} } from '@/store/models/${tableInfo.dbName}'\n")
        sb.append("// ... 其他导入\n")
        sb.append("</script>\n")
        sb.append("\n")
        sb.append("<template>\n")
        sb.append("  <div>edit ${tableName} form</div>\n")
        sb.append("</template>\n")
        
        return sb.toString()
    }
    
    /**
     * 构建 store model 代码
     */
    private func buildStoreModelCode(tableInfo: TableInfo): String {
        let tableName = tableInfo.tableName
        let className = tableInfo.className
        
        let sb = StringBuilder()
        sb.append("import { Model } from 'pinia-orm';\n")
        sb.append("import { Attr, Str, Uid, Num, Bool } from 'pinia-orm/decorators';\n")
        sb.append("import { useAxiosRepo } from '@pinia-orm/axios';\n")
        sb.append("\n")
        sb.append("const apiURL = import.meta.env.VITE_BACKEND_URL || 'https://localhost:443';\n")
        sb.append("\n")
        sb.append("export class ${tableName} extends Model {\n")
        sb.append("  static override entity = '${tableName}'\n")
        sb.append("\n")
        
        for (field in tableInfo.fields) {
            let decorator = mapToDecorator(field.dataType, field.isNullable, field.columnName)
            let tsType = mapToTsType(field.dataType, field.isNullable)
            sb.append("  ${decorator} declare ${field.columnName}: ${tsType}\n")
        }
        
        sb.append("\n")
        sb.append("  static override config = {\n")
        sb.append("    axiosApi: {\n")
        sb.append("      actions: {\n")
        sb.append("        // API methods...\n")
        sb.append("      }\n")
        sb.append("    }\n")
        sb.append("  }\n")
        sb.append("}\n")
        
        return sb.toString()
    }
    
    // ==================== 文件操作辅助方法 ====================
    
    /**
     * 检查文件是否存在
     */
    private func fileExists(path: String): Bool {
        return exists(path)
    }
    
    /**
     * 检查目录是否存在
     */
    private func dirExists(path: String): Bool {
        return exists(path)
    }
    
    /**
     * 写入文件
     */
    private func writeFile(path: String, content: String): Unit {
        let p = Path(path)
        let parentPath = p.parent
        try {
            Directory.create(parentPath, recursive: true)
        } catch (e: Exception) {
            // 目录已存在,忽略错误
        }
        
        try {
            File.writeTo(path, content.toArray())
            println("生成文件: ${path}")
        } catch (e: Exception) {
            println("写入文件失败 ${path}: ${e.message}")
        }
    }
}
