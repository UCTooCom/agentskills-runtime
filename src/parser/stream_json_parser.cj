/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.parser

import magic.log.LogUtils
import std.collection.ArrayList
import std.sync.Mutex
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray}

public enum StreamEvent {
    | JsonParsed(JsonValue)
    | ParseError(String, Int64)
    | StreamEnd
}

public class StreamJsonParser {
    private var buffer = ""
    private let mutex = Mutex()
    private let callbacks = ArrayList<(StreamEvent) -> Unit>()
    private var position: Int64 = 0

    public init() {
    }

    public func feed(data: String): Unit {
        synchronized(mutex) {
            buffer = buffer + data
            tryParse()
        }
    }

    public func feedAll(dataList: Array<String>): Unit {
        synchronized(mutex) {
            for (data in dataList) {
                buffer = buffer + data
            }
            tryParse()
        }
    }

    public func onEvent(callback: (StreamEvent) -> Unit): Unit {
        synchronized(mutex) {
            callbacks.add(callback)
        }
    }

    public func getBuffer(): String {
        synchronized(mutex) {
            return buffer
        }
    }

    public func getPosition(): Int64 {
        synchronized(mutex) {
            return position
        }
    }

    public func reset(): Unit {
        synchronized(mutex) {
            buffer = ""
            position = 0
        }
    }

    private func tryParse(): Unit {
        var content = buffer
        var pos = 0
        var parsed = false

        while (pos < content.size) {
            let remaining = content[pos..content.size]
            
            if (remaining.startsWith("{")) {
                let (jsonStr, endPos, success) = extractJsonObject(content, pos)
                if (success && !jsonStr.isEmpty()) {
                    try {
                        let json = JsonValue.fromStr(jsonStr)
                        emitEvent(StreamEvent.JsonParsed(json))
                        pos = endPos
                        parsed = true
                    } catch (ex: Exception) {
                        emitEvent(StreamEvent.ParseError("Failed to parse JSON: ${ex.message}", pos))
                        pos++
                    }
                } else {
                    break
                }
            } else if (remaining.startsWith("[")) {
                let (jsonStr, endPos, success) = extractJsonArray(content, pos)
                if (success && !jsonStr.isEmpty()) {
                    try {
                        let json = JsonValue.fromStr(jsonStr)
                        emitEvent(StreamEvent.JsonParsed(json))
                        pos = endPos
                        parsed = true
                    } catch (ex: Exception) {
                        emitEvent(StreamEvent.ParseError("Failed to parse JSON array: ${ex.message}", pos))
                        pos++
                    }
                } else {
                    break
                }
            } else if (remaining.startsWith(" ") || remaining.startsWith("\n") || remaining.startsWith("\r") || remaining.startsWith("\t")) {
                pos++
            } else {
                pos++
            }
        }

        if (parsed) {
            if (pos < content.size) {
                buffer = content[pos..content.size]
            } else {
                buffer = ""
            }
            position += pos
        }
    }

    private func extractJsonObject(content: String, start: Int64): (String, Int64, Bool) {
        var depth = 0
        var inString = false
        var escape = false
        var pos = start

        while (pos < content.size) {
            let remaining = content[pos..content.size]

            if (escape) {
                escape = false
                pos++
                continue
            }

            if (remaining.startsWith("\\") && inString) {
                escape = true
                pos++
                continue
            }

            if (remaining.startsWith("\"")) {
                inString = !inString
                pos++
                continue
            }

            if (!inString) {
                if (remaining.startsWith("{")) {
                    depth++
                } else if (remaining.startsWith("}")) {
                    depth--
                    if (depth == 0) {
                        let jsonStr = content[start..(pos + 1)]
                        return (jsonStr, pos + 1, true)
                    }
                }
            }

            pos++
        }

        return ("", start, false)
    }

    private func extractJsonArray(content: String, start: Int64): (String, Int64, Bool) {
        var depth = 0
        var inString = false
        var escape = false
        var pos = start

        while (pos < content.size) {
            let remaining = content[pos..content.size]

            if (escape) {
                escape = false
                pos++
                continue
            }

            if (remaining.startsWith("\\") && inString) {
                escape = true
                pos++
                continue
            }

            if (remaining.startsWith("\"")) {
                inString = !inString
                pos++
                continue
            }

            if (!inString) {
                if (remaining.startsWith("[")) {
                    depth++
                } else if (remaining.startsWith("]")) {
                    depth--
                    if (depth == 0) {
                        let jsonStr = content[start..(pos + 1)]
                        return (jsonStr, pos + 1, true)
                    }
                }
            }

            pos++
        }

        return ("", start, false)
    }

    private func emitEvent(event: StreamEvent): Unit {
        for (callback in callbacks) {
            try {
                callback(event)
            } catch (ex: Exception) {
                LogUtils.error("[StreamJsonParser] Callback error: ${ex.message}")
            }
        }
    }
}

public class StreamJsonParserBuilder {
    private let parser = StreamJsonParser()

    public init() {
    }

    public func onJsonParsed(callback: (JsonValue) -> Unit): StreamJsonParserBuilder {
        parser.onEvent({ event: StreamEvent =>
            match (event) {
                case StreamEvent.JsonParsed(json) =>
                    callback(json)
                case _ =>
                    ()
            }
        })
        return this
    }

    public func onError(callback: (String, Int64) -> Unit): StreamJsonParserBuilder {
        parser.onEvent({ event: StreamEvent =>
            match (event) {
                case StreamEvent.ParseError(msg, pos) =>
                    callback(msg, pos)
                case _ =>
                    ()
            }
        })
        return this
    }

    public func onEnd(callback: () -> Unit): StreamJsonParserBuilder {
        parser.onEvent({ event: StreamEvent =>
            match (event) {
                case StreamEvent.StreamEnd =>
                    callback()
                case _ =>
                    ()
            }
        })
        return this
    }

    public func build(): StreamJsonParser {
        return parser
    }
}
