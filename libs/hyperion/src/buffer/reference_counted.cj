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

package hyperion.buffer

/**
 * ByteBuffer的引用计数，用于池化处理。
 *
 * @author yangfuping
 */
public class ReferenceCounted {

    /**
     * 持有的引用数量
     */
    private let refCount = AtomicInt64(0)

    private var delegateBuffer: ?ByteBuffer = None<ByteBuffer>

    public func getRefCount(): Int64 {
        return refCount.load()
    }

    public func retainRef(): ReferenceCounted {
        let count = refCount.fetchAdd(1)
        return this
    }

    public func releaseRef(): Bool {
        let count = refCount.fetchSub(1)
        return (count - 1) == 0
    }

    public func setDelegateBuffer(delegateBuffer: ByteBuffer) {
        this.delegateBuffer = delegateBuffer
    }

    public func getDelegateBuffer(): ?ByteBuffer {
        return this.delegateBuffer
    }
}
