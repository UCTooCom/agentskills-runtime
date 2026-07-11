/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */

package objectpool_example

let random = Random(128)
let printMutex = Mutex()
let running = AtomicBool(true)

/**
 * 
 * @author yangfuping
 */
main() {
    LoggerFactory.setLevel(LogLevel.DEBUG)
    let threadpool = ThreadPoolFactory.createThreadPool(0, 128, 4096, Duration.minute * 2)

    let poolConfig = PoolConfig()
    poolConfig.minActiveSize = 10
    poolConfig.maxActiveSize = 64
    poolConfig.borrowTimeout = Duration.second * 10
    poolConfig.evictionIntervals = Duration.second * 30
    poolConfig.idleTimeout = Duration.second * 60
    poolConfig.testOnBorrow = false
    poolConfig.testOnReturn = false
    poolConfig.testWhileIdle = true
    poolConfig.lifo = false

    let connFactory = MyConnectionFactory()
    let connectionPool = GenericObjectPool<MyConnection>(poolConfig, connFactory)
    connFactory.setConnectionPool(connectionPool)

    for (i in 0..5) {
        threadpool.addTask(UseConnectionTask(connectionPool))
    }

    threadpool.addTask(CloseConnectionTask(connectionPool))

    // threadpool.addTask(InvalidConnectionTask(connectionPool))

    sleep(120 * Duration.second)
    running.compareAndSwap(true, false)
    logMessage("===================threadpool.stop()===================")
    threadpool.stop()
}

public func logMessage(msg: String) {
    synchronized(printMutex) {
        println(msg)
    }
}

/**
 * 正常使用连接的任务
 */
public class UseConnectionTask <: Runnable {
    private static let mutex = Mutex()

    private let connectionPool: ObjectPool<MyConnection>

    public init(connectionPool: ObjectPool<MyConnection>) {
        this.connectionPool = connectionPool
    }

    public func run() {
        while (running.load()) {
            let connection = connectionPool.borrowObject()
            logMessage("${Thread.currentThread.name} borrow connection ${connection}")
            let sleepSeconds = random.nextUInt64(6)
            sleep(Int64(sleepSeconds) * Duration.second)
            logMessage("${Thread.currentThread.name} return connection ${connection}")
            connection.close()
        }
    }
}

/**
 * 模拟让连接底层被关闭的任务
 */
public class CloseConnectionTask <: Runnable {
    private static let mutex = Mutex()

    private let connectionPool: ObjectPool<MyConnection>

    public init(connectionPool: ObjectPool<MyConnection>) {
        this.connectionPool = connectionPool
    }

    public func run() {
        while (running.load()) {
            let connection = connectionPool.borrowObject()
            logMessage("${Thread.currentThread.name} borrow connection ${connection}")
            let sleepSeconds = random.nextUInt64(6)
            sleep(Int64(sleepSeconds) * Duration.second)
            logMessage("${Thread.currentThread.name} close connection ${connection}")
            connection.internalClose()
            // 返回被关闭的连接到连接池中
            connectionPool.returnObject(connection)
        }
    }
}

/**
 * 模拟让连接失效的任务
 */
public class InvalidConnectionTask <: Runnable {
    private static let mutex = Mutex()

    private let connectionPool: ObjectPool<MyConnection>

    public init(connectionPool: ObjectPool<MyConnection>) {
        this.connectionPool = connectionPool
    }

    public func run() {
        while (running.load()) {
            let connection = connectionPool.borrowObject()
            logMessage("${Thread.currentThread.name} borrow connection ${connection}")
            let sleepSeconds = random.nextUInt64(6)
            sleep(Int64(sleepSeconds) * Duration.second)
            logMessage("${Thread.currentThread.name} invalidate connection ${connection}")
            connection.close(invalidate: true)
        }
    }
}

public class MyConnection <: Hashable & Equatable<MyConnection> & ToString {
    private static let idGenerator = AtomicInt64(0)

    private let id: Int64

    private let closed = AtomicBool(false)

    private let invalidated = AtomicBool(false)

    private let connectionPool: ObjectPool<MyConnection>

    public init(connectionPool: ObjectPool<MyConnection>) {
        this.connectionPool = connectionPool
        id = idGenerator.fetchAdd(1)
        logMessage("Create {MyConnection: ${id}}")
    }

    public func markInvalid(): Unit {
        if (!this.invalidated.load()) {
            if (this.invalidated.compareAndSwap(false, true)) {
                logMessage("Invalidate ${this}")
            }
        }
    }

    public func isInvalid(): Bool {
        return this.invalidated.load()
    }

    public func isClosed(): Bool {
        return closed.load()
    }

    public func close() {
        if (!isInvalid()) {
            connectionPool.returnObject(this)
        } else {
            connectionPool.invalidateObject(this)
            internalClose()
        }
    }

    public func close(invalidate!: Bool) {
        if (invalidate) {
            markInvalid()
        }

        close()
    }

    protected func internalClose() {
        if (closed.compareAndSwap(false, true)) {
            logMessage("Close ${this}")
        }
    }

    public func toString(): String {
        return "{MyConnection: ${id}}"
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        var hashCode = 53 * id
        return hashCode
    }

    public operator override func ==(other: MyConnection): Bool {
        return this.id == other.id
    }

    public operator override func !=(other: MyConnection): Bool {
        return this.id != other.id
    }
}

public class MyConnectionFactory <: PooledObjectFactory<MyConnection> {
    private var connectionPool: ?ObjectPool<MyConnection> = None

    public init() {
    }

    public func setConnectionPool(connectionPool: ObjectPool<MyConnection>) {
        this.connectionPool = connectionPool
    }

    /*
     * 创建缓存的对象实例
     * @throws PoolException
     */
    public func createObject(): PooledObject<MyConnection> {
        if (let Some(connectionPool) <- connectionPool) {
            let conn = MyConnection(connectionPool)
            let pooledObj = PooledObject<MyConnection>(conn)
            return pooledObj
        }

        throw Exception("ConnectionPool is required")
    }

    /*
     * 验证缓存的对象实例
     */
    public func validObject(pooledObj: PooledObject<MyConnection>): Bool {
        if (pooledObj.value.isInvalid()) {
            return false
        }

        if (pooledObj.value.isClosed()) {
            return false
        }

        return true
    }

    /*
     * 销毁缓存的对象实例
     * @throws PoolException
     */
    public func destoryObject(pooledObj: PooledObject<MyConnection>): Unit {
        let conn = pooledObj.value
        if (!conn.isClosed()) {
            conn.markInvalid()
            conn.close()
        }
    }
}
