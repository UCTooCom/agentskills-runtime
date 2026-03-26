/*
 * Copyright (c) 2025 UCTOO
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package magic.app.core.database

import std.collection.HashMap
import std.collection.ArrayList
import std.collection.Map
import f_orm.*
import f_orm.wrap.{Propagation, NamedDatasource}
import magic.config.{Config as AppConfig}

/**
 * DatabaseConnection - 数据库连接封装类
 * 
 * 基于f_orm框架，提供数据库连接管理
 * 遵循UCTOO V4 ORM规范
 */
public class DatabaseConnection {
    private var config: DatabaseConfig
    private var connection: ?Connection = None<Connection>
    
    public init(config: DatabaseConfig) {
        this.config = config
    }
    
    /**
     * 连接数据库
     * @return 连接是否成功
     */
    public func connect(): Bool {
        try {
            connection = ORM.connection()
            return true
        } catch (e: Exception) {
            println("Database connection failed: ${e.message}")
            return false
        }
    }
    
    /**
     * 断开数据库连接
     */
    public func disconnect() {
        if (let Some(conn) <- connection) {
            conn.close()
            connection = None<Connection>
        }
    }
    
    /**
     * 检查连接是否有效
     * @return 连接是否有效
     */
    public func isConnected(): Bool {
        if (let Some(conn) <- connection) {
            return !conn.isClosed()
        }
        return false
    }
    
    /**
     * 获取SqlExecutor实例
     * @return SqlExecutor实例
     */
    public func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    /**
     * 执行事务
     * @param executor 事务执行函数
     * @return 执行结果
     */
    public func executeTransaction<T>(executor: (SqlExecutor) -> (T, Bool)): T {
        ORM.executor().execute<T>(propagation: Propagation.Required, executor: executor)
    }
    
    // 原有的基础CRUD方法已废弃,请使用DAO层进行数据访问
    // 这些方法使用了不兼容的JDBC API,已被注释掉
    
    /*
    public func insert(table: String, data: Map<String, Any>): Bool {
        throw Exception("Method deprecated. Please use DAO layer instead.")
    }
    
    public func update(table: String, whereClause: String, data: Map<String, Any>): Bool {
        throw Exception("Method deprecated. Please use DAO layer instead.")
    }
    
    public func delete(table: String, whereClause: String): Bool {
        throw Exception("Method deprecated. Please use DAO layer instead.")
    }
    
    public func queryOne(table: String, whereClause: String, params: ArrayList<Any>): ?Map<String, Any> {
        throw Exception("Method deprecated. Please use DAO layer instead.")
    }
    
    public func query(table: String, whereClause: String, params: ArrayList<Any>, orderBy: String, limit: Int32, offset: Int32): ArrayList<Map<String, Any>> {
        throw Exception("Method deprecated. Please use DAO layer instead.")
    }
    
    public func count(table: String, whereClause: String, params: ArrayList<Any>): Int64 {
        throw Exception("Method deprecated. Please use DAO layer instead.")
    }
    */
    
    private func buildConnectionUrl(): String {
        return config.url
    }
}

/**
 * DatabaseConfig - 数据库配置类
 */
public class DatabaseConfig {
    public var url: String = "postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo"
    public var maxConnections: Int32 = 10
    public var connectionTimeout: Int32 = 30000
    
    public init() {}
    
    public init(
        url: String,
        maxConnections: Int32,
        connectionTimeout: Int32
    ) {
        this.url = url
        this.maxConnections = maxConnections
        this.connectionTimeout = connectionTimeout
    }
    
    /**
     * 从环境变量加载配置
     * @return 数据库配置对象
     */
    public static func fromEnv(): DatabaseConfig {
        let config = DatabaseConfig()
        config.url = AppConfig.env["DATABASE_URL"].getOrDefault({ => "postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo" })
        config.maxConnections = Int32.parse(AppConfig.env["DB_MAX_CONNECTIONS"].getOrDefault({ => "10" }))
        config.connectionTimeout = Int32.parse(AppConfig.env["DB_CONNECTION_TIMEOUT"].getOrDefault({ => "30000" }))
        return config
    }
}

/**
 * DatabaseConnectionPool - 数据库连接池
 * 
 * 基于f_orm的DatabasePool实现
 */
public class DatabaseConnectionPool {
    private static var instance: ?DatabaseConnectionPool = None<DatabaseConnectionPool>
    private var connections: ArrayList<DatabaseConnection> = ArrayList<DatabaseConnection>()
    private var config: DatabaseConfig
    
    private init(config: DatabaseConfig) {
        this.config = config
    }
    
    /**
     * 获取连接池单例
     * @param config 数据库配置
     * @return 连接池实例
     */
    public static func getInstance(config: DatabaseConfig): DatabaseConnectionPool {
        return instance ?? DatabaseConnectionPool(config)
    }
    
    /**
     * 获取数据库连接
     * @return 数据库连接
     */
    public func getConnection(): DatabaseConnection {
        let conn = DatabaseConnection(config)
        conn.connect()
        return conn
    }
    
    /**
     * 释放数据库连接
     * @param conn 数据库连接
     */
    public func releaseConnection(conn: DatabaseConnection) {
        conn.disconnect()
    }
    
    /**
     * 关闭所有连接
     */
    public func closeAll() {
        // f_orm的连接池会自动管理连接
    }
    
    /**
     * 获取SqlExecutor实例
     * @return SqlExecutor实例
     */
    public func getExecutor(): SqlExecutor {
        ORM.executor()
    }
}

/**
 * ORM初始化工具类
 */
public class ORMInitializer {
    /**
     * 初始化ORM
     * @param config 数据库配置
     */
    public static func `init`(config: DatabaseConfig): Unit {
        // 注册数据源
        ORM.register("postgres", config.url, [])
        
        println("ORM initialized successfully with URL: ${config.url}")
    }
    
    /**
     * 从环境变量初始化ORM
     */
    public static func initFromEnv(): Unit {
        let config = DatabaseConfig.fromEnv()
        `init`(config)
    }
}
