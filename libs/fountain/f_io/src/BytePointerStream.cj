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

import std.io.*
import std.sync.AtomicInt64

import f_base.*
import f_io.exception.BytePointerException

public class BytePointerStream <: IOStream & Resource {
    private let readOffset_ = AtomicInt64(0)
    private let writeOffset_ = AtomicInt64(0)
    private var closed = false
    private BytePointerStream(
        private let pointer: CPointer<Byte>,
        private let size: Int64,
        public let readable: Bool,
        public let writable: Bool,
        private let freeable: Bool
    ){}

    public init(pointer: CPointer<Byte>, size: Int64, readable!: Bool = true, writable!: Bool = true){
        this(pointer, size, readable, writable, false)
    }
    public init(size: Int64, readable!: Bool = true, writable!: Bool = true){
        this(LibC.malloc<Byte>(count: size), size, readable, writable, true)
    }

    public func isClosed(): Bool {
        closed
    }
    public func close(): Unit {
        if(freeable){
            unsafe {
                LibC.free(pointer)
            }
            closed = true
        }
    }

    public mut prop readOffset: Int64 {
        get(){
            readOffset_.load()
        }
        set(value){
            readOffset_.store(value)
        }
    }
    public mut prop writeOffset: Int64 {
        get(){
            writeOffset_.load()
        }
        set(value){
            writeOffset_.store(value)
        }
    }
    public prop length: Int64 {
        get(){
            size
        }
    }
    private func checkWritable() {
        if (!writable) {
            throw BytePointerException('current BytePointerException is not writable')
        }
    }
    private func checkReadable() {
        if (!readable) {
            throw BytePointerException('current BytePointerException is not readable')
        }
    }
    unsafe func pointerOffset(offset: Int64) {
        CPointer<Unit>(CPointer<Byte>(this.pointer) + offset)
    }
    private func opsize(size: Int64, offset: Int64, len: Int64) {
        if (let s <- len - offset && s < size) {
            s
        } else {
            size
        }
    }
    private func access(p: CPointer<Byte>, size: Int64, pIsDst: Bool) {
        unsafe{
            let (dstptr, srcptr) = if(pIsDst){
                (CPointer<Unit>(p), pointerOffset(0))
            }else{
                (pointerOffset(0), CPointer<Unit>(p))
            }
            mcopy(dstptr, srcptr, UIntNative(size))
        }
    }
    /**
     * 返回值是当前映射的内存区域min(剩余可读字节数, maxSize)
     */
    public func read(p: CPointer<Byte>, maxSize: Int64): Int64 {
        checkReadable()
        let readOff = readOffset_.load()
        let size = opsize(maxSize, readOff, if (writable) {
            writeOffset_.load()
        } else {
            size
        })
        if (size == 0) {
            return 0
        }
        access(p, size, true)
        readOffset_.fetchAdd(size)
        size
    }
    private func access<T>(buffer: Array<Byte>, fn: (CPointer<Byte>, Int64) -> T): T {
        unsafe {
            let bufferAddr = acquireArrayRawData(buffer)
            try{
                let bufferPtr = bufferAddr.pointer
                fn(bufferPtr, buffer.size)
            }finally{
                releaseArrayRawData(bufferAddr)
            }
        }
    }
    /**
     * 返回值是当前映射的内存区域min(剩余可读字节数, buffer.size)
     */
    public func read(buffer: Array<Byte>): Int64 {
        checkReadable()
        access<Int64>(buffer, read)
    }
    /**
     * 如果映射的内存区域剩余可写字节数小于s会抛出异常
     */
    public func write(p: CPointer<Byte>, size: Int64): Unit {
        checkWritable()
        let writeOff = writeOffset_.load()
        let s = opsize(size, writeOff, this.size)
        if (s < size) {
            throw BytePointerException("remainder mmapped size is too small, remainder: ${s}, buffer.size: ${size}")
        }
        access(p, s, false)
        writeOffset_.fetchAdd(s)
    }
    /**
     * 如果映射的内存区域剩余可写字节数小于buffer.size会抛出异常
     */
    public func write(buffer: Array<Byte>): Unit {
        checkWritable()
        access<Unit>(buffer, write)
    }
}