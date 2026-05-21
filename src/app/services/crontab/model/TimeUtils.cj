package magic.app.services.crontab.model

import std.time.DateTime

public func dateTimeToEpochMs(dt: DateTime): Int64 {
    (dt - DateTime.UnixEpoch).toMilliseconds()
}

public func durationMsBetween(start: DateTime, end: DateTime): Int64 {
    dateTimeToEpochMs(end) - dateTimeToEpochMs(start)
}
