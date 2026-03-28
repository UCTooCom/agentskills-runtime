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

public struct DataUnit <: Data & Hashable & Equatable<DataUnit> {
    public static let UNIT = DataUnit()
    private init() {}
    public func toString(): String {
        '()'
    }
    public static func tryParse(data: String): ?Data {
        if (data == "()") {
            DataUnit.UNIT
        } else {
            None<Data>
        }
    }
    public static func parse(data: String): Data {
        tryParse(data).getOrThrow {
            DataException("DataBool.parse receives string 'true' 'false' or their upper cases, but current is ${data}")
        }
    }
    public func toUnit(): Unit {
        ()
    }
    public func tryToUnit(): ?Unit {
        ()
    }
    public func hashCode(): Int64 {
        ().hashCode()
    }
    public operator func ==(other: DataUnit): Bool {
        true
    }
}

extend Unit <: DataFields<Unit> {
    public func toData(): Data {
        DataUnit.UNIT
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataUnit => x.tryToUnit()
            case _: DataNone => None<Unit>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Unit>()}')
            case x: DataString => DataUnit.tryParse(x.toString())
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted to ${TypeInfo.of<Unit>()}')
            case _ => None<Unit>
        }
    }
}
