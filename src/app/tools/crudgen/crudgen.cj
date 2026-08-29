package magic.app.tools.crudgen

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

/**
 * CRUD代码生成器命令行工具
 * 
 * 用法：
 *   crudgen --db <数据库名> --table <表名> [--all] [--output <输出目录>]
 * 
 * 示例：
 *   # 生成指定表的CRUD代码
 *   crudgen --db uctoo --table entity
 *   
 *   # 生成所有表的CRUD代码
 *   crudgen --db uctoo --all
 *   
 *   # 指定输出目录
 *   crudgen --db uctoo --table entity --output ./src/app
 */
main(args: Array<String>) {
    println("CRUD Generator starting...")
    println("Args: ${args}")

    // 加载 .env 环境变量（orm_* 数据源配置来源）
    // 与 plugingen/main.cj 启动流程一致：读取 .env → Config.set → ORMConfig.refresh → ORM.initialize
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
    var tableName: String = ""
    var outputDir: String = "./src/app"
    var generateAll: Bool = false
    
    // 解析命令行参数
    var i = 0  // 从第一个参数开始
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
            case "--table" =>
                if (i + 1 < args.size) {
                    tableName = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--output" =>
                if (i + 1 < args.size) {
                    outputDir = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--all" =>
                generateAll = true
                i += 1
            case "--help" | "-h" =>
                printHelp()
                return
            case _ =>
                print("未知参数: ${arg}")
                printHelp()
                return
        }
    }
    
    // 验证参数
    if (dbName.isEmpty()) {
        print("错误: 必须指定数据库名 (--db)")
        printHelp()
        return
    }
    
    if (!generateAll && tableName.isEmpty()) {
        print("错误: 必须指定表名 (--table) 或使用 --all 生成所有表")
        printHelp()
        return
    }
    
    // 初始化生成器
    let generator = CrudGenerator(outputDir)
    
    try {
        if (generateAll) {
            // 生成所有表的CRUD代码
            print("开始生成 ${dbName} 数据库所有表的CRUD代码...")
            let tables = generator.readAllTables(dbName)

            for (table in tables) {
                print("生成表 ${table} 的CRUD代码...")
                let tableInfo = generator.readTableInfo(dbName, table)
                generator.generateAllLayers(tableInfo)
                // 生成权限节点
                generator.generatePermissionNodes(dbName, table)
                print("表 ${table} 的CRUD代码生成完成")
            }

            print("\n所有表的CRUD代码生成完成！")
        } else {
            // 生成指定表的CRUD代码
            print("开始生成 ${dbName}.${tableName} 表的CRUD代码...")
            let tableInfo = generator.readTableInfo(dbName, tableName)
            generator.generateAllLayers(tableInfo)
            // 生成权限节点
            generator.generatePermissionNodes(dbName, tableName)
            print("表 ${tableName} 的CRUD代码生成完成！")
        }
    } catch (e: Exception) {
        print("错误: ${e.message}")
    }
}

/**
 * 打印帮助信息
 */
func printHelp(): Unit {
    print("CRUD代码生成器命令行工具")
    print("")
    print("用法：")
    print("  crudgen --db <数据库名> --table <表名> [--all] [--output <输出目录>]")
    print("")
    print("选项：")
    print("  --db <数据库名>    指定数据库名")
    print("  --table <表名>    指定表名")
    print("  --all             生成所有表的CRUD代码")
    print("  --output <目录>   指定输出目录，默认：./src/app")
    print("  --help, -h        显示帮助信息")
    print("")
    print("示例：")
    print("  # 生成指定表的CRUD代码")
    print("  crudgen --db uctoo --table entity")
    print("")
    print("  # 生成所有表的CRUD代码")
    print("  crudgen --db uctoo --all")
    print("")
    print("  # 指定输出目录")
    print("  crudgen --db uctoo --table entity --output ./src/app")
}

/**
 * 初始化ORM和数据库连接
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