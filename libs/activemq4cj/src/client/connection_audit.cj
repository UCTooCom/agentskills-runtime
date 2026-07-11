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

class ConnectionAudit {
    private var checkForDuplicatesVal: Bool = false
    private let destinations: LRUCache<ActiveMQDestination, ActiveMQMessageAudit> = LRUCache<ActiveMQDestination, ActiveMQMessageAudit>(
        1000)
    private let dispatchers: LRUCache<ActiveMQDispatcher, ActiveMQMessageAudit> = LRUCache<ActiveMQDispatcher, ActiveMQMessageAudit>(
        1000)

    private var auditDepthVal: Int64 = ActiveMQMessageAudit.DEFAULT_WINDOW_SIZE
    private var auditMaximumProducerNumberVal: Int64 = ActiveMQMessageAudit.MAXIMUM_PRODUCER_COUNT

    private let mutex: Mutex = Mutex()

    func removeDispatcher(dispatcher: ActiveMQDispatcher) {
        synchronized(mutex) {
            dispatchers.remove(dispatcher)
        }
    }

    func isDuplicate(dispatcher: ActiveMQDispatcher, message: ?Message): Bool {
        if (checkForDuplicates) {
            if (let Some(message) <- message) {
                var destination: ?ActiveMQDestination = message.destination
                if (let Some(destination) <- destination) {
                    if (destination.isQueue()) {
                        var audit: ActiveMQMessageAudit
                        if (let Some(destinationAudit) <- destinations.get(destination)) {
                            audit = destinationAudit
                        } else {
                            audit = ActiveMQMessageAudit(auditDepth, auditMaximumProducerNumber)
                            destinations.add(destination, audit)
                        }
                        return audit.isDuplicate(message.messageId)
                    }

                    var audit: ActiveMQMessageAudit
                    if (let Some(dispatcherAudit) <- dispatchers.get(dispatcher)) {
                        audit = dispatcherAudit
                    } else {
                        audit = ActiveMQMessageAudit(auditDepth, auditMaximumProducerNumber)
                        dispatchers.add(dispatcher, audit)
                    }

                    return audit.isDuplicate(message.messageId)
                }
            }
        }
        return false
    }

    protected func rollbackDuplicate(dispatcher: ActiveMQDispatcher, message: Message) {
        synchronized(mutex) {
            if (checkForDuplicates) {
                if (let Some(destination) <- message.destination) {
                    if (destination.isQueue()) {
                        if (let Some(audit) <- destinations.get(destination)) {
                            audit.rollback(message.messageId)
                        }
                    } else {
                        if (let Some(audit) <- dispatchers.get(dispatcher)) {
                            audit.rollback(message.messageId)
                        }
                    }
                }
            }
        }
    }

    public mut prop checkForDuplicates: Bool {
        get() {
            return this.checkForDuplicatesVal
        }
        set(value) {
            this.checkForDuplicatesVal = value
        }
    }

    public mut prop auditDepth: Int64 {
        get() {
            return this.auditDepthVal
        }
        set(value) {
            this.auditDepthVal = value
        }
    }

    public mut prop auditMaximumProducerNumber: Int64 {
        get() {
            return this.auditMaximumProducerNumberVal
        }
        set(value) {
            this.auditMaximumProducerNumberVal = value
        }
    }
}
