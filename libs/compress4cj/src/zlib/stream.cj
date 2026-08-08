/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 *
 * Define Stream class
 */
package compress4cj.zlib

/**
 * Streaming Compression/Decompression Base Class.
 *
 * @since 0.28.4
 */
public open class Stream {

    /* Input buffer */
    protected var next_in: Array<UInt8> = NULL_ARR_UINT8

    /* Read cursor in next_in */
    protected var pos_in: Int64 = 0

    /* Number of unread bytes in next_in */
    protected var avail_in: Int64 = 0

    /* Total number of data read from next_in */
    protected var total_in: Int64 = 0

    /* Output buffer */
    protected var next_out: Array<UInt8> = NULL_ARR_UINT8

    /* Write Cursor in next_out */
    protected var pos_out: Int64 = 0

    /* Remaining space in next_out */
    protected var avail_out: Int64 = 0

    /* Total number of next_out data written */
    protected var total_out: Int64 = 0

    /* Error Messages */
    public var message: String = ""

    /*
     * 1. Compression: Compressor guessed raw data type
     * 2. Decompressed: Decoding status
     */
    protected var data_type: Int32 = 0

    /* Original data check value: adler32 check or crc32 check */
    protected var adler: UInt32 = 0

    /**
     * The Function is Stream init constructor
     *
     * @since 0.28.4
     */
    @Frozen
    public init() {}

    /**
     * Check whether the internal input buffer is empty.
     * If yes, set the input data before invoking the deflate/inflate interface.
     *
     * @return The return type of Bool
     * @since 0.28.4
     */
    @Frozen
    public func isInbufEmpty(): Bool {
        return avail_in == 0
    }

    /**
     * Check whether there is data in the output buffer.
     *
     * @return The return type of Bool
     * @since 0.28.4
     */
    @Frozen
    public func isHaveOutData(): Bool {
        return pos_out > 0
    }

    /**
     * The Function is setting input cache
     *
     * @param The parameter type is Array<UInt8>
     *
     * @return Int64 Returns the actual remaining space of the input buffer
     * @since 0.28.4
     */
    @Frozen
    public func setInBuf(buf: Array<UInt8>): Int64 {
        return setInBuf(buf, 0, buf.size)
    }

    /**
     * The Function is setting input cache
     *
     * @param buf Set buf as input buffer
     * @param start Set start to the current cursor position of the input buffer
     * @param len Set len to the space remaining in the input buffer
     *
     * @return Int64 Returns the actual remaining space of the input buffer
     * @since 0.28.4
     */
    @Frozen
    public func setInBuf(buf: Array<UInt8>, start: Int64, len: Int64): Int64 {
        var length: Int64 = len
        if (length < 0 || start > buf.size) {
            return 0
        }
        if (start + length > buf.size) {
            length = buf.size - start
        }
        this.next_in = buf
        this.pos_in = start
        this.avail_in = length
        return length
    }

    /**
     * The Function is setting output cache
     *
     * @param buf Set buf as output buffer
     *
     * @return Int64 Returns the actual remaining space of the output buffer
     * @since 0.28.4
     */
    @Frozen
    public func setOutBuf(buf: Array<UInt8>): Int64 {
        return setOutBuf(buf, 0, buf.size)
    }

    /**
     * The Function is setting output cache
     *
     * @param buf Set buf as output buffer
     * @param start Set start to the current cursor position of the output buffer
     * @param len Set len to the space remaining in the output buffer
     *
     * @return Int64 Returns the actual remaining space of the output buffer
     * @since 0.28.4
     */
    @Frozen
    public func setOutBuf(buf: Array<UInt8>, start: Int64, len: Int64): Int64 {
        var length: Int64 = len
        if (length < 0 || start > buf.size) {
            return 0
        }
        if (start + length > buf.size) {
            length = buf.size - start
        }
        next_out = buf
        pos_out = start
        avail_out = length
        return length
    }

    /**
     * The Function is resetting output buffer state
     *
     * @return Unit The return type of Unit
     * @since 0.28.4
     */
    @Frozen
    public func resetOutBuf(): Unit {
        pos_out = 0
        avail_out = next_out.size
    }

    /**
     * The Function is returnning the length of data in the output buffer
     *
     * @return Int64 Returns the length of data in the output buffer
     * @since 0.28.4
     */
    @Frozen
    public func getOutDataLength(): Int64 {
        return pos_out
    }

    /**
     * The Function is returnning the size of the output data that has been generated so far
     *
     * @return Int64 Returns the total number of output data bytes
     * @since 0.28.4
     */
    @Frozen
    public func getTotalOut(): Int64 {
        return total_out
    }

    /**
     * The Function is returnning the size of the input data consumed so far
     *
     * @return Int64 Returns the total number of bytes of input data
     * @since 0.28.4
     */
    @Frozen
    public func getTotalIn(): Int64 {
        return total_in
    }
}
