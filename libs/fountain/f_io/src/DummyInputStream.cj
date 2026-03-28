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
package f_io

public class DummyInputStream <: InputStream & Resource {
    public static const THROW_ON_ACCESSING = DummyInputStream(true)
    public static const SILENCE = DummyInputStream(false)
    private const DummyInputStream(private let throwing: Bool) {}

    public func isClosed(): Bool {
        false
    }
    public func close(): Unit {}

    public func read(buffer: Array<Byte>): Int64 {
        if (throwing) {
            throw Exception("DummyInputStream is not readable")
        } else {
            0
        }
    }
}
