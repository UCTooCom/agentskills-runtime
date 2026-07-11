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
import opengauss.driver.PGDriver
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
 * 初始化ORM和数据库连接
 * 与 crudgen 工具使用相同的初始化逻辑
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

        println("数据库连接成功")

        return true
    } catch (e: Exception) {
        println("初始化失败: ${e.message}")
        return false
    }
}
