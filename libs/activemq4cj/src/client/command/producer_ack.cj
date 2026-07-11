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

public class ProducerAck <: BaseCommand {
    private var producerIdVal: ?ProducerId = None
    private var sizeVal: Int32 = 0

    public func copy(copy: ProducerAck): Unit {
        super.copy(copy)
        copy.producerId = producerId
        copy.size = size
    }

    public func getDataStructureType(): Byte {
        return CommandTypes.PRODUCER_ACK
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processProducerAck(this)
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ProducerAck)) {
            return false
        }
        if (let Some(other) <- (other as ProducerAck)) {
            if (this.producerId != other.producerId) {
                return false
            }
            if (this.size != other.size) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ProducerAck)) {
            return true
        }
        if (let Some(other) <- (other as ProducerAck)) {
            if (this.producerId != other.producerId) {
                return true
            }
            if (this.size != other.size) {
                return true
            }
        }
        return false
    }

    public mut prop producerId: ?ProducerId {
        get() {
            return this.producerIdVal
        }
        set(value) {
            this.producerIdVal = value
        }
    }

    public mut prop size: Int32 {
        get() {
            return this.sizeVal
        }
        set(value) {
            this.sizeVal = value
        }
    }
}
