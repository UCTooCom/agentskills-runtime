/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.fs.exists
import std.time.DateTime
import f_orm.{ORM, SqlExecutor}
import magic.app.models.uctoo.DbInfoPO
import magic.app.models.uctoo.PermissionsPO
import magic.app.models.uctoo.I18PO

/**
 * 表字段信息（db_info 行）
 */
public class FieldInfo {
    public var columnName: String = ""
    public var dataType: String = ""
    public var isNullable: String = ""
    public var columnDefault: ?String = None<String>
    public var ordinalPosition: Int32 = 0
    /// 列注释（db_info.column_comment）。契约骨架生成用；CRUD 模板不使用。
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
 * PluginGenerator - 插件生成器（PS-T013）
 *
 * 从 db_info 读表结构，按模板集生成"三维一体"插件目录 skills/{name}/：
 *   SKILL.md + plugin.yaml + scripts/cj/（PO/DAO/Service/Controller/Route/Plugin 入口）
 * 产物经 build-sync（PS-T015）同步到 src/plugins/{name} 参与编译，
 * 包名 magic.plugins.{name}（design.md §2.6 包名规范）。
 *
 * 与 crudgen 双通道并行：crudgen 生成宿主模块到 src/app（存量轨），
 * plugingen 生成插件到 skills/（插件轨），互不干扰。
 */
public class PluginGenerator {
    private let rules = NameRules()
    private let builder = FieldCodeBuilder()
    private let templateEngine = TemplateEngine()
    private let templatesDir: String

    /// 插件根输出目录（canonical 源码路径，见 design.md §2.7）
    private let skillsRoot: String = "./skills"

    /// 宿主插件加载清单路径
    private let pluginsYamlPath: String = "./config/plugins.yaml"

    public init(templatesDir!: String = "./src/plugin/tools/plugingen/templates") {
        this.templatesDir = templatesDir
    }

    /// 从 db_info 读取表结构
    public func readTableInfo(dbName: String, tableName: String): TableInfo {
        let tableInfo = TableInfo()
        tableInfo.tableName = tableName
        tableInfo.dbName = dbName
        tableInfo.className = rules.toPascalCase(tableName)

        let executor = ORM.executor()
        let sql = """
            SELECT *
            FROM db_info
            WHERE table_catalog = '${dbName}' AND table_name = '${tableName}'
            ORDER BY ordinal_position
        """
        let results = executor.setSql(sql).list<DbInfoPO>()
        for (dbInfo in results) {
            let field = FieldInfo()
            field.columnName = dbInfo.columnName
            field.dataType = dbInfo.dataType ?? ""
            field.isNullable = dbInfo.isNullable
            field.columnDefault = dbInfo.columnDefault
            field.ordinalPosition = dbInfo.ordinalPosition
            field.columnComment = dbInfo.columnComment ?? ""
            tableInfo.fields.add(field)
        }
        return tableInfo
    }

    /**
     * 生成 CRUD 插件（多表聚合模式，对齐 crudgen 的「保护区 + 公共产物幂等追加」行为）
     *
     * 行为契约（对应方案 B 三特性）：
     *  1) 一次传入多张表 → 逐表生成 CRUD 五层 + 聚合入口/路由 + 公共产物（plugin.yaml/SKILL.md/cjpm.toml/pkg.cj）。
     *  2) 再次传入相同插件名 + 不同表 → 仅对新表生成五层，公共产物（含表清单）追加新表，不覆盖旧表信息。
     *  3) 再次传入相同插件名 + 相同表 → 仅覆盖该表五层 AutoCreateCode 保护区内容（保留二开），公共产物表名不重复。
     *
     * 实现要点：
     *  - 读已有聚合路由中的 `// table:` 标记还原历史表清单，与本次请求表清单去重保序合并；
     *  - 各表 PO/DAO/Service/Controller/Route 文件名含表名（{{className}}），天然累积；逐表 updateFile 只覆盖保护区；
     *  - plugin.yaml/SKILL.md/聚合 Plugin/Route 基于合并表清单整体重渲（updateFile 保留二开保护区）；
     *  - config/plugins.yaml 仅登记一个聚合入口/路由（宿主每插件仅注册单一 entry/routeClass）。
     *
     * @param name 插件名（已规范化）
     * @param dbName 数据库名
     * @param tableNames 表名数组（≥1）
     * @return 成功与否
     */
    public func generateCrudPlugin(name: String, dbName: String, tableNames: Array<String>): Bool {
        if (tableNames.isEmpty()) {
            println("错误: 表驱动模式至少需要一个 --table / --tables 参数")
            return false
        }
        let pluginDir = "${skillsRoot}/${name}"
        let cjDir = "${pluginDir}/src"
        let pkgName = "skill_${name}"

        // 1. 还原历史表清单 + 与本次请求去重保序合并
        let existingTables = this.readExistingTables(pluginDir, name)
        let mergedTables = this.mergeTableList(existingTables, tableNames)

        // 2. 逐表生成 CRUD 五层（仅本次请求表；已有表靠 AutoCreateCode 保护区保留二开）
        for (tableName in tableNames) {
            let tableInfo = this.readTableInfo(dbName, tableName)
            if (tableInfo.fields.isEmpty()) {
                println("错误: 表 ${dbName}.${tableName} 在 db_info 中无字段记录")
                println("请先执行 npm run loadDbInfo ${dbName} 刷新数据库信息")
                return false
            }
            let className = tableInfo.className
            let variables = this.buildVariables(name, tableInfo)
            this.writeRendered(variables, "Model.cj.tpl", "${cjDir}/${className}PO.cj")
            this.writeRendered(variables, "DAO.cj.tpl", "${cjDir}/${className}DAO.cj")
            this.writeRendered(variables, "Service.cj.tpl", "${cjDir}/${className}Service.cj")
            this.writeRendered(variables, "Controller.cj.tpl", "${cjDir}/${className}Controller.cj")
            this.writeRendered(variables, "Route.cj.tpl", "${cjDir}/${className}Route.cj")
        }

        // 3. 聚合入口 Plugin + 聚合路由 Route（基于合并表清单整体重渲，保护区保留二开）
        let aggVars = this.buildAggregateVariables(name, dbName, mergedTables)
        let aggClassName = rules.toPascalCase(name)
        this.writeRendered(aggVars, "pkg.cj.tpl", "${cjDir}/pkg.cj")
        this.writeRendered(aggVars, "PluginAggregateEntry.cj.tpl", "${cjDir}/${aggClassName}Plugin.cj")
        this.writeRendered(aggVars, "RouteAggregate.cj.tpl", "${cjDir}/${aggClassName}Route.cj")

        // 4. 公共产物：plugin.yaml / SKILL.md（聚合元数据，整体重渲幂等）
        this.writeRendered(aggVars, "plugin.yaml.aggregate.tpl", "${pluginDir}/plugin.yaml")
        this.writeRendered(aggVars, "SKILL.md.aggregate.tpl", "${pluginDir}/SKILL.md")

        // 5. 独立 cjpm 包配置（workspace 成员模式，与表无关，幂等覆盖）
        this.writeCjpmToml(name, "${pluginDir}/cjpm.toml")

        println("插件 ${name} 生成完成：${pluginDir}/（包名 ${pkgName}，合并表清单：${mergedTables}）")
        println("独立编译：cd ${pluginDir} && cjpm build → target/release/libskill_${name}.so")
        println("宿主加载：经 PluginHostManager 加载聚合入口 ${pkgName}.${aggClassName}Plugin")

        // 6. 追加宿主 workspace members（若尚未包含）
        this.appendWorkspaceMember(name)

        // 7. 追加/更新宿主加载清单条目（聚合入口 + 聚合路由）
        this.appendPluginsYamlEntry(name, "${pkgName}.${aggClassName}Plugin", "${pkgName}.${aggClassName}Route")

        // 8. 生成 permissions 菜单节点 + i18 多语言数据（按本次请求表幂等，已有表节点跳过）
        // 权限结构：database -> database.{dbName} -> database.{dbName}.{tableName}
        for (tableName in tableNames) {
            this.generatePermissionNodes(dbName, tableName)
        }
        return true
    }

    /// 还原已有插件已生成的表清单（解析聚合路由中的 `// table:` 标记，避免依赖逆向 PascalCase）
    private func readExistingTables(pluginDir: String, name: String): Array<String> {
        let cjDir = "${pluginDir}/src"
        let aggRouteFile = "${cjDir}/${rules.toPascalCase(name)}Route.cj"
        let result = ArrayList<String>()
        if (!exists(aggRouteFile)) {
            return result.toArray()
        }
        let content = templateEngine.readText(aggRouteFile)
        for (line in content.split("\n")) {
            let t = line.trimAscii()
            if (t.startsWith("// table: ")) {
                let tbl = t["// table: ".size..].trimAscii()
                if (!tbl.isEmpty() && !result.contains(tbl)) {
                    result.add(tbl)
                }
            }
        }
        return result.toArray()
    }

    /// 去重保序合并：历史表在前（保持顺序），新请求中未出现的追加在后
    private func mergeTableList(existing: Array<String>, requested: Array<String>): Array<String> {
        let result = ArrayList<String>()
        for (t in existing) {
            if (!result.contains(t)) {
                result.add(t)
            }
        }
        for (t in requested) {
            if (!result.contains(t)) {
                result.add(t)
            }
        }
        return result.toArray()
    }

    /// 汇总聚合模板变量（公共产物与聚合入口/路由用，含表清单驱动的循环体）
    private func buildAggregateVariables(name: String, dbName: String, tableNames: Array<String>): HashMap<String, String> {
        let variables = HashMap<String, String>()
        variables.add("name", name)
        variables.add("dbName", dbName)
        variables.add("aggregateClassName", rules.toPascalCase(name))

        let sbTables = StringBuilder()
        let sbRoutes = StringBuilder()
        let sbInline = StringBuilder()
        let sbList = StringBuilder()
        var firstClassName = ""
        var idx = 0
        for (t in tableNames) {
            let c = rules.toPascalCase(t)
            if (idx == 0) {
                firstClassName = c
            }
            sbTables.append("  - ${t}\n")
            sbRoutes.append("  - skill_${name}.${c}Route\n")
            if (idx > 0) {
                sbInline.append(", ")
            }
            sbInline.append(t)
            sbList.append("  - **${t}**: `POST/GET /api/v1/${dbName}/${t}/...`（服务类 `${c}Service`）\n")
            idx += 1
        }
        variables.add("tablesDecl", sbTables.toString())
        variables.add("tableWhitelistDecl", sbTables.toString())
        variables.add("routesDecl", sbRoutes.toString())
        variables.add("tablesInline", sbInline.toString())
        variables.add("tablesList", sbList.toString())
        variables.add("firstControllerClass", firstClassName)
        variables.add("onLoadBody", this.buildAggregateOnLoadBody(name, tableNames))
        variables.add("routeRegisterBody", this.buildAggregateRouteBody(tableNames))
        return variables
    }

    /// 聚合 Plugin.onLoad 体：循环装配所有表的 Service 并接线 Controller（接线点模式）
    private func buildAggregateOnLoadBody(name: String, tableNames: Array<String>): String {
        let sb = StringBuilder()
        for (t in tableNames) {
            let c = rules.toPascalCase(t)
            sb.append("        // table: ${t}\n")
            sb.append("        {\n")
            sb.append("            let service = ${c}Service()\n")
            sb.append("            ${c}Controller.wiredService = Some(service)\n")
            sb.append("            context.onCleanup({ =>\n")
            sb.append("                ${c}Controller.wiredService = None\n")
            sb.append("            })\n")
            sb.append("            LogUtils.info(\"[${name}Plugin] wired ${t}\")\n")
            sb.append("        }\n")
        }
        return sb.toString()
    }

    /// 聚合 Route.register 体：循环委托各表 Route 注册其 8 条 V4 CRUD 路由
    private func buildAggregateRouteBody(tableNames: Array<String>): String {
        let sb = StringBuilder()
        for (t in tableNames) {
            let c = rules.toPascalCase(t)
            sb.append("            // table: ${t}\n")
            sb.append("            {\n")
            sb.append("                let ctrl = ${c}Controller()\n")
            sb.append("                ${c}Route().register(r, ctrl)\n")
            sb.append("            }\n")
        }
        return sb.toString()
    }

    /**
     * 生成 L3 进程隔离轨插件（--mode process）
     *
     * 产出独立 cjpm executable 工程（design §5.3）：
     * - cjpm.toml: output-type = "executable"，依赖 ystyle::cordis_plugin + jsonvalue
     * - src/main.cj: PluginRuntime.run(...) 显式 API 入口（禁用 @Plugin 宏）
     * - src/handlers.cj: V4 CRUD RPC handler 框架
     * - src/effects.cj: ctx.effect 可逆效果注册框架
     * - plugin.yaml: mode: process + command 指向编译产物
     * - SKILL.md: 技能定义
     *
     * @param name 插件名（已规范化）
     * @return 成功与否
     */
    public func generateProcessPlugin(name: String): Bool {
        let className = rules.toPascalCase(name)
        let pkgName = "skill_${name}"
        let pluginDir = "${skillsRoot}/${name}"
        let cjDir = "${pluginDir}/src"

        let variables = HashMap<String, String>()
        variables.add("name", name)
        variables.add("className", className)
        variables.add("pkgName", pkgName)

        // 1. 技能与清单
        this.writeRendered(variables, "SKILL.md.tpl", "${pluginDir}/SKILL.md")
        this.writeProcessPluginYaml(name, className, pluginDir)

        // 2. 独立 cjpm executable 工程配置
        this.writeProcessCjpmToml(name, pluginDir)

        // 3. 仓颉源码（PluginRuntime.run 显式入口，禁用 @Plugin 宏）
        this.writeProcessMain(name, className, pkgName, cjDir)
        this.writeProcessHandlers(name, className, pkgName, cjDir)
        this.writeProcessEffects(name, className, pkgName, cjDir)

        // 4. README（第三方开发者手册）
        this.writeProcessReadme(name, pluginDir)

        println("L3 进程轨插件 ${name} 生成完成：${pluginDir}/")
        println("独立编译：cd ${pluginDir} && cjpm build → target/release/skill_${name}.exe")
        println("放置 + plugins.yaml 登记即生效（不重编宿主、不重启宿主）")
        return true
    }

    /// 写入 process 轨 plugin.yaml（mode: process + command）
    ///
    /// §14.1 同步（2026-09-15）：与宿主实际解析的 `plugin_config.cj` 对齐——
    /// 删除无解析逻辑的 `protocol`（避免误导为可切换传输层），
    /// 显式化 enabled/autoRestart/order，并补上功能必需的 `tableWhitelist` 占位。
    private func writeProcessPluginYaml(name: String, className: String, pluginDir: String): Unit {
        let sb = StringBuilder()
        sb.append("name: ${name}\n")
        sb.append("version: 1.0.0\n")
        sb.append("mode: process\n")
        // command 是相对**宿主工作目录**的路径（CordisHostManager.resolvePluginCommand
        // 直接 `${cwd}/${command}`，无校验、无兜底），必须带 skills/{name}/ 前缀，
        // 否则开发态（cwd=仓库根）与发布态（cwd=bin）都定位不到 exe。
        sb.append("command: ./skills/${name}/target/release/bin/skill_${name}.exe\n")
        sb.append("description: L3 进程隔离轨插件 ${name}\n")
        sb.append("enabled: true\n")
        sb.append("order: 10\n")
        sb.append("autoRestart: true\n")
        // 空白骨架不连 DB，无法自动得知需要哪些表；此处留空并提示——
        // 一旦本插件开始经 ctx.invoke("host.db", ...) 访问数据，必须补齐，否则调用被拒。
        sb.append("# TODO: 本插件需访问的表（未列入的表 host.db 调用会被宿主拒绝）\n")
        sb.append("tableWhitelist: []\n")
        sb.append("routes:\n")
        sb.append("  - method: POST\n")
        sb.append("    path: /api/v1/${name}/add\n")
        sb.append("  - method: POST\n")
        sb.append("    path: /api/v1/${name}/edit\n")
        sb.append("  - method: POST\n")
        sb.append("    path: /api/v1/${name}/del\n")
        sb.append("  - method: GET\n")
        sb.append("    path: /api/v1/${name}/list\n")
        templateEngine.writeFile("${pluginDir}/plugin.yaml", sb.toString())
        println("已生成: ${pluginDir}/plugin.yaml")
    }

    /// 写入 process 轨 cjpm.toml（独立 executable 工程）
    private func writeProcessCjpmToml(name: String, pluginDir: String): Unit {
        let pkgName = "skill_${name}"
        let sb = StringBuilder()
        sb.append("[package]\n")
        sb.append("  cjc-version = \"1.1.3\"\n")
        sb.append("  compile-option = \"--dy-std -Woff all\"\n")
        sb.append("  description = \"L3 进程隔离轨插件 ${name}（独立 executable 工程）\"\n")
        sb.append("  link-option = \"\"\n")
        sb.append("  name = \"${pkgName}\"\n")
        sb.append("  output-type = \"executable\"\n")
        sb.append("  src-dir = \"src\"\n")
        sb.append("  target-dir = \"target\"\n")
        sb.append("  version = \"1.0.0\"\n")
        sb.append("  package-configuration = {}\n")
        sb.append("  scripts = {}\n")
        sb.append("\n")
        sb.append("[dependencies]\n")
        sb.append("  \"ystyle::cordis_plugin\" = { path = \"../../libs/cordis-cj/cordis_plugin\" }\n")
        sb.append("  \"ystyle::cordis_core\" = { path = \"../../libs/cordis-cj/cordis_core\" }\n")
        sb.append("  \"jsonvalue\" = { path = \"../../libs/jsonvalue\" }\n")
        sb.append("  \"ystyle::jsonrpc\" = { path = \"../../libs/jsonrpc\" }\n")
        templateEngine.writeFile("${pluginDir}/cjpm.toml", sb.toString())
        println("已生成: ${pluginDir}/cjpm.toml")
    }

    /// 写入 process 轨 main.cj（PluginRuntime.run 显式入口）
    private func writeProcessMain(
        name: String,
        className: String,
        pkgName: String,
        cjDir: String
    ): Unit {
        let sb = StringBuilder()
        sb.append("/*\n")
        sb.append(" * L3 进程隔离轨插件 ${name} 入口\n")
        sb.append(" * 禁用 @Plugin 宏（cjpm 宏包 organization 跨模块缺陷）\n")
        sb.append(" * 显式 API：PluginRuntime.run(...)\n")
        sb.append(" */\n")
        sb.append("package ${pkgName}\n\n")
        sb.append("import ystyle::cordis_plugin.{PluginRuntime, PluginContext}\n")
        sb.append("import jsonvalue.*\n\n")
        sb.append("main(): Int64 {\n")
        sb.append("    // stdout 是 JSON-RPC 协议通道（NewlineFraming 逐行解析），诊断信息必须走 stderr\n")
        sb.append("    eprintln(\"[skill_${name}] L3 process plugin starting\")\n")
        sb.append("    let inject = Array<String>(0, { _ => \"\" })\n")
        sb.append("    let provide = Array<String>(0, { _ => \"\" })\n")
        sb.append("    PluginRuntime.run(\n")
        sb.append("        \"${name}\",\n")
        sb.append("        inject,\n")
        sb.append("        provide,\n")
        sb.append("        { ctx =>\n")
        sb.append("            ${className}Handlers.register(ctx)\n")
        sb.append("            ${className}Effects.register(ctx)\n")
        sb.append("        }\n")
        sb.append("    )\n")
        sb.append("    return 0\n")
        sb.append("}\n")
        templateEngine.writeFile("${cjDir}/main.cj", sb.toString())
        println("已生成: ${cjDir}/main.cj")
    }

    /// 写入 process 轨 handlers.cj（V4 CRUD RPC handler 框架）
    private func writeProcessHandlers(
        name: String,
        className: String,
        pkgName: String,
        cjDir: String
    ): Unit {
        let sb = StringBuilder()
        sb.append("/*\n")
        sb.append(" * V4 CRUD RPC handler 框架（${name}）\n")
        sb.append(" */\n")
        sb.append("package ${pkgName}\n\n")
        sb.append("import ystyle::cordis_plugin.PluginContext\n")
        sb.append("import jsonvalue.*\n\n")
        sb.append("public class ${className}Handlers {\n")
        sb.append("    public static func register(ctx: PluginContext): Unit {\n")
        sb.append("        // V4 CRUD: add/edit/del/get/list\n")
        sb.append("        // 注册 API 见 plugin_runtime.cj:52 registerHandler(key, (String, Array<JsonValue>) -> JsonValue)\n")
        sb.append("        // 请求体位于 args[0]（JsonValue），method 为调用方传入的路由键\n")
        sb.append("        ctx.registerHandler(\"${name}/add\", { method, args => ${className}Handlers.handleAdd(args[0]) })\n")
        sb.append("        ctx.registerHandler(\"${name}/edit\", { method, args => ${className}Handlers.handleEdit(args[0]) })\n")
        sb.append("        ctx.registerHandler(\"${name}/del\", { method, args => ${className}Handlers.handleDel(args[0]) })\n")
        sb.append("        ctx.registerHandler(\"${name}/get\", { method, args => ${className}Handlers.handleGet(args[0]) })\n")
        sb.append("        ctx.registerHandler(\"${name}/list\", { method, args => ${className}Handlers.handleList(args[0]) })\n")
        sb.append("    }\n\n")
        sb.append("    private static func handleAdd(req: JsonValue): JsonValue {\n")
        sb.append("        // TODO: 实现 add 逻辑\n")
        sb.append("        // 经 ctx.invoke(\"host.db\", ...) 访问宿主数据库\n")
        sb.append("        return ${className}Handlers.okResult(\"add\")\n")
        sb.append("    }\n\n")
        sb.append("    private static func handleEdit(req: JsonValue): JsonValue {\n")
        sb.append("        // TODO: 实现 edit 逻辑\n")
        sb.append("        return ${className}Handlers.okResult(\"edit\")\n")
        sb.append("    }\n\n")
        sb.append("    private static func handleDel(req: JsonValue): JsonValue {\n")
        sb.append("        // TODO: 实现 del 逻辑\n")
        sb.append("        return ${className}Handlers.okResult(\"del\")\n")
        sb.append("    }\n\n")
        sb.append("    private static func handleGet(req: JsonValue): JsonValue {\n")
        sb.append("        // TODO: 实现 get 逻辑\n")
        sb.append("        return ${className}Handlers.okResult(\"get\")\n")
        sb.append("    }\n\n")
        sb.append("    private static func handleList(req: JsonValue): JsonValue {\n")
        sb.append("        // TODO: 实现 list 逻辑\n")
        sb.append("        // V4 列表格式: { currentPage, totalCount, totalPage, entitys }\n")
        sb.append("        return ${className}Handlers.okResult(\"list\")\n")
        sb.append("    }\n\n")
        sb.append("    private static func okResult(op: String): JsonValue {\n")
        sb.append("        let m = HashMap<String, JsonValue>()\n")
        sb.append("        m[\"errno\"] = JsonValue.fromDataModel(DataModelInt64(0))\n")
        sb.append("        m[\"errmsg\"] = JsonValue.fromDataModel(DataModelString(\"ok\"))\n")
        sb.append("        m[\"op\"] = JsonValue.fromDataModel(DataModelString(op))\n")
        sb.append("        return JsonValue.fromObject(m)\n")
        sb.append("    }\n")
        sb.append("}\n")
        templateEngine.writeFile("${cjDir}/handlers.cj", sb.toString())
        println("已生成: ${cjDir}/handlers.cj")
    }

    /// 写入 process 轨 effects.cj（ctx.effect 可逆效果注册框架）
    private func writeProcessEffects(
        name: String,
        className: String,
        pkgName: String,
        cjDir: String
    ): Unit {
        let sb = StringBuilder()
        sb.append("/*\n")
        sb.append(" * ctx.effect 可逆效果注册框架（${name}）\n")
        sb.append(" * 卸载时逆序执行已注册的清理效果\n")
        sb.append(" */\n")
        sb.append("package ${pkgName}\n\n")
        sb.append("import ystyle::cordis_plugin.PluginContext\n")
        sb.append("import jsonvalue.*\n\n")
        sb.append("public class ${className}Effects {\n")
        sb.append("    public static func register(ctx: PluginContext): Unit {\n")
        sb.append("        // effect(disposer, label): 插件卸载时逆序执行 disposer 清理资源（plugin_runtime.cj:82）\n")
        sb.append("        ctx.effect({\n")
        sb.append("            // 逆向执行：清理资源（卸载时调用）\n")
        sb.append("            // TODO: 注册资源清理逻辑\n")
        sb.append("        }, label: \"${name}/cleanup\")\n")
        sb.append("    }\n")
        sb.append("}\n")
        templateEngine.writeFile("${cjDir}/effects.cj", sb.toString())
        println("已生成: ${cjDir}/effects.cj")
    }

    /// 写入 process 轨 README.md（第三方开发者手册）
    private func writeProcessReadme(name: String, pluginDir: String): Unit {
        let sb = StringBuilder()
        sb.append("# ${name} 插件（L3 进程隔离轨）\n\n")
        sb.append("独立 cjpm executable 工程，对标 DeepSeek Harness Cordis 的进程隔离插件轨。\n\n")
        sb.append("## 编译\n\n")
        sb.append("```bash\n")
        sb.append("cd ${pluginDir}\n")
        sb.append("cjpm build\n")
        sb.append("```\n\n")
        sb.append("产物：`target/release/skill_${name}.exe`\n\n")
        sb.append("## 登记到宿主\n\n")
        sb.append("在宿主 `config/plugins.yaml` 追加：\n\n")
        sb.append("```yaml\n")
        sb.append("plugins:\n")
        sb.append("  - name: ${name}\n")
        sb.append("    mode: process\n")
        sb.append("    command: ./skills/${name}/target/release/skill_${name}.exe\n")
        sb.append("    enabled: true\n")
        sb.append("    autoRestart: true\n")
        sb.append("```\n\n")
        sb.append("## 约束\n\n")
        sb.append("- 依赖仅 `ystyle::cordis_plugin` + `jsonvalue`（+仓颉标准库）——零 magic 包依赖\n")
        sb.append("- 禁用 `@Plugin` 宏：用显式 API `PluginRuntime.run(...)`\n")
        sb.append("- 数据访问一律经 `host.db` 服务代理（不直连数据库）\n")
        sb.append("- 独立 `cjpm build` 产出可执行文件，放置 + plugins.yaml 登记即生效\n")
        templateEngine.writeFile("${pluginDir}/README.md", sb.toString())
        println("已生成: ${pluginDir}/README.md")
    }

    /**
     * 生成空白插件骨架（--blank 模式）
     *
     * @param name 插件名（已规范化）
     * @return 成功与否
     */
    public func generateBlankPlugin(name: String): Bool {
        let className = rules.toPascalCase(name)
        let pkgName = "skill_${name}"
        let cjDir = "${skillsRoot}/${name}/src"
        let variables = HashMap<String, String>()
        variables.add("name", name)
        variables.add("dbName", "")
        variables.add("tableName", name)
        variables.add("className", className)
        variables.add("tablesDecl", "  # （暂无表依赖，接入数据表后在此登记）")
        variables.add("routesDecl", "  # （暂无路由，添加 Route 类后在此登记）")
        variables.add("onLoadBody",
            "        // TODO: 在此组装服务并注册（参考 doc-helper 插件接线点模式）\n" +
            "        LogUtils.info(\"[${className}Plugin] loaded (blank skeleton)\")")

        this.writeRendered(variables, "SKILL.md.tpl", "${skillsRoot}/${name}/SKILL.md")
        this.writeRendered(variables, "plugin.yaml.tpl", "${skillsRoot}/${name}/plugin.yaml")
        this.writeCjpmToml(name, "${skillsRoot}/${name}/cjpm.toml")
        this.writeRendered(variables, "pkg.cj.tpl", "${cjDir}/pkg.cj")
        this.writeRendered(variables, "PluginEntry.cj.tpl", "${cjDir}/${className}Plugin.cj")

        println("空白插件 ${name} 生成完成：${skillsRoot}/${name}/（包名 ${pkgName}）")
        println("独立编译：cd ${skillsRoot}/${name} && cjpm build → target/release/libskill_${name}.so")

        this.appendWorkspaceMember(name)
        this.appendPluginsYamlEntry(name, "${pkgName}.${className}Plugin", "")
        return true
    }

    /// 渲染模板并写入目标路径
    private func writeRendered(variables: HashMap<String, String>, tplName: String, targetPath: String): Unit {
        let template = templateEngine.loadTemplate("${templatesDir}/${tplName}")
        if (template.isEmpty()) {
            println("警告: 模板 ${tplName} 加载失败（${templatesDir}/${tplName}），跳过 ${targetPath}")
            return
        }
        let content = templateEngine.replaceVariables(template, variables)
        templateEngine.updateFile(targetPath, content)
        println("已生成: ${targetPath}")
    }

    /// 汇总模板变量（静态变量 + 字段构建变量，表结构只读一次）
    private func buildVariables(name: String, tableInfo: TableInfo): HashMap<String, String> {
        let variables = HashMap<String, String>()
        let tableName = tableInfo.tableName
        let fields = tableInfo.fields
        let className = tableInfo.className

        variables.add("name", name)
        variables.add("dbName", tableInfo.dbName)
        variables.add("tableName", tableName)
        variables.add("className", className)
        variables.add("tablesDecl", "  - ${tableName}")
        variables.add("routesDecl", "  - skill_${name}.${className}Route")
        variables.add("onLoadBody", this.crudOnLoadBody(className))

        variables.add("fieldDefinitions", builder.fieldDefinitions(fields, tableName))
        variables.add("constructorParams", builder.constructorParams(fields, tableName))
        variables.add("constructorAssignments", builder.constructorAssignments(fields, tableName))
        variables.add("toJsonMappings", builder.toJsonMappings(fields, tableName))
        variables.add("insertColumns", builder.insertColumns(fields))
        variables.add("insertValues", builder.insertValues(fields, tableName))
        variables.add("selectColumns", builder.selectColumns(fields))
        variables.add("updateSets", builder.updateSets(fields, tableName))
        variables.add("creatorCheckCode", builder.creatorCheckCode(fields))
        variables.add("fieldMergeCode", builder.fieldMergeCode(fields, tableName))
        variables.add("fieldMappingCode", builder.fieldMappingCode(fields, tableName, className))
        return variables
    }

    /// CRUD 插件 onLoad 体：组装 Service 并接线 Controller（接线点模式）
    private func crudOnLoadBody(className: String): String {
        let sb = StringBuilder()
        sb.append("        // 组装 Service/Controller（接线点模式：激活注入，停用清空）\n")
        sb.append("        let service = ${className}Service()\n")
        sb.append("        ${className}Controller.wiredService = Some(service)\n")
        sb.append("        context.onCleanup({ =>\n")
        sb.append("            ${className}Controller.wiredService = None\n")
        sb.append("        })\n")
        sb.append("        LogUtils.info(\"[${className}Plugin] loaded: service wired\")")
        return sb.toString()
    }

    /// 写入独立 cjpm 包配置（workspace 成员模式）
    private func writeCjpmToml(name: String, targetPath: String): Unit {
        let pkgName = "skill_${name}"
        let content = StringBuilder()
        content.append("[package]\n")
        content.append("  cjc-version = \"1.0.5\"\n")
        content.append("  compile-option = \"-O2 --dy-std -Woff all\"\n")
        content.append("  description = \"${name} 插件（workspace 成员模式，独立动态库）\"\n")
        content.append("  link-option = \"\"\n")
        content.append("  name = \"${pkgName}\"\n")
        content.append("  output-type = \"dynamic\"\n")
        content.append("  src-dir = \"src\"\n")
        content.append("  target-dir = \"target\"\n")
        content.append("  version = \"1.0.0\"\n")
        content.append("  package-configuration = {}\n")
        content.append("  scripts = {}\n")
        content.append("\n")
        content.append("[dependencies]\n")
        content.append("  plugin_spi = { path = \"../../libs/plugin-spi\" }\n")
        content.append("  f_orm = { path = \"../../libs/fountain/f_orm\" }\n")
        content.append("  f_data = { path = \"../../libs/fountain/f_data\" }\n")
        content.append("  f_base = { path = \"../../libs/fountain/f_base\" }\n")
        content.append("  f_bean = { path = \"../../libs/fountain/f_bean\" }\n")
        content.append("  f_macros = { path = \"../../libs/fountain/f_macros\" }\n")
        content.append("  f_exception = { path = \"../../libs/fountain/f_exception\" }\n")
        content.append("  f_log = { path = \"../../libs/fountain/f_log\" }\n")
        content.append("  f_collection = { path = \"../../libs/fountain/f_collection\" }\n")
        content.append("  f_cache = { path = \"../../libs/fountain/f_cache\" }\n")
        content.append("  f_concurrent = { path = \"../../libs/fountain/f_concurrent\" }\n")
        content.append("  f_regex = { path = \"../../libs/fountain/f_regex\" }\n")
        content.append("  f_time = { path = \"../../libs/fountain/f_time\" }\n")
        content.append("  f_aspect = { path = \"../../libs/fountain/f_aspect\" }\n")
        content.append("  f_config = { path = \"../../libs/fountain/f_config\" }\n")
        content.append("  f_util = { path = \"../../libs/fountain/f_util\" }\n")
        content.append("  f_mockdb = { path = \"../../libs/fountain/f_mockdb\" }\n")
        content.append("  f_pool = { path = \"../../libs/fountain/f_pool\" }\n")
        content.append("  charset4cj = { path = \"../../libs/charset4cj\" }\n")
        content.append("  json4cj = { path = \"../../libs/json4cj\" }\n")
        content.append("  magic = { path = \"../../\" }\n")
        content.append("\n")
        content.append("#----------------------------------------\n")
        content.append("#  Setting cangjie-stdx\n")
        content.append("#----------------------------------------\n")
        content.append("[target.x86_64-unknown-linux-gnu.bin-dependencies]\n")
        content.append("  path-option = [\"../../libs/cangjie-stdx-linux-x64-1.0.5.1/linux_x86_64_cjnative/dynamic/stdx\"]\n")
        content.append("\n")
        content.append("[target.x86_64-unknown-windows-gnu.bin-dependencies]\n")
        content.append("  path-option = [\"../../libs/cangjie-stdx-windows-x64-1.0.5.1/windows_x86_64_cjnative/dynamic/stdx\"]\n")
        content.append("\n")
        content.append("[target.x86_64-w64-mingw32.bin-dependencies]\n")
        content.append("  path-option = [\"../../libs/cangjie-stdx-windows-x64-1.0.5.1/windows_x86_64_cjnative/dynamic/stdx\"]\n")
        content.append("\n")
        content.append("[target.aarch64-unknown-linux-gnu.bin-dependencies]\n")
        content.append("  path-option = [\"../../libs/cangjie-stdx-linux-aarch64-1.0.5.1/linux_aarch64_cjnative/dynamic/stdx\"]\n")
        content.append("\n")
        content.append("[target.aarch64-apple-darwin.bin-dependencies]\n")
        content.append("  path-option = [\"../../libs/cangjie-stdx-mac-aarch64-1.0.5.1/darwin_aarch64_cjnative/dynamic/stdx\"]\n")
        templateEngine.writeFile(targetPath, content.toString())
        println("已生成: ${targetPath}")
    }

    /// 追加宿主 workspace members（若尚未包含）
    private func appendWorkspaceMember(name: String): Unit {
        let hostTomlPath = "./cjpm.toml"
        if (!exists(hostTomlPath)) {
            println("提示: ${hostTomlPath} 不存在，请手动追加 workspace 成员：")
            println("  [workspace]")
            println("    members = [\"./skills/${name}\"]")
            return
        }
        let content = templateEngine.readText(hostTomlPath)
        let memberPath = "\"./skills/${name}\""
        if (content.contains(memberPath)) {
            println("宿主 cjpm.toml workspace members 已含 ${name}，跳过追加")
            return
        }
        // 查找 members 行，追加新成员
        let membersMarker = "members = ["
        if (let Some(idx) <- content.indexOf(membersMarker)) {
            let beforeMembers = content[0..idx]
            let fromMembers = content[idx..]
            // 找到 members 数组的闭合 ]
            if (let Some(closeIdx) <- fromMembers.indexOf("]")) {
                let membersContent = fromMembers[0..closeIdx]
                let afterMembers = fromMembers[closeIdx..]
                // 追加新成员（确保前面有逗号）
                let newMembers = if (membersContent.trimAscii().endsWith(",")) {
                    membersContent + " " + memberPath
                } else {
                    membersContent + ", " + memberPath
                }
                templateEngine.writeFile(hostTomlPath, beforeMembers + newMembers + afterMembers)
                println("已追加宿主 workspace 成员: ${name}")
            }
        }
    }

    /// 追加/更新 plugins.yaml 条目（同名条目整体替换为聚合类，保留 order；首次则追加）
    private func appendPluginsYamlEntry(name: String, classNameFull: String, routeClassFull: String): Unit {
        if (!exists(pluginsYamlPath)) {
            println("提示: ${pluginsYamlPath} 不存在，请按现有格式手动追加插件条目：")
            println("  - name: ${name}")
            println("    className: ${classNameFull}")
            println("    enabled: true")
            return
        }
        let content = templateEngine.readText(pluginsYamlPath)
        if (this.hasEntry(content, name)) {
            // 已存在同名条目：整体替换为聚合类（保留原有 order），确保重生成后指向聚合入口/路由
            let oldOrder = this.findEntryOrder(content, name)
            let newBlock = this.buildPluginEntryBlock(name, classNameFull, routeClassFull, oldOrder)
            let rebuilt = this.replaceEntryBlock(content, name, newBlock)
            templateEngine.writeFile(pluginsYamlPath, rebuilt)
            println("已更新 plugins.yaml 条目: ${name}（聚合类 ${classNameFull}）")
            return
        }

        let order = nextOrder(content)
        let sb = StringBuilder()
        sb.append("\n  # plugingen 生成的插件\n")
        sb.append("  - name: ${name}\n")
        sb.append("    className: ${classNameFull}\n")
        sb.append("    enabled: true\n")
        sb.append("    order: ${order}\n")
        if (!routeClassFull.isEmpty()) {
            sb.append("    routeClass: ${routeClassFull}\n")
        }
        sb.append("    config: {}\n")
        templateEngine.writeFile(pluginsYamlPath, content + sb.toString())
        println("已追加 plugins.yaml 条目: ${name} (order=${order})")
    }

    /// 是否存在同名插件条目（精确匹配，避免前缀误命中，如 github / githubx）
    private func hasEntry(content: String, name: String): Bool {
        for (line in content.split("\n")) {
            if (line.trimAscii() == "- name: ${name}") {
                return true
            }
        }
        return false
    }

    /// 解析同名条目当前的 order 值（缺省 0）
    private func findEntryOrder(content: String, name: String): Int64 {
        let lines = content.split("\n")
        var inTarget = false
        for (line in lines) {
            let t = line.trimAscii()
            if (t == "- name: ${name}") {
                inTarget = true
                continue
            }
            if (inTarget) {
                if (t.startsWith("- name:")) {
                    break
                }
                if (t.startsWith("order:")) {
                    let value = t["order:".size..].trimAscii()
                    if (let Some(n) <- Int64.tryParse(value)) {
                        return n
                    }
                }
            }
        }
        return 0
    }

    /// 构建条目块文本（含 order）
    private func buildPluginEntryBlock(name: String, classNameFull: String, routeClassFull: String, order: Int64): String {
        let sb = StringBuilder()
        sb.append("\n  # plugingen 生成的插件\n")
        sb.append("  - name: ${name}\n")
        sb.append("    className: ${classNameFull}\n")
        sb.append("    enabled: true\n")
        sb.append("    order: ${order}\n")
        if (!routeClassFull.isEmpty()) {
            sb.append("    routeClass: ${routeClassFull}\n")
        }
        sb.append("    config: {}\n")
        return sb.toString()
    }

    /// 替换同名条目块（保留其前的全部内容与块后的后续条目）
    private func replaceEntryBlock(content: String, name: String, newBlock: String): String {
        let lines = content.split("\n")
        var startIdx = -1
        var endIdx = lines.size
        for (i in 0..lines.size) {
            if (lines[i].trimAscii() == "- name: ${name}") {
                startIdx = i
                break
            }
        }
        if (startIdx < 0) {
            return content + newBlock
        }
        for (i in (startIdx + 1)..lines.size) {
            if (lines[i].trimAscii().startsWith("- name:")) {
                endIdx = i
                break
            }
        }
        let sb = StringBuilder()
        for (i in 0..startIdx) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append(lines[i])
        }
        sb.append(newBlock)
        for (i in endIdx..lines.size) {
            sb.append(lines[i])
            if (i < lines.size - 1) {
                sb.append("\n")
            }
        }
        let result = sb.toString()
        if (content.endsWith("\n") && !result.endsWith("\n")) {
            return result + "\n"
        }
        return result
    }

    /// 解析现有条目的最大 order，返回下一个序号
    private func nextOrder(content: String): Int64 {
        var maxOrder = 0
        for (line in content.split("\n")) {
            let t = line.trimAscii()
            if (t.startsWith("order:")) {
                let value = t["order:".size..].trimAscii()
                if (let Some(n) <- Int64.tryParse(value)) {
                    if (n > maxOrder) {
                        maxOrder = n
                    }
                }
            }
        }
        return maxOrder + 1
    }

    // ==================== 权限菜单节点生成（与 crudgen 一致） ====================
    //
    // 向 permissions 表写入三级菜单结构：
    //   database -> database.{dbName} -> database.{dbName}.{tableName}
    // 并向 i18 表插入多语言 title。
    // 幂等：节点已存在则跳过；软删除则恢复；不存在则创建。

    /// 默认 creator（与 crudgen 一致，根管理员 UUID）
    private static let DEFAULT_CREATOR = "505cf909-5e0e-4dde-b215-74274d2cc548"

    /// 生成权限菜单节点（幂等，不更新已存在节点）
    public func generatePermissionNodes(dbName: String, tableName: String): Bool {
        try {
            let executor = ORM.executor()
            let tablePermissionName = "database.${dbName}.${tableName}"

            // 1. 获取或创建 database 父节点（处理软删除）
            let (databaseParentId, parentCreator) = this.ensureDatabaseParentNode(executor)

            // 2. 获取或创建 database.{dbName} 节点（处理软删除）
            let dbNodeId = this.ensureDatabaseNode(executor, dbName, databaseParentId, parentCreator)

            // 3. 检查表权限节点是否存在（包括软删除的）
            let existingTable = executor.setSql('''
                SELECT * FROM permissions
                WHERE permission_name = ${arg(tablePermissionName)}
            ''').first<PermissionsPO>()

            match (existingTable) {
                case Some(table) =>
                    if (table.deletedAt.isNone()) {
                        println("表权限节点已存在: ${tablePermissionName}")
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
                    let now = DateTime.now()
                    let tablePermission = PermissionsPO()
                    tablePermission.permissionName = tablePermissionName
                    tablePermission.typeVal = 1
                    tablePermission.hidden = 1
                    tablePermission.weight = 1
                    tablePermission.creator = Some(parentCreator)
                    tablePermission.createdAt = now
                    tablePermission.updatedAt = now
                    tablePermission.path = Some(tableName)
                    tablePermission.title = Some(tableName)
                    tablePermission.parentId = Some(dbNodeId)
                    tablePermission.menuType = Some("normal")
                    tablePermission.locale = Some("menu.database.${dbName}.${tableName}")
                    tablePermission.component = Some("database/${dbName}/${tableName}/index")

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
                            ${optArg(tablePermission.typeVal)},
                            ${optArg(tablePermission.hidden)},
                            ${optArg(tablePermission.weight)},
                            ${arg(parentCreator)},
                            NOW(),
                            NOW(),
                            null,
                            1,
                            ${arg(tablePermission.path.getOrThrow())},
                            ${arg(tablePermission.title.getOrThrow())},
                            ${arg(dbNodeId)},
                            ${optArg(tablePermission.meta)},
                            ${optArg(tablePermission.method)},
                            ${arg(tablePermission.menuType.getOrThrow())},
                            ${arg(tablePermission.locale.getOrThrow())}
                        )
                    ''').update

                    println("已生成表权限节点: ${tablePermissionName}")

                    // 插入 i18 多语言数据
                    match (tablePermission.locale) {
                        case Some(localeKey) => this.insertI18Data(executor, localeKey, tableName)
                        case None => println("locale 为空，跳过 i18 数据插入")
                    }
            }

            return true
        } catch (e: Exception) {
            println("生成权限节点失败: ${e.message}")
            return false
        }
    }

    /// 确保 database 父节点存在（幂等，处理软删除）
    /// @return (parentId, creator)
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
                    case None => DEFAULT_CREATOR
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
                            case None => DEFAULT_CREATOR
                        }
                        return (deletedNode.id, creator)
                    case None =>
                        let creator = DEFAULT_CREATOR

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
                            case None => return (DEFAULT_CREATOR, creator)
                        }
                }
        }
    }

    /// 确保 database.{dbName} 节点存在（幂等，处理软删除）
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
                            case None => return DEFAULT_CREATOR
                        }
                }
        }
    }

    /// 插入 i18 多语言数据（幂等，处理软删除）
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
