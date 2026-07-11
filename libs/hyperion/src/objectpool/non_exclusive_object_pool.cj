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
 * 非独占资源的对象池。非独占资源可以被多个线程同时借出使用。
 *
 * @author yangfuping
 */
public class NonExclusiveObjectPool<T> <: ObjectPool<T> where T <: Hashable & Equatable<T> {
    protected static let logger = LoggerFactory.getLogger("objectpool")

    private let poolConfig: PoolConfig

    private let objectFactory: PooledObjectFactory<T>

    /**
     *  共享的非独占资源列表
     */
    private let sharedObjects: Array<AtomicOptionReference<PooledObject<T>>>

    private let allObjects = ConcurrentHashMap<T, PooledObject<T>>()

    private let nextIndexGenerator = AtomicUInt64(0)

    private let removeObjects = ConcurrentHashMap<PooledObject<T>, T>()

    /**
     * 正在创建的对象数和活跃对象数的总和
     */
    private let createAndActiveCount = AtomicInt64(0)

    /**
     *  活跃状态的对象数
     */
    private let activeCount = AtomicInt64(0)

    private let initialized = AtomicBool(false)

    private let poolMutex = Mutex()

    private let notEmptyMonitor = synchronized(poolMutex) {
        poolMutex.condition()
    }

    private let closed = AtomicBool(false)

    private let evictorThread = AtomicOptionReference<NonExclusiveEvictorThread<T>>()

    public init(poolConfig: PoolConfig, objectFactory: PooledObjectFactory<T>) {
        this.poolConfig = poolConfig
        this.objectFactory = objectFactory
        sharedObjects = Array<AtomicOptionReference<PooledObject<T>>>(
            poolConfig.maxActiveSize,
            {
                // 需要确保每个元素使用单独的AtomicOptionReference
                i => AtomicOptionReference<PooledObject<T>>()
            }
        )
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

                let evictor = NonExclusiveEvictorThread<T>(this, evictionIntervalsInSeconds)
                if (evictorThread.compareAndSwap(None, evictor)) {
                    // 启动检测线程
                    spawn {
                        Thread.currentThread.name = "NonExclusiveObjectPool-Evictor"
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
            while (createAndActiveCount.load() < poolConfig.minActiveSize) {
                if (let Some(pooledObj) <- create()) {
                    addShareObject(pooledObj)
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
            let count = createAndActiveCount.fetchAdd(1)
            if (count + 1 <= poolConfig.maxActiveSize) {
                let pooledObj = objectFactory.createObject()
                if (logger.isDebugEnabled()) {
                    logger.log(LogLevel.DEBUG, "Create object ${stringiferPooledObject(pooledObj)}")
                }

                pooledObj.config(poolConfig)
                allObjects.add(pooledObj.value, pooledObj)
                created = true

                logPoolAction(pooledObj, PoolActions.CREATE_ACTION)
                return pooledObj
            }

            return None
        } catch (poolEx: PoolException) {
            if (logger.isDebugEnabled()) {
                logger.debug("Failure to create PooledObject", poolEx)
            }
            throw poolEx
        } finally {
            if (!created) {
                createAndActiveCount.fetchSub(1)
            }
        }
    }

    private func addShareObject(pooledObj: PooledObject<T>): Unit {
        if (logger.isDebugEnabled()) {
            logger.log(LogLevel.DEBUG, "Add object ${stringiferPooledObject(pooledObj)}")
        }

        var retry = false
        var retryCount = 0
        do {
            retryCount++
            let nextIndex = nextIndex()
            for (i in 0..sharedObjects.size) {
                let realIndex = (nextIndex + i) % sharedObjects.size
                let storedObj = sharedObjects[realIndex]
                if (let Some(storeObject) <- storedObj.load()) {
                    if (logger.isTraceEnabled()) {
                        logger.log(LogLevel.TRACE, "The share[${realIndex}] is  ${stringiferPooledObject(storeObject)}")
                    }

                    continue
                }

                if (logger.isDebugEnabled()) {
                    logger.log(LogLevel.DEBUG, "The sharedObjects[${realIndex}] is None")
                }

                if (storedObj.compareAndSwap(None, pooledObj)) {
                    if (logger.isDebugEnabled()) {
                        logger.log(
                            LogLevel.DEBUG,
                            "Set sharedObjects[${realIndex}] to ${stringiferPooledObject(pooledObj)}"
                        )
                    }

                    // 增加活跃对象数
                    activeCount.fetchAdd(1)
                    synchronized(poolMutex) {
                        notEmptyMonitor.notifyAll()
                    }
                    return
                } else {
                    retry = true
                    if (logger.isTraceEnabled()) {
                        logger.log(
                            LogLevel.TRACE,
                            "Failure to set sharedObjects[${realIndex}] to ${stringiferPooledObject(pooledObj)}, continue"
                        )
                    }
                }
            }
        } while (retry && retryCount < 3)

        // 抛出异常前，应减少createAndActiveCount的数目
        createAndActiveCount.fetchSub(1)
        throw PoolException("Failure to add object ${stringiferPooledObject(pooledObj)}")
    }

    private func stringiferPooledObject(pooledObj: PooledObject<T>): String {
        if (let Some(toString) <- (pooledObj.value as ToString)) {
            return toString.toString()
        } else {
            return "PooledObject, id: ${pooledObj.id}"
        }
    }

    /*
     * 往对象池中添加实例
     * @throws PoolException
     */
    public func addObject(): Unit {
        checkOpen()

        if (let Some(pooledObj) <- create()) {
            addShareObject(pooledObj)
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
            if (createAndActiveCount.load() >= poolConfig.maxActiveSize) {
                break
            }

            if (let Some(pooledObj) <- create()) {
                addShareObject(pooledObj)
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
                Thread.currentThread.name = "NonExclusiveObjectPool-Initializer"
                initialize()
            }
        }

        if (createAndActiveCount.load() < poolConfig.maxActiveSize) {
            // 尝试创建对象
            var createdObj = create()
            if (let Some(pooledObj) <- createdObj) {
                addShareObject(pooledObj)
                pooledObj.allocate()
                logPoolAction(pooledObj, PoolActions.BORROW_ACTION)
                return pooledObj.value
            }
        }

        var currentTime = DateTime.now().nanosecond
        let expireTime = currentTime + poolConfig.borrowTimeout.toNanoseconds()
        while (currentTime < expireTime) {
            var loopCount = 0
            var hasDestroyed = false
            while (loopCount < sharedObjects.size) {
                loopCount++
                let index = nextIndex()
                var valid = true
                if (let Some(pooledObj) <- sharedObjects[index].load()) {
                    var valid = true
                    if (poolConfig.testOnBorrow) {
                        valid = objectFactory.validObject(pooledObj)
                    }

                    if (valid) {
                        pooledObj.allocate()
                        logPoolAction(pooledObj, PoolActions.BORROW_ACTION)
                        return pooledObj.value
                    } else {
                        hasDestroyed = true
                        sharedObjects[index].store(None)
                        destoryObject(pooledObj, PoolActions.TEST_ON_BORROW)
                    }
                }
            }

            if (hasDestroyed && createAndActiveCount.load() < poolConfig.maxActiveSize) {
                // 尝试创建对象
                var createdObj = create()
                if (let Some(pooledObj) <- createdObj) {
                    addShareObject(pooledObj)
                    pooledObj.allocate()
                    logPoolAction(pooledObj, PoolActions.BORROW_ACTION)
                    return pooledObj.value
                }
            }

            let waitTime = expireTime - currentTime
            synchronized(poolMutex) {
                if (activeCount.load() == 0) {
                    notEmptyMonitor.wait(timeout: waitTime * Duration.nanosecond)
                }
            }

            currentTime = DateTime.now().nanosecond
        }

        throw NoSuchElementException(
            "Timeout waiting for idle object, maxWaitTime: ${poolConfig.borrowTimeout.toMilliseconds()} millseconds")
    }

    @OverflowWrapping
    private func nextIndex(): Int64 {
        let index = nextIndexGenerator.fetchAdd(1) % UInt64(sharedObjects.size)
        return Int64(index)
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

            if (poolConfig.testOnReturn) {
                if (!objectFactory.validObject(pooledObj)) {
                    for (i in 0..sharedObjects.size) {
                        if (let Some(storeObj) <- sharedObjects[i].load()) {
                            if (storeObj == pooledObj) {
                                sharedObjects[i].store(None)
                                break
                            }
                        }
                    }

                    destoryObject(pooledObj, PoolActions.TEST_ON_RETURN)
                }
            }
        } else {
            if (logger.isDebugEnabled()) {
                if (let Some(toString) <- (obj as ToString)) {
                    logger.debug("Returned object ${toString} not belongs to this pool")
                } else {
                    logger.debug("Returned object not belongs to this pool")
                }
            }
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
            for (i in 0..sharedObjects.size) {
                if (let Some(storeObj) <- sharedObjects[i].load()) {
                    if (storeObj == pooledObj) {
                        sharedObjects[i].store(None)
                        break
                    }
                }
            }

            destoryObject(pooledObj, PoolActions.INVALIDATION)

            if (createAndActiveCount.load() < poolConfig.minActiveSize) {
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
        let removeEntries = ArrayList<PooledObject<T>>()
        for (i in 0..sharedObjects.size) {
            if (let Some(pooledObj) <- sharedObjects[i].load()) {
                removeEntries.add(pooledObj)
                sharedObjects[i].store(None)
                destoryObject(pooledObj, PoolActions.INVALIDATION)
            }
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
            objectFactory.destoryObject(pooledObj)
            activeCount.fetchSub(1)
            createAndActiveCount.fetchSub(1)
            logPoolAction(pooledObj, PoolActions.DESTORY_ACTION, cause)
        }
    }

    /**
     * 清理过期或者失效对象
     */
    public func evict() {
        let invalidEntries = ArrayList<PooledObject<T>>()

        let expireEntries = ArrayList<PooledObject<T>>()

        for (i in 0..sharedObjects.size) {
            if (let Some(sharedObject) <- sharedObjects[i].load()) {
                let idle = sharedObject.checkIdleAndSetExpireTime()
                if (poolConfig.testWhileIdle && !objectFactory.validObject(sharedObject)) {
                    sharedObjects[i].store(None)
                    invalidEntries.add(sharedObject)
                    continue
                }

                if ((idle && sharedObject.isExpired()) && createAndActiveCount.load() - expireEntries.size > poolConfig.
                    minActiveSize) {
                    sharedObjects[i].store(None)
                    expireEntries.add(sharedObject)
                    continue
                }
            }
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
        builder.append("NonExclusiveObjectPool{")
        builder.append("createAndActive objects: ${createAndActiveCount.load()}, ")
        builder.append("active objects: ${activeCount.load()}, ")
        builder.append("share objects: ${sharedObjects.size}, ")
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
class NonExclusiveEvictorThread<T> where T <: Hashable & Equatable<T> {
    private static let logger = LoggerFactory.getLogger("objectpool")

    private let pool: NonExclusiveObjectPool<T>

    private let evictionIntervalsInSeconds: Int64

    public init(pool: NonExclusiveObjectPool<T>, evictionIntervalsInSeconds: Int64) {
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
