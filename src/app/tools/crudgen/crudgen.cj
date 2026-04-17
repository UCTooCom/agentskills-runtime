package magic.app.tools.crudgen

import std.collection.*
import std.process.*
import std.io.*
import f_orm.*
import f_config.Config
import f_orm.wrap.ORMConfig
import std.database.sql.DriverManager
import opengauss.driver.PGDriver

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
                print("表 ${table} 的CRUD代码生成完成")
            }
            
            print("\n所有表的CRUD代码生成完成！")
        } else {
            // 生成指定表的CRUD代码
            print("开始生成 ${dbName}.${tableName} 表的CRUD代码...")
            let tableInfo = generator.readTableInfo(dbName, tableName)
            generator.generateAllLayers(tableInfo)
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
            let pgDriver = PGDriver("postgres")
            DriverManager.register("postgres", pgDriver)
            println("PostgreSQL驱动已注册")
        }
        
        // 初始化ORM
        ORM.initialize()
        println("ORM初始化成功")
        
        // 测试连接
        let connection = ORM.connection()
        println("数据库连接成功")
        connection.close()
        
        return true
    } catch (e: Exception) {
        println("初始化失败: ${e.message}")
        return false
    }
}