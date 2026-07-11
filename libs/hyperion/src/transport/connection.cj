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

package hyperion.transport

/**
 * 连接支持的操作
 * 
 * @author yangfuping
 */
public interface Connection <: Resource & Expirable & Equatable<Connection> & Hashable & ToString {
    func addListener(listener: ConnectionLister): Unit

    func isAsyncWrite(): Bool

    func write(buffer: Array<Byte>): Unit

    func write(buffer: Array<Byte>, startPos: Int64, length: Int64): Unit

    func write(buffer: Array<Byte>, promise: WriteBeforePromise): Unit

    func write(buffer: Array<Byte>, startPos: Int64, length: Int64, promise: WriteBeforePromise): Unit

    func gatheringWrite(gatheredBuffers: Array<Array<Byte>>): Unit

    func gatheringWrite(gatheredBuffers: Array<Array<Byte>>, promise: WriteBeforePromise): Unit

    func read(buffer: Array<Byte>): Int64

    func read(buffer: Array<Byte>, startPos: Int64, length: Int64): Int64

    func readFully(buffer: Array<Byte>): Int64

    func readFully(buffer: Array<Byte>, startPos: Int64, length: Int64): Int64

    func write(buffer: ByteBuffer): Unit

    func write(buffer: ByteBuffer, promise: WriteBeforePromise): Unit

    func gatheringWrite(gatheredBuffers: Array<ByteBuffer>): Unit

    func gatheringWrite(gatheredBuffers: Array<ByteBuffer>, promise: WriteBeforePromise): Unit

    func read(buffer: ByteBuffer): Int64

    func readFully(buffer: ByteBuffer): Int64

    func getReadCompletionHandler(): ?ReadCompletionHandler

    func addReadCompletionListener(completionListener: ReadCompletionListener): Unit

    func removeReadCompletionHandler(): Unit

    func flush(): Unit

    func markInvalid(): Unit

    func isInvalid(): Bool

    func config(options: TcpSocketOptions): Unit

    func setTimeoutInfinite(): Unit

    func rollbackTimeout(): Unit

    func isClosed(): Bool

    func close(): Unit

    func close(markInvalid!: Bool): Unit

    func simpleName(): String
}

/**
 * 连接上的监听器
 *
 * @author yangfuping
 */
public interface ConnectionLister {
    func onClose(): Unit
}
