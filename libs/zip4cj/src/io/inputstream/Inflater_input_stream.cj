/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

class InflaterInputStream <: DecompressedInputStream {
    private var inflater: DecompressInputStream
    private var buff: Array<Byte>
    private var singleByteBuffer = Array<Byte>(1, repeat: 0)
    private var len: Int64 = 0

    public init(cipherInputStream: ICipherInputStream, bufferSize: Int64) {
        super(cipherInputStream)
        this.inflater = DecompressInputStream(cipherInputStream, bufLen: bufferSize)
        buff = Array<Byte>(bufferSize, repeat: 0)
    }

    public func read(b: Array<Byte>): Int64 {
        return inflater.read(b)
    }

    public func endOfEntryReached(inputStream: InputStream, numberOfBytesPushedBack: Int64) {
        //inflater.end()
        super.endOfEntryReached(inputStream, numberOfBytesPushedBack)
    }

    public func close(): Unit {
        inflater.close()
        super.close()
    }

    private func fill(): Unit {
        len = super.read(buff[0..buff.size])
        if (len == -1) {
            throw Exception("Unexpected end of input stream")
        }
    }
}
