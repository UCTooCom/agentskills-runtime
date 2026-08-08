/*
 * driver.cj —— Driver 接口实现与向 DriverManager 的注册。
 */

package pgsql

import std.database.sql.*

// 驱动名称，使用 DriverManager.getDriver("postgres") 获取本驱动。
public const DRIVER_NAME = "postgres"
// 驱动版本。
public const DRIVER_VERSION = "1.0.0"

/**
 * PostgreSQL 数据库驱动。
 */
public class PostgresDriver <: Driver {
    public init() {}

    /** 驱动名称。 */
    public prop name: String {
        get() {
            DRIVER_NAME
        }
    }

    /** 是否与连接池亲和：PostgreSQL 连接较重，池化收益明显，返回 true。 */
    public prop preferredPooling: Bool {
        get() {
            true
        }
    }

    /** 驱动版本。 */
    public prop version: String {
        get() {
            DRIVER_VERSION
        }
    }

    /**
     * 通过连接字符串与选项打开数据源。
     *
     * @param connectionString 形如 `postgres://user:pwd@host:port/db` 的连接串。
     * @param opts 额外的 (键, 值) 选项数组。
     * @return 数据源实例。
     */
    public func open(connectionString: String, opts: Array<(String, String)>): Datasource {
        return parseDatasource(connectionString, opts)
    }
}

/**
 * 幂等地将本驱动注册到 [DriverManager]，注册名为 "postgres"。
 *
 * 包加载时会自动调用一次；如需在其它驱动名下注册，也可显式调用。
 */
public func registerDriver(): Unit {
    if (DriverManager.getDriver(DRIVER_NAME).isNone()) {
        DriverManager.register(DRIVER_NAME, PostgresDriver())
    }
}

// 包加载时自动注册，使 DriverManager.getDriver("postgres") 开箱即用。
let autoRegistered: Bool = autoRegister()

// 执行自动注册并返回标记，供 [isDriverRegistered] 观测（同时消除未使用告警）。
func autoRegister(): Bool {
    registerDriver()
    return true
}

/** 本驱动是否已（在包加载时）自动注册到 DriverManager。 */
public func isDriverRegistered(): Bool {
    return autoRegistered
}
