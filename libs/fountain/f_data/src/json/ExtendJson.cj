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
package f_data.json

import std.io.{InputStream, StringReader, StringWriter, ByteBuffer}
import f_data.exception.DataException
import charset4cj.charset.encoding.Charset
import charset4cj.charset.{Charsets, TextReader, TextWriter}
// import charset4cj.{Charset, Charsets, TextReader, TextWriter}

public interface ExtendJsonValue {
    static func fromInput(input: InputStream, charset!: Charset): JsonValue {
        fromReader(TextReader(input, charset: charset))
    }
    static func fromReader<I>(reader: StringReader<I>): JsonValue where I <: InputStream {
        let buffer = ByteBuffer()
        let writer = StringWriter(buffer)
        while (let Some(line) <- reader.readln()) {
            writer.writeln(line)
        }
        writer.flush()
        JsonValue.fromStr(String.fromUtf8(buffer.bytes()))
    }
    static func fromReader(reader: TextReader): JsonValue {
        let buffer = ByteBuffer()
        let writer = StringWriter(buffer)
        while (let Some(line) <- reader.readln()) {
            writer.writeln(line)
        }
        writer.flush()
        JsonValue.fromStr(String.fromUtf8(buffer.bytes()))
    }
    func toData(): Data
    static func tryFromData(data: Data, flag!: DataConversionFlag): JsonValue
}

public let JSON_NULL = JsonNull()

extend JsonValue <: ExtendJsonValue {
    public func toData(): Data {
        match (this) {
            case x: JsonBool => x.getValue().toData()
            case x: JsonInt => x.getValue().toData()
            case x: JsonFloat => x.getValue().toData()
            case x: JsonNull => DataNone.INSTANCE
            case x: JsonString => x.getValue().toData()
            case x: JsonArray => DataJsonArray(x)
            case x: JsonObject => DataJsonObject(x)
            case _ => throw UnreachableException()
        }
    }
    public static func tryFromData(data: Data, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): JsonValue {
        func from(data: Data) {
            match (tryFromData(data, flag: flag)) {
                case x: JsonValue => x
                case x: ?JsonValue => match (x) {
                    case Some(x) => x
                    case _ => JSON_NULL
                }
                case x: ?JsonBool => match (x) {
                    case Some(x) => x
                    case _ => JSON_NULL
                }
                case x: ?JsonInt => match (x) {
                    case Some(x) => x
                    case _ => JSON_NULL
                }
                case x: ?JsonFloat => match (x) {
                    case Some(x) => x
                    case _ => JSON_NULL
                }
                case x: ?JsonString => match (x) {
                    case Some(x) => x
                    case _ => JSON_NULL
                }
                case x: ?JsonObject => match (x) {
                    case Some(x) => x
                    case _ => JSON_NULL
                }
                case x: ?JsonArray => match (x) {
                    case Some(x) => x
                    case _ => JSON_NULL
                }
                case _ => JSON_NULL
            }
        }
        match (data) {
            case x: DataJsonArray => x.json
            case x: DataJsonObject => x.json
            case x: DataNone => JsonNull()
            case x: DataBool => JsonBool(x.data)
            case x: DataReal => if(x.data.isInteger()){
                JsonInt(x.data.toInt64())
            }else{
                JsonFloat(x.data.toFloat64())
            }
            case x: DataString => JsonString(x.data)
            case x: DataDateTime => JsonString(x.data.toString())
            case x: DataDuration => JsonString(x.data.toString())
            case x: Iterable<Data> =>
                let arr = JsonArray()
                for (d in x) {
                    arr.add(from(d))
                }
                arr
            case x: Iterable<(String, Data)> =>
                let obj = JsonObject()
                for ((k, v) in x) {
                    obj.put(k, from(v))
                }
                obj
            case x: Iterable<(Data, Data)> =>
                let obj = JsonObject()
                for ((k, v) in x) {
                    let ks = match(from(k)){
                        case x: JsonString => x.getValue()
                        case x => x.toString()
                    }
                    let vs = from(v)
                    obj.put(ks, vs)
                }
                obj
            case _ => throw DataException("can not convert data type to JsonValue")
        }
    }
}

public class DataJsonArrayIterator <: Iterator<Data> {
    public DataJsonArrayIterator(private let itr: Iterator<JsonValue>) {}
    public func next(): ?Data {
        itr.next()?.toData()
    }
}

public struct DataJsonArray <: Data & Collection<Data> {
    public DataJsonArray(public let json: JsonArray) {}
    public prop size: Int64 {
        get() {
            json.size()
        }
    }
    public func isEmpty() {
        size == 0
    }
    public func iterator(): Iterator<Data> {
        DataJsonArrayIterator(json.getItems().iterator())
    }
    public func toString() {
        json.toString()
    }
    public static func tryParse(s: String): ?Data {
        JsonValue.fromStr(s).toData()
    }
    public static func parse(s: String): Data {
        tryParse(s).getOrThrow {DataParsableException('${s} cannot be parsed to ${TypeInfo.of<DataJsonArray>()}')}
    }
}

public class DataJsonObjectIterator <: Iterator<(String, Data)> {
    public DataJsonObjectIterator(private let itr: Iterator<(String, JsonValue)>) {}
    public func next(): ?(String, Data) {
        for ((k, v) in itr) {
            return (k, v.toData())
        }
        None
    }
}

public struct DataJsonObject <: Data & Collection<(String, Data)> {
    public DataJsonObject(public let json: JsonObject) {}
    public prop size: Int64 {
        get() {
            json.size()
        }
    }
    public func isEmpty() {
        size == 0
    }
    public func iterator(): Iterator<(String, Data)> {
        DataJsonObjectIterator(json.getFields().iterator())
    }
    public func toString() {
        json.toString()
    }
    public static func tryParse(s: String): ?Data {
        JsonValue.fromStr(s).toData()
    }
    public static func parse(s: String): Data {
        tryParse(s).getOrThrow {DataParsableException('${s} cannot be parsed to ${TypeInfo.of<DataJsonObject>()}')}
    }
}
