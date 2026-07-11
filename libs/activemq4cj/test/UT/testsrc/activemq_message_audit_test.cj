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
package activemq_client_unit_test

@Test
public class ActiveMQMessageAuditTest {
    private let connectionIdGenerator: IdGenerator = IdGenerator()
    private let sessionIdGenerator: AtomicInt64 = AtomicInt64(0)
    private let producerIdGenerator: AtomicInt64 = AtomicInt64(0)
    private let sequenceIdGenerator: AtomicInt64 = AtomicInt64(0)

    @TestCase
    public func testAuditDepth(): Unit {
        var maxAuditDepth = Int64(Int16.Max)

        var connectionId: ConnectionId = ConnectionId(connectionIdGenerator.generateId())
        var sessionId: SessionId = SessionId(connectionId.value, sessionIdGenerator.fetchAdd(1))
        var producerId: ProducerId = ProducerId(sessionId, producerIdGenerator.fetchAdd(1))

        var audit: ActiveMQMessageAuditNoSync = ActiveMQMessageAuditNoSync()
        audit.auditDepth = maxAuditDepth

        var msgId: MessageId = MessageId(producerId, 0)
        for (i in 0..maxAuditDepth) {
            msgId.producerSequenceId = sequenceIdGenerator.fetchAdd(1)
            @Assert(!audit.isDuplicate(msgId))
        }

        for (i in 0..maxAuditDepth) {
            @Assert(audit.isDuplicate(msgId))
        }
    }

    @TestCase
    public func testIsDuplicateString(): Unit {
        var count: Int64 = 10000
        var audit: ActiveMQMessageAudit = ActiveMQMessageAudit()
        var idGenerator: IdGenerator = IdGenerator()
        var list: LinkedList<String> = LinkedList<String>()
        for (i in 0..count) {
            var id: String = idGenerator.generateId()
            list.addLast(id)
            @Assert(!audit.isDuplicate(id))
        }

        if (let Some(node) <- list.nodeAt(count - 1 - audit.auditDepth)) {
            var subList = list.splitOff(node)
            for (id in subList) {
                @Assert(audit.isDuplicate(id))
            }
        }
    }

    @TestCase
    public func testIsDuplicateMessage(): Unit {
        var count: Int64 = 10000
        var audit: ActiveMQMessageAudit = ActiveMQMessageAudit()
        var list: LinkedList<CJMSMessage> = LinkedList<CJMSMessage>()
        for (i in 0..count) {
            var pid: ProducerId = ProducerId()
            pid.connectionId = "test"
            pid.sessionId = 0
            pid.value = 1
            var id: MessageId = MessageId()
            id.producerId = pid
            id.producerSequenceId = i
            var msg: ActiveMQMessage = ActiveMQMessage()
            msg.messageId = id
            list.addLast(msg)
            @Assert(!audit.isDuplicate(msg))
        }

        if (let Some(node) <- list.nodeAt(count - 1 - audit.auditDepth)) {
            var subList = list.splitOff(node)
            for (msg in subList) {
                @Assert(audit.isDuplicate(msg))
            }
        }
    }

    @TestCase
    public func testIsInOrderString(): Unit {
        var count: Int64 = 10000
        var audit: ActiveMQMessageAudit = ActiveMQMessageAudit()
        var idGenerator: IdGenerator = IdGenerator()
        var list: LinkedList<String> = LinkedList<String>()
        for (i in 0..count) {
            var id = idGenerator.generateId()
            if (i == 0) {
                @Assert(!audit.isDuplicate(id))
                @Assert(audit.isInOrder(id))
            }
            if (i > 1 && i % 2 != 0) {
                list.addLast(id)
            }
        }
        for (id in list) {
            @Assert(!audit.isInOrder(id))
            @Assert(!audit.isDuplicate(id))
        }
    }
}
