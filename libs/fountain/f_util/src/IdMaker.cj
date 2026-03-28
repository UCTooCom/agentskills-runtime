/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_util

import std.time.DateTime
import std.sync.AtomicInt64
import f_config.*
import f_util.exception.IdException

public class IdMaker {
    public static const HOST_SERIAL = "idMakerHostSerial"

    private let startMillis: Int64 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    private let current: AtomicInt64
    public IdMaker(private let hostSerial!: Int64) {
        if (hostSerial > 1023 || hostSerial < 0) {
            throw IdException("host serial is too large, ${hostSerial} must be between 0 and 1023.")
        }
        current = AtomicInt64((hostSerial << (62 - 9)) | (startMillis << (62 - 41 - 9)))
    }
    public init() {
        this(hostSerial: getSerial())
    }
    private static func getSerial(): Int64 {
        Config.getValue<Int64>(HOST_SERIAL).getOrThrow()
    }
    public func nextInt64(): Int64 {
        current.fetchAdd(1)
    }
}
