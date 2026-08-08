/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

abstract class ICipherOutputStream <: OutputStream & Resource {

    public func write(b: Array<UInt8>): Unit

    public func writeHeaders(b: Array<UInt8>): Unit

    public func closeEntry(): Unit
    
    public func close(): Unit

    public func isClosed(): Bool

    public func getNumberOfBytesWrittenForThisEntry(): Int64 
}

abstract class CipherOutputStream<T> <: ICipherOutputStream where T <: Encrypter {
    protected var outputStream: ZipEntryOutputStream
    protected var zipParameters: ZipParameters
    protected var password: ?Array<Rune>
    protected var useUtf8ForPassword: Bool
    protected var encrypter: T = unsafe { zeroValue<T>() }
    var closed = false
    public init(
        zipEntryOutputStream: ZipEntryOutputStream,
        zipParameters: ZipParameters,
        password: ?Array<Rune>,
        useUtf8ForPassword: Bool
    ) {
        this.outputStream = zipEntryOutputStream
        this.zipParameters = zipParameters
        this.password = password
        this.useUtf8ForPassword = useUtf8ForPassword
    }

    protected func initializeEncrypter(
        outputStream: OutputStream,
        zipParameters: ZipParameters,
        password: ?Array<Rune>,
        useUtf8ForPassword: Bool
    ): T 

    public open func write(b: Array<UInt8>): Unit {
        encrypter.encryptData(b)
        this.outputStream.write(b)
    }

    public open func writeHeaders(b: Array<UInt8>): Unit {
        this.outputStream.write(b)
    }

    public open func closeEntry(): Unit {
        this.outputStream.closeEntry()
    }

    public open func close(): Unit {
        this.outputStream.close()
        closed = true
    }

    public open func isClosed(): Bool {
        if (let Some(v) <- (outputStream as Resource)){
            v.isClosed()
        } else {
            closed
        }
    }

    public open func getNumberOfBytesWrittenForThisEntry(): Int64 {
        return this.outputStream.getNumberOfBytesWrittenForThisEntry()
    }

    protected open func getEncrypter(): T {
        return encrypter
    }

    public open func flush(): Unit {
        return
    }
}
