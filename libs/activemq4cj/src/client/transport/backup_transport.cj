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
package activemq4cj.client.transport

public class BackupTransport <: DefaultTransportListener & Equatable<BackupTransport> {
    private let failoverTransport: FailoverTransport

    private var transportVal: ?Transport = None
    private var urlVal: ?URL = None
    private var disposedVal: Bool = false
    private var brokerInfoVal: ?BrokerInfo = None

    init(ft: FailoverTransport) {
        this.failoverTransport = ft
    }

    public override func onException(error: TransportException): Unit {
        this.disposed = true
        failoverTransport.reconnect(false)
    }

    public override func onCommand(command: Command): Unit {
        if (let Some(brokerInfo) <- (command as BrokerInfo)) {
            this.brokerInfoVal = brokerInfo
        }
    }

    public prop brokerInfo: ?BrokerInfo {
        get() {
            return this.brokerInfoVal
        }
    }

    public mut prop transport: ?Transport {
        get() {
            return this.transportVal
        }
        set(value) {
            if (let Some(value) <- value) {
                value.transportListener = this
            }
            this.transportVal = value
        }
    }

    public mut prop url: ?URL {
        get() {
            return this.urlVal
        }
        set(value) {
            this.urlVal = value
        }
    }

    public mut prop disposed: Bool {
        get() {
            if (let Some(transport) <- transport) {
                return transport.disposed || disposedVal
            }
            return disposedVal
        }
        set(value) {
            this.disposedVal = value
        }
    }

    public operator func ==(other: BackupTransport): Bool {
        if (!URLSupport.checkURLEquals(this.urlVal, other.urlVal)) {
            return false
        }
        return true
    }

    public operator func !=(other: BackupTransport): Bool {
        if (!URLSupport.checkURLEquals(this.urlVal, other.urlVal)) {
            return true
        }
        return false
    }
}
