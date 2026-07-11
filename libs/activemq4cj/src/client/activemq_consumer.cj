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

public class ActiveMQConsumer <: CJMSConsumer {
    private let activemqContext: ActiveMQContext
    private let activemqMessageConsumer: MessageConsumer

    init(activemqContext: ActiveMQContext, activemqMessageConsumer: MessageConsumer) {
        this.activemqContext = activemqContext
        this.activemqMessageConsumer = activemqMessageConsumer
    }

    public prop messageSelector: ?String {
        get() {
            return activemqMessageConsumer.messageSelector
        }
    }

    public mut prop messageListener: ?MessageListener {
        get() {
            return activemqMessageConsumer.messageListener
        }
        set(value) {
            activemqMessageConsumer.messageListener = value
        }
    }

    public override func receive(): ?CJMSMessage {
        return activemqMessageConsumer.receive()
    }

    public override func receive(timeout: Duration): ?CJMSMessage {
        return activemqMessageConsumer.receive(timeout)
    }

    public override func receiveNoWait(): ?CJMSMessage {
        return activemqMessageConsumer.receiveNoWait()
    }

    public override func isClosed(): Bool {
        return activemqMessageConsumer.isClosed()
    }

    public override func close(): Unit {
        activemqMessageConsumer.close()
    }

    public override func ReceiveBody(): Any {
        throw UnsupportedException("ReceiveBody() is not supported")
    }

    public override func receiveBody(timeout: Duration): Any {
        throw UnsupportedException("ReceiveBody(timeout) is not supported")
    }

    public override func receiveBodyNoWait(): Any {
        throw UnsupportedException("ReceiveBodyNoWait() is not supported")
    }
}
