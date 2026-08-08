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

import std.io.*
import f_collection.*
import f_data.*
import f_io.RotatableBuffer
import f_util.UUID
/**
https://www.rfc-editor.org/rfc/rfc1867
multipart/form-data
        Content-type: multipart/form-data; boundary=AaB03x

        --AaB03x
        content-disposition: form-data; name="field1"

        Joe Blow
        --AaB03x
        content-disposition: form-data; name="pics"; filename="file1.txt"
        Content-Type: text/plain

         ... contents of file1.txt ...
        --AaB03x--



multipart/form-data multipart/mixed
        Content-type: multipart/form-data; boundary=AaB03x

        --AaB03x
        content-disposition: form-data; name="field1"

        Joe Blow
        --AaB03x
        content-disposition: form-data; name="pics"
        Content-type: multipart/mixed; boundary=BbC04y

        --BbC04y
        Content-disposition: attachment; filename="file1.txt"
        Content-Type: text/plain

        ... contents of file1.txt ...
        --BbC04y
        Content-disposition: attachment; filename="file2.gif"
        Content-type: image/gif
        Content-Transfer-Encoding: binary

          ...contents of file2.gif...
        --BbC04y--
        --AaB03x--
 */
public class MultipartFormDataParser {
    private static let DOUBLE_CRLF = [b'\r', b'\n', b'\r', b'\n']
    private let stream: RotatableBuffer
    private let seperatorBoundaryBytes: Array<Byte>
    
    public MultipartFormDataParser(input: InputStream, private let mediaType: String, private let boundary: String){
        seperatorBoundaryBytes = '\r\n--${boundary}'.unsafeBytes()
        stream = RotatableBuffer(input, seperatorBoundaryBytes, halfBufferSize: HttpConfig.halfBufferSize)
    }
    public static func new(ctx: HttpContext){
        let contentType = ctx.request.headers.getFirst("Content-Type").getOrThrow()
        let boundary = contentType[contentType.indexOf('boundary=').getOrThrow() + 'boundary='.size ..]
        MultipartFormDataParser(ctx.request.body, contentType, boundary)
    }
    public func parse(): Data {
        let boundaryBytes = seperatorBoundaryBytes[2 ..]
        let path = Path('/tmp/${UUID.random()}')
        let crlf = Array<Byte>(2, repeat: 0)
        let parts = if(mediaType.startsWith('multipart/form-data')){
            DataMultipartTuples()
        }else if(mediaType.startsWith('multipart/mixed')){
            DataMultipartList()
        }else{
            throw MultipartException('${mediaType} is not be supported.')
        }
        var start = stream.indexOf(boundaryBytes)
        if(start < 0){
            throw MultipartException()
        }
        stream.addOffset(boundaryBytes.size)
        start += boundaryBytes.size
        while(true){
            let (l, _, _) = stream.read(crlf)
            match((crlf[0], crlf[1])){
                case (b'\r', b'\n') =>
                    start = stream.offset
                    var end = stream.indexOf(DOUBLE_CRLF, from: start)
                    var buf = Array<Byte>(end - start + DOUBLE_CRLF.size, repeat: 0)
                    stream.read(buf)
                    let partHeader = String.fromUtf8(buf).split('\r\n')
                    let contentDisposition = ContentDisposition.parse(partHeader[0]['Content-Disposition: '.size ..])
                    let filename = contentDisposition.getFilename()
                    end = stream.indexOf(seperatorBoundaryBytes)
                    if(end > 0){
                        buf = Array<Byte>(end - stream.offset, repeat: 0)
                        stream.read(buf)
                        if(filename.isEmpty()){
                            let value = if(let Some(charset) <- contentDisposition.getCharset()){
                                charset.newDecoder().decode(buf)
                            }else{
                                String.fromUtf8(buf)
                            }
                            let name = contentDisposition.getName()
                            if(let mediaType <- partHeader[1].replace('Content-Type:', '').trimAscii() && mediaType.size > 0){
                                let contentType = MediaTypes.parse(mediaType)
                                if(let p: DataMultipartTuples <- parts){
                                    p.add(name, contentType.toData(value))
                                }else if(let p: DataMultipartList <- parts){
                                    p.add(contentType.toData(value))
                                }
                            }else if(let p: DataMultipartTuples <- parts){
                                p.add(name, value.toData())
                            }else if(let p: DataMultipartList <- parts){
                                p.add(value.toData())
                            }
                        }else{
                            let part = MultipartFile(contentDisposition, ByteBuffer(buf), charset: contentDisposition.getCharset() ?? Charsets.UTF8)
                            part.setSize(buf.size)
                            if(let p: DataMultipartTuples <- parts){
                                p.add(contentDisposition.getName(), part)
                            }else if(let p: DataMultipartList <- parts){
                                p.add(part)
                            }
                        }
                    }else if (filename.isEmpty()){
                        let byteList = ArrayList<Byte>()
                        buf = Array<Byte>(1024, repeat: 0)
                        while(let (len, _, _) <- stream.read(buf)){
                            byteList.add(all: buf[0 .. len])
                            if(len < buf.size){
                                break
                            }
                        }
                        let bytes = byteList.unsafeData()
                        let value = if(let Some(charset) <- contentDisposition.getCharset()){
                            charset.newDecoder().decode(bytes)
                        }else{
                            String.fromUtf8(bytes)
                        }
                        let name = contentDisposition.getName()
                        if(let mediaType <- partHeader[1].replace('Content-Type:', '').trimAscii() && mediaType.size > 0){
                            let contentType = MediaTypes.parse(mediaType)
                            if(let p: DataMultipartTuples <- parts){
                                p.add(name, contentType.toData(value))
                            }else if(let p: DataMultipartList <- parts){
                                p.add(contentType.toData(value))
                            }
                        }else if(let p: DataMultipartTuples <- parts){
                            p.add(name, value.toData())
                        }else if(let p: DataMultipartList <- parts){
                            p.add(value.toData())
                        }
                    }else{
                        Directory.create(path, recursive: true)
                        let file = File(path.join(filename), ReadWrite)
                        buf = Array<Byte>(1024, repeat: 0)
                        var l = 0
                        while(let (len, _, _) <- stream.read(buf)){
                            l += len
                            if(len < buf.size){
                                file.write(buf[0..len])
                                break
                            }else{
                                file.write(buf)
                            }
                        }
                        file.seek(Begin(0))
                        let part = MultipartFile(contentDisposition, file, charset: contentDisposition.getCharset()?? Charsets.UTF8)
                        part.setSize(file.length)
                        if(let p: DataMultipartTuples <- parts){
                            p.add(contentDisposition.getName(), part)
                        }else if(let p: DataMultipartList <- parts){
                            p.add(part)
                        }
                    }
                case (b'-', b'-') => 
                    break
                case _ => throw MultipartException()
            }
        }
        parts
    }
}
public interface DataMultiparts<T> <: Data {
    func add(value: T): Unit
}
public struct DataMultipartTuples <: DataMultiparts<(String, Data)> & Iterable<(String, Data)>{
    private let map = HashMap<String, ArrayList<Data>>()

    public func add(value: (String, Data)): Unit {
        add(value[0], value[1])
    }
    public func add(name: String, input: Data): Unit {
        map.computeIfAbsent(name){ArrayList<Data>()}.add(input)
    }
    public func get(name: String){
        match(map.get(name)){
            case Some(x) where x.size == 1 => x[0]
            case Some(x) => DataIterable(x)
            case _ => DataNone.INSTANCE 
        }
    }
    public func iterator(): Iterator<(String, Data)> {
        DataMultipartTuplesIterator(map.iterator())
    }
    public static func tryParse(_: String): ?Data {
        throw IllegalAccessException()
    }
    public static func parse(_: String): Data {
        throw IllegalAccessException()
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        throw IllegalAccessException()
    }
    public func toString(): String {
        throw IllegalAccessException()
    }
}
public struct DataMultipartList <: DataMultiparts<Data> & Iterable<Data>{
    private let list = ArrayList<Data>()

    public func add(input: Data){
        list.add(input)
    }
    public func get(index: Int64){
        list.get(index)
    }
    public func iterator(): Iterator<Data> {
        DataMultipartListIterator(list.iterator())
    }
    public static func tryParse(_: String): ?Data {
        throw IllegalAccessException()
    }
    public static func parse(_: String): Data {
        throw IllegalAccessException()
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        throw IllegalAccessException()
    }
    public func toString(): String {
        throw IllegalAccessException()
    }
}
public class DataMultipartTuplesIterator <: Iterator<(String, Data)>{
    DataMultipartTuplesIterator(private let itr: Iterator<(String, ArrayList<Data>)>){}

    public func next(): ?(String, Data) {
        while(let Some((k, v)) <- itr.next()){
            return if(v.isEmpty()){
                continue
            }else if(v.size == 1){
                if(let l: DataMultipartList <- v[0]){
                    (k, DataIterable(l))
                }else{
                    (k, v[0])
                }
            }else{
                (k, DataIterable(v))
            }
        }
        None<(String, Data)>
    }
}
public class DataMultipartListIterator <: Iterator<Data> {
    DataMultipartListIterator(private let itr: Iterator<Data>){}

    public func next(): ?Data {
        while(let Some(d) <- itr.next()){
            d
        }
        None<Data>
    }
}