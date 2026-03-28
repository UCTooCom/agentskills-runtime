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

internal class LengthPathNode <: DataPathNode {
    static let instance = LengthPathNode()
    private init() {}
    public func get(data: Data): Iterator<Data> {
        match (data) {
            case x: Collection<Data> => SingleIterator<Data>(x.size.toData())
            case x: Collection<(String, Data)> => SingleIterator<Data>(x.size.toData())
            case x: Collection<(Data, Data)> => SingleIterator<Data>(x.size.toData())
            case x: DataString => SingleIterator<Data>(x.data.size.toData())
            case _ => OptionIterator<Data>()
        }
    }
}
