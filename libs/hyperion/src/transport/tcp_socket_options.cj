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

package hyperion.transport

/**
 * Hyperion通信框架相关的配置项
 * 
 * @author yangfuping
 */
public open class TcpSocketOptions {

    //监听端口
    private var portVal: UInt16 = 0

    public mut prop port: UInt16 {
        get() {
            portVal
        }
        set(v) {
            this.portVal = v
        }
    }

    //接收缓冲区
    private var receiveBufferSizeVal: ?Int64 = None

    public mut prop receiveBufferSize: ?Int64 {
        get() {
            receiveBufferSizeVal
        }
        set(v) {
            this.receiveBufferSizeVal = v
        }
    }

    //发送缓冲区
    private var sendBufferSizeVal: ?Int64 = None

    public mut prop sendBufferSize: ?Int64 {
        get() {
            sendBufferSizeVal
        }
        set(v) {
            this.sendBufferSizeVal = v
        }
    }

    //TCP_NODELAY Option
    private var noDelayVal: ?Bool = None

    public mut prop noDelay: ?Bool {
        get() {
            noDelayVal
        }
        set(v) {
            this.noDelayVal = v
        }
    }

    private var lingerVal: ?Duration = None

    public mut prop linger: ?Duration {
        get() {
            lingerVal
        }
        set(v) {
            this.lingerVal = v
        }
    }

    // 读超时时间
    private var readTimeoutVal: ?Duration = None

    public mut prop readTimeout: ?Duration {
        get() {
            readTimeoutVal
        }
        set(v) {
            this.readTimeoutVal = v
        }
    }

    // 写超时时间
    private var writeTimeoutVal: ?Duration = None

    public mut prop writeTimeout: ?Duration {
        get() {
            writeTimeoutVal
        }
        set(v) {
            this.writeTimeoutVal = v
        }
    }

    // 连接空闲超时时间
    private var idleTimeoutVal: ?Duration = None

    public mut prop idleTimeout: ?Duration {
        get() {
            idleTimeoutVal
        }
        set(v) {
            this.idleTimeoutVal = v
        }
    }

    // 异步写数据，每个连接一个写线程
    private var asyncWriteVal: Bool = true

    public mut prop asyncWrite: Bool {
        get() {
            asyncWriteVal
        }
        set(v) {
            this.asyncWriteVal = v
        }
    }

    // 写队列长度，asyncWrite为true时使用
    private var writeQueueSizeVal: Int64 = 8192

    public mut prop writeQueueSize: Int64 {
        get() {
            writeQueueSizeVal
        }
        set(v) {
            if (v > 0) {
                this.writeQueueSizeVal = v
            }
        }
    }

    // 写缓冲区大小，asyncWrite为true时使用，可以减少Socket write系统调用
    private var writeBufferSizeVal: Int64 = 8192

    public mut prop writeBufferSize: Int64 {
        get() {
            writeBufferSizeVal
        }
        set(v) {
            if (v > 0) {
                this.writeBufferSizeVal = v
            }
        }
    }

    // 写线程空闲超时时间
    private var writeThreadIdleTimeoutVal: Duration = Duration.second * 60

    public mut prop writeThreadIdleTimeout: Duration {
        get() {
            writeThreadIdleTimeoutVal
        }
        set(v) {
            this.writeThreadIdleTimeoutVal = v
        }
    }

    // 为每个连接固定一个读数据的线程
    private var stickyReadVal: Bool = true

    public mut prop stickyRead: Bool {
        get() {
            stickyReadVal
        }
        set(v) {
            this.stickyReadVal = v
        }
    }

    // 在读线程上执行编解码和业务逻辑，stickyRead为true时使用
    private var execOnReadThreadVal: Bool = true

    public mut prop execOnReadThread: Bool {
        get() {
            execOnReadThreadVal
        }
        set(v) {
            this.execOnReadThreadVal = v
        }
    }

    // 将要处理的消息报文从读缓存通过切片的方式分割出来，可以减少数组的拷贝
    private var sliceExceedBufferVal: Bool = true

    public mut prop sliceExceedBuffer: Bool {
        get() {
            sliceExceedBufferVal
        }
        set(v) {
            this.sliceExceedBufferVal = v
        }
    }

    /**
     * 能处理的最大消息长度，默认64M
     */
    private var maxMessageSizeInBytesVal: Int64 = 64 * 1024 * 1024

    public mut prop maxMessageSizeInBytes: Int64 {
        get() {
            maxMessageSizeInBytesVal
        }
        set(v) {
            if (v > 0) {
                this.maxMessageSizeInBytesVal = v
            }
        }
    }

    /**
     * 默认分配的ByteBuffer的容量
     *
     */
    private var bufferAllocateSizeVal: Int64 = 8192

    public mut prop bufferAllocateSize: Int64 {
        get() {
            bufferAllocateSizeVal
        }
        set(v) {
            if (v > 0 && v < maxMessageSizeInBytesVal) {
                this.bufferAllocateSizeVal = v
            }
        }
    }

    /**
     * 是否将ByteBuffer缓存到池中
     *
     */
    private var usePooledBufferAllocatorVal: Bool = false

    public mut prop usePooledBufferAllocator: Bool {
        get() {
            usePooledBufferAllocatorVal
        }
        set(v) {
            this.usePooledBufferAllocatorVal = v
        }
    }

    /**
     * 最大缓存的ByteBuffer的数量
     *
     */
    private var maxPooledBuffersVal: Int64 = 1024

    public mut prop maxPooledBuffers: Int64 {
        get() {
            maxPooledBuffersVal
        }
        set(v) {
            if (v > 0) {
                this.maxPooledBuffersVal = v
            }
        }
    }
}
