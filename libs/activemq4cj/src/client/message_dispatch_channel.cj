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

public interface MessageDispatchChannel {
    prop size: Int64

    func enqueue(message: MessageDispatch): Unit

    func enqueueFirst(message: MessageDispatch): Unit

    func isEmpty(): Bool

    func dequeue(timeout: Duration): ?MessageDispatch

    func dequeueNoWait(): ?MessageDispatch

    func peek(): ?MessageDispatch

    func start(): Unit

    func stop(): Unit

    func close(): Unit

    func clear(): Unit

    func isClosed(): Bool

    func getMutex(): Mutex

    func getCondition(): Condition

    func isRunning(): Bool

    func removeAll(): LinkedList<MessageDispatch>
}
