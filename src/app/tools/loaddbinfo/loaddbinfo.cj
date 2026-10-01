/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.tools.loaddbinfo

import std.collection.*
import std.process.*
import std.io.*
import f_orm.*
import f_config.Config
import f_orm.wrap.ORMConfig
import std.database.sql.DriverManager
import pgsql.PostgresDriver
import std.fs.{Path, File, exists}
import std.regex.Regex
import magic.app.services.uctoo.DbInfoService
import magic.app.core.response.APIResult

/**
 * 数据库信息加载命令行工具
 *
 * 从数据库结构（information_schema）读取表结构信息，
 * 保存到 db_info 表中，供 crudgen 等工具使用。
 *
 * 用法：
 *   loaddbinfo --db <数据库名>
 *
 * 示例：
 *   # 加载指定数据库的表结构信息到 db_info 表
 *   loaddbinfo --db uctoo
 */
main(args: Array<String>) {
    println("LoadDbInfo starting...")
    println("Args: ${args}")

    // 加载 .env 环境变量（orm_* 数据源配置来源）
    // 与 plugingen/main.cj 及 crudgen.cj 启动流程一致：读取 .env → Config.set → ORMConfig.refresh → ORM.initialize
    // 否则 ORMConfig.getDefaultDriver() 为空，ORM.executor() 抛 "default datasource is not specified"
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

    // 将 .env 中的 ORM 配置显式同步到 fountain 的 Config 中
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

    // 初始化ORM和数据库连接
    if (!initializeORM()) {
        println("错误: 无法初始化数据库连接")
        println("请确保:")
        println("1. 配置文件(config.yaml或config.toml)存在且配置正确")
        println("2. 数据库服务正在运行")
        println("3. 数据库连接信息正确")
        return
    }

    var dbName: String = ""

    // 解析命令行参数
    var i = 0
    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--db" =>
                if (i + 1 < args.size) {
                    dbName = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--help" | "-h" =>
                printHelp()
                return
            case _ =>
                println("未知参数: ${arg}")
                printHelp()
                return
        }
    }

    // 验证参数
    if (dbName.isEmpty()) {
        println("错误: 必须指定数据库名 (--db)")
        printHelp()
        return
    }

    // 执行数据库信息加载
    try {
        println("开始加载数据库 ${dbName} 的表结构信息...")

        let service = DbInfoService()
        let result = service.loadDbInfo(dbName)

        if (result.success) {
            if (let Some(count) <- result.data) {
                println("数据库信息加载成功！共加载 ${count} 条列信息到 db_info 表。")
            } else {
                println("数据库信息加载成功！")
            }
        } else {
            let reason = result.reason ?? "加载失败"
            println("错误: ${reason}")
        }
    } catch (e: Exception) {
        println("错误: ${e.message}")
    }
}

/**
 * 打印帮助信息
 */
func printHelp(): Unit {
    println("数据库信息加载命令行工具")
    println("")
    println("从数据库结构(information_schema)读取表结构信息，保存到 db_info 表。")
    println("")
    println("用法：")
    println("  loaddbinfo --db <数据库名>")
    println("")
    println("选项：")
    println("  --db <数据库名>    指定要加载的数据库名")
    println("  --help, -h         显示帮助信息")
    println("")
    println("示例：")
    println("  # 加载 uctoo 数据库的表结构信息")
    println("  loaddbinfo --db uctoo")
    println("")
    println("说明：")
    println("  1. 此工具独立运行，不依赖 runtime 服务启动")
    println("  2. 加载后会清空该数据库原有的 db_info 记录并重新写入")
    println("  3. 支持 PostgreSQL 和 MySQL 数据库")
    println("  4. 加载完成后可使用 crudgen 工具生成 CRUD 代码")
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

/**
 * 初始化ORM和数据库连接
 * 与 crudgen 工具使用相同的初始化逻辑
 */
func initializeORM(): Bool {
    try {
        println("正在初始化数据库连接...")

        // 注册 PostgreSQL 驱动
        let driver = DriverManager.getDriver("postgres")
        if (driver.isNone()) {
            let pgDriver = PostgresDriver()
            DriverManager.register("postgres", pgDriver)
            println("PostgreSQL驱动已注册")
        }

        // 初始化ORM
        ORM.initialize()
        println("ORM初始化成功")

        println("数据库连接成功")

        return true
    } catch (e: Exception) {
        println("初始化失败: ${e.message}")
        return false
    }
}
