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
package activemq4cj.client.api

public class CommandTypes {
    private init() {
    }

    public static let PROTOCOL_VERSION: Byte = 12

    // What is the latest version of the openwire protocol used in the stores
    public static let PROTOCOL_STORE_VERSION: Byte = 11

    // What is the legacy version that old KahaDB store's most commonly used
    public static let PROTOCOL_LEGACY_STORE_VERSION: Byte = 6

    // What is the first version that BROKER_SUBSCRIPTION_INFO is supported
    public static let PROTOCOL_VERSION_DURABLE_SYNC: Byte = 12

    // A marshaling layer can use this type to specify a null object.
    public static let NULL: Byte = 0

    public static let MAGIC: String = "ActiveMQ"

    public static let PROVIDER_NAME: String = "ActiveMQ"
    public static let DEFAULT_PLATFORM_DETAILS: String = "Cangjie"

    public static let WIREFORMAT_INFO: Byte = 1
    public static let BROKER_INFO: Byte = 2
    public static let CONNECTION_INFO: Byte = 3
    public static let SESSION_INFO: Byte = 4
    public static let CONSUMER_INFO: Byte = 5
    public static let PRODUCER_INFO: Byte = 6
    public static let TRANSACTION_INFO: Byte = 7
    public static let DESTINATION_INFO: Byte = 8
    public static let REMOVE_SUBSCRIPTION_INFO: Byte = 9
    public static let KEEP_ALIVE_INFO: Byte = 10
    public static let SHUTDOWN_INFO: Byte = 11
    public static let REMOVE_INFO: Byte = 12
    public static let CONTROL_COMMAND: Byte = 14
    public static let FLUSH_COMMAND: Byte = 15
    public static let CONNECTION_ERROR: Byte = 16
    public static let CONSUMER_CONTROL: Byte = 17
    public static let CONNECTION_CONTROL: Byte = 18
    public static let PRODUCER_ACK: Byte = 19
    public static let MESSAGE_PULL: Byte = 20
    public static let MESSAGE_DISPATCH: Byte = 21
    public static let MESSAGE_ACK: Byte = 22
    public static let ACTIVEMQ_MESSAGE: Byte = 23
    public static let ACTIVEMQ_BYTES_MESSAGE: Byte = 24
    public static let ACTIVEMQ_MAP_MESSAGE: Byte = 25
    public static let ACTIVEMQ_OBJECT_MESSAGE: Byte = 26
    public static let ACTIVEMQ_STREAM_MESSAGE: Byte = 27
    public static let ACTIVEMQ_TEXT_MESSAGE: Byte = 28
    public static let ACTIVEMQ_BLOB_MESSAGE: Byte = 29

    public static let RESPONSE: Byte = 30
    public static let EXCEPTION_RESPONSE: Byte = 31
    public static let DATA_RESPONSE: Byte = 32
    public static let DATA_ARRAY_RESPONSE: Byte = 33
    public static let INTEGER_RESPONSE: Byte = 34

    public static let DISCOVERY_EVENT: Byte = 40

    public static let JOURNAL_ACK: Byte = 50
    public static let JOURNAL_REMOVE: Byte = 52
    public static let JOURNAL_TRACE: Byte = 53
    public static let JOURNAL_TRANSACTION: Byte = 54
    public static let DURABLE_SUBSCRIPTION_INFO: Byte = 55

    public static let PARTIAL_COMMAND: Byte = 60
    public static let PARTIAL_LAST_COMMAND: Byte = 61

    public static let REPLAY: Byte = 65;

    public static let BYTE_TYPE: Byte = 70
    public static let CHAR_TYPE: Byte = 71
    public static let SHORT_TYPE: Byte = 72
    public static let INTEGER_TYPE: Byte = 73
    public static let LONG_TYPE: Byte = 74
    public static let DOUBLE_TYPE: Byte = 75
    public static let FLOAT_TYPE: Byte = 76
    public static let STRING_TYPE: Byte = 77
    public static let BOOLEAN_TYPE: Byte = 78
    public static let BYTE_ARRAY_TYPE: Byte = 79

    public static let MESSAGE_DISPATCH_NOTIFICATION: Byte = 90
    public static let NETWORK_BRIDGE_FILTER: Byte = 91
    public static let BROKER_SUBSCRIPTION_INFO: Byte = 92

    public static let ACTIVEMQ_QUEUE: Byte = 100
    public static let ACTIVEMQ_TOPIC: Byte = 101
    public static let ACTIVEMQ_TEMP_QUEUE: Byte = 102
    public static let ACTIVEMQ_TEMP_TOPIC: Byte = 103

    public static let MESSAGE_ID: Byte = 110
    public static let ACTIVEMQ_LOCAL_TRANSACTION_ID: Byte = 111
    public static let ACTIVEMQ_XA_TRANSACTION_ID: Byte = 112

    public static let CONNECTION_ID: Byte = 120
    public static let SESSION_ID: Byte = 121
    public static let CONSUMER_ID: Byte = 122
    public static let PRODUCER_ID: Byte = 123
    public static let BROKER_ID: Byte = 124
}
