/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

abstract class DecompressedInputStream <: InputStream & Resource {
    private var cipherInputStream: ICipherInputStream
    protected var oneByteBuffer: Array<Byte> = Array<Byte>(1, repeat: 0)
    var closed = false
    public init(cipherInputStream: ICipherInputStream) {
        this.cipherInputStream = cipherInputStream
    }

    public open func read(b: Array<Byte>): Int64 {
        return cipherInputStream.read(b)
    }

    public open func close(): Unit {
        cipherInputStream.close()
        closed = true
    }

    public open func isClosed(): Bool {
        if (let Some(v) <- (this.cipherInputStream as Resource)) {
            v.isClosed()
        } else {
            closed
        }
    }

    public open func endOfEntryReached(inputStream: InputStream, numberOfBytesPushedBack: Int64): Unit {
        cipherInputStream.endOfEntryReached(inputStream, numberOfBytesPushedBack)
    }

    public open func pushBackInputStreamIfNecessary(pushbackInputStream: InputStream): Int64 {
        pushbackInputStream
        // Do nothing by default
        return 0
    }

    protected func getLastReadRawDataCache(): Array<Byte> {
        return cipherInputStream.getLastReadRawDataCache()
    }
}
