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

package objectpool_idletime

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
    poolConfig.minActiveSize = 4
    poolConfig.maxActiveSize = 64
    poolConfig.borrowTimeout = Duration.second * 10
    poolConfig.evictionIntervals = Duration.second * 10
    poolConfig.idleTimeout = Duration.second * 30
    poolConfig.testOnBorrow = true
    poolConfig.testOnReturn = false
    poolConfig.testWhileIdle = true
    poolConfig.lifo = true

    let connFactory = MyConnectionFactory()
    let connectionPool = GenericObjectPool<MyConnection>(poolConfig, connFactory)
    connFactory.setConnectionPool(connectionPool)

    for (i in 0..15) {
        threadpool.addTask(UseConnectionTask(connectionPool))
    }

    sleep(30 * Duration.second)
    // 停止第一个线程池
    running.store(false)
    threadpool.stop()

    // 主线程睡眠90秒钟，等待连接空闲超时
    logMessage("===================Sleep 90 seconds: ===================")
    sleep(90 * Duration.second)
    logMessage("===================Sleep 90 seconds ends===================")

    running.store(true)
    // 启动第二个线程池
    let threadpool2 = ThreadPoolFactory.createThreadPool(0, 128, 4096, Duration.minute * 2)
    for (i in 0..15) {
        threadpool2.addTask(UseConnectionTask(connectionPool))
    }

    sleep(30 * Duration.second)
    // 停止第二个线程池
    running.store(false)
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
