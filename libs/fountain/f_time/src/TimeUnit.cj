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
package f_time

import std.convert.Parsable

public type TU = TimeUnit

public enum TimeUnit <: ToString & Parsable<TimeUnit> {
    | NANOSECOND
    | MICROSECOND
    | MILLISECOND
    | SECOND
    | MINUTE
    | HOUR
    | DAY
    | WEEK
    | MONTH
    | YEAR

    public static func parse(value: String): TimeUnit {
        tryParse(value).getOrThrow {IllegalArgumentException('${value} cannot be parsed to TimeUnit')}
    }
    public static func tryParse(value: String): Option<TimeUnit> {
        match (value.toAsciiUpper()) {
            case "NANOSECOND" => Some(NANOSECOND)
            case "MICROSECOND" => Some(MICROSECOND)
            case "MILLISECOND" => Some(MILLISECOND)
            case "SECOND" => Some(SECOND)
            case "MINUTE" => Some(MINUTE)
            case "HOUR" => Some(HOUR)
            case "DAY" => Some(DAY)
            case "WEEK" => Some(WEEK)
            case "MONTH" => Some(MONTH)
            case "YEAR" => Some(YEAR)
            case _ => None<TimeUnit>
        }
    }
    public prop current: DateTime {
        get() {
            trim(DateTime.now())
        }
    }
    /**
     * datetime在当前时间单位的未来duration个整点，duration可以是负数
     * 比如datetime是2023-10-11 12:31:32.568900，当前时间单位是minute，duration是1，返回值是2023-10-11 12:32:00.000000
     */
    public func next(datetime!: DateTime = DateTime.now(), duration!: Int64 = 1, toTrim!: Bool = true): DateTime {
        let d = if (toTrim) {
            trim(datetime)
        } else {
            datetime
        }
        match (this) {
            case NANOSECOND => d.addNanoseconds(duration)
            case MICROSECOND => d.addMicroseconds(duration)
            case MILLISECOND => d.addMilliseconds(duration)
            case SECOND => d.addSeconds(duration)
            case MINUTE => d.addMinutes(duration)
            case HOUR => d.addHours(duration)
            case DAY => d.addDays(duration)
            case WEEK => d.addWeeks(duration)
            case MONTH => d.addMonths(duration)
            case YEAR => d.addYears(duration)
        }
    }
    /**
     * datetime在当前时间单位的过去duration个整点，duration可以是负数
     * 比如datetime是2023-10-11 12:31:32.568900，当前时间单位是minute，duration是1，返回值是2023-10-11 12:31:00.000000
     */
    public func prev(datetime!: DateTime = DateTime.now(), duration!: Int64 = 1, toTrim!: Bool = true): DateTime {
        next(datetime: datetime, duration: -duration, toTrim: toTrim)
    }
    /**
     * datetime在当前时间单位距离未来duration个时间单位的时间长度，duration可以是负数
     * 比如datetime是2023-10-11 12:31:32.568900，当前时间单位是minute，返回值等于Duration.minute
     */
    public func since(datetime!: DateTime = DateTime.now(), duration!: Int64 = 1): Duration {
        next(datetime: datetime, duration: duration) - datetime
    }
    public func trim(t: DateTime): DateTime {
        match (this) {
            case NANOSECOND => t
            case MICROSECOND =>
                let year = t.year
                let month = t.month
                let day = t.dayOfMonth
                let hour = t.hour
                let min = t.minute
                let sec = t.second
                let nano = (t.nanosecond / 1000) * 1000
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case MILLISECOND =>
                let year = t.year
                let month = t.month
                let day = t.dayOfMonth
                let hour = t.hour
                let min = t.minute
                let sec = t.second
                let nano = (t.nanosecond / 1000000) * 1000000
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case SECOND =>
                let year = t.year
                let month = t.month
                let day = t.dayOfMonth
                let hour = t.hour
                let min = t.minute
                let sec = t.second
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case MINUTE =>
                let year = t.year
                let month = t.month
                let day = t.dayOfMonth
                let hour = t.hour
                let min = t.minute
                let sec = 0
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case HOUR =>
                let year = t.year
                let month = t.month
                let day = t.dayOfMonth
                let hour = t.hour
                let min = 0
                let sec = 0
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case DAY =>
                let year = t.year
                let month = t.month
                let day = t.dayOfMonth
                let hour = 0
                let min = 0
                let sec = 0
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case MONTH =>
                let year = t.year
                let month = t.month
                let day = 1
                let hour = 0
                let min = 0
                let sec = 0
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case YEAR =>
                let year = t.year
                let month = Month.January
                let day = 1
                let hour = 0
                let min = 0
                let sec = 0
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
            case WEEK =>
                let weekday = t.dayOfWeek.toInteger()
                let date = t.addDays(-weekday)
                let year = date.year
                let month = date.month
                let day = date.dayOfMonth
                let hour = 0
                let min = 0
                let sec = 0
                let nano = 0
                DateTime.of(year: year, month: month, dayOfMonth: day, hour: hour, minute: min, second: sec,
                    nanosecond: nano)
        }
    }
    public func ago(duration: Int64): DateTime {
        before(DateTime.now(), duration)
    }
    public func before(t: DateTime, duration: Int64) {
        after(t, -duration)
    }
    public func later(duration: Int64): DateTime {
        after(DateTime.now(), duration)
    }
    public func after(t: DateTime, duration: Int64): DateTime {
        match (this) {
            case YEAR => t.addYears(duration)
            case MONTH => t.addMonths(duration)
            case DAY => t.addDays(duration)
            case WEEK => t.addWeeks(duration)
            case HOUR => t.addHours(duration)
            case MINUTE => t.addMinutes(duration)
            case SECOND => t.addSeconds(duration)
            case MILLISECOND => t.addMilliseconds(duration)
            case MICROSECOND => t.addMicroseconds(duration)
            case NANOSECOND => t.addNanoseconds(duration)
        }
    }

    public func duration(n: Int64): Option<Duration> {
        match (this) {
            case NANOSECOND => n * Duration.nanosecond
            case MICROSECOND => n * Duration.microsecond
            case MILLISECOND => n * Duration.millisecond
            case SECOND => n * Duration.second
            case MINUTE => n * Duration.minute
            case HOUR => n * Duration.hour
            case DAY => n * Duration.day
            case _ => None<Duration>
        }
    }

    public func name(): String {
        toString()
    }
    public func toString(): String {
        match (this) {
            case NANOSECOND => "NANOSECOND"
            case MICROSECOND => "MICROSECOND"
            case MILLISECOND => "MILLISECOND"
            case SECOND => "SECOND"
            case MINUTE => "MINUTE"
            case HOUR => "HOUR"
            case DAY => "DAY"
            case WEEK => "WEEK"
            case MONTH => "MONTH"
            case YEAR => "YEAR"
        }
    }
}
