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

internal import std.io.{InputStream, OutputStream, ByteBuffer}
internal import std.collection.concurrent.ArrayBlockingQueue
import f_base.*
import f_exception.IllegalSizeException

public func pipe<I, O>(input!: I, output!: O, bufferSize!: Int64 = 4096): Unit where I <: InputStream, O <: OutputStream {
    let buf = Array<Byte>(bufferSize, repeat: 0)
    while (let len <- input.read(buf) && len > 0) {
        output.write(buf[0..len])
    }
}

public func asyncPipe<I, O>(input!: I, output!: O, bufferSize!: Int64 = 4096): Unit where I <: InputStream,
    O <: OutputStream {
    spawn {
        pipe<I, O>(input: input, output: output, bufferSize: bufferSize)
    }
}

public func copyToCType<T>(input: InputStream): T where T <: CType {
    let size = Int64(sizeOf<T>())
    let buf = Array<Byte>(size, repeat: 0)
    let len = input.read(buf)
    if(len < size) {
        throw IllegalSizeException("remainder bytes in InputStream is ${len}, but size of ${TypeInfo.of<T>()} is ${size}")
    }
    unsafe{
        let handle = acquireArrayRawData<Byte>(buf)
        let pointer = handle.pointer
        try{
            CPointer<T>(pointer).read()
        }finally{
            releaseArrayRawData(handle)
        }
    }
}