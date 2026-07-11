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
 * 存储对象的容器
 * 
 * @author yangfuping
 */
public open class PooledObject<T> <: Expirable & Hashable & Equatable<PooledObject<T>> where T <: Hashable & Equatable<T> {
    protected let id: Int64

    private static let idGenerator = AtomicInt64(0)

    private let borrowCount = AtomicUInt64(0)

    private let concurrentUseCount = AtomicUInt64(0)

    private var lastBorrowCount = AtomicUInt64(0)

    private let expirableDelegate = ExpirableItem()

    public init(value: T) {
        id = PooledObject<T>.idGenerator.fetchAdd(1)
        this.valueHolder = value
        createTimeVal = DateTime.now()
    }

    private var valueHolder: T

    public prop value: T {
        get() {
            return valueHolder
        }
    }

    private var createTimeVal: DateTime

    public prop createTime: ?DateTime {
        get() {
            return createTimeVal
        }
    }

    public mut prop idleTimeout: ?Duration {
        get() {
            return expirableDelegate.idleTimeout
        }
        set(value) {
            expirableDelegate.idleTimeout = value
        }
    }

    public func config(poolConfig: PoolConfig) {
        if (let Some(idleTimeout) <- poolConfig.idleTimeout) {
            this.idleTimeout = idleTimeout
        }
    }

    public func cancelExpireTime(): Unit {
        expirableDelegate.cancelExpireTime()
    }

    public func setExpireTimeIfAbsent(): Unit {
        expirableDelegate.setExpireTimeIfAbsent()
    }

    public func setExpireTime(): Unit {
        expirableDelegate.setExpireTime()
    }

    public func isExpired(): Bool {
        return expirableDelegate.isExpired()
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        var hashCode = 37 * id
        hashCode = hashCode + valueHolder.hashCode()
        hashCode = hashCode + createTime.hashCode()
        return hashCode
    }

    public operator override func ==(other: PooledObject<T>): Bool {
        if (id != other.id) {
            return false
        }

        if (value != other.value) {
            return false
        }

        if (createTime != other.createTime) {
            return false
        }

        return true
    }

    public operator override func !=(other: PooledObject<T>): Bool {
        if (id != other.id) {
            return true
        }

        if (value != other.value) {
            return true
        }

        if (createTime != other.createTime) {
            return true
        }

        return false
    }

    public func allocate() {
        borrowCount.fetchAdd(1)
        concurrentUseCount.fetchAdd(1)
        cancelExpireTime()
    }

    public func deallocate() {
        concurrentUseCount.fetchSub(1)
    }

    /**
     * 检测两个evict周期之间，连接是否空闲
     */
    public func checkIdleAndSetExpireTime(): Bool {
        let idle = concurrentUseCount.load() == 0
            && borrowCount.load() == lastBorrowCount.load()

        if (idle) {
            // 如果已经设置了超时时间，则沿用原来的超时时间
            setExpireTimeIfAbsent()
        } else {
            lastBorrowCount.store(borrowCount.load())
        }

        return idle
    }
}
