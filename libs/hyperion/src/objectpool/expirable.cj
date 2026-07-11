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
 * 支持过期的接口
 * 
 * @author yangfuping
 */
public interface Expirable {

    /**
     * 获取空闲超时时间
     */
    mut prop idleTimeout: ?Duration

    /**
     * 取消超时
     */
    func cancelExpireTime(): Unit

    /**
     * 延迟超时时间
     */
    func setExpireTimeIfAbsent(): Unit

    /**
     * 延迟超时时间
     */
    func setExpireTime(): Unit

    /**
     * 是否超时
     */
    func isExpired(): Bool
}

/**
 * 支持过期的对象
 * 
 * @author yangfuping
 */
public class ExpirableItem <: Expirable {
    private var idleTimeoutVal: ?Duration = None

    private var expirationTime: ?Int64 = None

    public mut prop idleTimeout: ?Duration {
        get() {
            return this.idleTimeoutVal
        }
        set(value) {
            this.idleTimeoutVal = value
        }
    }

    public func getIdleTimeout(): ?Duration {
        return this.idleTimeout
    }

    public func cancelExpireTime(): Unit {
        this.expirationTime = None
    }

    public func setExpireTimeIfAbsent(): Unit {
        if (let Some(idleTimeout) <- idleTimeout) {
            if (expirationTime.isNone()) {
                let nowUnixSeconds = DateTime.now().toUnixTimeStamp().toSeconds()
                this.expirationTime = nowUnixSeconds + idleTimeout.toSeconds()
            }
        }
    }

    public func setExpireTime(): Unit {
        if (let Some(idleTimeout) <- idleTimeout) {
            let nowUnixSeconds = DateTime.now().toUnixTimeStamp().toSeconds()
            this.expirationTime = nowUnixSeconds + idleTimeout.toSeconds()
        }
    }

    public func isExpired(): Bool {
        if (idleTimeout.isNone()) {
            return false
        }

        if (let Some(expirationTime) <- expirationTime) {
            let nowUnixSeconds = DateTime.now().toUnixTimeStamp().toSeconds()
            return nowUnixSeconds > expirationTime
        }

        return false
    }
}
