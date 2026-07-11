/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */

package hyperion.logadapter

/**
 * 格式化日志
 *
 * @author yangfuping
 */
public interface SimpleLogFormatter {
    func format(record: SimpleLogRecord): String
}

/**
 * 默认的SimpleLogFormatter实现
 *
 * @author yangfuping
 */
public open class DefaultSimpleLogFormatter <: SimpleLogFormatter {
    private static let RECORD_BEGIN_MARKER = "####|"
    private static let RECORD_END_MARKER = "|####"
    private static let FIELD_SEPARATOR = '|'
    protected static let LINE_SEPARATOR = '\n'
    private static let INDENT_STEP = "    "
    private static let MAX_CAUSE_DEPTH = 3

    public open func format(record: SimpleLogRecord): String {
        let builder = StringBuilder()
        builder.append(RECORD_BEGIN_MARKER)
        builder.append(formatDateTime(record.logTime))
        builder.append(FIELD_SEPARATOR)
        builder.append(record.level.getName())
        builder.append(FIELD_SEPARATOR)
        builder.append(record.threadName)
        builder.append(FIELD_SEPARATOR)
        builder.append(record.message)
        if (let Some(ex) <- record.exception) {
            builder.append(LINE_SEPARATOR)
            formatException(builder, ex)
        }
        builder.append(RECORD_END_MARKER)
        builder.append(LINE_SEPARATOR)

        return builder.toString()
    }

    public static func formatDateTime(dateTime: DateTime): String {
        let year = dateTime.year
        let month = dateTime.month.toInteger()
        let day = dateTime.dayOfMonth
        let hour = dateTime.hour
        let minute = dateTime.minute
        let second = dateTime.second
        let millSecond = dateTime.nanosecond / (1000 * 1000)

        return year.format("04") + "-" + month.format("02") + "-" + day.format("02") + "-" + hour.format("02") + ":" +
            minute.format("02") + ":" + second.format("02") + "." + millSecond.format("03")
    }

    public static func formatException(exception: Exception): String {
        let builder = StringBuilder()
        formatException(builder, exception)
        return builder.toString()
    }

    public static func formatException(builder: StringBuilder, exception: Exception) {
        builder.append(exception.toString())
        builder.append(LINE_SEPARATOR)
        builder.append("Detail stack traces:")
        builder.append(LINE_SEPARATOR)
        let traces = exception.getStackTrace()
        for (trace in traces) {
            builder.append(
                "${INDENT_STEP}at " + trace.declaringClass + "." + trace.methodName + "(" + trace.fileName + ":" +
                    "${trace.lineNumber}" + ")"
            )
            builder.append(LINE_SEPARATOR)
        }

        if (let Some(causeEmbbed) <- (exception as CauseEmbedded)) {
            if (let Some(innerCause) <- causeEmbbed.getCause()) {
                if (refEq(innerCause, exception)) {
                    return
                }

                let depth = AtomicInt64(0)
                appendCause(builder, INDENT_STEP, depth, causeEmbbed)
            }
        }
    }

    public static func appendCause(
        builder: StringBuilder,
        indent: String,
        depth: AtomicInt64,
        causeEmbbed: CauseEmbedded
    ): Unit {
        if (let Some(cause) <- causeEmbbed.getCause()) {
            depth.fetchAdd(1)
            if (depth.load() > MAX_CAUSE_DEPTH) {
                // 避免无限循环
                return
            }

            builder.append(LINE_SEPARATOR)
            builder.append(indent + "Cause: " + cause.toString())
            builder.append(LINE_SEPARATOR)
            builder.append("${indent}Detail stack traces:")
            builder.append(LINE_SEPARATOR)

            let traces = cause.getStackTrace()
            for (trace in traces) {
                builder.append(indent + INDENT_STEP)
                builder.append(
                    "at " + trace.declaringClass + "." + trace.methodName + "(" + trace.fileName + ":" +
                        "${trace.lineNumber}" + ")"
                )
                builder.append(LINE_SEPARATOR)
            }

            if (let Some(causeEmbbed) <- (cause as CauseEmbedded)) {
                if (let Some(innerCause) <- causeEmbbed.getCause()) {
                    if (refEq(innerCause, cause)) {
                        return
                    }

                    appendCause(builder, indent + INDENT_STEP, depth, causeEmbbed)
                }
            }
        }
    }
}
