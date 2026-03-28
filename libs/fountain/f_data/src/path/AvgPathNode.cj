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
package f_data.path

internal class AvgPathNode <: DataPathNode {
    static let instance = AvgPathNode()
    private init() {}
    public func get(data: Data): Iterator<Data> {
        match (data) {
            case x: Iterable<Data> =>
                var r = Decimal.zero
                var c = 0
                for (v in x) {
                    match (v) {
                        case x: DataReal =>
                            c++
                            r += x.data
                        case _ => return OptionIterator<Data>()
                    }
                }
                OptionIterator<Data>((r / Decimal(BigInt(c))).toData())
            case _ => OptionIterator<Data>()
        }
    }
}
