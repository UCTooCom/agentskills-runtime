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
package activemq4cj.client.openwire.v12

public class MarshallerFactory <: OpenWireMarshallerFactory {
    private let dataMarshallers: Array<DataStreamMarshaller> = Array<DataStreamMarshaller>(125,
            repeat: DefaultDataStreamMarshaller())

    public init() {
        dataMarshallers[1] = WireFormatInfoMarshaller()
        dataMarshallers[2] = BrokerInfoMarshaller()
        dataMarshallers[3] = ConnectionInfoMarshaller()
        dataMarshallers[4] = SessionInfoMarshaller()
        dataMarshallers[5] = ConsumerInfoMarshaller()
        dataMarshallers[6] = ProducerInfoMarshaller()
        dataMarshallers[7] = TransactionInfoMarshaller()
        dataMarshallers[8] = DestinationInfoMarshaller()
        dataMarshallers[9] = RemoveSubscriptionInfoMarshaller()
        dataMarshallers[10] = KeepAliveInfoMarshaller()
        dataMarshallers[11] = ShutdownInfoMarshaller()
        dataMarshallers[12] = RemoveInfoMarshaller()
        dataMarshallers[14] = ControlCommandMarshaller()
        dataMarshallers[15] = FlushCommandMarshaller()
        dataMarshallers[16] = ConnectionErrorMarshaller()
        dataMarshallers[17] = ConsumerControlMarshaller()
        dataMarshallers[18] = ConnectionControlMarshaller()
        dataMarshallers[19] = ProducerAckMarshaller()
        dataMarshallers[20] = MessagePullMarshaller()
        dataMarshallers[21] = MessageDispatchMarshaller()
        dataMarshallers[22] = MessageAckMarshaller()
        dataMarshallers[23] = ActiveMQMessageMarshaller()
        dataMarshallers[24] = ActiveMQBytesMessageMarshaller()
        dataMarshallers[25] = ActiveMQMapMessageMarshaller()
        dataMarshallers[26] = ActiveMQObjectMessageMarshaller()
        dataMarshallers[27] = ActiveMQStreamMessageMarshaller()
        dataMarshallers[28] = ActiveMQTextMessageMarshaller()
        dataMarshallers[29] = ActiveMQBlobMessageMarshaller()
        dataMarshallers[30] = ResponseMarshaller()
        dataMarshallers[31] = ExceptionResponseMarshaller()
        dataMarshallers[32] = DataResponseMarshaller()
        dataMarshallers[33] = DataArrayResponseMarshaller()
        dataMarshallers[34] = IntegerResponseMarshaller()
        dataMarshallers[40] = DiscoveryEventMarshaller()
        dataMarshallers[50] = JournalTopicAckMarshaller()
        dataMarshallers[52] = JournalQueueAckMarshaller()
        dataMarshallers[53] = JournalTraceMarshaller()
        dataMarshallers[54] = JournalTransactionMarshaller()
        dataMarshallers[55] = SubscriptionInfoMarshaller()
        dataMarshallers[60] = PartialCommandMarshaller()
        dataMarshallers[61] = LastPartialCommandMarshaller()
        dataMarshallers[65] = ReplayCommandMarshaller()
        dataMarshallers[90] = MessageDispatchNotificationMarshaller()
        dataMarshallers[91] = NetworkBridgeFilterMarshaller()
        dataMarshallers[100] = ActiveMQQueueMarshaller()
        dataMarshallers[101] = ActiveMQTopicMarshaller()
        dataMarshallers[102] = ActiveMQTempQueueMarshaller()
        dataMarshallers[103] = ActiveMQTempTopicMarshaller()
        dataMarshallers[110] = MessageIdMarshaller()
        dataMarshallers[111] = LocalTransactionIdMarshaller()
        dataMarshallers[112] = XATransactionIdMarshaller()
        dataMarshallers[120] = ConnectionIdMarshaller()
        dataMarshallers[121] = SessionIdMarshaller()
        dataMarshallers[122] = ConsumerIdMarshaller()
        dataMarshallers[123] = ProducerIdMarshaller()
        dataMarshallers[124] = BrokerIdMarshaller()
    }

    public func createMarshallerMap(): Array<DataStreamMarshaller> {
        return this.dataMarshallers
    }
}
