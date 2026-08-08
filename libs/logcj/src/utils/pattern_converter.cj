/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines PatternConverter interface and DefaultPatternConverter class.
 */

package logcj.utils

public interface PatternConverter {
    func formatLogRecord(pattern: String, logRecord: LogRecord): String
}

let defaultPatternConverter = DefaultPatternConverter()

public func getDefaultPatternConvert(): PatternConverter {
    return defaultPatternConverter
}

/**
 * Model class for formatting log recording.
 */
public class DefaultPatternConverter <: PatternConverter {
    // FormatLogRecord
    // Known format codes:
    // %T - Time (15:04:05 MST)
    // %t - Time (15:04)
    // %D - Date (2006/01/02)
    // %d - Date (01/02/06)
    // %o - UnixMilli (1649224315937)
    // %m - Millisecond (607)
    // %n - Nanosecond (794411287)
    // %L - Level (ALL, TRACE, DEBUG, INFO, WARN, ERROR, OFF)
    // %l - Label (TagName)
    // %S - Source
    // %M - Message
    // %I - ThreadID
    // Ignores unknown formats
    // Recommended: "[%D %T] [%L] (%S) %M"
    
    /**
     * Formatting log recording.
     *
     * @param pattern output pattern.
     * @param logRecord log record.
     * @return format result.
     */
    public func formatLogRecord(pattern: String, logRecord: LogRecord): String {
        var result = StringBuilder()
        if (pattern.size == 0) {
            return String.empty
        }
        let timeSlice = TimeSlice()
        timeSlice.getTimeSlice(logRecord.getCreatedTime())

        // Split the string into pieces by % signs.
        let pieces = pattern.split("%")
        var i: Int64 = 0
        while (pieces.size != 0 && i < pieces.size) {
            var piece: String = pieces.get(i).getOrThrow()
            if (piece != pieces[0] && piece.size > 0) {
                match (piece[0]) {
                    case b'T' => result.append(timeSlice.getLongTime())
                    case b'o' =>
                        result.append((logRecord.getCreatedTime().toUnixTimeStamp().toNanoseconds() / Int64(1e6)).toString()
                        )
                    case b'n' => result.append(flushLeft(logRecord.getCreatedTime().nanosecond.toString(), 9, "0"))
                    case b'm' =>
                        result.append(
                            flushLeft(
                                (logRecord.getCreatedTime().nanosecond / Int64(1e6)).toString(),
                                3,
                                "0"
                            )
                        )
                    case b't' => result.append(timeSlice.getShortTime())
                    case b'D' => result.append(timeSlice.getLongDate())
                    case b'd' => result.append(timeSlice.getShortDate())
                    case b'l' => result.append(logRecord.getTagName())
                    case b'L' => result.append(logRecord.getLevel().levelName())
                    case b'S' => result.append(logRecord.getSource())
                    case b's' =>
                        var slice: Array<String> = logRecord.getSource().split("/")
                        if (slice.size == 0) {
                            result.append(String.empty)
                        } else {
                            result.append(slice[slice.size - 1])
                        }
                    case b'M' => result.append(logRecord.getMessage())
                    case b'I' => result.append(logRecord.getThreadId())
                    case _ => result.append(String.empty)
                }
                if (piece.size > 1) {
                    result.append(piece[1..])
                }
            } else if (piece.size > 0) {
                result.append(piece)
            }
            i++
        }
        result.append("\n")
        return result.toString()
    }

}