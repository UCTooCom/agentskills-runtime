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
package f_http

public func rfc1123(t: DateTime) {
    //Wed, 16 Nov 2022 14:57:48 +0800
    let offset = t.zoneOffset.toSeconds() / 3600
    let zoneId = if (offset == 0) {
        t.zoneId
    } else if (offset > 0) {
        if (offset < 10) {
            "+0${offset}00"
        } else {
            "+${offset}00"
        }
    } else if (offset > -10) {
        "-0${-offset}00"
    } else {
        "${offset}00"
    }
    "${t.dayOfWeek.toString()[0..3]}, ${t.dayOfMonth} ${t.month.toString()[0..3]} ${t.year} ${t.hour}:${t.minute}:${t.second} ${zoneId}"
}

public func parseRfc1123(date: String): DateTime {
    let zoneIdx = date.lastIndexOf(" ").getOrThrow()
    let zoneId = date[zoneIdx + 1..zoneIdx + 3]
    let zone = if (zoneId == "GMT") {
        TimeZone(zoneId, Duration.Zero)
    } else if (zoneId.startsWith("+")) {
        TimeZone("", Duration.hour * (Int64.parse(zoneId[1..])))
    } else {
        TimeZone("", Duration.hour * (Int64.parse(zoneId)))
    }
    var start = 5
    var end = date.indexOf(" ", start).getOrThrow()
    let day = Int64.parse(date[start..end].trimAscii())
    start = end + 1
    end = date.indexOf(" ", start).getOrThrow()
    let month = match (date[start..end].trimAscii()) {
        case "Jan" => Month.January
        case "Feb" => Month.February
        case "Mar" => Month.March
        case "Apr" => Month.April
        case "May" => Month.May
        case "Jun" => Month.June
        case "Jul" => Month.July
        case "Aug" => Month.August
        case "Sep" => Month.September
        case "Oct" => Month.October
        case "Nov" => Month.November
        case "Dec" => Month.December
        case _ => throw UnreachableException()
    }
    start = end + 1
    end = date.indexOf(" ", start).getOrThrow()
    let year = Int64.parse(date[start..end])
    start = end + 1
    end = date.indexOf(":", start).getOrThrow()
    let hour = Int64.parse(date[start..end])
    start = end + 1
    end = date.indexOf(":", start).getOrThrow()
    let minute = Int64.parse(date[start..end])
    start = end + 1
    end = date.indexOf(" ", start).getOrThrow()
    let second = Int64.parse(date[start..end])

    //Wed, 16 Nov 2022 14:57:48 +0800
    //0123456789012345678901234567890
    DateTime.of(
        year: year,
        month: month,
        dayOfMonth: day,
        hour: hour,
        minute: minute,
        second: second,
        timeZone: zone
    )
}
