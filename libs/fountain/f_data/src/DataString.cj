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

public struct DataString <: Data & Hashable & Comparable<DataString> {
    public DataString(public let data: String) {}
    public init(data: ToString) {
        this(data.toString())
    }
    private init() {
        this("")
    }
    public func toString(): String {
        data
    }
    public static func tryParse(data: String): ?Data {
        parse(data)
    }
    public static func parse(data: String): Data {
        DataString(data)
    }
    public func hashCode(): Int64 {
        data.hashCode()
    }
    public func compare(other: DataString): Ordering {
        data.compare(other.data)
    }
}

extend String <: DataFields<String> {
    public func toData(): Data {
        DataString(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataString => x.data
            case x: DataNone => None<String>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match to ${TypeInfo.of<String>()}')
            case x => x.toString()
        }
    }
}
