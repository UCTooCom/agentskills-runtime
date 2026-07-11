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

public class ActiveMQMessageAudit <: ActiveMQMessageAuditNoSync {
    private let mutex: Mutex = Mutex()

    public init() {
        super()
    }

    public init(auditDepth: Int64, maximumNumberOfProducersToTrack: Int64) {
        super(auditDepth, maximumNumberOfProducersToTrack)
    }

    public override func isDuplicate(id: ?String): Bool {
        synchronized(mutex) {
            super.isDuplicate(id)
        }
    }

    public override func isDuplicate(id: ?MessageId): Bool {
        synchronized(mutex) {
            super.isDuplicate(id)
        }
    }

    public override func rollback(id: ?MessageId): Unit {
        synchronized(mutex) {
            super.rollback(id)
        }
    }

    public override func isInOrder(id: ?String) {
        synchronized(mutex) {
            super.isInOrder(id)
        }
    }

    public override func isInOrder(id: ?MessageId) {
        synchronized(mutex) {
            super.isInOrder(id)
        }
    }

    public func setMaximumNumberOfProducersToTrack(maximumNumberOfProducersToTrack: Int64) {
        synchronized(mutex) {
            super.maximumNumberOfProducersToTrack = maximumNumberOfProducersToTrack
        }
    }
}
