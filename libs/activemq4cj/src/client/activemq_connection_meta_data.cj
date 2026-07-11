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

public class ActiveMQConnectionMetaData <: ConnectionMetaData {
    public static let PROVIDER_VERSION: ?String = None
    public static let PROVIDER_MAJOR_VERSION: Int32 = 0
    public static let PROVIDER_MINOR_VERSION: Int32 = 0
    public static let PROVIDER_NAME = "ActiveMQ"

    public static let INSTANCE: ActiveMQConnectionMetaData = ActiveMQConnectionMetaData()

    public func getCJMSVersion(): String {
        return "2.0"
    }

    public func getCJMSMajorVersion(): Int32 {
        return 2
    }

    public func getCJMSMinorVersion(): Int32 {
        return 0
    }

    public func getCJMSProviderName(): String {
        return PROVIDER_NAME
    }

    public func getProviderVersion(): ?String {
        return PROVIDER_VERSION
    }

    public func getProviderMajorVersion(): Int32 {
        return PROVIDER_MAJOR_VERSION
    }

    public func getProviderMinorVersion(): Int32 {
        return PROVIDER_MINOR_VERSION
    }

    public func getCMSXPropertyNames(): LinkedList<String> {
        let rc = LinkedList<String>()
        rc.addLast("CJMSXUserID")
        rc.addLast("CJMSXGroupID")
        rc.addLast("CJMSXGroupSeq")
        rc.addLast("CJMSXDeliveryCount")
        rc.addLast("CJMSXProducerTXID")
        return rc
    }
}
