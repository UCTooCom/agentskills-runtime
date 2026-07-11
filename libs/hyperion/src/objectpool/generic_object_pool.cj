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

package hyperion.objectpool

/**
 * 通用对象池实现
 * 
 * @author yangfuping
 */
public class GenericObjectPool<T> <: ObjectPool<T> where T <: Hashable & Equatable<T> {
    protected static let logger = LoggerFactory.getLogger("objectpool")

    private let poolConfig: PoolConfig

    private let objectFactory: PooledObjectFactory<T>

    /**
     *  空闲对象列表
     */
    private let idleObjects: LinkedList<PooledObject<T>>

    private let poolMutex = Mutex()

    private let idleObjectsMonitor = synchronized(poolMutex) {
        poolMutex.condition()
    }

    private let allObjects = ConcurrentHashMap<T, PooledObject<T>>()

    /**
     *  活跃状态的对象数
     */
    private let activeCount = AtomicInt64(0)

    private let initialized = AtomicBool(false)

    private let closed = AtomicBool(false)

    private let evictorThread = AtomicOptionReference<EvictorThread<T>>()

    public init(poolConfig: PoolConfig, objectFactory: PooledObjectFactory<T>) {
        this.poolConfig = poolConfig
        this.objectFactory = objectFactory
        idleObjects = LinkedList<PooledObject<T>>()
    }

    /*
     * 初始化对象池
     *
     * @throws PoolException
     */
    public func initialize() {
        if (initialized.compareAndSwap(false, true)) {
            ensureMinActiveObjects()

            var evictionIntervalsInSeconds = -1
            if (let Some(evictionIntervals) <- poolConfig.evictionIntervals) {
                evictionIntervalsInSeconds = evictionIntervals.toSeconds()
            } else if (let Some(idleTimeout) <- poolConfig.idleTimeout) {
                evictionIntervalsInSeconds = idleTimeout.toSeconds() / 3
            }

            if (evictionIntervalsInSeconds > 0) {
                if (evictorThread.load().isSome()) {
                    return
                }

                let evictor = EvictorThread<T>(this, evictionIntervalsInSeconds)
                if (evictorThread.compareAndSwap(None, evictor)) {
                    // 启动检测线程
                    spawn {
                        Thread.currentThread.name = "GenericObjectPool-Evictor"
                        evictor.run()
                    }
                }
            }
        }
    }

    /*
     * 保证最小对象实例数
     */
    private func ensureMinActiveObjects() {
        if (poolConfig.minActiveSize > 0) {
            while (activeCount.load() < poolConfig.minActiveSize) {
                if (let Some(pooledObj) <- create()) {
                    addIdleObject(pooledObj)
                }
            }
        }
    }

    /*
     * 创建对象
     *
     */
    protected func create(): ?PooledObject<T> {
        var created = false
        try {
            activeCount.fetchAdd(1)
            if (activeCount.load() <= poolConfig.maxActiveSize) {
                let pooledObj = objectFactory.createObject()
                pooledObj.config(poolConfig)
                created = true
                allObjects.add(pooledObj.value, pooledObj)

                logPoolAction(pooledObj, PoolActions.CREATE_ACTION)
                return pooledObj
            }

            return None
        } catch (poolEx: PoolException) {
            throw poolEx
        } finally {
            if (!created) {
                activeCount.fetchSub(1)
            }
        }
    }

    private func addIdleObject(pooledObj: PooledObject<T>) {
        synchronized(poolMutex) {
            if (poolConfig.lifo) {
                idleObjects.addFirst(pooledObj)
            } else {
                idleObjects.addLast(pooledObj)
            }

            idleObjectsMonitor.notify()
        }
    }

    /*
     * 往对象池中添加实例
     * @throws PoolException
     */
    public func addObject(): Unit {
        checkOpen()

        if (let Some(pooledObj) <- create()) {
            addIdleObject(pooledObj)
        }
    }

    /*
     * 往对象池中添加指定数量的实例
     *
     * @param count
     * @throws PoolException
     */
    public func addObject(count: Int64): Unit {
        checkOpen()

        for (i in 0..count) {
            if (activeCount.load() >= poolConfig.maxActiveSize) {
                break
            }

            if (let Some(pooledObj) <- create()) {
                addIdleObject(pooledObj)
            }
        }
    }

    /*
     * 借出对象
     *
     * @throws NoSuchElementException
     */
    public func borrowObject(): T {
        checkOpen()

        if (!initialized.load()) {
            spawn {
                Thread.currentThread.name = "GenericObjectPool-Initializer"
                initialize()
            }
        }

        synchronized(poolMutex) {
            // 取队列头节点
            if (let Some(pooledObj) <- idleObjects.removeFirst()) {
                var valid = true
                if (poolConfig.testOnBorrow) {
                    valid = objectFactory.validObject(pooledObj)
                }

                if (valid) {
                    pooledObj.allocate()
                    logPoolAction(pooledObj, PoolActions.BORROW_ACTION)
                    return pooledObj.value
                } else {
                    destoryObject(pooledObj, PoolActions.TEST_ON_BORROW)
                }
            }

            if (activeCount.load() < poolConfig.maxActiveSize) {
                // 尝试创建对象
                var createdObj = create()
                if (let Some(pooledObj) <- createdObj) {
                    pooledObj.allocate()
                    logPoolAction(pooledObj, PoolActions.BORROW_ACTION)
                    return pooledObj.value
                }
            }

            // 等待归还的对象
            var currentTime = DateTime.now().nanosecond
            let expireTime = currentTime + poolConfig.borrowTimeout.toNanoseconds()
            while (currentTime < expireTime) {
                let waitTime = expireTime - currentTime
                if (waitTime <= 0) {
                    throw NoSuchElementException(
                        "Timeout waiting for idle object, maxWaitTime: ${poolConfig.borrowTimeout.toMilliseconds()} millseconds"
                    )
                }

                idleObjectsMonitor.wait(timeout: waitTime * Duration.nanosecond)

                if (let Some(pooledObj) <- idleObjects.removeFirst()) {
                    var valid = true
                    if (poolConfig.testOnBorrow) {
                        valid = objectFactory.validObject(pooledObj)
                    }

                    if (valid) {
                        pooledObj.allocate()
                        logPoolAction(pooledObj, PoolActions.BORROW_ACTION)
                        return pooledObj.value
                    } else {
                        destoryObject(pooledObj, PoolActions.TEST_ON_BORROW)
                    }
                }

                currentTime = DateTime.now().nanosecond
            }

            throw NoSuchElementException(
                "Timeout waiting for idle object, maxWaitTime: ${poolConfig.borrowTimeout.toMilliseconds()} millseconds"
            )
        }
    }

    /*
     * 归还对象到池中
     */
    public func returnObject(obj: T) {
        if (let Some(pooledObj) <- allObjects.get(obj)) {
            pooledObj.deallocate()

            if (closed.load()) {
                destoryObject(pooledObj, PoolActions.POOL_CLOSED)
                return
            }

            var valid = true
            if (poolConfig.testOnReturn) {
                valid = objectFactory.validObject(pooledObj)
            }

            if (valid) {
                synchronized(poolMutex) {
                    if (poolConfig.lifo) {
                        idleObjects.addFirst(pooledObj)
                    } else {
                        idleObjects.addLast(pooledObj)
                    }

                    idleObjectsMonitor.notify()
                }

                logPoolAction(pooledObj, PoolActions.RETURN_ACTION)
            } else {
                destoryObject(pooledObj, PoolActions.TEST_ON_RETURN)
            }
        } else {
            throw PoolException("Returned object not belongs to this pool")
        }
    }

    /*
     * 从对象池中销毁指定实例
     *
     * @param obj
     * @throws PoolException
     */
    public func invalidateObject(obj: T): Unit {
        if (let Some(pooledObj) <- allObjects.get(obj)) {
            destoryObject(pooledObj, PoolActions.INVALIDATION)

            if (activeCount.load() < poolConfig.minActiveSize) {
                addObject()
            }
        }
    }

    /*
     * 从对象池中销毁所有实例
     *
     * @throws PoolException
     */
    public func invalidateAll(): Unit {
        synchronized(poolMutex) {
            while (let Some(pooledObj) <- idleObjects.removeFirst()) {
                destoryObject(pooledObj, PoolActions.INVALIDATION)
            }
        }

        let removeEntries = ArrayList<PooledObject<T>>()
        for ((obj, pooledObj) in allObjects) {
            removeEntries.add(pooledObj)
        }

        for (pooledObj in removeEntries) {
            destoryObject(pooledObj, PoolActions.INVALIDATION)
        }
    }

    /*
     * 销毁对象
     */
    private func destoryObject(pooledObj: PooledObject<T>, cause: String) {
        if (let Some(pooledObj) <- allObjects.remove(pooledObj.value)) {
            logPoolAction(pooledObj, PoolActions.DESTORY_ACTION, cause)

            objectFactory.destoryObject(pooledObj)
            activeCount.fetchSub(1)
        }
    }

    /**
     * 清理过期或者失效对象
     */
    public func evict() {
        let invalidEntries = ArrayList<PooledObject<T>>()

        let expireEntries = ArrayList<PooledObject<T>>()

        func needRemove(checkObjet: PooledObject<T>): Bool {
            if (invalidEntries.contains(checkObjet)) {
                return true
            }

            if (expireEntries.contains(checkObjet)) {
                return true
            }

            return false
        }

        synchronized(poolMutex) {
            for (idleObject in idleObjects) {
                let idle = idleObject.checkIdleAndSetExpireTime()

                if (poolConfig.testWhileIdle && !objectFactory.validObject(idleObject)) {
                    invalidEntries.add(idleObject)
                    continue
                }

                if ((idle && idleObject.isExpired()) && idleObjects.size - expireEntries.size > poolConfig.minActiveSize) {
                    expireEntries.add(idleObject)
                }
            }

            idleObjects.removeIf(needRemove)
        }

        for (removeObj in invalidEntries) {
            destoryObject(removeObj, PoolActions.TEST_WHILTE_IDLE)
        }

        for (removeObj in expireEntries) {
            destoryObject(removeObj, PoolActions.EXPIRATION)
        }

        // 保证最小活跃连接数
        ensureMinActiveObjects()
    }

    /**
     * 检查对象池是否为未关闭状态
     */
    protected func checkOpen() {
        if (closed.load()) {
            throw PoolException("Pool is closed");
        }
    }

    private func logPoolAction(pooledObj: PooledObject<T>, action: String) {
        if (logger.isLoggable(LogLevel.DEBUG)) {
            if (let Some(toString) <- (pooledObj.value as ToString)) {
                logger.log(LogLevel.DEBUG, "${action} PooledObject ${toString}")
            } else {
                logger.log(LogLevel.DEBUG, "${action} PooledObject, id: ${pooledObj.id}")
            }
        }

        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.TRACE, getObjectPoolStatus())
        }
    }

    private func logPoolAction(pooledObj: PooledObject<T>, action: String, cause: String) {
        if (logger.isLoggable(LogLevel.DEBUG)) {
            if (let Some(toString) <- (pooledObj.value as ToString)) {
                logger.log(
                    LogLevel.DEBUG,
                    "${action} PooledObject ${toString}, due to ${cause}"
                )
            } else {
                logger.log(
                    LogLevel.DEBUG,
                    "${action} PooledObject, id: ${pooledObj.id}, due to ${cause}"
                )
            }
        }

        if (logger.isLoggable(LogLevel.TRACE)) {
            logger.log(LogLevel.TRACE, getObjectPoolStatus())
        }
    }

    private func clear(): Unit {
        invalidateAll()
    }

    public func getObjectPoolStatus(): String {
        let builder = StringBuilder()
        builder.append("GenericObjectPool{")
        builder.append("Active objects: ${activeCount.load()}, ")
        builder.append("idle objects: ${idleObjects.size}, ")
        builder.append("all objects: ${allObjects.size}")
        builder.append("}")

        return builder.toString()
    }

    public func isClosed() {
        return closed.load()
    }

    /*
     * @throws PoolException
     */
    public func close(): Unit {
        if (closed.load()) {
            return
        }

        if (closed.compareAndSwap(false, true)) {
            clear()
        }
    }
}

/**
 * 清理失效对象和空闲超时对象的线程
 */
class EvictorThread<T> where T <: Hashable & Equatable<T> {
    private static let logger = LoggerFactory.getLogger("objectpool")

    private let pool: GenericObjectPool<T>

    private let evictionIntervalsInSeconds: Int64

    public init(pool: GenericObjectPool<T>, evictionIntervalsInSeconds: Int64) {
        this.pool = pool
        this.evictionIntervalsInSeconds = evictionIntervalsInSeconds
    }

    public func run() {
        while (!pool.isClosed()) {
            try {
                sleep(evictionIntervalsInSeconds * Duration.second)
                pool.evict()
            } catch (ex: Exception) {
                logger.log(LogLevel.WARN, ex.message, ex)
            }
        }
    }
}
