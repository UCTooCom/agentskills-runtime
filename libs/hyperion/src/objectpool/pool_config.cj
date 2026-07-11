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

/*
 * 对象池配置
 *
 * @author yangfuping
 */
public open class PoolConfig {
    private var minActiveSizeVal: Int64 = 0

    public mut prop minActiveSize: Int64 {
        get() {
            return minActiveSizeVal
        }
        set(value) {
            this.minActiveSizeVal = value
        }
    }

    private var maxActiveSizeVal: Int64 = 0

    public mut prop maxActiveSize: Int64 {
        get() {
            return maxActiveSizeVal
        }
        set(value) {
            this.maxActiveSizeVal = value
        }
    }

    private var borrowTimeoutVal: Duration = Duration.second * 30

    public mut prop borrowTimeout: Duration {
        get() {
            return borrowTimeoutVal
        }
        set(value) {
            this.borrowTimeoutVal = value
        }
    }

    private var idleTimeoutVal: ?Duration = None

    public mut prop idleTimeout: ?Duration {
        get() {
            return idleTimeoutVal
        }
        set(value) {
            this.idleTimeoutVal = value
        }
    }

    private var evictionIntervalsVal: ?Duration = None

    public mut prop evictionIntervals: ?Duration {
        get() {
            return evictionIntervalsVal
        }
        set(value) {
            this.evictionIntervalsVal = value
        }
    }

    private var lifoVal: Bool = true

    public mut prop lifo: Bool {
        get() {
            return lifoVal
        }
        set(value) {
            this.lifoVal = value
        }
    }

    private var testOnCreateVal: Bool = false

    public mut prop testOnCreate: Bool {
        get() {
            return testOnCreateVal
        }
        set(value) {
            this.testOnCreateVal = value
        }
    }

    private var testOnBorrowVal: Bool = false

    public mut prop testOnBorrow: Bool {
        get() {
            return testOnBorrowVal
        }
        set(value) {
            this.testOnBorrowVal = value
        }
    }

    private var testOnReturnVal: Bool = false

    public mut prop testOnReturn: Bool {
        get() {
            return testOnReturnVal
        }
        set(value) {
            this.testOnReturnVal = value
        }
    }

    private var testWhileIdleVal: Bool = false

    public mut prop testWhileIdle: Bool {
        get() {
            return testWhileIdleVal
        }
        set(value) {
            this.testWhileIdleVal = value
        }
    }
}
