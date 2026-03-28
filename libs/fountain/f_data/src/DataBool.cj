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

import std.convert.Parsable

public struct DataBool <: Data & Hashable & Equatable<DataBool> {
    public static let TRUE = DataBool(true)
    public static let FALSE = DataBool(false)
    private DataBool(public let data: Bool) {}
    public func toString(): String {
        data.toString()
    }
    public static func tryParse(data: String): ?Data {
        match (Bool.tryParse(extractPureString(data).toAsciiLower())) {
            case Some(x) => DataBool(x)
            case _ => None<Data>
        }
    }
    public static func parse(data: String): Data {
        tryParse(data).getOrThrow {
            DataException("DataBool.parse receives string 'true' 'false' or their upper cases, but current is ${data}")
        }
    }
    public func toBool(): Bool {
        data
    }
    public func tryToBool(): ?Bool {
        data
    }
    public func hashCode(): Int64 {
        data.hashCode()
    }
    public operator func ==(other: DataBool): Bool {
        data == other.data
    }
}

extend Bool <: DataFields<Bool> {
    public func toData(): Data {
        if (this) {
            DataBool.TRUE
        } else {
            DataBool.FALSE
        }
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataBool => x.tryToBool()
            case _: DataNone => None<Bool>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<Bool>()}')
            case x: DataString =>
                let s = x.toString().toAsciiLower()
                if (s == "true" || s == "false") {
                    Bool.tryParse(s)
                } else {
                    None<Bool>
                }
            case x: DataReal => x.toDecimal() != Decimal.zero
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted to ${TypeInfo.of<Bool>()}')
            case _ => None<Bool>
        }
    }
}
