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

internal import std.collection.ArrayList
internal import std.collection.concurrent.ConcurrentHashMap
internal import std.convert.*
internal import std.fs.*
internal import std.io.{InputStream, ByteBuffer, OutputStream, copy}
internal import stdx.encoding.base64.*
internal import stdx.encoding.hex.*
internal import stdx.encoding.json.*
internal import stdx.encoding.url.*
internal import stdx.net.http.*
internal import charset4cj.charset.encoding.Charset
internal import charset4cj.charset.{Charsets, TextReader, TextWriter}
internal import f_bean.*
internal import f_config.*
internal import f_data.*
internal import f_data.json.*
internal import f_exception.*
internal import f_http.exception.*
internal import f_io.*
internal import f_regex.*

public abstract class MediaType <: ToString & Hashable & Equatable<MediaType> {
    protected var hash: Int64
    public MediaType(public let mediaType: String) {
        hash = mediaType.hashCode()
    }
    public open func toString(): String {
        mediaType
    }
    public open func hashCode(): Int64 {
        hash
    }
    public func make(mediaType: String): MediaType
    public open operator func ==(other: MediaType): Bool {
        refEq(this, other) || (this.hashCode() == other.hashCode() && this.mediaType == other.mediaType)
    }
    public func fromDataFields<T>(data: T): Array<Byte> where T <: DataFields<T> {
        fromData(data.toData())
    }
    public open func fromData(data: Data): Array<Byte>
    public open func toData(data: Array<Byte>): Data
    public open func toData(input: InputStream): Data {
        let list = ArrayList<Byte>()
        let buf = Array<Byte>(1024, repeat: 0)
        while (let len <- input.read(buf)) {
            if (len > 0) {
                list.add(all: buf[0..len])
            } else {
                break
            }
        }
        toData(list.unsafeData())
    }
    public open func toData(data: String): Data {
        toData(data.toArray())
    }
    public func toDataFields<T>(data: Data): T where T <: DataFields<T> {
        (T.fromData(data) as T).getOrThrow{MediaTypeException(data.toString())}
    }
    public func toDataFields<T>(data: Array<Byte>): T where T <: DataFields<T> {
        toDataFields<T>(toData(data))
    }
    public func toDataFields<T>(input: InputStream): T where T <: DataFields<T> {
        toDataFields<T>(toData(input))
    }
    public func toDataFields<T>(data: String): T where T <: DataFields<T> {
        toDataFields<T>(toData(data))
    }
}
