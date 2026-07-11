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
package activemq4cj.client.util

import std.posix.*

public class IdGenerator {
    @When[os != "Windows"]
    private static let hostName = gethostname()

    @When[os == "Windows"]
    private static let hostName = "${Random().nextUInt16()}"
    private static var instanceCount: AtomicInt32 = AtomicInt32(0)
    private static let UNIQUE_STUB: String
    private var seed: String
    private let sequence: AtomicInt64 = AtomicInt64(1)

    static init() {
        UNIQUE_STUB = "${hostName}-${Random().nextUInt16()}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
    }

    public init(prefix: String) {
        this.seed = "${prefix}${UNIQUE_STUB}-${instanceCount.fetchAdd(1)}"
    }

    public init() {
        this("ID:")
    }

    public func generateId(): String {
        return "${seed}:${sequence.fetchAdd(1)}"
    }

    public static func getSeedFromId(id: String): String {
        var result = id
        var index = id.lastIndexOf(':')
        if (let Some(index) <- index) {
            if (index + 1 < id.size) {
                result = id[0..index]
            }
        }
        return result
    }

    public static func getSequenceFromId(id: String): Int64 {
        var result = -1
        var index = id.lastIndexOf(':')
        if (let Some(index) <- index) {
            if (index + 1 < id.size) {
                result = Int64.parse(id[index + 1..id.size])
            }
        }
        return result
    }
}
