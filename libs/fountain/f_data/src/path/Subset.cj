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

internal abstract class Subset<T> where T <: ToString & DataFields<T> {
    protected let left: DataPath
    private let right = HashSet<String>()
    init(left: DataPath, right: ArrayList<T>) {
        for (v in right) {
            this.right.add(v.toData().toString())
        }
        this.left = left
    }
    func subset(data: Data): Int64 {
        var subsetSize = 0
        let d = match (left.get(data).next()) {
            case Some(x) => x
            case _ => return subsetSize
        }
        match (d) {
            case x: Iterable<Data> => for (v in x where right.contains(v.toString())) {
                subsetSize++
            }
            case x: Iterable<(String, Data)> => for ((k, v) in x where right.contains(k)) {
                subsetSize++
            }
            case x: Iterable<(Data, Data)> => for ((k, _) in x where right.contains(k.toString())) {
                subsetSize++
            }
            case _ => ()
        }
        subsetSize
    }
}
