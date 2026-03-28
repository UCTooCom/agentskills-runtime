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

import f_collection.*
import f_data.*
import f_io.RotatableBuffer
import f_util.UUID
/**
https://www.rfc-editor.org/rfc/rfc1867
multipart/form-data
        Content-type: multipart/form-data, boundary=AaB03x

        --AaB03x
        content-disposition: form-data; name="field1"

        Joe Blow
        --AaB03x
        content-disposition: form-data; name="pics"; filename="file1.txt"
        Content-Type: text/plain

         ... contents of file1.txt ...
        --AaB03x--



multipart/form-data multipart/mixed
        Content-type: multipart/form-data, boundary=AaB03x

        --AaB03x
        content-disposition: form-data; name="field1"

        Joe Blow
        --AaB03x
        content-disposition: form-data; name="pics"
        Content-type: multipart/mixed, boundary=BbC04y

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
    private let stream: RotatableBuffer
    private let boundaryBytes: Array<Byte>
    
    public MultipartFormDataParser(input: InputStream, private let boundary: String){
        stream = RotatableBuffer(input, halfBufferSize: HttpConfig.halfBufferSize)
        boundaryBytes = '--${boundary}'.unsafeBytes()
    }
    public static func new(ctx: HttpContext){
        let contentType = ctx.request.headers.getFirst("Content-Type").getOrThrow()
        let boundary = contentType[contentType.indexOf('boundary=').getOrThrow() + 'boundary='.size ..]
        MultipartFormDataParser(ctx.request.body, boundary)
    }
    public func parse(){
        let path = Path('/tmp/${UUID.random()}')
        let crlf = Array<Byte>(2, repeat: 0)
        let parts = DataMultiparts()
        var start = stream.indexOf(boundaryBytes)
        while(true){
            if(start < 0){
                throw MultipartFormDataException()
            }
            start += boundaryBytes.size
            stream.read(crlf)
            match((crlf[0], crlf[1])){
                case (b'\r', b'\n') =>
                    start += 2
                    var end = stream.indexOf([b'\r', b'\n', b'\r', b'\n'], from: start)
                    var buf = Array<Byte>(end - start, repeat: 0)
                    stream.read(buf)
                    let partHeader = String.fromUtf8(buf).split('\r\n')
                    let contentDisposition = ContentDisposition.parse(partHeader[0])
                    let contentType = MediaTypes.parse(partHeader[1].replace('Content-Type:', '').trimAscii())
                    let filename = contentDisposition.getFilename()
                    stream.addOffset(4)
                    end = stream.indexOf(boundaryBytes)
                    if(end > 0){
                        buf = Array<Byte>(end - start, repeat: 0)
                        stream.read(buf)
                        if(filename.isEmpty()){
                            let value = if(let Some(charset) <- contentDisposition.getCharset()){
                                charset.newDecoder().decode(buf)
                            }else{
                                String.fromUtf8(buf)
                            }
                            parts.add(contentDisposition.getName(), contentType.toData(value))
                        }else{
                            let part = MultipartFile(contentDisposition, ByteBuffer(buf), charset: contentDisposition.getCharset() ?? Charsets.UTF8)
                            parts.add(contentDisposition.getName(), part)
                        }
                    }else if(filename.isEmpty()){
                        buf = Array<Byte>(1024, repeat: 0)
                        let bytes = ArrayList<Byte>()
                        while(let (len, _, _) <- stream.read(buf)){
                            bytes.add(all: buf[0..len])
                            end = stream.indexOf(boundaryBytes)
                            start = stream.offset
                            if(end > 0){
                                buf = Array<Byte>(end - start, repeat: 0)
                                stream.read(buf)
                                bytes.add(all: buf)
                                break
                            }
                        }
                        buf = bytes.unsafeData()
                        let value = if(let Some(charset) <- contentDisposition.getCharset()){
                            charset.newDecoder().decode(buf)
                        }else{
                            String.fromUtf8(buf)
                        }
                        parts.add(contentDisposition.getName(), contentType.toData(value))
                    }else{
                        let file = File(path.join(filename), ReadWrite)
                        buf = Array<Byte>(1024, repeat: 0)
                        while(let (len, _, _) <- stream.read(buf)){
                            file.write(buf[0..len])
                            end = stream.indexOf(boundaryBytes)
                            start = stream.offset
                            if(end > 0){
                                buf = Array<Byte>(end - start, repeat: 0)
                                stream.read(buf)
                                file.write(buf)
                                break
                            }
                        }
                        let part = MultipartFile(contentDisposition, file, charset: contentDisposition.getCharset()?? Charsets.UTF8)
                        parts.add(contentDisposition.getName(), part)
                    }
                case (b'-', b'-') => break
                case _ => throw MultipartFormDataException()
            }
        }
        parts
    }
}

public class DataMultiparts <: Data & Iterable<(String, Data)>{
    private let map = HashMap<String, ArrayList<Data>>()

    public func add(name: String, input: Data){
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
        DataMultipartsIterator(map.iterator())
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
public class DataMultipartsIterator <: Iterator<(String, Data)>{
    DataMultipartsIterator(private let itr: Iterator<(String, ArrayList<Data>)>){}

    public func next(): ?(String, Data) {
        while(let Some((k, v)) <- itr.next()){
            if(v.isEmpty()){
                continue
            }else if(v.size == 1){
                return (k, v[0])
            }else{
                return (k, DataIterable(v))
            }
        }
        None<(String, Data)>
    }
}