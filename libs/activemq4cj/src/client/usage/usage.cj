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
package activemq4cj.client.usage

public class Usage {
    private var limiter: UsageCapacity = DefaultUsageCapacity()

    private var nameVal: ?String = None
    private var percentUsage: Int32 = 0
    private var usageVal: Int64 = 0
    private var percentUsageMinDelta: Int32 = 1

    private let mtx: Monitor = Monitor()
    private let started: AtomicBool = AtomicBool(false)

    public init() {
    }

    public init(name: String) {
        this.nameVal = name
    }

    /**
     * 使用百分比达到100时等待
     */
    public func waitForSpace(): Unit {
        synchronized(mtx) {
            if (this.percentUsage >= 100 && isStarted()) {
                while (this.percentUsage >= 100 && isStarted()) {
                    mtx.wait()
                }
            }
            if (this.percentUsage >= 100 && !isStarted()) {
                throw ActiveMQException("WaitForSpace stopped during wait")
            }
        }
    }

    public func waitForSpace(timeout: Duration): Bool {
        synchronized(mtx) {
            if (this.percentUsage >= 100 && isStarted()) {
                let start = DateTime.now()
                while (this.percentUsage >= 100 && DateTime.now() - start < timeout) {
                    mtx.wait(timeout: timeout)
                }
            }
        }
        return percentUsage < 100
    }

    public func increaseUsage(value: Int64): Unit {
        if (value == 0) {
            return
        }
        synchronized(mtx) {
            usage += value
            setPercentUsage(caclPercentUsage())
        }
    }

    public func decreaseUsage(value: Int64): Unit {
        if (value == 0) {
            return
        }
        synchronized(mtx) {
            usage -= value
            setPercentUsage(caclPercentUsage())
        }
    }

    public func getPercentUsage(): Int32 {
        return this.percentUsage
    }

    private func setPercentUsage(value: Int32): Unit {
        synchronized(mtx) {
            var oldValue: Int32 = percentUsage
            this.percentUsage = value
            if (oldValue != value && oldValue >= 100 && value < 100) {
                mtx.notifyAll()
            }
        }
    }

    private func caclPercentUsage(): Int32 {
        if (limiter.limit == 0) {
            return 0
        }
        return Int32(((((usage * 100) / limiter.limit) / Int64(percentUsageMinDelta)) * Int64(percentUsageMinDelta)) &
            0xFFFFFFFF)
    }

    public func start(): Unit {
        this.started.compareAndSwap(false, true)
    }

    public func stop(): Unit {
        if (this.started.compareAndSwap(true, false)) {
            synchronized(mtx) {
                mtx.notifyAll()
            }
        }
    }

    public func isStarted(): Bool {
        return started.load()
    }

    public mut prop limit: Int64 {
        get() {
            synchronized(mtx) {
                return this.limiter.limit
            }
        }
        set(value) {
            synchronized(mtx) {
                this.limiter.limit = value
                setPercentUsage(caclPercentUsage())
            }
        }
    }

    public mut prop name: ?String {
        get() {
            return this.nameVal
        }
        set(value) {
            this.nameVal = value
        }
    }

    public mut prop usage: Int64 {
        get() {
            return this.usageVal
        }
        set(value) {
            this.usageVal = value
        }
    }
}
