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

import std.collection.ArrayList
import std.io.{InputStream, OutputStream, ByteBuffer, copy}
import std.fs.File
import std.time.DateTime
import f_base.*
import f_random.RandomString

public class MultipartFormData {
    public let boundary = 'FountainBoundary${RandomString().randomLettersNumbers(32)}'
    let parts = ArrayList<MultipartFile>()
    public func newPart(): MultipartFileBuilder {
        MultipartFileBuilder(this)
    }
    public func encode(output: OutputStream){
        for(part in parts){
            output.write('--${boundary}\r\n'.unsafeBytes())
            let cd = part.contentDisposition.toString().unsafeBytes()
            let input = part.content
            output.write(cd)
            copy(input, to: output)
            output.write('\r\n'.unsafeBytes())
        }
        output.write('--${boundary}--\r\n'.unsafeBytes())
    }
    public func input(): InputStream {
        MultipartFileInputStream(this)
    }
}
public class MultipartFileBuilder {
    private let builder = ContentDispositionBuilder(ContentDisposition()).formData
    private var content = unsafe{zeroValue<InputStream>()}
    MultipartFileBuilder(private let data: MultipartFormData){}
    public func name(name: String): This {
        builder.name(name)
        this
    }
    public func value(content: Array<Byte>): This {
        let buf = ByteBuffer()
        this.content = buf
        buf.write(content)
        this
    }
    public func value<T>(content: T): This where T <: ToString {
        value(content.toString().unsafeBytes())
    }
    public func file(file: File): This {
        content = file
        builder.filename(file.info.name)
        builder.size(file.info.size)
        builder.creationDate(file.info.creationTime)
        builder.modificationDate(file.info.lastModificationTime)
        this
    }
    public func file(fileName: String, content: InputStream, size!: Int64 = -1, 
                     creationDate!: ?DateTime = None<DateTime>, modificationDate!: ?DateTime = None<DateTime>): This{
        if(size >= 0){
            builder.size(size)
        }
        if(let Some(x) <- creationDate){
            builder.creationDate(x)
        }
        if(let Some(x) <- modificationDate){
            builder.modificationDate(x)
        }
        builder.filename(fileName)
        this.content = content
        this
    }
    public func build(): MultipartFormData {
        data.parts.add(MultipartFile(builder.build(), content))
        data
    }
}
public class MultipartFileInputStream <: InputStream {
    private var cur = CurrentMultipartFile.Start
    MultipartFileInputStream(private let data: MultipartFormData){}
    public func read(buf: Array<Byte>): Int64 {
        match(cur){
            case Start => 
                cur = Current(0, data.parts[0], StartBoundary)
                read(buf)
            case Current(idx, tmp, offset, part) => 
                if(let s <- tmp.size - offset && s > 0 && s <= buf.size){
                    tmp.copyTo(buf, offset, 0, s)
                    cur = Current(idx, data.parts[idx], part.next)
                    s
                }else if(let s <- tmp.size - offset && s > 0 && s > buf.size){
                    tmp.copyTo(buf, offset, 0, buf.size)
                    cur = Current(idx, tmp, offset + buf.size, part)
                    buf.size
                }else {
                    cur = Current(idx, data.parts[idx], part.next)
                    read(buf)
                }
            case Current(idx, input) =>
                let l = input.read(buf)
                if(l == 0){
                    cur = Current(idx, data.parts[idx], CRLF_Boundary)
                }
                l
            case Current(idx, file, part) =>
                cur = match(part){
                    case StartBoundary => Current(idx, '--${data.boundary}\r\n'.unsafeBytes(), 0, StartBoundary)
                    case ContentDisposition =>
                        let tmp = file.contentDisposition.toString().unsafeBytes()
                        Current(idx, tmp, 0, MultipartPart.ContentDisposition)
                    case Content => Current(idx, file.content)
                    case CRLF_Boundary => Current(idx, '\r\n--${data.boundary}--\r\n'.unsafeBytes(), 0, CRLF_Boundary)
                    case Next => Current(idx + 1, data.parts[idx + 1], StartBoundary)
                }
                read(buf)
        }
    }
}
enum CurrentMultipartFile {
    | Start
    | Current(Int64, MultipartFile, MultipartPart)
    | Current(Int64, Array<Byte>, Int64, MultipartPart)
    | Current(Int64, InputStream)
}
enum MultipartPart{
    | StartBoundary
    | ContentDisposition
    | Content
    | CRLF_Boundary
    | Next
    prop next: MultipartPart {
        get(){
            match(this){
                case StartBoundary => ContentDisposition
                case ContentDisposition => Content
                case Content => CRLF_Boundary
                case CRLF_Boundary => Next
                case Next => StartBoundary
            }
        }
    }
}