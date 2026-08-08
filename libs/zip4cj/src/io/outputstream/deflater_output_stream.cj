/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

enum OUTPUT <: OutputStream & Resource {
    | DEFLATE(CompressOutputStream)
    | BUFFER(BufferedOutputStream<ICipherOutputStream>)

    public func write(b: Array<UInt8>): Unit {
        match(this) {
            case DEFLATE(v) => v.write(b)
            case BUFFER(v) => v.write(b)
        }
    } 

    public func close(): Unit {
        match(this) {
            case DEFLATE(v) => v.close()
            case BUFFER(v) => v.close()
        }
    }

    public func isClosed(): Bool {
        match(this) {
            case DEFLATE(v) => false
            case BUFFER(v) => v.isClosed()
        }
    }

    public func flush(): Unit {
        match(this) {
            case DEFLATE(v) => v.flush()
            case BUFFER(v) => v.flush()
        }
    }
}

class DeflaterOutputStream <: CompressedOutputStream {
    var deflater: OUTPUT
    public init(cipherOutputStream: ICipherOutputStream, compressionLevel: CompressionLevel, bufferSize: Int64) {
        super(cipherOutputStream)
        this.deflater = match (compressionLevel.getLevel()) {
            case 0 => OUTPUT.BUFFER(BufferedOutputStream<ICipherOutputStream>(cipherOutputStream))
            case 1 | 2 | 3 => OUTPUT.DEFLATE(CompressOutputStream(cipherOutputStream, compressLevel: BestSpeed, bufLen: bufferSize))
            case 4 | 5 | 6 => OUTPUT.DEFLATE(CompressOutputStream(cipherOutputStream, compressLevel: DefaultCompression, bufLen: bufferSize))
            case 7 | 8 | 9 => OUTPUT.DEFLATE(CompressOutputStream(cipherOutputStream, compressLevel: BestCompression, bufLen: bufferSize))
            case _ => throw NoneValueException()
        }
    }

    public func write(b: Array<UInt8>): Unit {
        this.deflater.write(b)
    }

    public func closeEntry(): Unit {
        this.deflater.close()
        super.closeEntry()
    }
}
