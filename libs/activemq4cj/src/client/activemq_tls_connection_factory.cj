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
package activemq4cj.client

public class ActiveMQTlsConnectionFactory <: ActiveMQConnectionFactory {
    private var tlsClientConfig: ?TlsClientConfig = None

    public init() {
        super()
    }

    public init(brokerURL: String) {
        super(brokerURL)
    }

    public init(brokerURL: URL) {
        super(brokerURL)
    }

    public init(userName: String, password: String, brokerURL: String) {
        super(userName, password, brokerURL)
    }

    public init(userName: String, password: String, brokerURL: URL) {
        super(userName, password, brokerURL)
    }

    public func setTlsClientConfig(tlsClientConfig: TlsClientConfig): Unit {
        this.tlsClientConfig = tlsClientConfig
    }

    protected override func createTransport(): Transport {
        var existing = TlsContext.getCurrent()
        try {
            if (let Some(tlsClientConfig) <- this.tlsClientConfig) {
                TlsContext.setCurrentTlsClientConfig(tlsClientConfig)
            } else {
                throw TransportException("Could not create Tls Transport. Reason: TlsClientConfig not found.")
            }
            return super.createTransport()
        } finally {
            TlsContext.setCurrentTlsClientConfig(existing)
        }
    }
}
