/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import f_orm.ORM
import f_orm.wrap.ORMConfig
import f_config.Config
import std.collection.HashMap
import std.database.sql.DriverManager
import std.fs.{Path, File, exists}
import std.regex.Regex
import pgsql.PostgresDriver

/**
 * plugingen - 插件生成器命令行工具（PS-T013）
 *
 * 与 crudgen 同构的确定性生成工具，产出插件形态代码（插件轨）；
 * crudgen/crudweb 保持不动，继续承担宿主代码通道（存量轨）。
 *
 * 用法：
 *   # 表驱动：从 db_info 读表结构，生成五层 CRUD 插件到 skills/{name}/
 *   plugingen --name <插件名> --db <数据库名> --table <表名>
 *
 *   # 空白骨架：仅生成 SKILL.md + plugin.yaml + 包占位 + 插件入口
 *   plugingen --name <插件名> --blank
 *
 *   plugingen --help
 *
 * 示例：
 *   plugingen --name entity --db uctoo --table entity
 *   plugingen --name mytool --blank
 */
main(args: Array<String>) {
    println("Plugin Generator (plugingen) starting...")
    println("Args: ${args}")

    var pluginName = ""
    var dbName = ""
    var tableName = ""
    var blank = false
    var mode = "sync"  // 缺省 sync 轨；process 轨产出独立 cjpm executable 工程

    var i = 0
    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--name" =>
                if (i + 1 < args.size) {
                    pluginName = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--db" =>
                if (i + 1 < args.size) {
                    dbName = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--table" =>
                if (i + 1 < args.size) {
                    tableName = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--mode" =>
                if (i + 1 < args.size) {
                    mode = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--blank" =>
                blank = true
                i += 1
            case "--help" | "-h" =>
                printHelp()
                return
            case _ =>
                println("未知参数: ${arg}")
                printHelp()
                return
        }
    }

    // mode 校验：仅支持 sync/dylib/process
    if (mode != "sync" && mode != "dylib" && mode != "process") {
        println("错误: --mode 仅支持 sync/dylib/process，当前值: ${mode}")
        printHelp()
        return
    }

    if (pluginName.isEmpty()) {
        println("错误: 必须指定插件名 (--name)")
        printHelp()
        return
    }

    // 插件名校验：包名段合法性 + 保留名保护
    let rules = NameRules()
    let (normalized, replaced) = rules.normalizePluginName(pluginName)
    if (replaced) {
        println("提示: 插件名已规范化为 '${normalized}'（连字符转下划线，包名段要求）")
    }
    if (!rules.isValidPluginName(normalized)) {
        println("错误: 插件名 '${normalized}' 不是合法包名段（仅小写字母/数字/下划线，不以数字开头）")
        return
    }
    if (rules.isReservedName(normalized)) {
        println("错误: 插件名 '${normalized}' 是保留名（src/plugins/ 示例插件，禁止覆盖）")
        return
    }

    // L3 进程隔离轨：独立 cjpm executable 工程（design §5.3）
    // 不走表驱动（进程插件经 host.db 服务代理访问数据，不直接依赖 f_orm/DbInfoPO）
    if (mode == "process") {
        let generator = PluginGenerator()
        if (generator.generateProcessPlugin(normalized)) {
            println("\nL3 进程轨插件生成完成！")
            println("后续步骤:")
            println("1. cd skills/${normalized} && cjpm build（产出 target/release/skill_${normalized}.exe）")
            println("2. 在 config/plugins.yaml 追加 mode:process + command 条目")
            println("3. 启动宿主后经 CordisHostManager 加载，路由经 ExternalPluginRouteGateway 注册")
        } else {
            println("\n生成失败，请检查上述错误信息")
        }
        return
    }

    if (blank) {
        let generator = PluginGenerator()
        if (generator.generateBlankPlugin(normalized)) {
            println("\n空白插件骨架生成完成！")
        } else {
            println("\n生成失败，请检查上述错误信息")
        }
        return
    }

    if (dbName.isEmpty() || tableName.isEmpty()) {
        println("错误: 表驱动模式必须同时指定 --db 与 --table（或使用 --blank 生成空白骨架）")
        printHelp()
        return
    }

    // 加载 .env 环境变量（orm_* 数据源配置来源）
    // 注意1：不引入 magic.config.EnvWrapper——plugingen 可执行体仅链接 magic.app.models.uctoo
    //   与 fountain 外部库，引入 magic.config 会产生 undefined symbol（链接库集合不含该包）；
    //   故本地轻量行级解析（解析行为对齐 EnvWrapper.load），参照 package_release 同款先例。
    // 注意2：f_config.Config 的 static init 在首次触碰时快照系统环境变量，setEnv 时序不可靠；
    //   须显式 Config.set 写入 fountain 配置表并 ORMConfig.refresh，确保 ORM.initialize 拿到默认数据源。
    let envPaths = [Path("./.env"), Path("../.env")]
    var envMap = HashMap<String, String>()
    var envLoaded = false
    for (envPath in envPaths) {
        if (let Some(map) <- loadEnvFile(envPath)) {
            println("已加载 .env: ${envPath}")
            envMap = map
            envLoaded = true
            break
        }
    }
    if (!envLoaded) {
        println("警告: 未找到可用的 .env 文件，将使用默认/系统环境变量中的 orm_* 配置")
    }

    // 将 .env 中的 ORM 配置显式同步到 fountain 的 Config 中（与 main.cj 启动流程一致）
    let ormDrivers = envGetOrDefault(envMap, "orm_drivers", "postgres")
    let ormDefaultDriver = envGetOrDefault(envMap, "orm_defaultDriver", "postgres")
    let ormConnectionUrl = envGetOrDefault(envMap, "orm_connectionUrl", "")
    let postgresOrmConnectionUrl = envGetOrDefault(envMap, "postgres_orm_connectionUrl", ormConnectionUrl)
    Config.set([
        ("orm_drivers", ormDrivers),
        ("orm_defaultDriver", ormDefaultDriver),
        ("orm_connectionUrl", ormConnectionUrl),
        ("postgres_orm_connectionUrl", postgresOrmConnectionUrl)
    ])
    ORMConfig.refresh {
    }

    if (!initializeORM()) {
        println("错误: 无法初始化数据库连接")
        println("请确保:")
        println("1. 配置文件(config.yaml或config.toml)存在且配置正确")
        println("2. 数据库服务正在运行")
        println("3. 数据库连接信息正确")
        return
    }

    let generator = PluginGenerator()
    if (generator.generateCrudPlugin(normalized, dbName, tableName)) {
        println("\n插件生成完成！")
        println("后续步骤:")
        println("1. cjpm build（build-sync 自动同步 skills/ -> src/plugins/ 并编译）")
        println("2. 启动宿主后经 PluginHostManager 加载，路由经 PluginRouteScanner 注册")
    } else {
        println("\n生成失败，请检查上述错误信息")
    }
}

/**
 * 打印帮助信息
 */
func printHelp(): Unit {
    println("插件生成器命令行工具（plugingen，插件轨；宿主模块请用 crudgen）")
    println("")
    println("用法：")
    println("  plugingen --name <插件名> --db <数据库名> --table <表名>")
    println("  plugingen --name <插件名> --blank")
    println("")
    println("选项：")
    println("  --name <插件名>   插件唯一名（小写字母/数字/下划线；连字符自动转下划线）")
    println("  --db <数据库名>   表驱动模式：数据库名（读 db_info 表结构）")
    println("  --table <表名>    表驱动模式：表名")
    println("  --mode <轨>       加载轨：sync（缺省）/ dylib / process")
    println("  --blank           生成空白插件骨架（跳过表结构）")
    println("  --help, -h        显示帮助")
    println("")
    println("输出：")
    println("  skills/{name}/SKILL.md          技能定义（SkillEngine 资产）")
    println("  skills/{name}/plugin.yaml       插件清单（design.md §2.5）")
    println("  skills/{name}/scripts/cj/       仓颉源码（包 magic.plugins.{name}）")
    println("  config/plugins.yaml             自动追加启用条目")
    println("")
    println("示例：")
    println("  plugingen --name entity --db uctoo --table entity")
    println("  plugingen --name mytool --blank")
}

/**
 * 初始化ORM和数据库连接（与 crudgen 同构）
 */
func initializeORM(): Bool {
    try {
        println("正在初始化数据库连接...")

        let driver = DriverManager.getDriver("postgres")
        if (driver.isNone()) {
            let pgDriver = PostgresDriver()
            DriverManager.register("postgres", pgDriver)
            println("PostgreSQL驱动已注册")
        }

        ORM.initialize()
        println("ORM初始化成功")
        return true
    } catch (e: Exception) {
        println("初始化失败: ${e.message}")
        return false
    }
}

/**
 * 轻量解析 .env 文件（不引入 magic.config 依赖）
 *
 * 行级 KEY=VALUE 解析，支持行尾注释与成对引号剥离，
 * 解析行为对齐 magic.config.EnvWrapper.load 的正则规则。
 *
 * @param path .env 文件路径
 * @return 成功返回键值表；文件不存在或读取失败返回 None
 */
func loadEnvFile(path: Path): Option<HashMap<String, String>> {
    if (!exists(path)) {
        return None<HashMap<String, String>>
    }
    let map = HashMap<String, String>()
    try {
        let content = String.fromUtf8(File.readFrom(path))
        let regex = Regex("^\\s*([\\w.]+)\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^#]*)\\s*(?:#.*)?$")
        for (line in content.split("\n")) {
            if (let Some(md) <- regex.find(line, group: true)) {
                let key = md.matchString(1).trimAscii()
                var value = md.matchString(2).trimAscii()
                if (value.startsWith("\"")) {
                    value = value.replace("\"", "")
                } else if (value.startsWith("'")) {
                    value = value.replace("'", "")
                }
                if (!key.isEmpty()) {
                    map[key] = value
                }
            }
        }
        return Some(map)
    } catch (_: Exception) {
        println("警告: 读取 ${path} 失败，忽略该文件")
        return None<HashMap<String, String>>
    }
}

/**
 * 从 .env 键值表读取配置，缺省时返回默认值
 */
func envGetOrDefault(map: HashMap<String, String>, key: String, dft: String): String {
    if (let Some(v) <- map.get(key)) {
        return v
    }
    return dft
}
