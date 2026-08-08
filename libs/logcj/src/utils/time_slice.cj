/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines TimeSlice class and setCachedTimeSlice function.
 */

package logcj.utils

public var timeSliceCache = TimeSlice()

/**
 * Sets the value of timeSliceCache.
 *
 * @param timeSlice time slice.
 */
public func setCachedTimeSlice(timeSlice: TimeSlice): Unit {
    timeSliceCache.lock.lock()
    timeSliceCache.lastUpdateSeconds = timeSlice.lastUpdateSeconds
    timeSliceCache.shortTime = timeSlice.shortTime
    timeSliceCache.shortDate = timeSlice.shortDate
    timeSliceCache.longTime = timeSlice.longTime
    timeSliceCache.longDate = timeSlice.longDate
    timeSliceCache.lock.unlock()
}

/**
 * Timestamp class, used to print timestamps of different specifications based on the pattern.
 */
public class TimeSlice {
    public var lastUpdateSeconds: Int64 = 0
    public var shortTime: String = ""
    public var shortDate: String = ""
    public var longTime: String = ""
    public var longDate: String = ""
    public var lock: ReentrantMutex = ReentrantMutex()

    /**
     * Get time slice.
     *
     * @param time time.
     */
    public func getTimeSlice(time: DateTime): Unit {
        var secs = time.toUnixTimeStamp().toNanoseconds() / Int64(1e9)
        var cached = timeSliceCache
        if (cached.lastUpdateSeconds != secs) {
            let year = time.year
            let month = time.monthValue
            let day = time.dayOfMonth
            let hour = time.hour
            let minute = time.minute
            let second = time.second
            let zone = time.zoneId

            this.lastUpdateSeconds = secs
            this.shortTime = hour.format("02") + ":" + minute.format("02")
            this.shortDate = day.format("02") + "/" + month.format("02") + "/" + (year % 100).format("02")
            this.longTime = hour.format("02") + ":" + minute.format("02") + ":" + second.format("02") + " " + zone
            this.longDate = year.format("04") + "/" + month.format("02") + "/" + day.format("02")
            setCachedTimeSlice(this)
        } else {
            this.lastUpdateSeconds = cached.lastUpdateSeconds
            this.shortTime = cached.shortTime
            this.shortDate = cached.shortDate
            this.longTime = cached.longTime
            this.longDate = cached.longDate
        }
    }

    public func getShortTime(): String {
        return this.shortTime
    }

    public func getLongTime(): String {
        return this.longTime
    }

    public func getShortDate(): String {
        return this.shortDate
    }

    public func getLongDate(): String {
        return this.longDate
    }
}
