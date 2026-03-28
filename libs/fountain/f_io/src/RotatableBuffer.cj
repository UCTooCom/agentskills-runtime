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
package f_io

public class RotatableBuffer {
    public var offset = 0
    private var buffer: (Array<Byte>, Array<Byte>)
    private var sectionEnd = -1
    private var bufferEnd = -1
    private let bufferSize: Int64
    public RotatableBuffer(private let input: InputStream, 
                           private let halfBufferSize!: Int64 = 4096) {
        buffer = (Array<Byte>(halfBufferSize, repeat: 0), Array<Byte>(halfBufferSize, repeat: 0))
        bufferEnd = input.read(buffer[0])
        if(bufferEnd == halfBufferSize){
            bufferEnd += input.read(buffer[1])
        }
        bufferSize = halfBufferSize * 2
    }

    private operator func [](index: Int64): Byte{
        if(index < 0 || index >= bufferSize){
            throw IndexOutOfBoundsException('index: ${index}; bufferSize: ${bufferSize}')
        }else if(index < halfBufferSize){
            buffer[0][index]
        }else{
            buffer[1][index - halfBufferSize]
        }
    }
    public func indexOf(bytes: Array<Byte>, from!: Int64 = this.offset): Int64 {
        if(bytes.size == 0){
            return offset
        }
        let first = bytes[0]
        var i = from
        while(i <= bufferEnd){
            while(this[i] != first && let _ <- i++ && i <= bufferEnd){}
            if(i <= bufferEnd){
                var j = i + 1
                let end = j + bytes.size - 1
                var k = 1
                while(j < end && this[j] == bytes[k]){
                    j++
                    k++
                }
                if (j == end){
                    sectionEnd = i - offset
                    return sectionEnd
                }
            }
        }
        sectionEnd = -1
        return -1
    }
    public func addOffset(off: Int64){
        this.offset += off
    }
    public func read(bytes: Array<Byte>, boundary: Array<Byte>): (length: Int64, remainder: Bool, partEnd: Bool){
        let size = min(bytes.size, if(sectionEnd > 0){sectionEnd - offset}else{bufferSize - offset})
        for(i in 0 .. size){
            bytes[i] = this[offset + i]
        }
        offset += size
        let partEnd = offset == sectionEnd
        if(offset == halfBufferSize){
            buffer = (buffer[1], buffer[0])
            offset = 0
            if(bufferEnd < bufferSize){
                bufferEnd -= halfBufferSize
            }else{
                bufferEnd = halfBufferSize + input.read(buffer[1])
            }
            sectionEnd = -1
        }else if(offset > halfBufferSize && offset < bufferSize){
            buffer = (buffer[1], buffer[0])
            offset -= halfBufferSize
            if(bufferEnd < bufferSize){
                bufferEnd -= halfBufferSize
            }else{
                bufferEnd = halfBufferSize + input.read(buffer[1])
            }
            sectionEnd = -1
        }else if(offset == bufferSize){
            offset = 0
            bufferEnd = input.read(buffer[0])
            if(bufferEnd == halfBufferSize){
                bufferEnd += input.read(buffer[1])
            }
            sectionEnd = -1
        }else if(offset == sectionEnd && sectionEnd < halfBufferSize && sectionEnd + boundary.size >= halfBufferSize){
            buffer = (buffer[1], buffer[0])
            offset = offset + boundary.size - halfBufferSize
            if(bufferEnd < bufferSize){
                bufferEnd -= halfBufferSize
            }else{
                bufferEnd = halfBufferSize + input.read(buffer[1])
            }
            sectionEnd = -1
        }else{
            offset += bytes.size
        }
        (size, bufferEnd > halfBufferSize, partEnd)
    }
}