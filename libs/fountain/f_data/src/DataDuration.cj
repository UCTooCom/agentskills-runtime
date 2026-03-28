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

public struct DataDuration <: Data & Hashable & Comparable<DataDuration> {
    public DataDuration(public let data: Duration) {}
    public func toString(): String {
        data.toString()
    }
    public static func tryParse(data: String): ?Data {
        match (Duration.tryParse(extractPureString(data).toAsciiLower())) {
            case Some(x) => DataDuration(x)
            case _ => None<Data>
        }
    }
    public static func parse(data: String): Data {
        tryParse(data).getOrThrow {
            DataException(
                "DataDuration.parse receives string as mdnhimjskns, or there upper cases, m n i j k are integers, but current is ${data}")
        }
    }
    public func toDuration(): Duration {
        data
    }
    public func tryToDuration(): ?Duration {
        data
    }
    public func hashCode(): Int64 {
        data.hashCode()
    }
    public func compare(other: DataDuration): Ordering {
        data.compare(other.data)
    }
}

extend Duration <: DataFields<Duration> {
    public func toData(): Data {
        DataDuration(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataDuration => x.tryToDuration()
            case _: DataNone => None<Duration>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match to ${TypeInfo.of<Duration>()}')
            case x: DataDateTime => match (x.tryToDateTime()) {
                case Some(x) => x - DateTime.UnixEpoch
                case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                    '(${data}) does not match to ${TypeInfo.of<Duration>()}')
                case _ => return None<Duration>
            }
            case x: DataString => Duration.tryParse(x.data)
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted to ${TypeInfo.of<Duration>()}')
            case _ => None<Duration>
        }
    }
}
