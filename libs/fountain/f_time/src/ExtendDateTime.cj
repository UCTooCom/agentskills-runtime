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

public import std.time.*

public interface ExtendDateTime {
    static prop currentDuration: Duration
    static prop yesterday: DateTime
    static prop today: DateTime
    static prop tomorrow: DateTime
    func addMilliseconds(millis: Int64): DateTime
    func addMicroseconds(micros: Int64): DateTime

    func setYear(year: Int64): DateTime
    func setMonth(month: Int64): DateTime
    func setMonth(month: Month): DateTime
    func setDay(day: Int64): DateTime
    func setHour(hour: Int64): DateTime
    func setMinute(minute: Int64): DateTime
    func setSecond(second: Int64): DateTime
    func setMillisecond(millis: Int64): DateTime
    func setMicrosecond(micros: Int64): DateTime
    func setNanosecond(nanos: Int64): DateTime
    prop isLeapYear: Bool
    prop isLastMonthDay: Bool
    func toUnixEpochSeconds(): Int64
    func toUnixEpochMillis(): Int64
    func toUnixEpochMicros(): Int64
    func toUnixEpochNanos(): Int64
}

extend DateTime <: ExtendDateTime {
    public static prop currentDuration: Duration {
        get() {
            now().toUnixTimeStamp()
        }
    }
    public static prop today: DateTime {
        get() {
            let now = DateTime.now()
            DateTime.of(year: now.year, month: now.month, dayOfMonth: now.dayOfMonth)
        }
    }
    public static prop yesterday: DateTime {
        get() {
            today - Duration.day
        }
    }
    public static prop tomorrow: DateTime {
        get() {
            today + Duration.day
        }
    }
    public func addMilliseconds(millis: Int64): DateTime {
        this + millis * Duration.millisecond
    }
    public func addMicroseconds(micros: Int64): DateTime {
        this + micros * Duration.microsecond
    }
    public func setYear(year: Int64): DateTime {
        DateTime.of(
            year: year,
            month: this.month,
            dayOfMonth: this.dayOfMonth,
            hour: this.hour,
            minute: this.minute,
            second: this.second,
            nanosecond: this.nanosecond
        )
    }
    public func setMonth(month: Int64): DateTime {
        setMonth(Month.of(month))
    }
    public func setMonth(month: Month): DateTime {
        DateTime.of(
            year: this.year,
            month: month,
            dayOfMonth: this.dayOfMonth,
            hour: this.hour,
            minute: this.minute,
            second: this.second,
            nanosecond: this.nanosecond
        )
    }
    public func setDay(day: Int64): DateTime {
        DateTime.of(
            year: this.year,
            month: this.month,
            dayOfMonth: day,
            hour: this.hour,
            minute: this.minute,
            second: this.second,
            nanosecond: this.nanosecond
        )
    }
    public func setHour(hour: Int64): DateTime {
        DateTime.of(
            year: this.year,
            month: this.month,
            dayOfMonth: this.dayOfMonth,
            hour: hour,
            minute: this.minute,
            second: this.second,
            nanosecond: this.nanosecond
        )
    }
    public func setMinute(minute: Int64): DateTime {
        DateTime.of(
            year: this.year,
            month: this.month,
            dayOfMonth: this.dayOfMonth,
            hour: this.hour,
            minute: minute,
            second: this.second,
            nanosecond: this.nanosecond
        )
    }
    public func setSecond(second: Int64): DateTime {
        DateTime.of(
            year: this.year,
            month: this.month,
            dayOfMonth: this.dayOfMonth,
            hour: this.hour,
            minute: this.minute,
            second: second,
            nanosecond: this.nanosecond
        )
    }
    public func setMillisecond(millis: Int64): DateTime {
        DateTime.of(
            year: this.year,
            month: this.month,
            dayOfMonth: this.dayOfMonth,
            hour: this.hour,
            minute: this.minute,
            second: this.second,
            nanosecond: millis * 1000_000
        )
    }
    public func setMicrosecond(micros: Int64): DateTime {
        DateTime.of(
            year: this.year,
            month: this.month,
            dayOfMonth: this.dayOfMonth,
            hour: this.hour,
            minute: this.minute,
            second: this.second,
            nanosecond: micros * 1000
        )
    }
    public func setNanosecond(nanos: Int64): DateTime {
        DateTime.of(
            year: this.year,
            month: this.month,
            dayOfMonth: this.dayOfMonth,
            hour: this.hour,
            minute: this.minute,
            second: this.second,
            nanosecond: nanos
        )
    }
    public prop isLeapYear: Bool {
        get() {
            let y = this.year
            ((y & 3) == 0 && (y % 100) != 0) || y % 400 == 0
        }
    }
    public prop isLastMonthDay: Bool {
        get() {
            match (this.month) {
                case January | March | May | July | August | October | December => this.dayOfMonth == 31
                case April | June | September | November => this.dayOfMonth == 30
                case February => (isLeapYear && this.dayOfMonth == 29) || this.dayOfMonth == 28
            }
        }
    }
    public func toUnixEpochSeconds(): Int64 {
        toUnixTimeStamp().toSeconds()
    }
    public func toUnixEpochMillis(): Int64 {
        toUnixTimeStamp().toMilliseconds()
    }
    public func toUnixEpochMicros(): Int64 {
        toUnixTimeStamp().toMicroseconds()
    }
    public func toUnixEpochNanos(): Int64 {
        toUnixTimeStamp().toNanoseconds()
    }
}
