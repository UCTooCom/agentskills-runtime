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

package hyperion.buffer

/**
 * ByteBuffer分配器
 *
 * @author yangfuping
 */
public abstract class ByteBufferAllocator <: Equatable<ByteBufferAllocator> {
    protected static let logger = LoggerFactory.getLogger("transport")

    protected static let idGen = AtomicInt64(0)

    protected let createTime = DateTime.now()

    protected let id = idGen.fetchAdd(1)

    protected let allocateSize: Int64

    public init(allocateSize: Int64) {
        if (allocateSize < 0) {
            throw IllegalArgumentException("Negative allocate size ${allocateSize}")
        }
        this.allocateSize = allocateSize
    }

    public open func allocate(): ByteBuffer

    public open func allocate(capacity: Int64): ByteBuffer

    public open func allocate(capacity: Int64, expandSupport: Bool): ByteBuffer

    public open func free(buffer: ?ByteBuffer): Unit
}

/**
 * 不带池化的ArrayByteBuffer分配器
 *
 * @author yangfuping
 */
public open class ArrayByteBufferAllocator <: ByteBufferAllocator {
    private let expandSupport: Bool
    public init() {
        super(ByteBuffer.DEFAULT_INITIAL_CAPACITY)
        // 默认支持扩展
        this.expandSupport = true
    }

    public init(allocateSize: Int64) {
        super(allocateSize)
        // 默认支持扩展
        this.expandSupport = true
    }

    public init(allocateSize: Int64, expandSupport: Bool) {
        super(allocateSize)
        this.expandSupport = expandSupport
    }

    public open func allocate(): ByteBuffer {
        return allocate(allocateSize)
    }

    public open func allocate(capacity: Int64): ArrayByteBuffer {
        var realAllocateSize = capacity
        if (capacity < allocateSize) {
            // 需要的空间小于allocateSize, 按allocateSize分配
            realAllocateSize = allocateSize
        }

        return ArrayByteBuffer(realAllocateSize, expandSupport: expandSupport)
    }

    public open func allocate(capacity: Int64, expandSupport: Bool): ArrayByteBuffer {
        var realAllocateSize = capacity
        if (capacity < allocateSize) {
            // 需要的空间小于allocateSize, 按allocateSize分配
            realAllocateSize = allocateSize
        }

        return ArrayByteBuffer(realAllocateSize, expandSupport: expandSupport)
    }

    public open func free(buffer: ?ByteBuffer): Unit {
        // do nothing
    }

    public open operator func ==(other: ByteBufferAllocator): Bool {
        if (let Some(buffer) <- (other as ArrayByteBufferAllocator)) {
            if (id != buffer.id) {
                return false
            }

            if (createTime != buffer.createTime) {
                return false
            }

            return true
        }

        return false
    }

    public open operator func !=(other: ByteBufferAllocator): Bool {
        if (let Some(buffer) <- (other as ArrayByteBufferAllocator)) {
            if (id != buffer.id) {
                return true
            }

            if (createTime != buffer.createTime) {
                return true
            }

            return false
        }

        return true
    }
}

/**
 * 池化的ArrayByteBuffer分配器
 *
 * @author yangfuping
 */
public open class PooledArrayByteBufferAllocator <: ArrayByteBufferAllocator {
    static let DEFAULT_POOLED_BUFFER_CAPACITY = 8192

    static let DEFAULT_MAX_POOLED_BUFFERS = 2048

    private let maxPooledBuffers: Int64

    private let queue: ArrayBlockingQueue<ArrayByteBuffer>

    public init() {
        super(DEFAULT_POOLED_BUFFER_CAPACITY)
        this.maxPooledBuffers = DEFAULT_MAX_POOLED_BUFFERS
        queue = ArrayBlockingQueue<ArrayByteBuffer>(maxPooledBuffers)
    }

    public init(allocateSize: Int64, maxPooledBuffers: Int64) {
        super(allocateSize)
        this.maxPooledBuffers = maxPooledBuffers
        queue = ArrayBlockingQueue<ArrayByteBuffer>(maxPooledBuffers)
    }

    public open func allocate(): ByteBuffer {
        return allocate(allocateSize)
    }

    public open func allocate(capacity: Int64): ArrayByteBuffer {
        if (capacity <= allocateSize) {
            if (let Some(buffer) <- queue.tryRemove()) {
                buffer.retain()
                return buffer
            }

            //未从队列中取到值，直接创建
            let refCounted = ReferenceCounted()
            let buffer = ArrayByteBuffer(allocateSize, expandSupport: false, allocator: this, refCounted: refCounted)
            refCounted.setDelegateBuffer(buffer)
            // 增加引用数
            buffer.retain()

            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Create Pooled ByteBuffer: ${buffer}, queue size: ${queue.size}")
            }
            return buffer
        } else {
            // 容量超出从allocateSize，直接创建
            let buffer = ArrayByteBuffer(capacity)
            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Create UnPooled ByteBuffer: ${buffer}, queue size: ${queue.size}")
            }
            return buffer
        }
    }

    public open func allocate(capacity: Int64, expandSupport: Bool): ArrayByteBuffer {
        if (capacity <= allocateSize && !expandSupport) {
            if (let Some(buffer) <- queue.tryRemove()) {
                // 增加引用数
                buffer.retain()
                return buffer
            }

            let refCounted = ReferenceCounted()
            let buffer = ArrayByteBuffer(allocateSize, expandSupport: false, allocator: this, refCounted: refCounted)
            refCounted.setDelegateBuffer(buffer)
            // 增加引用数
            buffer.retain()

            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Create Pooled ByteBuffer: ${buffer}, queue size: ${queue.size}")
            }

            return buffer
        }

        // 容量超出从allocateSize，或者需要扩展的ByteBuffer,直接创建
        let buffer = ArrayByteBuffer(capacity, expandSupport: expandSupport)
        if (logger.isTraceEnabled()) {
            logger.log(LogLevel.TRACE, "Create UnPooled ByteBuffer: ${buffer}, queue size: ${queue.size}")
        }
        return buffer
    }

    protected open func returnBuffer(buffer: ArrayByteBuffer): Unit {
        if (queue.size < maxPooledBuffers) {
            // 加入队列重新利用
            if (queue.tryAdd(buffer)) {
                if (logger.isTraceEnabled()) {
                    logger.log(LogLevel.TRACE, "Return Pooled ByteBuffer: ${buffer}, queue size: ${queue.size}")
                }
            }
        }
    }

    public open func free(buffer: ?ByteBuffer): Unit {
        if (let Some(buffer) <- buffer) {
            if (let Some(arryByteBuffer) <- (buffer as ArrayByteBuffer)) {
                if (let Some(allocator) <- buffer.getAllocator()) {
                    if (allocator == this) {
                        arryByteBuffer.free()
                        returnBuffer(arryByteBuffer)
                    }
                }
            }
        }
    }

    public operator func ==(other: ByteBufferAllocator): Bool {
        if (let Some(buffer) <- (other as PooledArrayByteBufferAllocator)) {
            if (id != buffer.id) {
                return false
            }

            if (createTime != buffer.createTime) {
                return false
            }

            return true
        }

        return false
    }

    public operator func !=(other: ByteBufferAllocator): Bool {
        if (let Some(buffer) <- (other as PooledArrayByteBufferAllocator)) {
            if (id != buffer.id) {
                return true
            }

            if (createTime != buffer.createTime) {
                return true
            }

            return false
        }

        return true
    }
}
