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
package activemq4cj.client.command

public interface CommandVisitor {
    func processAddConnection(info: ConnectionInfo): ?Response

    func processAddSession(info: SessionInfo): ?Response

    func processAddProducer(info: ProducerInfo): ?Response

    func processAddConsumer(info: ConsumerInfo): ?Response

    func processRemoveConnection(id: ConnectionId, lastDeliveredSequenceId: Int64): ?Response

    func processRemoveSession(id: SessionId, lastDeliveredSequenceId: Int64): ?Response

    func processRemoveProducer(id: ProducerId): ?Response

    func processRemoveConsumer(id: ConsumerId, lastDeliveredSequenceId: Int64): ?Response

    func processAddDestination(info: DestinationInfo): ?Response

    func processRemoveDestination(info: DestinationInfo): ?Response

    func processMessage(message: Message): ?Response

    func processMessageAck(ack: MessageAck): ?Response

    func processMessagePull(messagePull: MessagePull): ?Response

    func processBeginTransaction(info: TransactionInfo): ?Response

    func processCommitTransaction(info: TransactionInfo): ?Response

    func processRollbackTransaction(info: TransactionInfo): ?Response

    func processBrokerInfo(info: BrokerInfo): ?Response

    func processProducerAck(ack: ProducerAck): ?Response

    func processMessageDispatch(dispatch: MessageDispatch): ?Response

    func processConnectionControl(info: ConnectionControl): ?Response

    func processConsumerControl(info: ConsumerControl): ?Response

    func processControlCommand(command: ControlCommand): ?Response

    func processFlush(command: FlushCommand): ?Response

    func processKeepAlive(info: KeepAliveInfo): ?Response

    func processMessageDispatchNotification(notification: MessageDispatchNotification): ?Response

    func processRemoveSubscription(info: RemoveSubscriptionInfo): ?Response

    func processShutdown(info: ShutdownInfo): ?Response

    func processConnectionError(error: ConnectionError): ?Response

    func processWireFormat(info: WireFormatInfo): ?Response
}

public open class CommandVisitorAdapter <: CommandVisitor {
    public open func processAddConnection(info: ConnectionInfo): ?Response {
        return None
    }

    public open func processAddSession(info: SessionInfo): ?Response {
        return None
    }

    public open func processAddProducer(info: ProducerInfo): ?Response {
        return None
    }

    public open func processAddConsumer(info: ConsumerInfo): ?Response {
        return None
    }

    public open func processRemoveConnection(id: ConnectionId, lastDeliveredSequenceId: Int64): ?Response {
        return None
    }

    public open func processRemoveSession(id: SessionId, lastDeliveredSequenceId: Int64): ?Response {
        return None
    }

    public open func processRemoveProducer(id: ProducerId): ?Response {
        return None
    }

    public open func processRemoveConsumer(id: ConsumerId, lastDeliveredSequenceId: Int64): ?Response {
        return None
    }

    public open func processAddDestination(info: DestinationInfo): ?Response {
        return None
    }

    public open func processRemoveDestination(info: DestinationInfo): ?Response {
        return None
    }

    public open func processMessage(message: Message): ?Response {
        return None
    }

    public open func processMessageAck(ack: MessageAck): ?Response {
        return None
    }

    public open func processMessagePull(messagePull: MessagePull): ?Response {
        return None
    }

    public open func processBeginTransaction(info: TransactionInfo): ?Response {
        return None
    }

    public open func processCommitTransaction(info: TransactionInfo): ?Response {
        return None
    }

    public open func processRollbackTransaction(info: TransactionInfo): ?Response {
        return None
    }

    public open func processBrokerInfo(info: BrokerInfo): ?Response {
        return None
    }

    public open func processProducerAck(ack: ProducerAck): ?Response {
        return None
    }

    public open func processMessageDispatch(dispatch: MessageDispatch): ?Response {
        return None
    }

    public open func processConnectionControl(info: ConnectionControl): ?Response {
        return None
    }

    public open func processConsumerControl(info: ConsumerControl): ?Response {
        return None
    }

    public open func processControlCommand(command: ControlCommand): ?Response {
        return None
    }

    public open func processFlush(command: FlushCommand): ?Response {
        return None
    }

    public open func processKeepAlive(info: KeepAliveInfo): ?Response {
        return None
    }

    public open func processMessageDispatchNotification(notification: MessageDispatchNotification): ?Response {
        return None
    }

    public open func processRemoveSubscription(info: RemoveSubscriptionInfo): ?Response {
        return None
    }

    public open func processShutdown(info: ShutdownInfo): ?Response {
        return None
    }

    public open func processConnectionError(error: ConnectionError): ?Response {
        return None
    }

    public open func processWireFormat(info: WireFormatInfo): ?Response {
        return None
    }
}
