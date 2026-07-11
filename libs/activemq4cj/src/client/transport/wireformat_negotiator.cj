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

/**
 * connection start时发送WireformatInfo命令，与服务端协商
 */
public class WireFormatNegotiator <: TransportFilter {
    private static let logger: Logger = LoggerFactory.getLogger("activemq-sdk")

    private let firstStart: AtomicBool = AtomicBool(false)

    private let wireFormat: OpenWireFormat
    private let negotiateTimeout: Duration = Duration.second * 15

    private let readyCountDownLatch = SyncCounter(1)
    private let wireInfoSentDownLatch = SyncCounter(1)
    public init(next: Transport, wireFormat: OpenWireFormat) {
        super(next)
        this.wireFormat = wireFormat
    }

    public override func start(): Unit {
        super.start()
        if (firstStart.compareAndSwap(false, true)) {
            try {
                if (let Some(wireFormatInfo) <- wireFormat.getPreferedWireFormatInfo()) {
                    if (logger.isDebugEnabled()) {
                        logger.debug("Sending WireFormatInfo: ${wireFormatInfo}")
                    }
                    next.oneway(wireFormatInfo)
                }
            } finally {
                wireInfoSentDownLatch.dec()
            }
        }
    }

    public override func oneway(command: Command): Unit {
        //只有收到服务器发回WireFoematInfo，才允许发送其它命令，否则超时抛异常
        readyCountDownLatch.waitUntilZero(timeout: negotiateTimeout)
        if (readyCountDownLatch.count > 0) {
            throw TransportException("Wire format negotiation timeout: peer did not send his wire format")
        }
        next.oneway(command)
    }

    public override func onCommand(command: Command): Unit {
        if (let Some(wireformatInfo) <- (command as WireFormatInfo)) {
            if (logger.isDebugEnabled()) {
                logger.debug("Receive: ${wireformatInfo}")
            }
            negociate(wireformatInfo)
        }
        if (let Some(listener) <- transportListener) {
            listener.onCommand(command)
        }
    }

    public func negociate(info: WireFormatInfo): Unit {
        try {
            wireInfoSentDownLatch.waitUntilZero()
            if (!info.isValid()) {
                onException(TransportException("Remote wire format magic is invalid"))
            }
            wireFormat.renegotiateWireFormat(info)
        } catch (e: TransportException) {
            onException(e)
        }
        readyCountDownLatch.dec()
    }

    public override func onException(error: TransportException): Unit {
        readyCountDownLatch.dec()
        super.onException(error)
    }
}
