/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_orm.wrap

public import std.database.sql.*
import std.collection.Map
import std.sync.AtomicUInt64
import std.unicode.UnicodeStringExtension
import f_log.impl.LoggerFactory
import f_pool.Pool

public class DatabasePool <: Resource & Datasource {
    private static let logger = LoggerFactory.getLogger<DatabasePool>()

    private let driver: Driver
    private let pool: Pool<PooledConnection>
    private var connectTimeout: Duration

    public init(
        driver!: Driver,
        initSize!: Int64 = 0,
        minSize!: Int64 = 0,
        maxSize!: Int64 = 10,
        checkOnCreation!: Bool = false,
        checkOnBorrowing!: Bool = true,
        checkOnReturning!: Bool = true,
        connectionLife!: Duration = Duration.hour,
        idleTimeout!: Duration = Duration.Zero,
        checkInterval!: Duration = Duration.minute * 5,
        connectTimeout!: Duration = Duration.Max,
        creator!: () -> Connection,
        checker!: (Connection) -> Bool
    ) {
        this.driver = driver
        this.connectTimeout = connectTimeout
        this.pool = Pool<PooledConnection>(
            initSize: initSize,
            minSize: minSize,
            maxSize: maxSize,
            checkOnCreation: checkOnCreation,
            checkOnBorrowing: checkOnBorrowing,
            checkOnReturning: checkOnReturning,
            idleTimeout: idleTimeout,
            checkInterval: checkInterval,
            creator: {=> PooledConnection(creator())},
            checker: {
                c => try {
                    if(connectionLife > Duration.Zero && let conn: PooledConnection <- c && MonoTime.now() - conn.birth >= connectionLife) {
                        false
                    } else {
                        !c.isDestroied() && checker(c)
                    }
                } catch (e: Exception) {
                    logger.error("database check failed", e)
                    false
                }
            },
            destroier: {
                c => try {
                    if (!c.isDestroied()) {
                        c.destroy()
                    }
                } catch (e: Exception) {
                    logger.warn('to destroy connection in DatabasePool failed', e)
                }
            }
        )
    }
    public init(
        driver!: Driver,
        initSize!: Int64 = 0,
        minSize!: Int64 = 0,
        maxSize!: Int64 = 10,
        checkOnCreation!: Bool = false,
        checkOnBorrowing!: Bool = true,
        checkOnReturning!: Bool = true,
        connectionLife!: Duration = Duration.hour,
        idleTimeout!: Duration = Duration.Zero,
        checkInterval!: Duration = Duration.minute * 5,
        connectTimeout!: Duration = Duration.Max,
        creator!: () -> Connection,
        checkSql!: String = "select 1"
    ) {
        this(
            driver: driver,
            initSize: initSize,
            minSize: minSize,
            maxSize: maxSize,
            checkOnCreation: checkOnCreation,
            checkOnBorrowing: checkOnBorrowing,
            checkOnReturning: checkOnReturning,
            connectionLife: connectionLife,
            idleTimeout: idleTimeout,
            checkInterval: checkInterval,
            connectTimeout: connectTimeout,
            creator: creator,
            checker: {
                c => if (checkSql[0..6].toLower() == "select") {
                    try (stmt = c.prepareStatement(checkSql)) {
                        try (r = stmt.query()) {
                            return r.next()
                        }
                    }
                    false
                } else {
                    try (stmt = c.prepareStatement(checkSql)) {
                        return stmt.update().rowCount > 0
                    }
                    false
                }
            }
        )
    }
    public init(driver: Driver, creator: () -> Connection) {
        this(
            driver: driver,
            initSize: ORMConfig.getPoolInitSize(driverName: driver.name),
            minSize: ORMConfig.getPoolMinSize(driverName: driver.name),
            maxSize: ORMConfig.getPoolMaxSize(driverName: driver.name),
            checkOnCreation: ORMConfig.getCheckOnCreation(driverName: driver.name),
            checkOnBorrowing: ORMConfig.getCheckOnBorrowing(driverName: driver.name),
            checkOnReturning: ORMConfig.getCheckOnReturning(driverName: driver.name),
            connectionLife: ORMConfig.getConnectionLife(driverName: driver.name),
            idleTimeout: ORMConfig.getIdleTimeout(driverName: driver.name),
            checkInterval: ORMConfig.getPoolCheckInterval(driverName: driver.name),
            connectTimeout: ORMConfig.getConnectTimeout(driverName: driver.name),
            creator: creator,
            checkSql: ORMConfig.getPoolCheckSql(driverName: driver.name)
        )
    }
    public init(driver: Driver, options: Array<(String, String)>) {
        this(driver, {
            =>
                let ds = driver.open(ORMConfig.getUrl(driverName: driver.name), options)
                {
                    => ds.connect()
                }
        }())
    }

    public func isClosed(): Bool {
        pool.isClosed()
    }
    public func close(): Unit {
        if (!isClosed()) {
            pool.close()
        }
    }

    public func getConnection(timeout!: Duration = connectTimeout): Option<Connection> {
        if (isClosed()) {
            throw ConnectionException('database pool is closed')
        }
        pool.borrow(timeout: timeout)?.activate(pool.giveBack)
    }
    public func setOption(key: String, value: String): Unit {}
    public func connect(): Connection {
        getConnection().getOrThrow{ConnectionException()}
    }
}

class PooledConnection <: Connection {
    private static let logger = LoggerFactory.getLogger<PooledConnection>()
    private static let serialGen = AtomicUInt64(1)
    private let serial = serialGen.fetchAdd(1)
    let birth = MonoTime.now()
    PooledConnection(private let connection: Connection) {}

    private var returnFn = {c: PooledConnection => ()}

    private var assigned = false

    public func isClosed(): Bool {
        !assigned
    }
    public func close(): Unit {
        assigned = false
        logger.debug {"database Connection ${serial} is returning"}
        returnFn(this)
        logger.debug {"database Connection ${serial} is returned"}
    }
    func activate(returnFn: (PooledConnection) -> Unit): Connection {
        assigned = true
        this.returnFn = returnFn
        logger.debug {"database Connection ${serial} is assigned"}
        this
    }
    func isDestroied(): Bool {
        connection.isClosed()
    }
    func destroy(): Unit {
        logger.debug {"database Connection ${serial} is closing"}
        if (!(assigned || connection.isClosed())) {
            connection.close()
            logger.debug {"database Connection ${serial} is closed"}
        } else {
            logger.debug {"database Connection ${serial} cannot close"}
        }
    }

    /**
     * 通过传入的 sql 语句，返回一个预执行的 Statement 对象实例
     * 参数 sql - 预执行的 sql 语句
     * 返回值 Statement - 一个可以执行 sql 语句的实例对象
     */
    public func prepareStatement(sql: String): Statement {
        logger.debug {"database Connection ${serial} is preparing a statement"}
        let stmt = connection.prepareStatement(sql)
        logger.debug {"database Connection ${serial} a statement is prepared"}
        stmt
    }

    /**
     * 接口 Statement ，sql 语句预执行接口，它绑定了一个 Connection , 继承该接口的 class、interface、
     * struct 也需要遵守该接口中函数的入参及返回值定义。
     * 开始事务
     */
    public func createTransaction(): Transaction {
        logger.debug {"database Connection ${serial} a transaction is beginning"}
        let tx = connection.createTransaction()
        logger.debug {"database Connection ${serial} a transaction began"}
        tx
    }
    public prop state: ConnectionState {
        get() {
            connection.state
        }
    }
    public func getMetaData(): Map<String, String> {
        connection.getMetaData()
    }
}
