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
import std.fs.*
import std.sync.AtomicInt64
import f_base.*
import f_io.exception.MMapException

/**
 * 内存映射文件，本类没有做并发安全处理
 * 写映射区每次重定位都是mapLength大小
 * 读映射区每次重定位按照mapLength和this.length - offset的大小动态决定
 * 如果file是zeroValue<File>()，按照Anonymous初始化，且offset不生效。
 * 如果file不是zeroValue<File>()，且file.length - offset < mapLength, 文件又以只读方式打开，会抛出异常；此时如果文件可写会自动延长文件长度
 */
@When[os == "Linux"]
public class MMapFile <: Resource & IOStream {
    private static let zeroFile = unsafe { zeroValue<File>() }
    private static let ANONYMOUS_FD = IntNative(-1)
    private let fd: IntNative
    private var dirtyStart = 0i64 // 脏数据起始位置，相对于文件开头是offset + dirtyStart
    private var dirtyBytes = 0i64 // 脏数据大小

    private let pointer: CPointer<Unit>
    private let ptrStream: BytePointerStream

    private var closed = false

    MMapFile(
        private let file: File,
        private let prots: Array<MMapProt>,
        private let flag!: MMapFlag = MMapFlag.Private,
        private let offset!: Int64 = 0,
        private let mapLength!: Int64 = DEFAULT_MMAP_BYTES
    ) {
        let protBits = prots.combine()
        let readable = MMapProt.Read & protBits
        let writable = MMapProt.Write & protBits
        let flags: IntNative
        (this.fd, flags) = if (!isZeroFile(file)) {
            if (writable && offset + mapLength > file.length) {
                file.setLength(offset + mapLength)
            } else {
                throw MMapException(
                    'file ${file.info.path} is not writable but the file length - offset(${file.length} - ${offset}) is less than mapLength ${mapLength}')
            }
            (file.fileDescriptor.fileHandle, flag.value)
        } else {
            (ANONYMOUS_FD, flag.value | MMapFlag.Anonymous.value)
        }
        pointer = unsafe {
            mmap(nullptr, UIntNative(mapLength), protBits, flags, fd, if (fd == ANONYMOUS_FD) {
                0
            } else {
                IntNative(offset)
            })
        }
        this.ptrStream = BytePointerStream(CPointer<Byte>(pointer), mapLength, readable: readable,
            writable: writable)
    }
    public static func anonymous(prots: Array<MMapProt>, flag!: MMapFlag = MMapFlag.Private,
        mapLength!: Int64 = DEFAULT_MMAP_BYTES) {
        MMapFile(zeroFile, prots, flag: flag, mapLength: mapLength)
    }
    private static func isZeroFile(file: File) {
        refEq(file, zeroFile)
    }
    private func isNullPointer(pointer: CPointer<Unit>) {
        pointer.toUIntNative() == nullptr.toUIntNative()
    }
    public prop info: FileInfo {
        get(){
            file.info
        }
    }
    public prop isReadable: Bool {
        get() {
            ptrStream.readable
        }
    }
    public prop isWritable: Bool {
        get() {
            ptrStream.writable
        }
    }
    public prop isSyncable: Bool {
        get() {
            !(this.flag.isPrivate || this.isAnonymous)
        }
    }
    public prop isAnonymous: Bool {
        get() {
            this.fd == ANONYMOUS_FD
        }
    }
    /**
     * 相对文件头的读偏移量
     */
    public mut prop readOffset: Int64 {
        get(){
            offset + ptrStream.readOffset
        }
        set(value){
            ptrStream.readOffset = value - offset
        }
    }
    /**
     * 相对文件头的写偏移量
     */
    public mut prop writeOffset: Int64 {
        get(){
            offset + ptrStream.writeOffset
        }
        set(value){
            ptrStream.writeOffset = value - offset
        }
    }
    /**
     * 同步内存映射区域到磁盘，取消映射，不关闭文件
     */
    public func syncAndUnmap(): Unit {
        sync()
        unmap()
    }
    private func unmap() {
        unsafe {
            munmap(pointer, UIntNative(mapLength))
        }
    }

    /**
     * 使用指定的flag将未同步数据同步到磁盘。
     */
    public func sync(flag: MSyncFlag) {
        if (!isSyncable) {
            throw MMapException("current mmap can not sync, due to it is Anonymous or Private.")
        }
        unsafe {
            let syncStart = (dirtyStart / MEM_PAGE_SIZE) * MEM_PAGE_SIZE
            msync(ptrStream.pointerOffset(syncStart), UIntNative(dirtyBytes + dirtyStart % MEM_PAGE_SIZE), flag.value)
        }
    }
    private func sync() {
        if (dirtyBytes > 0 && isSyncable) {
            sync(MSyncFlag.Sync)
            dirtyStart += dirtyBytes
            dirtyBytes = 0
        }
    }
    private func extract(ex: ?MMapException, caused: Exception) {
        match (ex) {
            case Some(e) =>
                e.addSuppressed(caused)
                e
            case _ => MMapException(caused)
        }
    }
    /**
     * 使用指定参数重映射。offset是文件开头的偏移量。mapLength是映射的内存大小，默认是当前的mapLength
     */
    public func remap(offset: Int64, mapLength!: Int64 = this.mapLength, flag!: MMapFlag = this.flag): MMapFile {
        sync()
        unmap()
        if (isAnonymous) {
            MMapFile(file, prots, flag: flag, offset: offset, mapLength: mapLength)
        } else {
            file.mmap(offset, mapLength, flag: flag)
        }
    }
    
    public func isClosed() {
        closed
    }
    /**
     * 同步内存映射区域到磁盘，取消映射，关闭文件
     */
    public func close() {
        closed = true
        var ex = None<MMapException>
        try {
            sync()
        } catch (e: Exception) {
            ex = extract(ex, e)
        }
        try {
            unmap()
        } catch (e: Exception) {
            ex = extract(ex, e)
        }
        try {
            if (!isAnonymous) {
                file.close()
            }
        } catch (e: Exception) {
            ex = extract(ex, e)
        }
        if (let Some(e) <- ex) {
            throw e
        }
    }
    /**
     * 映射内存的大小
     */
    public prop length: Int64 {
        get() {
            mapLength
        }
    }
    public func setLength(length!: Int64 = this.writeOffset) {
        if(!isAnonymous){
            file.setLength(length)
        }
    }
    private func checkWritable() {
        if (!isWritable) {
            if (isAnonymous) {
                throw MMapException('current MMapFile is not writable and it is Anonymous')
            }
            throw MMapException('current MMapFile is not writable ${file.info.path}')
        }
    }
    private func checkReadable() {
        if (!isReadable) {
            if (isAnonymous) {
                throw MMapException('current MMapFile is not readable and it is Anonymous')
            }
            throw MMapException('current MMapFile is not readable ${file.info.path}')
        }
    }
    /**
     * 返回值是当前映射的内存区域min(剩余可读字节数, maxSize)
     */
    public func read(p: CPointer<Byte>, maxSize: Int64): Int64 {
        checkReadable()
        ptrStream.read(p, maxSize)
    }
    /**
     * 返回值是当前映射的内存区域min(剩余可读字节数, buffer.size)
     */
    public func read(buffer: Array<Byte>): Int64 {
        checkReadable()
        ptrStream.read(buffer)
    }
    /**
     * 如果映射的内存区域剩余可写字节数小于s会抛出异常
     */
    public func write(p: CPointer<Byte>, s: Int64): Unit {
        checkWritable()
        ptrStream.write(p, s)
    }
    /**
     * 如果映射的内存区域剩余可写字节数小于buffer.size会抛出异常
     */
    public func write(buffer: Array<Byte>): Unit {
        checkWritable()
        ptrStream.write(buffer)
    }
    /**
     * 使用MSyncFlag.Sync将未同步数据同步到磁盘，如果当前映射是Anonmous则抛出异常
     */
    public func flush(): Unit {
        sync()
    }
}

@When[os == "Linux"]
public interface ToMMap {
    /**
     * 用此函数创建的内存映射文件只有读写两个prot，与当前File实例的可读可写属性一致。File扩展此接口
     */
    func mmap(offset: Int64, mapLength: Int64, flag!: MMapFlag): MMapFile
}

@When[os == "Linux"]
extend File <: ToMMap {
    public func mmap(offset: Int64, mapLength: Int64, flag!: MMapFlag = MMapFlag.Private): MMapFile {
        let prots = if (this.canRead() && this.canWrite()) {
            [MMapProt.Read, MMapProt.Write]
        } else if (this.canRead()) {
            [MMapProt.Read]
        } else if (this.canWrite()) {
            [MMapProt.Write]
        } else {
            throw IOException("file ${canonicalize(this.info.path)} cannot be read and written")
        }
        MMapFile(this, prots, offset: offset, mapLength: mapLength, flag: flag)
    }
}
