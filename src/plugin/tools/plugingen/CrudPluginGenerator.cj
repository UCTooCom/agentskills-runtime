/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import std.collection.{ArrayList, HashMap}
import std.convert.*

/**
 * CrudPluginGenerator - 表驱动 CRUD 进程插件生成器
 *
 * 从 db_info 读取表结构，生成对标 codelabs 的完整 V4 CRUD 插件：
 *   - plugin.yaml: V4 API 路由（add/edit/del/empty-recycle-bin/:id/:limit/:page）
 *   - cjpm.toml: 独立 executable 工程（--dy-std -Woff all）
 *   - main.cj: PluginRuntime.run 显式入口
 *   - handlers.cj: 完整 CRUD handler 框架（dispatch 路由 + host.db 调用）
 *   - effects.cj: ctx.effect 可逆效果注册框架
 *
 * 与 crudgen 的确定性代码生成方式对齐：
 *   crudgen 从数据库结构生成宿主 CRUD 模块到 src/app，
 *   plugingen 从数据库结构生成独立进程插件到 skills/{name}/。
 *
 * 参考已验证通过的 codelabs 插件实现。
 */
public class CrudPluginGenerator {
    private let templateEngine = TemplateEngine()
    private let rules = NameRules()

    /// 插件根输出目录
    private static let SKILLS_ROOT = "./skills"

    /**
     * 生成完整 CRUD 进程插件（支持多表累积）
     *
     * 范式对齐已验证的 long-running-task L3 插件：表名作为**运行时参数**传入
     * 各 handler，`TABLES` 常量 + `getWritableColumns(table)` 按表分派，
     * 而非把表名编译期写死。多表共用一个 handlers.cj。
     *
     * @param name 插件名（已规范化）
     * @param dbName 数据库名
     * @param tableNames 本次请求的表清单（可多张）
     * @return 成功与否
     */
    public func generate(name: String, dbName: String, tableNames: Array<String>): Bool {
        let className = rules.toPascalCase(name)
        let pkgName = "skill_${name}"
        let pluginDir = "${CrudPluginGenerator.SKILLS_ROOT}/${name}"
        let cjDir = "${pluginDir}/src"

        // 还原该插件已生成的历史表清单，与本次请求去重保序合并（同名插件分多次生成时累积）
        let existingTables = this.readExistingTables(cjDir)
        let tables = this.mergeTableList(existingTables, tableNames)

        // 1. plugin.yaml（V4 API 路由，按表逐组声明）
        this.writePluginYaml(name, tables, pluginDir)

        // 2. cjpm.toml（独立 executable 工程）
        this.writeCjpmToml(name, pluginDir)

        // 3. main.cj（PluginRuntime.run 显式入口）
        this.writeMain(name, className, pkgName, cjDir)

        // 4. handlers.cj（完整 CRUD handler 框架，多表共用 + AutoCreateCode 保护区）
        this.writeHandlers(name, className, pkgName, dbName, tables, cjDir)

        // 5. effects.cj（ctx.effect 可逆效果注册框架）
        this.writeEffects(name, className, pkgName, cjDir)

        // 6. README.md（第三方开发者手册）
        this.writeReadme(name, tables, pluginDir)

        // 7. 生成 permissions 菜单节点 + i18 多语言数据（幂等，与 sync 轨同口径）
        //    ⚠️ 遍历**累积后**的全量表清单而非仅本次请求表：process 轨早期版本没有这一步，
        //    历史插件普遍存在「有页面、无菜单节点」的表，重跑一次即自动补齐。
        //    缺节点的后果：前端侧边栏看不到入口（PermissionsService.getUserMenuTree 的
        //    菜单树直接来自 permissions 表 type=1 的节点）——后端 API 层反而不受影响，
        //    因为超级管理员角色在 role_has_permission 里持有 '*' 通配符会直接放行。
        let permissionNodes = PermissionNodeGenerator()
        var permissionOk = 0
        for (t in tables) {
            if (permissionNodes.generatePermissionNodes(dbName, t)) {
                permissionOk += 1
            }
        }
        println("权限菜单节点：${permissionOk}/${tables.size} 张表已处理（三级结构 database.{dbName}.{tableName} + i18，幂等）")

        println("CRUD 进程轨插件 ${name} 生成完成：${pluginDir}/（表：${tables.size} 张）")
        if (tables.size > tableNames.size) {
            println("累积合并：历史表 ${existingTables.size} 张 + 本次 ${tableNames.size} 张 → 共 ${tables.size} 张")
        }
        println("独立编译：cd ${pluginDir} && cjpm build → target/release/bin/skill_${name}.exe")
        return true
    }

    /**
     * 还原已生成的历史表清单。
     *
     * 从 handlers.cj 的 TABLES 常量区解析 `// table: <表名>` 标记行，
     * 避免对表名做逆 PascalCase 推导带来的歧义（与 sync 轨 PluginGenerator 同策略）。
     * ⚠️ 文件名必须与 `writeHandlers` 的写盘路径**逐字一致**（固定名 `handlers.cj`）。
     * 曾经写成 `${className}Handlers.cj`（同步轨 PluginGenerator 的命名），而 process 轨
     * 产物叫 `handlers.cj` ⇒ 每次都读不到历史表，同名插件追加表时**表清单被整体覆盖**，
     * 累积能力静默失效（plugin.yaml 里旧表路由直接消失）。
     * 类名 `${className}` 只出现在**产物内容**里（TABLES 所属类名），与文件名无关。
     */
    private func readExistingTables(cjDir: String): Array<String> {
        let path = "${cjDir}/handlers.cj"
        if (!templateEngine.fileExists(path)) {
            return Array<String>()
        }
        let content = templateEngine.readText(path)
        let result = ArrayList<String>()
        // 表名是 ASCII 标识符，按字节切片安全（与 sync 轨 PluginGenerator 同写法）
        for (raw in content.split("\n")) {
            let line = raw.trimAscii()
            if (line.startsWith("// table: ")) {
                let table = line["// table: ".size..].trimAscii()
                if (!table.isEmpty() && !result.contains(table)) {
                    result.add(table)
                }
            }
        }
        return result.toArray()
    }

    /// 写入 plugin.yaml（V4 API 路由，按表逐组 6 条，对标 codelabs / long-running-task）
    ///
    /// §14.1 同步（2026-09-15）：字段面与宿主实际解析的 `plugin_config.cj` 对齐——
    ///   - **删除 `protocol`**：plugin_config 无该字段解析逻辑，写了只会被静默忽略；
    ///     且会误导后来者以为传输层可切换（L3 进程轨固定 stdio）。
    ///   - **补 `tableWhitelist`**：功能必需。生成的 handler 经 `ctx.invoke("host.db", ...)`
    ///     访问数据，未列入白名单的表会被宿主直接拒绝——缺它等于生成即不可用。
    ///   - 补 `enabled` / `autoRestart` / `order`：显式化，避免依赖隐式默认值。
    ///
    /// 多表：路由 basePath 用**表名**（`/api/v1/uctoo/{table}/add`）而非插件名——
    ///   插件名只能有一个，多表必须靠表名区分路径段，否则多组路由互相冲突。
    ///
    /// 保护区划分（YAML 注释用 `#`）：
    ///   - 保护区**外**：`name` / `version` / `mode` / `command` / `enabled` / `order` /
    ///     `autoRestart` —— 二开最常改的就是这几项（停用插件、调顺序、改 exe 路径），
    ///     放进保护区等于每次重新生成都被改回去。
    ///   - 保护区**内**：`description`（含表数）/ `tableWhitelist` / `routes` —— 都随表清单
    ///     变化，必须跟着累积刷新，否则新表访问被宿主白名单拒绝、路由也缺失。
    private func writePluginYaml(name: String, tables: Array<String>, pluginDir: String): Unit {
        let sb = StringBuilder()
        sb.append("# ${name} 插件清单（plugingen process 轨生成）\n")
        sb.append("# 保护区外为二开区：停用插件（enabled: false）、调 order、改 command 路径请改这里，重新生成不会被覆盖。\n")
        sb.append("name: ${name}\n")
        sb.append("version: 1.0.0\n")
        sb.append("mode: process\n")
        // command 是相对**宿主工作目录**的路径（CordisHostManager.resolvePluginCommand
        // 直接 `${cwd}/${command}`，无校验、无兜底），必须带 skills/{name}/ 前缀，
        // 否则开发态（cwd=仓库根）与发布态（cwd=bin）都定位不到 exe。
        sb.append("command: ./skills/${name}/target/release/bin/skill_${name}.exe\n")
        sb.append("enabled: true\n")
        sb.append("order: 10\n")
        sb.append("autoRestart: true\n")
        sb.append("#region AutoCreateCode\n")
        sb.append("# ↓ 本行以下由 plugingen 自动维护，重新生成会覆盖；表清单与路由随 --tables 累积刷新。\n")
        sb.append("description: L3 进程隔离轨插件 ${name}（${tables.size} 张表）\n")
        // 未在白名单的表，host.db 调用会被宿主拒绝（不是可选项）
        sb.append("tableWhitelist:\n")
        for (t in tables) {
            sb.append("  - ${t}\n")
        }
        sb.append("routes:\n")
        for (t in tables) {
            sb.append("  # ${t} CRUD\n")
            sb.append("  - method: POST\n")
            sb.append("    path: /api/v1/uctoo/${t}/add\n")
            sb.append("  - method: POST\n")
            sb.append("    path: /api/v1/uctoo/${t}/edit\n")
            sb.append("  - method: POST\n")
            sb.append("    path: /api/v1/uctoo/${t}/del\n")
            sb.append("  - method: POST\n")
            sb.append("    path: /api/v1/uctoo/${t}/empty-recycle-bin\n")
            sb.append("  - method: GET\n")
            sb.append("    path: /api/v1/uctoo/${t}/:id\n")
            sb.append("  - method: GET\n")
            sb.append("    path: /api/v1/uctoo/${t}/:limit/:page\n")
        }
        sb.append("#endregion AutoCreateCode\n")
        sb.append("# ── 二次开发区 ──\n")
        sb.append("# 需要追加自定义路由 / 额外白名单表时写在本区（在 routes 之外另起键），重新生成会保留。\n")
        templateEngine.updateFileWithMarkers(
            "${pluginDir}/plugin.yaml",
            sb.toString(),
            TemplateEngine.CONF_REGION_START,
            TemplateEngine.CONF_REGION_END
        )
        println("已生成: ${pluginDir}/plugin.yaml")
    }

    /// 写入 cjpm.toml（独立 executable 工程，对标 codelabs）
    ///
    /// 保护区划分（TOML 注释用 `#`）：
    ///   - 保护区**外**：`[package]` 段 —— 二开常改 `compile-option`（加 `-O2`）、
    ///     `output-type`、`src-dir`，这些是人工调优项，覆盖等于白改。
    ///   - 保护区**内**：`[dependencies]` / `[target...]` 段 —— 依赖与 stdx 路径由生成器
    ///     统一维护，重生成时保证与 runtime 的 libs 布局一致。
    private func writeCjpmToml(name: String, pluginDir: String): Unit {
        let pkgName = "skill_${name}"
        let sb = StringBuilder()
        sb.append("# ${pkgName} 独立工程配置（plugingen process 轨生成）\n")
        sb.append("# 保护区外为二开区：compile-option / output-type / src-dir 等请改这里，重新生成不会被覆盖。\n")
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
        sb.append("#region AutoCreateCode\n")
        sb.append("# ↓ 本行以下由 plugingen 自动维护，重新生成会覆盖；依赖与 stdx 路径请勿手改。\n")
        sb.append("[dependencies]\n")
        sb.append("  \"ystyle::cordis_plugin\" = { path = \"../../libs/cordis-cj/cordis_plugin\" }\n")
        sb.append("  \"ystyle::cordis_core\" = { path = \"../../libs/cordis-cj/cordis_core\" }\n")
        sb.append("  \"jsonvalue\" = { path = \"../../libs/jsonvalue\" }\n")
        sb.append("  \"ystyle::jsonrpc\" = { path = \"../../libs/jsonrpc\" }\n")
        sb.append("\n")
        sb.append("[target.x86_64-w64-mingw32.bin-dependencies]\n")
        sb.append("  path-option = [\"../../libs/cangjie-stdx-windows-x64-1.1.3.1/windows_x86_64_cjnative/dynamic/stdx\"]\n")
        sb.append("#endregion AutoCreateCode\n")
        templateEngine.updateFileWithMarkers(
            "${pluginDir}/cjpm.toml",
            sb.toString(),
            TemplateEngine.CONF_REGION_START,
            TemplateEngine.CONF_REGION_END
        )
        println("已生成: ${pluginDir}/cjpm.toml")
    }

    /// 写入 main.cj（PluginRuntime.run 显式入口，对标 codelabs）
    ///
    /// 保护区划分：`main()` 函数体在保护区内（注册哪几个 Handler/Effects 由生成器决定），
    /// 保护区外留二次开发区 —— 二开要追加自定义注册时写在那里再手动接进 `main()`，
    /// 这样重新生成不会把接好的调用抹掉。
    private func writeMain(
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
        sb.append("//#region AutoCreateCode\n")
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
        sb.append("//#endregion AutoCreateCode\n\n")
        sb.append("// ── 二次开发区 ────────────────────────────────────────────────\n")
        sb.append("// 重新生成时以上 AutoCreateCode 区间会被覆盖，本区域的手写代码保留。\n")
        sb.append("// 需要注册自定义 handler/effect 时：在此定义类，再把调用接进上面 main() 的 lambda 中。\n")
        templateEngine.updateFile("${cjDir}/main.cj", sb.toString())
        println("已生成: ${cjDir}/main.cj")
    }

    /// 写入 effects.cj（ctx.effect 可逆效果注册框架，对标 codelabs）
    ///
    /// 保护区划分：`${className}Effects` 类在保护区内，二次开发区留在类外，
    /// 自定义的可逆效果写在那里，重新生成保留。
    private func writeEffects(
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
        sb.append("import ystyle::cordis_plugin.PluginContext\n\n")
        sb.append("//#region AutoCreateCode\n")
        sb.append("public class ${className}Effects {\n")
        sb.append("    public static func register(ctx: PluginContext): Unit {\n")
        sb.append("        // 注册可逆效果（卸载时逆序执行）\n")
        sb.append("        ctx.effect({ =>\n")
        sb.append("            // 逆向执行：清理资源（卸载时调用）\n")
        sb.append("            // TODO: 注册资源清理逻辑\n")
        sb.append("        })\n")
        sb.append("    }\n")
        sb.append("}\n")
        sb.append("//#endregion AutoCreateCode\n\n")
        sb.append("// ── 二次开发区 ────────────────────────────────────────────────\n")
        sb.append("// 重新生成时以上 AutoCreateCode 区间会被覆盖，本区域的手写代码保留。\n")
        sb.append("// 自定义可逆效果写在此处（另起 class，用 ctx.effect 注册），再接进 main.cj 的注册链。\n")
        templateEngine.updateFile("${cjDir}/effects.cj", sb.toString())
        println("已生成: ${cjDir}/effects.cj")
    }

    /// 写入 README.md（第三方开发者手册）
    ///
    /// 保护区用 **HTML 注释**（`<!-- #region AutoCreateCode -->`）而非 `#region`——
    /// Markdown 里行首 `#` 是 ATX 标题语法，`#region` 会被渲染成标题而不是标记，
    /// 导致保护区匹配不上、退化成整文件覆盖。保护区只圈随表清单变化的两张表，
    /// 编译说明 / 约束等固定文案留在保护区外，重生成不会冲掉二开补充的说明。
    private func writeReadme(name: String, tables: Array<String>, pluginDir: String): Unit {
        let sb = StringBuilder()
        sb.append("# ${name} 插件（L3 进程隔离轨）\n\n")
        sb.append("独立 cjpm executable 工程，对标 DeepSeek Harness Cordis 的进程隔离插件轨。\n\n")
        sb.append("<!-- #region AutoCreateCode -->\n")
        sb.append("## 覆盖表（${tables.size} 张）\n\n")
        sb.append("分多次生成时表清单自动累积合并：\n\n")
        for (t in tables) {
            sb.append("- `${t}`\n")
        }
        sb.append("\n## V4 API 端点\n\n")
        sb.append("每张表 6 条路由，basePath 为 `/api/v1/uctoo/{表名}`：\n\n")
        sb.append("| 方法 | 路径 | 说明 |\n")
        sb.append("|---|---|---|\n")
        for (t in tables) {
            sb.append("| GET | /api/v1/uctoo/${t}/:limit/:page | ${t} 分页列表 |\n")
            sb.append("| GET | /api/v1/uctoo/${t}/:id | ${t} 单条查询 |\n")
            sb.append("| POST | /api/v1/uctoo/${t}/add | ${t} 创建 |\n")
            sb.append("| POST | /api/v1/uctoo/${t}/edit | ${t} 更新（含批量/恢复） |\n")
            sb.append("| POST | /api/v1/uctoo/${t}/del | ${t} 删除（含批量/硬删） |\n")
            sb.append("| POST | /api/v1/uctoo/${t}/empty-recycle-bin | ${t} 清空回收站 |\n")
        }
        sb.append("<!-- #endregion AutoCreateCode -->\n\n")
        sb.append("## 编译\n\n")
        sb.append("```bash\n")
        sb.append("cd ${pluginDir}\n")
        sb.append("cjpm build\n")
        sb.append("```\n\n")
        sb.append("产物：`target/release/bin/skill_${name}.exe`\n\n")
        sb.append("## 约束\n\n")
        sb.append("- 依赖仅 `ystyle::cordis_plugin` + `jsonvalue`（+仓颉标准库）——零 magic 包依赖\n")
        sb.append("- 禁用 `@Plugin` 宏：用显式 API `PluginRuntime.run(...)`\n")
        sb.append("- 数据访问一律经 `host.db` 服务代理（不直连数据库）\n")
        sb.append("- `getWritableColumns(table)` 按表返回可写列白名单，**需按各表实际字段补全**\n\n")
        sb.append("## 保护区约定（重新生成时勿丢二开）\n\n")
        sb.append("本插件由 plugingen 生成，以下文件的自动区块会在重新生成时被覆盖，\n")
        sb.append("**手写代码必须写在区块之外**。各文件的区块起止标记用其语言对应的注释语法：\n\n")
        sb.append("| 文件 | 区块标记前缀 | 二开位置 |\n")
        sb.append("|---|---|---|\n")
        sb.append("| `handlers.cj` | Cangjie 行注释 + region AutoCreateCode | 结束标记之后（类外顶层函数区） |\n")
        sb.append("| `main.cj` | Cangjie 行注释 + region AutoCreateCode | 结束标记之后 |\n")
        sb.append("| `effects.cj` | Cangjie 行注释 + region AutoCreateCode | 结束标记之后（类外另起 class） |\n")
        sb.append("| `plugin.yaml` | YAML 行注释 + region AutoCreateCode | `enabled` / `order` / `command` 在区块外 |\n")
        sb.append("| `cjpm.toml` | TOML 行注释 + region AutoCreateCode | `[package]` 段（`compile-option` 等在区块外） |\n")
        sb.append("| `README.md` | HTML 注释包裹的 region AutoCreateCode | 区块之外（本节即在区块外） |\n\n")
        sb.append("> 标记语法随文件类型不同：仓颉源码用 `//`，YAML/TOML 用 `#`，\n")
        sb.append("> Markdown 用 HTML 注释 —— 因为行首 `#` 在 Markdown 里是标题语法。\n")
        sb.append("> 完整标记串见对应文件的开头与结束标记行。\n")
        templateEngine.updateFileWithMarkers(
            "${pluginDir}/README.md",
            sb.toString(),
            TemplateEngine.MD_REGION_START,
            TemplateEngine.MD_REGION_END
        )
        println("已生成: ${pluginDir}/README.md")
    }

    /// 去重保序合并表清单（历史表在前，本次新表追加在后）
    ///
    /// 与 `PluginGenerator.mergeTableList` 同语义。此处独立实现而非复用：
    /// 那份是 `private`，仓颉中私有成员仅类内可见，跨类不可调用。
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

    /// 写入 handlers.cj（完整 CRUD handler 框架，多表共用，对标 codelabs / long-running-task）
    ///
    /// 多表范式（对齐 long-running-task 已验证实现）：
    ///   - `TABLES` 常量列出本插件支持的全部表，每行带 `// table:` 标记（供下次生成还原历史表）；
    ///   - `getWritableColumns(table)` 按表返回可写列白名单；
    ///   - 各 handler 接收 `table: String` **运行时参数**，不把表名写死；
    ///   - 全部自动生成内容包在 `//#region AutoCreateCode` 保护区，重新生成只覆盖该区间。
    private func writeHandlers(
        name: String,
        className: String,
        pkgName: String,
        dbName: String,
        tables: Array<String>,
        cjDir: String
    ): Unit {
        let sb = StringBuilder()

        // 文件头注释
        sb.append("/*\n")
        sb.append(" * V4 CRUD RPC handler 框架（${name}）\n")
        sb.append(" * 独立进程插件，通过 ctx.invoke(\"host.db\", ...) 访问宿主数据库\n")
        sb.append(" *\n")
        sb.append(" * 多表支持：${tables.size} 张表共用本文件，表名作为运行时参数传入 handler。\n")
        sb.append(" * 路由（遵循 uctoo V4 API 规范，basePath /api/v1/uctoo/{表名}）：\n")
        sb.append(" *   GET  /:limit/:page               分页列表\n")
        sb.append(" *   GET  /:id                        单条查询\n")
        sb.append(" *   POST /add                        创建\n")
        sb.append(" *   POST /edit                       更新（含批量 ids / 恢复 deleted_at='0'）\n")
        sb.append(" *   POST /del                        删除（含批量 ids / 硬删 force=1）\n")
        sb.append(" *   POST /empty-recycle-bin          清空回收站（物理删除 deleted_at NOT NULL）\n")
        sb.append(" *\n")
        sb.append(" * 列表键名遵守 API 规范 §8.2：表名 + s（复数）\n")
        sb.append(" *\n")
        sb.append(" * ⚠️ 自动生成内容请勿手工修改：重新生成会覆盖 AutoCreateCode 保护区。\n")
        sb.append(" *    二次开发写在保护区结束标记之后。\n")
        sb.append(" */\n")
        sb.append("package ${pkgName}\n\n")
        sb.append("import ystyle::cordis_plugin.{PluginContext, PluginRuntime}\n")
        sb.append("import jsonvalue.*\n")
        sb.append("import std.collection.{HashMap, ArrayList}\n")
        sb.append("import std.convert.*\n\n")

        // ── AutoCreateCode 保护区开始 ──
        sb.append("//#region AutoCreateCode\n\n")
        sb.append("public class ${className}Handlers {\n")
        sb.append("    /// 插件上下文（register 时注入），handler 内经 ctx.invoke 访问宿主服务\n")
        sb.append("    private static var ctx: ?PluginContext = None\n\n")

        // TABLES 常量（多表清单，带 // table: 标记供下次生成还原）
        sb.append("    /// 本插件支持的全部表（分多次生成时自动累积合并）\n")
        sb.append("    private static let TABLES: Array<String> = [\n")
        for (t in tables) {
            sb.append("        // table: ${t}\n")
            sb.append("        \"${t}\",\n")
        }
        sb.append("    ]\n\n")

        // register 方法
        sb.append("    public static func register(ctx: PluginContext): Unit {\n")
        sb.append("        ${className}Handlers.ctx = ctx\n")
        sb.append("        // 注册通用服务 handler：宿主 invoke 转发时 service=\"${name}\"\n")
        sb.append("        // 内部根据 ExternalRequest 的 method + path 分发到具体 CRUD handler\n")
        sb.append("        ctx.registerHandler(\"${name}\", { method, args => ${className}Handlers.dispatch(method, args) })\n")
        sb.append("    }\n\n")

        // dispatch 方法（按表循环分派）
        sb.append("    /**\n")
        sb.append("     * 路由分发：根据 HTTP method + path 分发到具体 CRUD handler\n")
        sb.append("     * args[0] 是 ExternalRequest { method, path, queryParams, body, userId, permissions, ... }\n")
        sb.append("     *\n")
        sb.append("     * 多表：遍历 TABLES，用表名作为路径段匹配（/api/v1/uctoo/{表名}/...）。\n")
        sb.append("     */\n")
        sb.append("    private static func dispatch(httpMethod: String, args: Array<JsonValue>): JsonValue {\n")
        sb.append("        if (args.size == 0) {\n")
        sb.append("            return ${className}Handlers.errResult(1, \"missing args\")\n")
        sb.append("        }\n")
        sb.append("        // 解析 ExternalRequest\n")
        sb.append("        let extReq = args[0]\n")
        sb.append("        match (extReq) {\n")
        sb.append("            case JsonValue.Map(fields) =>\n")
        sb.append("                let path = ${className}Handlers.extractString(fields, \"path\")\n")
        sb.append("                let reqMethod = ${className}Handlers.extractString(fields, \"method\")\n")
        sb.append("                // 遍历 TABLES 按表名匹配路径段\n")
        sb.append("                for (table in ${className}Handlers.TABLES) {\n")
        sb.append("                    if (path.contains(\"/\${table}/\")) {\n")
        sb.append("                        if (reqMethod == \"GET\") {\n")
        sb.append("                            // /api/v1/uctoo/{table}/:limit/:page → list\n")
        sb.append("                            // /api/v1/uctoo/{table}/:id → get（单条）\n")
        sb.append("                            let parts = path.split(\"/\")\n")
        sb.append("                            var tableIdx: Int64 = -1\n")
        sb.append("                            for (i in 0..parts.size) {\n")
        sb.append("                                if (parts[i] == table) {\n")
        sb.append("                                    tableIdx = i\n")
        sb.append("                                    break\n")
        sb.append("                                }\n")
        sb.append("                            }\n")
        sb.append("                            if (tableIdx >= 0 && tableIdx + 1 < parts.size) {\n")
        sb.append("                                let remaining = parts.size - tableIdx - 1\n")
        sb.append("                                if (remaining >= 2) {\n")
        sb.append("                                    return ${className}Handlers.handleList(table, fields, args)\n")
        sb.append("                                } else {\n")
        sb.append("                                    return ${className}Handlers.handleGet(table, fields, args)\n")
        sb.append("                                }\n")
        sb.append("                            }\n")
        sb.append("                            return ${className}Handlers.handleList(table, fields, args)\n")
        sb.append("                        } else if (reqMethod == \"POST\") {\n")
        sb.append("                            if (path.contains(\"/\${table}/add\")) {\n")
        sb.append("                                return ${className}Handlers.handleAdd(table, fields, args)\n")
        sb.append("                            } else if (path.contains(\"/\${table}/edit\")) {\n")
        sb.append("                                return ${className}Handlers.handleEdit(table, fields, args)\n")
        sb.append("                            } else if (path.contains(\"/\${table}/del\")) {\n")
        sb.append("                                return ${className}Handlers.handleDel(table, fields, args)\n")
        sb.append("                            } else if (path.contains(\"/\${table}/empty-recycle-bin\")) {\n")
        sb.append("                                return ${className}Handlers.handleEmptyRecycleBin(table, fields, args)\n")
        sb.append("                            }\n")
        sb.append("                        }\n")
        sb.append("                    }\n")
        sb.append("                }\n")
        sb.append("                return ${className}Handlers.errResult(1, \"no route matched: \${reqMethod} \${path}\")\n")
        sb.append("            case _ => return ${className}Handlers.errResult(1, \"invalid args format\")\n")
        sb.append("        }\n")
        sb.append("        return ${className}Handlers.errResult(1, \"dispatch fallback\")\n")
        sb.append("    }\n\n")

        // getWritableColumns（按表返回白名单）
        this.writeGetWritableColumns(sb, name, tables, className)

        // ── CRUD handlers（表名为运行时参数）──
        this.writeHandleAdd(sb, name, className)
        this.writeHandleEdit(sb, name, className)
        this.writeHandleDel(sb, name, className)
        this.writeHandleGet(sb, name, className)
        this.writeHandleList(sb, name, className)
        this.writeHandleEmptyRecycleBin(sb, name, className)

        // ── 内部辅助方法 ──
        this.writeDoRestore(sb, name, className)
        this.writeQueryById(sb, name, className)
        this.writeBuildWhereFromFilter(sb, name, className)
        this.writeExtractBody(sb, name, className)
        this.writeExtractStringFromMap(sb, name, className)
        this.writeOkResult(sb, name, className)
        this.writeErrResult(sb, name, className)
        this.writeExtractString(sb, name, className)

        // 注意：类体在此闭合（//#endregion 之后是二次开发区，故类右括号必须在标记之前）
        sb.append("}\n\n")

        // ── 顶层辅助函数（仍在 AutoCreateCode 区间内：更新模板时需一并刷新）──
        this.writeParseIdList(sb, name, className)
        this.writeJoinQuoted(sb, name, className)

        // ── AutoCreateCode 保护区结束（其后为二次开发区）──
        sb.append("\n//#endregion AutoCreateCode\n\n")
        sb.append("// ── 二次开发区 ────────────────────────────────────────────────\n")
        sb.append("// 重新生成时以上 AutoCreateCode 区间会被覆盖，本区域的手写代码保留。\n")
        sb.append("// 自定义 handler 请写在此处，并在 dispatch 中按需接入。\n")

        // 用 updateFile 走保护区增量更新（保留二次开发），而非整文件覆盖
        templateEngine.updateFile("${cjDir}/handlers.cj", sb.toString())
        println("已生成: ${cjDir}/handlers.cj")
    }

    /// 生成 getWritableColumns 方法（按表返回可写字段白名单，对标 long-running-task）
    private func writeGetWritableColumns(sb: StringBuilder, name: String, tables: Array<String>, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 获取表的可写字段白名单（防止插件越权写入 id/created_at/updated_at）\n")
        sb.append("     *\n")
        sb.append("     * 不包含 id（数据库 DEFAULT gen_random_uuid）、created_at/updated_at（数据库自维护）。\n")
        sb.append("     * TODO: plugingen 进程模式未连 DB，无法自动读取 db_info，\n")
        sb.append("     *       请按各表实际字段补全下面的白名单。\n")
        sb.append("     */\n")
        sb.append("    private static func getWritableColumns(table: String): Array<String> {\n")
        for (t in tables) {
            sb.append("        if (table == \"${t}\") {\n")
            sb.append("            return [\"creator\", \"deleted_at\"]\n")
            sb.append("        }\n")
        }
        sb.append("        return Array<String>(0, { _ => \"\" })\n")
        sb.append("    }\n\n")
    }

    // ── CRUD handler 生成方法 ──

    /// 生成 handleAdd 方法
    private func writeHandleAdd(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 创建：POST /api/v1/uctoo/{表名}/add\n")
        sb.append("     * body: { ...业务字段 }\n")
        sb.append("     * 行级权限：creator = userId（宿主侧 host.db 会附加行级 WHERE，但 INSERT 时需要插件显式设置 creator）\n")
        sb.append("     */\n")
        sb.append("    private static func handleAdd(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {\n")
        sb.append("        eprintln(\"[${name}] handleAdd \${table} entered\")\n")
        sb.append("        let ctxOpt = ${className}Handlers.ctx\n")
        sb.append("        match (ctxOpt) {\n")
        sb.append("            case None => return ${className}Handlers.errResult(1, \"plugin context not initialized\")\n")
        sb.append("            case Some(ctx) =>\n")
        sb.append("                // 1. 提取 body（POST 请求体）\n")
        sb.append("                let body = ${className}Handlers.extractBody(fields)\n")
        sb.append("                match (body) {\n")
        sb.append("                    case None => return ${className}Handlers.errResult(40001, \"提交数据格式错误\")\n")
        sb.append("                    case Some(bodyMap) =>\n")
        sb.append("                        // 2. 构造 INSERT data，只允许白名单字段\n")
        sb.append("                        let dataMap = HashMap<String, JsonValue>()\n")
        sb.append("                        for (col in ${className}Handlers.getWritableColumns(table)) {\n")
        sb.append("                            match (bodyMap.get(col)) {\n")
        sb.append("                                case Some(v) => dataMap[col] = v\n")
        sb.append("                                case None => ()\n")
        sb.append("                            }\n")
        sb.append("                        }\n")
        sb.append("                        // 3. 设置 creator = userId（行级权限要求）\n")
        sb.append("                        let userId = ${className}Handlers.extractString(fields, \"userId\")\n")
        sb.append("                        if (!userId.isEmpty()) {\n")
        sb.append("                            dataMap[\"creator\"] = JsonValue.String(userId)\n")
        sb.append("                        }\n")

        sb.append("                        // 4. 调用 host.db execute insert\n")
        sb.append("                        let execParam = HashMap<String, JsonValue>()\n")
        sb.append("                        execParam[\"operation\"] = JsonValue.String(\"execute\")\n")
        sb.append("                        execParam[\"subOp\"] = JsonValue.String(\"insert\")\n")
        sb.append("                        execParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("                        execParam[\"data\"] = JsonValue.from(dataMap)\n")
        sb.append("                        // 行级权限参数\n")
        sb.append("                        let permArr = ArrayList<JsonValue>()\n")
        sb.append("                        match (fields.get(\"permissions\")) {\n")
        sb.append("                            case Some(JsonValue.Array(arr)) =>\n")
        sb.append("                                for (p in arr) { permArr.add(p) }\n")
        sb.append("                            case _ => ()\n")
        sb.append("                        }\n")
        sb.append("                        execParam[\"permissions\"] = JsonValue.Array(permArr)\n")
        sb.append("                        if (!userId.isEmpty()) {\n")
        sb.append("                            execParam[\"userId\"] = JsonValue.String(userId)\n")
        sb.append("                        }\n")
        sb.append("                        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("                        execArgs[0] = JsonValue.from(execParam)\n")
        sb.append("                        let execResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"execute\", execArgs)\n")
        sb.append("                        eprintln(\"[${name}] host.db insert result: \${execResult.stringify()}\")\n")
        sb.append("                        // 5. 返回成功（INSERT 无 RETURNING，不回读新记录）\n")
        sb.append("                        return ${className}Handlers.okResult(\"add\")\n")
        sb.append("                }\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    /// 生成 handleEdit 方法
    private func writeHandleEdit(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 更新：POST /api/v1/uctoo/{表名}/edit\n")
        sb.append("     * body 单条: { id, ...updateFields }\n")
        sb.append("     * body 批量: { ids: \"uuid1,uuid2,...\", ...updateFields }\n")
        sb.append("     * body 恢复: { id 或 ids, deleted_at: \"0\" }  // deleted_at='0' → 软恢复（SET deleted_at=NULL）\n")
        sb.append("     */\n")
        sb.append("    private static func handleEdit(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {\n")
        sb.append("        eprintln(\"[${name}] handleEdit entered\")\n")
        sb.append("        let ctxOpt = ${className}Handlers.ctx\n")
        sb.append("        match (ctxOpt) {\n")
        sb.append("            case None => return ${className}Handlers.errResult(1, \"plugin context not initialized\")\n")
        sb.append("            case Some(ctx) =>\n")
        sb.append("                let body = ${className}Handlers.extractBody(fields)\n")
        sb.append("                match (body) {\n")
        sb.append("                    case None => return ${className}Handlers.errResult(40001, \"提交数据格式错误\")\n")
        sb.append("                    case Some(bodyMap) =>\n")
        sb.append("                        let userId = ${className}Handlers.extractString(fields, \"userId\")\n")
        sb.append("                        let permArr = ArrayList<JsonValue>()\n")
        sb.append("                        match (fields.get(\"permissions\")) {\n")
        sb.append("                            case Some(JsonValue.Array(arr)) =>\n")
        sb.append("                                for (p in arr) { permArr.add(p) }\n")
        sb.append("                            case _ => ()\n")
        sb.append("                        }\n")
        sb.append("                        // 判断是批量（ids）还是单条（id）\n")
        sb.append("                        let idsVal = bodyMap.get(\"ids\")\n")
        sb.append("                        let idVal = bodyMap.get(\"id\")\n")
        sb.append("                        // 判断是否是恢复操作（deleted_at='0'）\n")
        sb.append("                        let deletedAtVal = bodyMap.get(\"deleted_at\")\n")
        sb.append("                        let isRestore = match (deletedAtVal) {\n")
        sb.append("                            case Some(JsonValue.String(s)) => s == \"0\"\n")
        sb.append("                            case _ => false\n")
        sb.append("                        }\n")
        sb.append("                        if (isRestore) {\n")
        sb.append("                            // 恢复操作：SET deleted_at=NULL WHERE id IN (...)\n")
        sb.append("                            return ${className}Handlers.doRestore(table, ctx, bodyMap, userId, permArr)\n")
        sb.append("                        }\n")
        sb.append("                        // 构造 UPDATE data，只允许白名单字段\n")
        sb.append("                        let dataMap = HashMap<String, JsonValue>()\n")
        sb.append("                        for (col in ${className}Handlers.getWritableColumns(table)) {\n")
        sb.append("                            match (bodyMap.get(col)) {\n")
        sb.append("                                case Some(v) => dataMap[col] = v\n")
        sb.append("                                case None => ()\n")
        sb.append("                            }\n")
        sb.append("                        }\n")
        sb.append("                        // updated_at 由数据库触发器维护，不显式设置\n")
        sb.append("                        if (dataMap.size == 0) {\n")
        sb.append("                            return ${className}Handlers.errResult(40002, \"没有可更新的字段\")\n")
        sb.append("                        }\n")
        sb.append("                        // 构造 WHERE 条件\n")
        sb.append("                        var whereClause = \"\"\n")
        sb.append("                        match (idsVal) {\n")
        sb.append("                            case Some(JsonValue.String(idsStr)) =>\n")
        sb.append("                                // 批量更新：WHERE id IN ('uuid1','uuid2',...)\n")
        sb.append("                                let idList = ${className}Helpers_parseIdList(idsStr)\n")
        sb.append("                                if (idList.size == 0) {\n")
        sb.append("                                    return ${className}Handlers.errResult(40002, \"ids 参数为空\")\n")
        sb.append("                                }\n")
        sb.append("                                whereClause = \"id IN (${className}Helpers_joinQuoted(idList)})\"\n")
        sb.append("                            case _ =>\n")
        sb.append("                                // 单条更新\n")
        sb.append("                                match (idVal) {\n")
        sb.append("                                    case Some(JsonValue.String(idStr)) =>\n")
        sb.append("                                        whereClause = \"id = '\${idStr}'\"\n")
        sb.append("                                    case _ =>\n")
        sb.append("                                        return ${className}Handlers.errResult(40002, \"缺少 id 或 ids 参数\")\n")
        sb.append("                                }\n")
        sb.append("                        }\n")
        sb.append("                        // 调用 host.db execute update\n")
        sb.append("                        let execParam = HashMap<String, JsonValue>()\n")
        sb.append("                        execParam[\"operation\"] = JsonValue.String(\"execute\")\n")
        sb.append("                        execParam[\"subOp\"] = JsonValue.String(\"update\")\n")
        sb.append("                        execParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("                        execParam[\"where\"] = JsonValue.String(whereClause)\n")
        sb.append("                        execParam[\"data\"] = JsonValue.from(dataMap)\n")
        sb.append("                        execParam[\"permissions\"] = JsonValue.Array(permArr)\n")
        sb.append("                        if (!userId.isEmpty()) {\n")
        sb.append("                            execParam[\"userId\"] = JsonValue.String(userId)\n")
        sb.append("                        }\n")
        sb.append("                        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("                        execArgs[0] = JsonValue.from(execParam)\n")
        sb.append("                        let execResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"execute\", execArgs)\n")
        sb.append("                        eprintln(\"[${name}] host.db update result: \${execResult.stringify()}\")\n")
        sb.append("                        // 返回更新后的记录（单条）\n")
        sb.append("                        match (idVal) {\n")
        sb.append("                            case Some(JsonValue.String(idStr)) =>\n")
        sb.append("                                let getResult = ${className}Handlers.queryById(table, ctx, idStr, userId, permArr)\n")
        sb.append("                                return getResult\n")
        sb.append("                            case _ => ()\n")
        sb.append("                        }\n")
        sb.append("                        // 批量更新：返回成功\n")
        sb.append("                        return ${className}Handlers.okResult(\"edit\")\n")
        sb.append("                }\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    /// 生成 handleDel 方法
    private func writeHandleDel(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 删除：POST /api/v1/uctoo/{表名}/del\n")
        sb.append("     * body 单条: { id }\n")
        sb.append("     * body 批量: { ids: \"uuid1,uuid2,...\" }\n")
        sb.append("     * body 硬删: { id 或 ids, force: 1 }  // force=1 → 物理删除\n")
        sb.append("     * 软删：SET deleted_at = $raw:CURRENT_TIMESTAMP WHERE id IN (...)\n")
        sb.append("     */\n")
        sb.append("    private static func handleDel(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {\n")
        sb.append("        eprintln(\"[${name}] handleDel entered\")\n")
        sb.append("        let ctxOpt = ${className}Handlers.ctx\n")
        sb.append("        match (ctxOpt) {\n")
        sb.append("            case None => return ${className}Handlers.errResult(1, \"plugin context not initialized\")\n")
        sb.append("            case Some(ctx) =>\n")
        sb.append("                let body = ${className}Handlers.extractBody(fields)\n")
        sb.append("                match (body) {\n")
        sb.append("                    case None => return ${className}Handlers.errResult(40001, \"提交数据格式错误\")\n")
        sb.append("                    case Some(bodyMap) =>\n")
        sb.append("                        let userId = ${className}Handlers.extractString(fields, \"userId\")\n")
        sb.append("                        let permArr = ArrayList<JsonValue>()\n")
        sb.append("                        match (fields.get(\"permissions\")) {\n")
        sb.append("                            case Some(JsonValue.Array(arr)) =>\n")
        sb.append("                                for (p in arr) { permArr.add(p) }\n")
        sb.append("                            case _ => ()\n")
        sb.append("                        }\n")
        sb.append("                        // 解析 id / ids\n")
        sb.append("                        let idVal = bodyMap.get(\"id\")\n")
        sb.append("                        let idsVal = bodyMap.get(\"ids\")\n")
        sb.append("                        var whereClause = \"\"\n")
        sb.append("                        match (idsVal) {\n")
        sb.append("                            case Some(JsonValue.String(idsStr)) =>\n")
        sb.append("                                let idList = ${className}Helpers_parseIdList(idsStr)\n")
        sb.append("                                if (idList.size == 0) {\n")
        sb.append("                                    return ${className}Handlers.errResult(40002, \"ids 参数为空\")\n")
        sb.append("                                }\n")
        sb.append("                                whereClause = \"id IN (${className}Helpers_joinQuoted(idList)})\"\n")
        sb.append("                            case _ =>\n")
        sb.append("                                match (idVal) {\n")
        sb.append("                                    case Some(JsonValue.String(idStr)) =>\n")
        sb.append("                                        whereClause = \"id = '\${idStr}'\"\n")
        sb.append("                                    case _ =>\n")
        sb.append("                                        return ${className}Handlers.errResult(40002, \"缺少 id 或 ids 参数\")\n")
        sb.append("                                }\n")
        sb.append("                        }\n")
        sb.append("                        // 判断是否硬删（force=1）\n")
        sb.append("                        let forceVal = bodyMap.get(\"force\")\n")
        sb.append("                        let isHardDelete = match (forceVal) {\n")
        sb.append("                            case Some(JsonValue.Number(n)) => n == 1.0\n")
        sb.append("                            case Some(JsonValue.String(s)) => s == \"1\" || s == \"true\"\n")
        sb.append("                            case _ => false\n")
        sb.append("                        }\n")
        sb.append("                        // 调用 host.db execute\n")
        sb.append("                        let execParam = HashMap<String, JsonValue>()\n")
        sb.append("                        execParam[\"operation\"] = JsonValue.String(\"execute\")\n")
        sb.append("                        execParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("                        execParam[\"where\"] = JsonValue.String(whereClause)\n")
        sb.append("                        execParam[\"permissions\"] = JsonValue.Array(permArr)\n")
        sb.append("                        if (!userId.isEmpty()) {\n")
        sb.append("                            execParam[\"userId\"] = JsonValue.String(userId)\n")
        sb.append("                        }\n")
        sb.append("                        if (isHardDelete) {\n")
        sb.append("                            // 物理删除\n")
        sb.append("                            execParam[\"subOp\"] = JsonValue.String(\"delete\")\n")
        sb.append("                        } else {\n")
        sb.append("                            // 软删除：SET deleted_at = CURRENT_TIMESTAMP\n")
        sb.append("                            // \"$raw:\" 前缀让 host.db 生成原始 SQL 函数（不加引号）\n")
        sb.append("                            let dataMap = HashMap<String, JsonValue>()\n")
        sb.append("                            dataMap[\"deleted_at\"] = JsonValue.String(\"$raw:CURRENT_TIMESTAMP\")\n")
        sb.append("                            execParam[\"subOp\"] = JsonValue.String(\"update\")\n")
        sb.append("                            execParam[\"data\"] = JsonValue.from(dataMap)\n")
        sb.append("                        }\n")
        sb.append("                        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("                        execArgs[0] = JsonValue.from(execParam)\n")
        sb.append("                        let execResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"execute\", execArgs)\n")
        sb.append("                        eprintln(\"[${name}] host.db delete result: \${execResult.stringify()}\")\n")
        sb.append("                        return ${className}Handlers.okResult(\"del\")\n")
        sb.append("                }\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    /// 生成 handleGet 方法
    private func writeHandleGet(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 单条查询：GET /api/v1/uctoo/{表名}/:id\n")
        sb.append("     * 返回完整的 ${name} 记录（含已软删除的，由行级权限控制）\n")
        sb.append("     */\n")
        sb.append("    private static func handleGet(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {\n")
        sb.append("        eprintln(\"[${name}] handleGet entered\")\n")
        sb.append("        let ctxOpt = ${className}Handlers.ctx\n")
        sb.append("        match (ctxOpt) {\n")
        sb.append("            case None => return ${className}Handlers.errResult(1, \"plugin context not initialized\")\n")
        sb.append("            case Some(ctx) =>\n")
        sb.append("                // 1. 从 path 提取 id\n")
        sb.append("                let path = ${className}Handlers.extractString(fields, \"path\")\n")
        sb.append("                let parts = path.split(\"/\")\n")
        sb.append("                var idStr = \"\"\n")
        sb.append("                var tableIdx: Int64 = -1\n")
        sb.append("                for (i in 0..parts.size) {\n")
        sb.append("                    if (parts[i] == table) {\n")
        sb.append("                        tableIdx = i\n")
        sb.append("                        break\n")
        sb.append("                    }\n")
        sb.append("                }\n")
        sb.append("                if (tableIdx >= 0 && tableIdx + 1 < parts.size) {\n")
        sb.append("                    idStr = parts[tableIdx + 1]\n")
        sb.append("                }\n")
        sb.append("                if (idStr.isEmpty()) {\n")
        sb.append("                    return ${className}Handlers.errResult(40002, \"缺少 ID 参数\")\n")
        sb.append("                }\n")
        sb.append("                // 2. 查询\n")
        sb.append("                let userId = ${className}Handlers.extractString(fields, \"userId\")\n")
        sb.append("                let permArr = ArrayList<JsonValue>()\n")
        sb.append("                match (fields.get(\"permissions\")) {\n")
        sb.append("                    case Some(JsonValue.Array(arr)) =>\n")
        sb.append("                        for (p in arr) { permArr.add(p) }\n")
        sb.append("                    case _ => ()\n")
        sb.append("                }\n")
        sb.append("                let getResult = ${className}Handlers.queryById(table, ctx, idStr, userId, permArr)\n")
        sb.append("                // 3. 未找到返回 404\n")
        sb.append("                match (getResult) {\n")
        sb.append("                    case JsonValue.Null => return ${className}Handlers.errResult(40401, \"未找到该记录（表 \${table}）\")\n")
        sb.append("                    case _ => return getResult\n")
        sb.append("                }\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    /// 生成 handleList 方法
    private func writeHandleList(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 列表查询：经 ctx.invoke(\"host.db\", \"query\", ...) 查询数据库\n")
        sb.append("     * V4 列表格式: { currentPage, totalCount, totalPage, ${name}s: [...] }\n")
        sb.append("     * 列表键名 = 表名 + s（复数）→ \"${name}s\"（API 规范 §8.2）\n")
        sb.append("     */\n")
        sb.append("    private static func handleList(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {\n")
        sb.append("        eprintln(\"[${name}] handleList entered, args.size=\${args.size}\")\n")
        sb.append("        // 1. 从 ExternalRequest 中解析分页参数\n")
        sb.append("        let path = ${className}Handlers.extractString(fields, \"path\")\n")
        sb.append("        let parts = path.split(\"/\")\n")
        sb.append("        var limit: Int64 = 10\n")
        sb.append("        var page: Int64 = 1\n")
        sb.append("        var tableIdx: Int64 = -1\n")
        sb.append("        for (i in 0..parts.size) {\n")
        sb.append("            if (parts[i] == table) {\n")
        sb.append("                tableIdx = i\n")
        sb.append("                break\n")
        sb.append("            }\n")
        sb.append("        }\n")
        sb.append("        if (tableIdx >= 0) {\n")
        sb.append("            if (tableIdx + 1 < parts.size) {\n")
        sb.append("                let limitStr = parts[tableIdx + 1]\n")
        sb.append("                match (Int64.tryParse(limitStr)) {\n")
        sb.append("                    case Some(v) => limit = v\n")
        sb.append("                    case None => ()\n")
        sb.append("                }\n")
        sb.append("            }\n")
        sb.append("            if (tableIdx + 2 < parts.size) {\n")
        sb.append("                let pageStr = parts[tableIdx + 2]\n")
        sb.append("                match (Int64.tryParse(pageStr)) {\n")
        sb.append("                    case Some(v) => page = v\n")
        sb.append("                    case None => ()\n")
        sb.append("                }\n")
        sb.append("            }\n")
        sb.append("        }\n")
        sb.append("        // 2. 通过 ctx.invoke(\"host.db\", \"query\", ...) 查询数据库\n")
        sb.append("        let ctxOpt = ${className}Handlers.ctx\n")
        sb.append("        eprintln(\"[${name}] ctxOpt is \" + (if (ctxOpt.isNone()) { \"None\" } else { \"Some\" }))\n")
        sb.append("        match (ctxOpt) {\n")
        sb.append("            case None => return ${className}Handlers.errResult(1, \"plugin context not initialized\")\n")
        sb.append("            case Some(ctx) =>\n")
        sb.append("                let userId = fields.get(\"userId\")\n")
        sb.append("                let permissions = fields.get(\"permissions\")\n")
        sb.append("                // 解析 filter 查询参数 → WHERE 子句\n")
        sb.append("                let whereClause = ${className}Handlers.buildWhereFromFilter(fields)\n")
        sb.append("                // 构造 host.db query 参数\n")
        sb.append("                let queryParam = HashMap<String, JsonValue>()\n")
        sb.append("                queryParam[\"operation\"] = JsonValue.String(\"query\")\n")
        sb.append("                queryParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("                queryParam[\"where\"] = JsonValue.String(whereClause)\n")
        sb.append("                queryParam[\"orderBy\"] = JsonValue.String(\"created_at DESC\")\n")
        sb.append("                queryParam[\"limit\"] = JsonValue.Number(Float64(limit))\n")
        sb.append("                queryParam[\"offset\"] = JsonValue.Number(Float64((page - 1) * limit))\n")
        sb.append("                match (userId) {\n")
        sb.append("                    case Some(v) => queryParam[\"userId\"] = v\n")
        sb.append("                    case None => ()\n")
        sb.append("                }\n")
        sb.append("                match (permissions) {\n")
        sb.append("                    case Some(v) => queryParam[\"permissions\"] = v\n")
        sb.append("                    case None => ()\n")
        sb.append("                }\n")
        sb.append("                let queryArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("                queryArgs[0] = JsonValue.from(queryParam)\n")
        sb.append("                let queryResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"query\", queryArgs)\n")
        sb.append("                eprintln(\"[${name}] host.db query result: \${queryResult.stringify()}\")\n")
        sb.append("                // 3. 查询总数（使用相同的 where 条件）\n")
        sb.append("                let countParam = HashMap<String, JsonValue>()\n")
        sb.append("                countParam[\"operation\"] = JsonValue.String(\"count\")\n")
        sb.append("                countParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("                countParam[\"where\"] = JsonValue.String(whereClause)\n")
        sb.append("                match (userId) {\n")
        sb.append("                    case Some(v) => countParam[\"userId\"] = v\n")
        sb.append("                    case None => ()\n")
        sb.append("                }\n")
        sb.append("                match (permissions) {\n")
        sb.append("                    case Some(v) => countParam[\"permissions\"] = v\n")
        sb.append("                    case None => ()\n")
        sb.append("                }\n")
        sb.append("                let countArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("                countArgs[0] = JsonValue.from(countParam)\n")
        sb.append("                let countResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"count\", countArgs)\n")
        sb.append("                eprintln(\"[${name}] host.db count result: \${countResult.stringify()}\")\n")
        sb.append("                // 4. 构造 V4 列表格式响应\n")
        sb.append("                let response = HashMap<String, JsonValue>()\n")
        sb.append("                response[\"currentPage\"] = JsonValue.Number(Float64(page))\n")
        sb.append("                var totalCount: Int64 = 0\n")
        sb.append("                match (countResult) {\n")
        sb.append("                    case JsonValue.Map(countFields) =>\n")
        sb.append("                        match (countFields.get(\"count\")) {\n")
        sb.append("                            case Some(JsonValue.Number(n)) => totalCount = Int64(n)\n")
        sb.append("                            case _ => ()\n")
        sb.append("                        }\n")
        sb.append("                    case _ => ()\n")
        sb.append("                }\n")
        sb.append("                response[\"totalCount\"] = JsonValue.Number(Float64(totalCount))\n")
        sb.append("                var totalPage: Int64 = 0\n")
        sb.append("                if (limit > 0) {\n")
        sb.append("                    totalPage = (totalCount + limit - 1) / limit\n")
        sb.append("                }\n")
        sb.append("                response[\"totalPage\"] = JsonValue.Number(Float64(totalPage))\n")
        sb.append("                let rows = match (queryResult) {\n")
        sb.append("                    case JsonValue.Map(queryFields) =>\n")
        sb.append("                        match (queryFields.get(\"rows\")) {\n")
        sb.append("                            case Some(JsonValue.Array(arr)) => arr\n")
        sb.append("                            case _ => ArrayList<JsonValue>()\n")
        sb.append("                        }\n")
        sb.append("                    case _ => ArrayList<JsonValue>()\n")
        sb.append("                }\n")
        sb.append("                response[\"\${table}s\"] = JsonValue.Array(rows)\n")
        sb.append("                return JsonValue.from(response)\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    /// 生成 handleEmptyRecycleBin 方法
    private func writeHandleEmptyRecycleBin(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 清空回收站：POST /api/v1/uctoo/{表名}/empty-recycle-bin\n")
        sb.append("     * 物理删除所有 deleted_at NOT NULL 的记录\n")
        sb.append("     */\n")
        sb.append("    private static func handleEmptyRecycleBin(table: String, fields: HashMap<String, JsonValue>, args: Array<JsonValue>): JsonValue {\n")
        sb.append("        eprintln(\"[${name}] handleEmptyRecycleBin entered\")\n")
        sb.append("        let ctxOpt = ${className}Handlers.ctx\n")
        sb.append("        match (ctxOpt) {\n")
        sb.append("            case None => return ${className}Handlers.errResult(1, \"plugin context not initialized\")\n")
        sb.append("            case Some(ctx) =>\n")
        sb.append("                let userId = ${className}Handlers.extractString(fields, \"userId\")\n")
        sb.append("                let permArr = ArrayList<JsonValue>()\n")
        sb.append("                match (fields.get(\"permissions\")) {\n")
        sb.append("                    case Some(JsonValue.Array(arr)) =>\n")
        sb.append("                        for (p in arr) { permArr.add(p) }\n")
        sb.append("                    case _ => ()\n")
        sb.append("                }\n")
        sb.append("                // 物理删除所有已软删除的记录\n")
        sb.append("                let execParam = HashMap<String, JsonValue>()\n")
        sb.append("                execParam[\"operation\"] = JsonValue.String(\"execute\")\n")
        sb.append("                execParam[\"subOp\"] = JsonValue.String(\"delete\")\n")
        sb.append("                execParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("                execParam[\"where\"] = JsonValue.String(\"deleted_at IS NOT NULL\")\n")
        sb.append("                execParam[\"permissions\"] = JsonValue.Array(permArr)\n")
        sb.append("                if (!userId.isEmpty()) {\n")
        sb.append("                    execParam[\"userId\"] = JsonValue.String(userId)\n")
        sb.append("                }\n")
        sb.append("                let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("                execArgs[0] = JsonValue.from(execParam)\n")
        sb.append("                let execResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"execute\", execArgs)\n")
        sb.append("                eprintln(\"[${name}] host.db empty-recycle-bin result: \${execResult.stringify()}\")\n")
        sb.append("                return ${className}Handlers.okResult(\"empty-recycle-bin\")\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    // ── 内部辅助方法生成 ──

    /// 生成 doRestore 方法
    private func writeDoRestore(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 执行恢复操作：SET deleted_at=NULL WHERE id IN (...)\n")
        sb.append("     */\n")
        sb.append("    private static func doRestore(\n")
        sb.append("        table: String,\n")
        sb.append("        ctx: PluginContext,\n")
        sb.append("        bodyMap: HashMap<String, JsonValue>,\n")
        sb.append("        userId: String,\n")
        sb.append("        permArr: ArrayList<JsonValue>\n")
        sb.append("    ): JsonValue {\n")
        sb.append("        var whereClause = \"\"\n")
        sb.append("        let idsVal = bodyMap.get(\"ids\")\n")
        sb.append("        let idVal = bodyMap.get(\"id\")\n")
        sb.append("        match (idsVal) {\n")
        sb.append("            case Some(JsonValue.String(idsStr)) =>\n")
        sb.append("                let idList = ${className}Helpers_parseIdList(idsStr)\n")
        sb.append("                if (idList.size == 0) {\n")
        sb.append("                    return ${className}Handlers.errResult(40002, \"ids 参数为空\")\n")
        sb.append("                }\n")
        sb.append("                whereClause = \"id IN (${className}Helpers_joinQuoted(idList)})\"\n")
        sb.append("            case _ =>\n")
        sb.append("                match (idVal) {\n")
        sb.append("                    case Some(JsonValue.String(idStr)) =>\n")
        sb.append("                        whereClause = \"id = '\${idStr}'\"\n")
        sb.append("                    case _ =>\n")
        sb.append("                        return ${className}Handlers.errResult(40002, \"缺少 id 或 ids 参数\")\n")
        sb.append("                }\n")
        sb.append("        }\n")
        sb.append("        // 恢复：deleted_at = NULL\n")
        sb.append("        let dataMap = HashMap<String, JsonValue>()\n")
        sb.append("        dataMap[\"deleted_at\"] = JsonValue.Null\n")
        sb.append("        let execParam = HashMap<String, JsonValue>()\n")
        sb.append("        execParam[\"operation\"] = JsonValue.String(\"execute\")\n")
        sb.append("        execParam[\"subOp\"] = JsonValue.String(\"update\")\n")
        sb.append("        execParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("        execParam[\"where\"] = JsonValue.String(whereClause)\n")
        sb.append("        execParam[\"data\"] = JsonValue.from(dataMap)\n")
        sb.append("        execParam[\"permissions\"] = JsonValue.Array(permArr)\n")
        sb.append("        if (!userId.isEmpty()) {\n")
        sb.append("            execParam[\"userId\"] = JsonValue.String(userId)\n")
        sb.append("        }\n")
        sb.append("        let execArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("        execArgs[0] = JsonValue.from(execParam)\n")
        sb.append("        let execResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"execute\", execArgs)\n")
        sb.append("        eprintln(\"[${name}] host.db restore result: \${execResult.stringify()}\")\n")
        sb.append("        return ${className}Handlers.okResult(\"restore\")\n")
        sb.append("    }\n\n")
    }

    /// 生成 queryById 方法
    private func writeQueryById(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 按 id 查询单条记录\n")
        sb.append("     * 返回 JsonValue（记录对象）或 JsonValue.Null（未找到）\n")
        sb.append("     */\n")
        sb.append("    private static func queryById(\n")
        sb.append("        table: String,\n")
        sb.append("        ctx: PluginContext,\n")
        sb.append("        idStr: String,\n")
        sb.append("        userId: String,\n")
        sb.append("        permArr: ArrayList<JsonValue>\n")
        sb.append("    ): JsonValue {\n")
        sb.append("        let queryParam = HashMap<String, JsonValue>()\n")
        sb.append("        queryParam[\"operation\"] = JsonValue.String(\"query\")\n")
        sb.append("        queryParam[\"table\"] = JsonValue.String(table)\n")
        sb.append("        queryParam[\"where\"] = JsonValue.String(\"id = '\${idStr}'\")\n")
        sb.append("        queryParam[\"limit\"] = JsonValue.Number(1.0)\n")
        sb.append("        if (!userId.isEmpty()) {\n")
        sb.append("            queryParam[\"userId\"] = JsonValue.String(userId)\n")
        sb.append("        }\n")
        sb.append("        queryParam[\"permissions\"] = JsonValue.Array(permArr)\n")
        sb.append("        let queryArgs = Array<JsonValue>(1, { _ => JsonValue.Null })\n")
        sb.append("        queryArgs[0] = JsonValue.from(queryParam)\n")
        sb.append("        let queryResult = ctx.invoke<JsonValue, JsonValue>(\"host.db\", \"query\", queryArgs)\n")
        sb.append("        match (queryResult) {\n")
        sb.append("            case JsonValue.Map(qFields) =>\n")
        sb.append("                match (qFields.get(\"rows\")) {\n")
        sb.append("                    case Some(JsonValue.Array(rows)) =>\n")
        sb.append("                        if (rows.size > 0) {\n")
        sb.append("                            return rows[0]\n")
        sb.append("                        }\n")
        sb.append("                    case _ => ()\n")
        sb.append("                }\n")
        sb.append("            case _ => ()\n")
        sb.append("        }\n")
        sb.append("        return JsonValue.Null\n")
        sb.append("    }\n\n")
    }

    /// 生成 buildWhereFromFilter 方法
    private func writeBuildWhereFromFilter(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 从 ExternalRequest 的 queryParams 中解析 filter 参数，构建 WHERE 子句。\n")
        sb.append("     *\n")
        sb.append("     * Web 前端发送的 filter 参数（URL 编码的 JSON）：\n")
        sb.append("     * - 普通模式: filter={\"deleted_at\":null}          → deleted_at IS NULL\n")
        sb.append("     * - 回收站:   filter={\"deleted_at\":{\"not\":null}} → deleted_at IS NOT NULL\n")
        sb.append("     *\n")
        sb.append("     * 约定：queryParams.filter 是 URL 编码字符串，需要先 URL 解码再 JSON 解析。\n")
        sb.append("     */\n")
        sb.append("    private static func buildWhereFromFilter(fields: HashMap<String, JsonValue>): String {\n")
        sb.append("        // 1. 从 queryParams 中提取 filter 参数\n")
        sb.append("        var filterStr = \"\"\n")
        sb.append("        match (fields.get(\"queryParams\")) {\n")
        sb.append("            case Some(JsonValue.Map(qp)) =>\n")
        sb.append("                match (qp.get(\"filter\")) {\n")
        sb.append("                    case Some(JsonValue.String(s)) => filterStr = s\n")
        sb.append("                    case _ => ()\n")
        sb.append("                }\n")
        sb.append("            case _ => ()\n")
        sb.append("        }\n")
        sb.append("        eprintln(\"[${name}] buildWhereFromFilter: raw filter='\${filterStr}'\")\n")
        sb.append("        // 2. URL 解码（兼容 %22 → \" 等编码）\n")
        sb.append("        if (!filterStr.isEmpty()) {\n")
        sb.append("            filterStr = filterStr.replace(\"%7B\", \"{\")\n")
        sb.append("                .replace(\"%7D\", \"}\")\n")
        sb.append("                .replace(\"%22\", \"\\\"\")\n")
        sb.append("                .replace(\"%3A\", \":\")\n")
        sb.append("                .replace(\"%2C\", \",\")\n")
        sb.append("                .replace(\"+\", \" \")\n")
        sb.append("        }\n")
        sb.append("        // 3. 缺省：普通模式（deleted_at IS NULL）\n")
        sb.append("        if (filterStr.isEmpty()) {\n")
        sb.append("            return \"deleted_at IS NULL\"\n")
        sb.append("        }\n")
        sb.append("        // 4. JSON 解析 filter\n")
        sb.append("        try {\n")
        sb.append("            let filterJson = JsonValue.parse(filterStr)\n")
        sb.append("            match (filterJson) {\n")
        sb.append("                case JsonValue.Map(filterMap) =>\n")
        sb.append("                    // 检查 deleted_at 字段\n")
        sb.append("                    match (filterMap.get(\"deleted_at\")) {\n")
        sb.append("                        case Some(JsonValue.Null) =>\n")
        sb.append("                            // {\"deleted_at\":null} → deleted_at IS NULL\n")
        sb.append("                            return \"deleted_at IS NULL\"\n")
        sb.append("                        case Some(JsonValue.Map(daMap)) =>\n")
        sb.append("                            // {\"deleted_at\":{\"not\":null}} → deleted_at IS NOT NULL\n")
        sb.append("                            match (daMap.get(\"not\")) {\n")
        sb.append("                                case Some(JsonValue.Null) => return \"deleted_at IS NOT NULL\"\n")
        sb.append("                                case _ => ()\n")
        sb.append("                            }\n")
        sb.append("                            // 其他操作符暂不支持，降级为 deleted_at IS NULL\n")
        sb.append("                            return \"deleted_at IS NULL\"\n")
        sb.append("                        case _ => ()\n")
        sb.append("                    }\n")
        sb.append("                case _ => ()\n")
        sb.append("            }\n")
        sb.append("        } catch (e: Exception) {\n")
        sb.append("            eprintln(\"[${name}] buildWhereFromFilter: JSON parse error: \${e.message}\")\n")
        sb.append("        }\n")
        sb.append("        // 5. 兜底：普通模式\n")
        sb.append("        return \"deleted_at IS NULL\"\n")
        sb.append("    }\n\n")
    }

    /// 生成 extractBody 方法
    private func writeExtractBody(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /**\n")
        sb.append("     * 从 ExternalRequest 提取 body（POST 请求体 JSON）\n")
        sb.append("     * body 字段是 JsonValue（parseBody 解析结果）\n")
        sb.append("     */\n")
        sb.append("    private static func extractBody(fields: HashMap<String, JsonValue>): ?HashMap<String, JsonValue> {\n")
        sb.append("        match (fields.get(\"body\")) {\n")
        sb.append("            case Some(JsonValue.Map(bodyMap)) => return Some(bodyMap)\n")
        sb.append("            case _ => return None\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    /// 生成 extractStringFromMap 方法
    private func writeExtractStringFromMap(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    /// 从 HashMap<String, JsonValue> 提取纯字符串值\n")
        sb.append("    private static func extractStringFromMap(map: HashMap<String, JsonValue>, key: String): String {\n")
        sb.append("        match (map.get(key)) {\n")
        sb.append("            case Some(JsonValue.String(s)) => return s\n")
        sb.append("            case _ => return \"\"\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    /// 生成 okResult 方法
    private func writeOkResult(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    private static func okResult(op: String): JsonValue {\n")
        sb.append("        let m = HashMap<String, JsonValue>()\n")
        sb.append("        m[\"errno\"] = JsonValue.Number(0.0)\n")
        sb.append("        m[\"errmsg\"] = JsonValue.String(\"ok\")\n")
        sb.append("        m[\"op\"] = JsonValue.String(op)\n")
        sb.append("        return JsonValue.from(m)\n")
        sb.append("    }\n\n")
    }

    /// 生成 errResult 方法
    private func writeErrResult(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    private static func errResult(errno: Int64, errmsg: String): JsonValue {\n")
        sb.append("        let m = HashMap<String, JsonValue>()\n")
        sb.append("        m[\"errno\"] = JsonValue.Number(Float64(errno))\n")
        sb.append("        m[\"errmsg\"] = JsonValue.String(errmsg)\n")
        sb.append("        return JsonValue.from(m)\n")
        sb.append("    }\n\n")
    }

    /// 生成 extractString 方法
    private func writeExtractString(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("    private static func extractString(fields: HashMap<String, JsonValue>, key: String): String {\n")
        sb.append("        match (fields.get(key)) {\n")
        sb.append("            case Some(JsonValue.String(s)) => s\n")
        sb.append("            case _ => \"\"\n")
        sb.append("        }\n")
        sb.append("    }\n")
    }

    // ── 顶层辅助函数生成 ──

    /// 生成 parseIdList 函数
    private func writeParseIdList(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("// ── 顶层辅助函数（解析 id 列表、拼接 SQL）─────────────────────────\n\n")
        sb.append("/// 解析 ids 字符串为 ArrayList<String>\n")
        sb.append("/// 支持格式：\n")
        sb.append("/// - JSON 数组字符串: '[\"uuid1\",\"uuid2\"]'\n")
        sb.append("/// - 逗号分隔: 'uuid1,uuid2'\n")
        sb.append("public func ${className}Helpers_parseIdList(idsStr: String): ArrayList<String> {\n")
        sb.append("    let idList = ArrayList<String>()\n")
        sb.append("    if (idsStr.isEmpty()) {\n")
        sb.append("        return idList\n")
        sb.append("    }\n")
        sb.append("    // 尝试 JSON 数组解析\n")
        sb.append("    try {\n")
        sb.append("        let jsonValue = JsonValue.parse(idsStr)\n")
        sb.append("        match (jsonValue) {\n")
        sb.append("            case JsonValue.Array(arr) =>\n")
        sb.append("                for (item in arr) {\n")
        sb.append("                    match (item) {\n")
        sb.append("                        case JsonValue.String(s) =>\n")
        sb.append("                            if (!s.isEmpty()) { idList.add(s) }\n")
        sb.append("                        case _ => ()\n")
        sb.append("                    }\n")
        sb.append("                }\n")
        sb.append("                return idList\n")
        sb.append("            case _ => ()\n")
        sb.append("        }\n")
        sb.append("    } catch (e: Exception) {\n")
        sb.append("        // 非 JSON，尝试逗号分隔\n")
        sb.append("        let parts = idsStr.split(\",\")\n")
        sb.append("        for (p in parts) {\n")
        sb.append("            let trimmed = p.trimAscii()\n")
        sb.append("            if (!trimmed.isEmpty() && trimmed != \"[\" && trimmed != \"]\" && trimmed != \"{\" && trimmed != \"}\") {\n")
        sb.append("                idList.add(trimmed)\n")
        sb.append("            }\n")
        sb.append("        }\n")
        sb.append("    }\n")
        sb.append("    return idList\n")
        sb.append("}\n\n")
    }

    /// 生成 joinQuoted 函数
    private func writeJoinQuoted(sb: StringBuilder, name: String, className: String): Unit {
        sb.append("/// 将 ArrayList<String> 拼接为 SQL IN 子句格式\n")
        sb.append("/// 示例: [\"uuid1\", \"uuid2\"] → \"'uuid1','uuid2'\"\n")
        sb.append("public func ${className}Helpers_joinQuoted(idList: ArrayList<String>): String {\n")
        sb.append("    let sb = StringBuilder()\n")
        sb.append("    var first = true\n")
        sb.append("    for (id in idList) {\n")
        sb.append("        if (!first) {\n")
        sb.append("            sb.append(\",\")\n")
        sb.append("        }\n")
        sb.append("        // 转义单引号\n")
        sb.append("        let escaped = id.replace(\"'\", \"''\")\n")
        sb.append("        sb.append(\"'\")\n")
        sb.append("        sb.append(escaped)\n")
        sb.append("        sb.append(\"'\")\n")
        sb.append("        first = false\n")
        sb.append("    }\n")
        sb.append("    return sb.toString()\n")
        sb.append("}\n")
    }
}
