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
package f_ticktock

import std.collection.ArrayList
import f_time.ExtendDateTime

abstract sealed class TicktockUnit <: Currently & ToString & Hashable & Equatable<TicktockUnit> {
    public static let SECONDLY = SecondlyTicktockUnit(0, false, 0..=59, 59..=59)
    public static let MINUTELY = MinutelyTicktockUnit(1, false, 0..=59, 59..=59)
    public static let HOURLY = HourlyTicktockUnit(2, false, 0..=23, 23..=23)
    public static let MONTH_DAILY = MonthDailyTicktockUnit(3, true, 1..=31, 28..=31)
    public static let MONTHLY = MonthlyTicktockUnit(4, true, 1..=12, 12..=12)
    public static let WEEK_DAILY = WeekDailyTicktockUnit(5, true, 1..=7, 7..=7)
    public static let YEARLY = YearlyTicktockUnit(6, false, DateTime.now().year..=Int64.Max, Int64.Max..=Int64.Max)

    private let value_: Int64
    private let oneStart: Bool
    private let range_: Range<Int64>
    private let lastRange_: Range<Int64>

    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }

    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        this.value_ = value
        this.oneStart = oneStart

        @OverflowSaturating
        func newRange(range: Range<Int64>) {
            range.start + rangeBase..=range.end + rangeBase
        }
        this.range_ = newRange(range)
        this.lastRange_ = newRange(lastRange)
    }
    public static prop values: Array<TicktockUnit> {
        get() {
            [SECONDLY, MINUTELY, HOURLY, MONTH_DAILY, MONTHLY, WEEK_DAILY, YEARLY]
        }
    }
    public static func valueOf(value: Int64): TicktockUnit {
        values[value]
    }
    public prop name: String {
        get() {
            match (value) {
                case 0 => "SECONDLY"
                case 1 => "MINUTELY"
                case 2 => "HOURLY"
                case 3 => "MONTH_DAILY"
                case 4 => "MONTHLY"
                case 5 => "WEEK_DAILY"
                case 6 => "YEARLY"
                case _ => throw IllegalArgumentException("UNREACHABLE!!! the value is ${value}")
            }
        }
    }
    public func toString(): String {
        name
    }
    public func hashCode(): Int64 {
        value
    }
    public operator func ==(unit: TicktockUnit) {
        refEq(this, unit) || this.value == unit.value
    }
    public operator func !=(unit: TicktockUnit) {
        !(this == unit)
    }

    protected prop range: Range<Int64> {
        get() {
            return range_
        }
    }

    public prop min: Int64 {
        get() {
            return range.start
        }
    }
    public prop max: Int64 {
        get() {
            return range.end
        }
    }

    public prop lastRange: Range<Int64> {
        get() {
            return lastRange_
        }
    }

    public open func convert(task: TicktockTask, last: Bool): TicktockTask {
        return task
    }

    public open func last(now: DateTime): Bool {
        return current(now) == lastRange.end
    }

    public prop value: Int64 {
        get() {
            return value_
        }
    }

    public open func convertRange(start: Int64, end: Int64): Array<Range<Int64>> {
        let begin = if (oneStart && start == 0) {
            1
        } else {
            start
        }
        let range = this.range
        if (end == 0) {
            throw IllegalArgumentException("${begin}-${end}, end must be greater than zero")
        } else if (begin > range.end) {
            throw IllegalArgumentException(
                "${begin}-${end}, start must be less than or equals to the max value in range of ${name}, max value: ${range.end}")
        } else if (end > range.end) {
            throw IllegalArgumentException(
                "${begin}-${end}, end must be less than or equals to the max value in range of ${name} , max value: ${range.end}")
        } else if (begin > end) {
            throw IllegalArgumentException("start must be less than end, start:${begin}, end:${end}")
        } else if (begin < range.start) {
            throw IllegalArgumentException(
                "start must be greater than or equals to min value of ${name} range, between ${range.start} and ${range.end}, start: ${begin}")
        } else if (end < range.start) {
            throw IllegalArgumentException(
                "end must be greater than or equals to min value of ${name} range, between ${range.start} and ${range.end}, end: ${end}")
        }
        return [begin..=end]
    }
    public func convertRange(exprPart: ArrayList<Int64>): Array<Range<Int64>> {
        let size = exprPart.size
        if (size > 2 || size < 1) {
            throw IllegalArgumentException(
                "value count of cron expression part must be one or two two!!! current TicktockUnit is ${name}")
        }
        var first: Int64
        var second: Int64
        if (size == 2) {
            first = exprPart[0]
            second = exprPart[1]
            if (first > second) {
                throw IllegalArgumentException(
                    "first value must be less than the second one, which in the same part of cron expression!!! current TicktockUnit is ${name}")
            }
        } else {
            second = exprPart[0]
            first = second
        }
        var result = convertRange(first, second)
        var range = this.range
        for (r in result where !(range.start <= r.start && r.start <= range.end && range.start <= r.end && r.end <= range
            .end)) {
            throw IllegalArgumentException(
                "at least one of the two values in same part of cron expression overflow!!! current TicktockUnit is ${name}, min: ${range.start}, max: ${range.end}")
        }
        result
    }

    public open func convertDuration(start: Int64, end: Int64, duration: Int64): Array<Range<Int64>> {
        let range = this.range
        if (end == 0) {
            throw IllegalArgumentException("${start}-${end}, end must be greater than zero")
        } else if (start > range.end) {
            throw IllegalArgumentException(
                "${start}/${duration}-${end}, start must be less than or equals to the toplimit in range of ${name}, toplimit: ${range.end}")
        } else if (end > range.end) {
            throw IllegalArgumentException(
                "${start}/${duration}-${end}, end must be less than or equals to the toplimit in range of ${name}, toplimit: ${range.end}")
        } else if (duration == 0) {
            throw IllegalArgumentException("duration must be great than zero, duration: ${duration}")
        } else if (start > end) {
            throw IllegalArgumentException(
                "start must be less than end, start:${start}, end:${end}, duration:${duration}")
        } else if (start < range.start) {
            throw IllegalArgumentException(
                "start must be greater than or equals to min value of ${name} range, between ${range.start} and ${range.end}, start: ${start}")
        } else if (end < range.start) {
            throw IllegalArgumentException(
                "end must be greater than or equals to min value of ${name} range, between ${range.start} and ${range.end}, end: ${end}")
        }
        if (oneStart && start == 0) {
            return [duration..=end : duration]
        }
        return [start..=end : duration]
    }
    public open func convertSingle(value: Int64) {
        let range = this.range
        if (value >= range.start && value <= range.end) {
            return value
        }
        throw IllegalArgumentException("value of ${name} must be between ${range.start} and ${range.end}")
    }
    public func wheelSize() {
        return range.end + 1
    }
}

public class SecondlyTicktockUnit <: TicktockUnit {
    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }

    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        super(value, oneStart, rangeBase, range, lastRange)
    }

    public func current(now: DateTime): Int64 {
        return now.second
    }
}

public class MinutelyTicktockUnit <: TicktockUnit {
    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }

    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        super(value, oneStart, rangeBase, range, lastRange)
    }

    public func current(now: DateTime): Int64 {
        return now.minute
    }
}

public class HourlyTicktockUnit <: TicktockUnit {
    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }

    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        super(value, oneStart, rangeBase, range, lastRange)
    }

    public func current(now: DateTime): Int64 {
        return now.hour
    }
}

public class MonthDailyTicktockUnit <: TicktockUnit {
    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }

    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        super(value, oneStart, rangeBase, range, lastRange)
    }

    public func current(now: DateTime): Int64 {
        return now.dayOfMonth
    }
    public func last(now: DateTime): Bool {
        now.isLastMonthDay
    }
}

public class MonthlyTicktockUnit <: TicktockUnit {
    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }
    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        super(value, oneStart, rangeBase, range, lastRange)
    }

    public func current(now: DateTime): Int64 {
        return now.month.toInteger()
    }
}

public class WeekDailyTicktockUnit <: TicktockUnit {
    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }
    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        super(value, oneStart, rangeBase, range, lastRange)
    }

    public func current(now: DateTime): Int64 {
        match (now.dayOfWeek.toInteger()) {
            case 0 => 7
            case x => x
        }
    }

    public override func convertRange(start: Int64, end: Int64): Array<Range<Int64>> {
        if (start == 0) {
            if (end == 0) {
                return [7..=7]
            } else if (end == 7 || end == 6) {
                return [1..=7]
            } else {
                return [1..=end, 7..=7]
            }
        }
        return super.convertRange(start, end)
    }

    public override func convertDuration(start: Int64, end: Int64, duration: Int64): Array<Range<Int64>> {
        if (start == 0) {
            return [super.convertDuration(duration, end, duration)[0], 7..=7]
        } else {
            return super.convertDuration(start, end, duration)
        }
    }

    public override func convertSingle(value: Int64): Int64 {
        if (value == 0) {
            return 7
        }
        return super.convertSingle(value)
    }
}

public class YearlyTicktockUnit <: TicktockUnit {
    init(value: Int64, oneStart: Bool, range: Range<Int64>, lastRange: Range<Int64>) {
        this(value, oneStart, 0, range, lastRange)
    }
    init(value: Int64, oneStart: Bool, rangeBase: Int64, range: Range<Int64>, lastRange: Range<Int64>) {
        super(value, oneStart, rangeBase, range, lastRange)
    }

    public override func convert(task: TicktockTask, last: Bool): TicktockTask {
        if (last) {
            throw IllegalArgumentException(
                "L tag for YEARLY unit in cron expression is forbidden, task is named as ${task.name}")
        }
        return task
    }
    public func current(now: DateTime): Int64 {
        return now.year
    }
}
