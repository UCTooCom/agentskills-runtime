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
package f_log.output

import std.time.DateTime
import stdx.log.{LogWriter, LogValue}
import f_base.{printStackTrace, BaseException}

protected class LogWriterImpl <: LogWriter {
    public LogWriterImpl(private let writer: OutputStream) {}

    public func writeNone(): Unit {
        writeString('None')
    }
    public func writeInt(v: Int64): Unit {
        writeString(v.toString())
    }
    public func writeUInt(v: UInt64): Unit {
        writeString(v.toString())
    }
    public func writeBool(v: Bool): Unit {
        writeString(v.toString())
    }
    public func writeFloat(v: Float64): Unit {
        writeString(v.toString())
    }
    public func writeString(v: String): Unit {
        writer.write(v.toArray())
    }
    public func writeDateTime(v: DateTime): Unit {
        writeString(v.toString())
    }
    public func writeDuration(v: Duration): Unit {
        writeString(v.toString())
    }
    public func writeKey(v: String): Unit {
        writeString(v)
    }
    public func writeValue(v: LogValue): Unit {
        v.writeTo(this)
    }
    public func startArray(): Unit {
        writeString('[')
    }
    public func endArray(): Unit {
        writeString(']')
    }
    public func startObject(): Unit {
        writeString('{')
    }
    public func endObject(): Unit {
        writeString('}')
    }
    public func writeException(v: Exception): Unit {
        if (let c: BaseException <- v) {
            c.printStackTrace(writer)
        } else {
            printStackTrace(v, writer)
        }
    }
}
