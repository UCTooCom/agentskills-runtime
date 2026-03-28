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

public struct DataDateTime <: Data & Hashable & Comparable<DataDateTime> {
    public DataDateTime(public let data: DateTime) {}
    public func toString(): String {
        data.toString()
    }
    public static func tryParse(data: String): ?Data {
        try {
            parse(data)
        } catch (e: Exception) {
            None<Data>
        }
    }
    public static func parse(data: String): Data {
        DataDateTime(DateTime.parse(extractPureString(data)))
    }
    public func toDateTime(): DateTime {
        data
    }
    public func tryToDateTime(): ?DateTime {
        data
    }
    public func hashCode(): Int64 {
        data.hashCode()
    }
    public func compare(other: DataDateTime): Ordering {
        data.compare(other.data)
    }
}

let currentThreadDateFormat = ThreadLocal<String>()
let defaultDateFormat = AtomicReference<Box<String>>(Box<String>(""))

public interface ExtendDateTimeData {
    static func setDefaultDateFormat(format: String): Unit
    static func setCurrentThreadDateFormat(format: String): Unit
}

extend DateTime <: DataFields<DateTime> & ExtendDateTimeData {
    public func toData(): Data {
        DataDateTime(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataDateTime => x.tryToDateTime()
            case _: DataNone => None<DateTime>
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                '(${data}) does not match ${TypeInfo.of<DateTime>()}')
            case x: DataDuration => match (x.tryToDuration()) {
                case Some(x) => DateTime.UnixEpoch + x
                case _ => None<DateTime>
            }
            case x: DataString =>
                let fmt = currentThreadDateFormat.get() ?? defaultDateFormat.load().value
                try {
                    if (fmt.isEmpty()) {
                        DateTime.parse(x.data)
                    } else {
                        DateTime.parse(x.data, fmt)
                    }
                } catch (e: Exception) {
                    if ((flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0) {
                        throw e
                    } else {
                        None<DateTime>
                    }
                }
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                '(${data}) cannot be converted to ${TypeInfo.of<DateTime>()}')
            case _ => None<DateTime>
        }
    }
    public static func setDefaultDateFormat(format: String) {
        var box = None<Box<String>>
        while (true) {
            let fmt = defaultDateFormat.load()
            if (fmt.value == "") {
                let b = match (box) {
                    case Some(x) => x
                    case _ =>
                        let b = Box<String>(format)
                        box = b
                        b
                }
                if (defaultDateFormat.compareAndSwap(fmt, b)) {
                    return
                }
            } else {
                throw DataException("default date format has bean specified: ${fmt.value}")
            }
        }
    }
    public static func setCurrentThreadDateFormat(format: String) {
        currentThreadDateFormat.set(format)
    }
}
