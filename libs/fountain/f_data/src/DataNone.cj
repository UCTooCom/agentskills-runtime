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
package f_data

public struct DataNone <: Data {
    public static let INSTANCE = DataNone()
    private init() {}
    public func toString(): String {
        "None"
    }
    public static func tryParse(data: String): ?Data {
        let d = extractPureString(data)
        if (d.size != 4) {
            return None<Data>
        }
        match (d.toAsciiLower()) {
            case "null" | "none" => INSTANCE
            case _ => None<Data>
        }
    }
    public static func parse(data: String): Data {
        tryParse(data).getOrThrow {
            DataException("DataNone.parse receives string 'null' 'none' or there upper cases, but current is ${data}")
        }
    }
}
