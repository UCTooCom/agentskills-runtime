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

public class ActiveMQBlobMessage <: ActiveMQMessage & BlobMessage {
    public static let BINARY_MIME_TYPE: String = "application/octet-stream"

    private var remoteBlobUrlVal: ?String = None
    private var mimeTypeVal: ?String = None
    private var deletedByBrokerVal: Bool = false

    private var url: ?URL = None

    public override func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_BLOB_MESSAGE
    }

    public override func getURL(): ?URL {
        if (let Some(remoteBlobUrl) <- this.remoteBlobUrlVal) {
            this.url = URL.parse(remoteBlobUrl)
        }
        return url
    }

    public func setURL(value: ?URL) {
        this.url = value
        if (let Some(value) <- value) {
            this.remoteBlobUrl = value.toString()
        } else {
            this.remoteBlobUrl = None
        }
    }

    public mut prop remoteBlobUrl: ?String {
        get() {
            return this.remoteBlobUrlVal
        }
        set(value) {
            this.remoteBlobUrlVal = value
        }
    }

    public mut prop mimeType: ?String {
        get() {
            return this.mimeTypeVal
        }
        set(value) {
            this.mimeTypeVal = value
        }
    }

    public mut prop deletedByBroker: Bool {
        get() {
            return this.deletedByBrokerVal
        }
        set(value) {
            this.deletedByBrokerVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQBlobMessage)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQBlobMessage)) {
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQBlobMessage)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQBlobMessage)) {
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
