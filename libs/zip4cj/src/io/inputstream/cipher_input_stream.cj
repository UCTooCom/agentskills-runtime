/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

abstract class ICipherInputStream <: InputStream & Resource {
    protected open func endOfEntryReached(inputStream: InputStream, numberOfBytesPushedBack: Int64): Unit
    public func getLastReadRawDataCache(): Array<Byte>
}

abstract class CipherInputStream<T> <: ICipherInputStream where T <: Decrypter {
    protected var zipEntryInputStream: ZipEntryInputStream
    protected var lastReadRawDataCache: Array<Byte> = InternalZipConstants.NULL_BYTE_ARRAY
    protected var singleByteBuffer: Array<Byte> = Array<Byte>(1, repeat: 0)
    protected var localFileHeader: LocalFileHeader
    protected var password: ?Array<Rune>
    protected var useUtf8ForPassword: Bool
    protected var decrypter: T = unsafe { zeroValue<T>() }
    var closed = false
    public init(
        zipEntryInputStream: ZipEntryInputStream,
        localFileHeader: LocalFileHeader,
        password: ?Array<Rune>,
        bufferSize: Int64,
        useUtf8ForPassword: Bool
    ) {
        this.useUtf8ForPassword = useUtf8ForPassword
        this.password = password
        this.zipEntryInputStream = zipEntryInputStream
        this.localFileHeader = localFileHeader
        if (Zip4cjUtil.getCompressionMethod(localFileHeader).getCode() == (CompressionMethod.DEFLATE).getCode()) {
            lastReadRawDataCache = Array<Byte>(bufferSize, repeat: 0)
        }
    }

    protected func initializeDecrypter(localFileHeader: LocalFileHeader, password: ?Array<Rune>, useUtf8ForPassword: Bool): T

    public open func read(b: Array<Byte>): Int64 {
        return this.read(b, 0, b.size)
    }

    func read(b: Array<Byte>, off: Int64, len: Int64): Int64 {
        var readLen = Zip4cjUtil.readFully(zipEntryInputStream, b, off, len)
        if (readLen > 0) {
            cacheRawData(b, readLen)
            decrypter.decryptData(b[off..off+readLen])
        }
        return readLen
    }

    public open func isClosed():Bool {
        if(let Some(v) <- (zipEntryInputStream as Resource)) {
            v.isClosed()
        } else {
            this.closed
        }
    }

    public open func close(): Unit {
        zipEntryInputStream.close()
        this.closed = true
    }

    public func getLastReadRawDataCache(): Array<Byte> {
        return lastReadRawDataCache
    }

    protected func readRaw(b: Array<Byte>): Int64 {
        return zipEntryInputStream.readRawFully(b)
    }

    private func cacheRawData(b: Array<Byte>, len: Int64): Unit {
        if (!lastReadRawDataCache.isEmpty()) {
            b.copyTo(lastReadRawDataCache, 0, 0, len)
        }
    }

    public func getDecrypter(): T {
        return decrypter
    }

    protected open func endOfEntryReached(inputStream: InputStream, numberOfBytesPushedBack: Int64): Unit {
        (inputStream,numberOfBytesPushedBack )
        // is optional but useful for AES
        return
    }

    protected func getNumberOfBytesReadForThisEntry(): Int64 {
        return zipEntryInputStream.getNumberOfBytesRead()
    }

    public func getLocalFileHeader(): LocalFileHeader {
        return localFileHeader
    }
}
