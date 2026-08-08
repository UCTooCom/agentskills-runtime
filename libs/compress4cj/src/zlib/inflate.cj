/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2021-2025. All rights reserved.
 */

/**
 * @file
 *
 * This is a class library that implements the function of decompressing data.
 * Provides stream decompression interfaces such as inflateInit, inflate, inflateEnd, getGzipHeader, and setDictionary.
 */
package compress4cj.zlib

/* Some constants */
let ENOUGH_LENS: UInt32 = 852
let ENOUGH_DISTS: UInt32 = 592

let MAXBITS: Int64 = 15

let TYPE_CODES: UInt32 = 1
let TYPE_LENS: UInt32  = 2
let TYPE_DISTS: UInt32 = 3

/* Decompression status */
let HEAD: UInt32     = 0
let FLAGS: UInt32    = 1
let TIME: UInt32     = 2
let OS: UInt32       = 3
let EXLEN: UInt32    = 4
let EXTRA: UInt32    = 5
let NAME: UInt32     = 6
let COMMENT: UInt32  = 7
let HCRC: UInt32     = 8
let DICTID: UInt32   = 9
let DICT: UInt32     = 10
let TYPE: UInt32     = 11
let TYPEDO: UInt32   = 12
let STORED: UInt32   = 13
let COPY_: UInt32    = 14
let COPY: UInt32     = 15
let TABLE: UInt32    = 16
let LENLENS: UInt32  = 17
let CODELENS: UInt32 = 18
let LEN_: UInt32     = 19
let LEN: UInt32      = 20
let LENEXT: UInt32   = 21
let DIST: UInt32     = 22
let DISTEXT: UInt32  = 23
let MATCH: UInt32    = 24
let LIT: UInt32      = 25
let CHECK: UInt32    = 26
let LENGTH: UInt32   = 27
let DONE: UInt32     = 28
let BAD: UInt32      = 29
let MEM: UInt32      = 30
let SYNC: UInt32     = 31

struct Code {
    /*
     * Option value description:
     * 00000000 - Original characters from 0 - 255
     * 0000tttt - Level-2 table link. tttt != 0 indicates the start position of the level-2 table.
     * 0001eeee - Length, distance, or eeee indicates the number of digits occupied by the extended value.
     * 01100000 - block terminator
     * 01000000 - Invalid value.
     */
    public Code(var option: UInt8, var bits: UInt8, var value: UInt16) {}
}

/* Static decompression code table of the literal length */
let lenfix: Array<Code> = [
    Code(96,7,0), Code(0,8,80), Code(0,8,16), Code(20,8,115), Code(18,7,31), Code(0,8,112), Code(0,8,48), Code(0,9,192),
    Code(16,7,10), Code(0,8,96), Code(0,8,32), Code(0,9,160), Code(0,8,0), Code(0,8,128), Code(0,8,64), Code(0,9,224),
    Code(16,7,6), Code(0,8,88), Code(0,8,24), Code(0,9,144), Code(19,7,59), Code(0,8,120), Code(0,8,56), Code(0,9,208),
    Code(17,7,17), Code(0,8,104), Code(0,8,40), Code(0,9,176), Code(0,8,8), Code(0,8,136), Code(0,8,72), Code(0,9,240),
    Code(16,7,4), Code(0,8,84), Code(0,8,20), Code(21,8,227), Code(19,7,43), Code(0,8,116), Code(0,8,52), Code(0,9,200),
    Code(17,7,13), Code(0,8,100), Code(0,8,36), Code(0,9,168), Code(0,8,4), Code(0,8,132), Code(0,8,68), Code(0,9,232),
    Code(16,7,8), Code(0,8,92), Code(0,8,28), Code(0,9,152), Code(20,7,83), Code(0,8,124), Code(0,8,60), Code(0,9,216),
    Code(18,7,23), Code(0,8,108), Code(0,8,44), Code(0,9,184), Code(0,8,12), Code(0,8,140), Code(0,8,76), Code(0,9,248),
    Code(16,7,3), Code(0,8,82), Code(0,8,18), Code(21,8,163), Code(19,7,35), Code(0,8,114), Code(0,8,50), Code(0,9,196),
    Code(17,7,11), Code(0,8,98), Code(0,8,34), Code(0,9,164), Code(0,8,2), Code(0,8,130), Code(0,8,66), Code(0,9,228),
    Code(16,7,7), Code(0,8,90), Code(0,8,26), Code(0,9,148), Code(20,7,67), Code(0,8,122), Code(0,8,58), Code(0,9,212),
    Code(18,7,19), Code(0,8,106), Code(0,8,42), Code(0,9,180), Code(0,8,10), Code(0,8,138), Code(0,8,74), Code(0,9,244),
    Code(16,7,5), Code(0,8,86), Code(0,8,22), Code(64,8,0), Code(19,7,51), Code(0,8,118), Code(0,8,54), Code(0,9,204),
    Code(17,7,15), Code(0,8,102), Code(0,8,38), Code(0,9,172), Code(0,8,6), Code(0,8,134), Code(0,8,70), Code(0,9,236),
    Code(16,7,9), Code(0,8,94), Code(0,8,30), Code(0,9,156), Code(20,7,99), Code(0,8,126), Code(0,8,62), Code(0,9,220),
    Code(18,7,27), Code(0,8,110), Code(0,8,46), Code(0,9,188), Code(0,8,14), Code(0,8,142), Code(0,8,78), Code(0,9,252),
    Code(96,7,0), Code(0,8,81), Code(0,8,17), Code(21,8,131), Code(18,7,31), Code(0,8,113), Code(0,8,49), Code(0,9,194),
    Code(16,7,10), Code(0,8,97), Code(0,8,33), Code(0,9,162), Code(0,8,1), Code(0,8,129), Code(0,8,65), Code(0,9,226),
    Code(16,7,6), Code(0,8,89), Code(0,8,25), Code(0,9,146), Code(19,7,59), Code(0,8,121), Code(0,8,57), Code(0,9,210),
    Code(17,7,17), Code(0,8,105), Code(0,8,41), Code(0,9,178), Code(0,8,9), Code(0,8,137), Code(0,8,73), Code(0,9,242),
    Code(16,7,4), Code(0,8,85), Code(0,8,21), Code(16,8,258), Code(19,7,43), Code(0,8,117), Code(0,8,53), Code(0,9,202),
    Code(17,7,13), Code(0,8,101), Code(0,8,37), Code(0,9,170), Code(0,8,5), Code(0,8,133), Code(0,8,69), Code(0,9,234),
    Code(16,7,8), Code(0,8,93), Code(0,8,29), Code(0,9,154), Code(20,7,83), Code(0,8,125), Code(0,8,61), Code(0,9,218),
    Code(18,7,23), Code(0,8,109), Code(0,8,45), Code(0,9,186), Code(0,8,13), Code(0,8,141), Code(0,8,77), Code(0,9,250),
    Code(16,7,3), Code(0,8,83), Code(0,8,19), Code(21,8,195), Code(19,7,35), Code(0,8,115), Code(0,8,51), Code(0,9,198),
    Code(17,7,11), Code(0,8,99), Code(0,8,35), Code(0,9,166), Code(0,8,3), Code(0,8,131), Code(0,8,67), Code(0,9,230),
    Code(16,7,7), Code(0,8,91), Code(0,8,27), Code(0,9,150), Code(20,7,67), Code(0,8,123), Code(0,8,59), Code(0,9,214),
    Code(18,7,19), Code(0,8,107), Code(0,8,43), Code(0,9,182), Code(0,8,11), Code(0,8,139), Code(0,8,75), Code(0,9,246),
    Code(16,7,5), Code(0,8,87), Code(0,8,23), Code(64,8,0), Code(19,7,51), Code(0,8,119), Code(0,8,55), Code(0,9,206),
    Code(17,7,15), Code(0,8,103), Code(0,8,39), Code(0,9,174), Code(0,8,7), Code(0,8,135), Code(0,8,71), Code(0,9,238),
    Code(16,7,9), Code(0,8,95), Code(0,8,31), Code(0,9,158), Code(20,7,99), Code(0,8,127), Code(0,8,63), Code(0,9,222),
    Code(18,7,27), Code(0,8,111), Code(0,8,47), Code(0,9,190), Code(0,8,15), Code(0,8,143), Code(0,8,79), Code(0,9,254),
    Code(96,7,0), Code(0,8,80), Code(0,8,16), Code(20,8,115), Code(18,7,31), Code(0,8,112), Code(0,8,48), Code(0,9,193),
    Code(16,7,10), Code(0,8,96), Code(0,8,32), Code(0,9,161), Code(0,8,0), Code(0,8,128), Code(0,8,64), Code(0,9,225),
    Code(16,7,6), Code(0,8,88), Code(0,8,24), Code(0,9,145), Code(19,7,59), Code(0,8,120), Code(0,8,56), Code(0,9,209),
    Code(17,7,17), Code(0,8,104), Code(0,8,40), Code(0,9,177), Code(0,8,8), Code(0,8,136), Code(0,8,72), Code(0,9,241),
    Code(16,7,4), Code(0,8,84), Code(0,8,20), Code(21,8,227), Code(19,7,43), Code(0,8,116), Code(0,8,52), Code(0,9,201),
    Code(17,7,13), Code(0,8,100), Code(0,8,36), Code(0,9,169), Code(0,8,4), Code(0,8,132), Code(0,8,68), Code(0,9,233),
    Code(16,7,8), Code(0,8,92), Code(0,8,28), Code(0,9,153), Code(20,7,83), Code(0,8,124), Code(0,8,60), Code(0,9,217),
    Code(18,7,23), Code(0,8,108), Code(0,8,44), Code(0,9,185), Code(0,8,12), Code(0,8,140), Code(0,8,76), Code(0,9,249),
    Code(16,7,3), Code(0,8,82), Code(0,8,18), Code(21,8,163), Code(19,7,35), Code(0,8,114), Code(0,8,50), Code(0,9,197),
    Code(17,7,11), Code(0,8,98), Code(0,8,34), Code(0,9,165), Code(0,8,2), Code(0,8,130), Code(0,8,66), Code(0,9,229),
    Code(16,7,7), Code(0,8,90), Code(0,8,26), Code(0,9,149), Code(20,7,67), Code(0,8,122), Code(0,8,58), Code(0,9,213),
    Code(18,7,19), Code(0,8,106), Code(0,8,42), Code(0,9,181), Code(0,8,10), Code(0,8,138), Code(0,8,74), Code(0,9,245),
    Code(16,7,5), Code(0,8,86), Code(0,8,22), Code(64,8,0), Code(19,7,51), Code(0,8,118), Code(0,8,54), Code(0,9,205),
    Code(17,7,15), Code(0,8,102), Code(0,8,38), Code(0,9,173), Code(0,8,6), Code(0,8,134), Code(0,8,70), Code(0,9,237),
    Code(16,7,9), Code(0,8,94), Code(0,8,30), Code(0,9,157), Code(20,7,99), Code(0,8,126), Code(0,8,62), Code(0,9,221),
    Code(18,7,27), Code(0,8,110), Code(0,8,46), Code(0,9,189), Code(0,8,14), Code(0,8,142), Code(0,8,78), Code(0,9,253),
    Code(96,7,0), Code(0,8,81), Code(0,8,17), Code(21,8,131), Code(18,7,31), Code(0,8,113), Code(0,8,49), Code(0,9,195),
    Code(16,7,10), Code(0,8,97), Code(0,8,33), Code(0,9,163), Code(0,8,1), Code(0,8,129), Code(0,8,65), Code(0,9,227),
    Code(16,7,6), Code(0,8,89), Code(0,8,25), Code(0,9,147), Code(19,7,59), Code(0,8,121), Code(0,8,57), Code(0,9,211),
    Code(17,7,17), Code(0,8,105), Code(0,8,41), Code(0,9,179), Code(0,8,9), Code(0,8,137), Code(0,8,73), Code(0,9,243),
    Code(16,7,4), Code(0,8,85), Code(0,8,21), Code(16,8,258), Code(19,7,43), Code(0,8,117), Code(0,8,53), Code(0,9,203),
    Code(17,7,13), Code(0,8,101), Code(0,8,37), Code(0,9,171), Code(0,8,5), Code(0,8,133), Code(0,8,69), Code(0,9,235),
    Code(16,7,8), Code(0,8,93), Code(0,8,29), Code(0,9,155), Code(20,7,83), Code(0,8,125), Code(0,8,61), Code(0,9,219),
    Code(18,7,23), Code(0,8,109), Code(0,8,45), Code(0,9,187), Code(0,8,13), Code(0,8,141), Code(0,8,77), Code(0,9,251),
    Code(16,7,3), Code(0,8,83), Code(0,8,19), Code(21,8,195), Code(19,7,35), Code(0,8,115), Code(0,8,51), Code(0,9,199),
    Code(17,7,11), Code(0,8,99), Code(0,8,35), Code(0,9,167), Code(0,8,3), Code(0,8,131), Code(0,8,67), Code(0,9,231),
    Code(16,7,7), Code(0,8,91), Code(0,8,27), Code(0,9,151), Code(20,7,67), Code(0,8,123), Code(0,8,59), Code(0,9,215),
    Code(18,7,19), Code(0,8,107), Code(0,8,43), Code(0,9,183), Code(0,8,11), Code(0,8,139), Code(0,8,75), Code(0,9,247),
    Code(16,7,5), Code(0,8,87), Code(0,8,23), Code(64,8,0), Code(19,7,51), Code(0,8,119), Code(0,8,55), Code(0,9,207),
    Code(17,7,15), Code(0,8,103), Code(0,8,39), Code(0,9,175), Code(0,8,7), Code(0,8,135), Code(0,8,71), Code(0,9,239),
    Code(16,7,9), Code(0,8,95), Code(0,8,31), Code(0,9,159), Code(20,7,99), Code(0,8,127), Code(0,8,63), Code(0,9,223),
    Code(18,7,27), Code(0,8,111), Code(0,8,47), Code(0,9,191), Code(0,8,15), Code(0,8,143), Code(0,8,79), Code(0,9,255)
]

/* Distance static decompression code table */
let distfix: Array<Code> = [
    Code(16,5,1), Code(23,5,257), Code(19,5,17), Code(27,5,4097), Code(17,5,5), Code(25,5,1025), Code(21,5,65), Code(29,5,16385),
    Code(16,5,3), Code(24,5,513), Code(20,5,33), Code(28,5,8193), Code(18,5,9), Code(26,5,2049), Code(22,5,129), Code(64,5,0),
    Code(16,5,2), Code(23,5,385), Code(19,5,25), Code(27,5,6145), Code(17,5,7), Code(25,5,1537), Code(21,5,97), Code(29,5,24577),
    Code(16,5,4), Code(24,5,769), Code(20,5,49), Code(28,5,12289), Code(18,5,13), Code(26,5,3073), Code(22,5,193), Code(64,5,0)
]

let lbase: Array<UInt16> = [
    3,  4,  5,  6,  7,  8,  9,  10,  11,  13,  15,  17,  19,  23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0,  0
]

let lext: Array<UInt16> = [
    16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 18, 18,  18, 18,
    19, 19, 19, 19, 20, 20, 20, 20, 21, 21, 21, 21, 16, 198, 196
]

let dbase: Array<UInt16> = [
    1,   2,   3,   4,   5,    7,    9,    13,   17,   25,   33,   49,    65,    97,    129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577, 0,   0
]

let dext: Array<UInt16> = [
    16, 16, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22,
    23, 23, 24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 64, 64
]

public class Inflate <: Stream {

    /* Current Decompression Status */
    private var mode: UInt32 = HEAD

    /* Last compressed block flag */
    private var last: Bool = false

    /* Data wrapper type: ZLIB, GZIP, or DEFLATE (without wrapper) */
    private var wrap: Int64 = ZLIB

    /* Whether a dictionary is required */
    private var havedict: Bool = false
    private var flags: Int32 = -1
    private var dmax: UInt32 = 32768
    private var check: UInt32 = 0

    /* Check the verification value */
    private var total: Int64 = 0
    private var head: ?GZIPHeader = None
    private var wbits: Int32 = 0
    private var wsize: UInt32 = 0
    private var whave: UInt32 = 0
    private var wnext: UInt32 = 0
    private var window: Array<UInt8> = NULL_ARR_UINT8
    private var hold: UInt32 = 0
    private var bits: UInt32 = 0
    private var length: UInt32 = 0
    private var offset: UInt32 = 0
    private var extra: UInt32 = 0
    private var lencodes: Array<Code> = NULL_ARR_Code
    private var distcodes: Array<Code> = NULL_ARR_Code
    private var lendyn: Array<Code> = NULL_ARR_Code
    private var distdyn: Array<Code> = NULL_ARR_Code
    private var lenbits: UInt32 = 0
    private var distbits: UInt32 = 0
    private var ncode: UInt32 = 0
    private var nlen: UInt32 = 0
    private var ndist: UInt32 = 0
    private var have: UInt32 = 0
    private var codelens: Array<UInt16> = NULL_ARR_UINT16
    private var work: Array<UInt16> = NULL_ARR_UINT16
    private var back: Int32 = -1
    private var was: UInt32 = 0
    private var hbuf: Array<UInt8> = Array<UInt8>(4, repeat: 0)
    private var finished = false
    var initout: Int64 = 0
    public init (wrap: Int64) {
        this(15, wrap)
    }

    @Frozen
    public init (wbits: Int64, wrap: Int64) {
        var nowrap = false
        var w = wbits
        if (wrap <= 0) {
            nowrap = true
        } else if (wrap == 1) {

        } else if (wrap == 2) {
           w = w + 16
        } else {
            nowrap = true
        }
        if (nowrap) {
            this.inflateInit2(-Int32(w))
        } else {
            this.inflateInit2(Int32(w))
        }
    }
    @Frozen
    public init() {
    }

    @Frozen
    public func end(): Unit {
        finished = true;
        this
    }

    @Frozen
    public func inflateInit(): Int32 {
        return inflateInit2(Int32(DEF_WINDOW_BITS))
    }

    @Frozen
    public func inflateInit2(wbits: Int32): Int32 {
        return inflateReset2(wbits)
    }

    @Frozen
    func inflateReset2(wbits: Int32): Int32 {
        var windowBits = wbits
        var wraps = 0
        if (windowBits < 0) {
            if (windowBits < -15) {
                return Z_STREAM_ERROR
            }
            wraps = 0;
            windowBits = -windowBits
        } else {
            wraps = Int64((windowBits >> 4) + 5)
            if (windowBits < 48) {
                windowBits &= 15
            }
        }
        if (windowBits != 0 && (windowBits < 8 || windowBits > 15)) {
            return Z_STREAM_ERROR
        }
        this.wbits = windowBits
        this.wrap = wraps
        inflateReset()
        try {
            window = Array<UInt8>(Int64(wsize), repeat: 0)
            lendyn = Array<Code>(Int64(ENOUGH_LENS), {_ => Code(0,0,0)})
            distdyn = Array<Code>(Int64(ENOUGH_DISTS), {_ => Code(0,0,0)})
            codelens = Array<UInt16>(320, repeat: 0)
            work = Array<UInt16>(288, repeat: 0)
        } catch (e: Exception) {
            message = erroMsg(Z_MEM_ERROR)
            return Z_MEM_ERROR
        }
        return Z_OK
    }

    @Frozen
    func CRC2(check: UInt32, word: UInt32): UInt32 {
        this.hbuf[0] = UInt8(word & 0xFF)
        this.hbuf[1] = UInt8(((word) >> 8) & 0xFF)
        return crc32(check, this.hbuf, 0, 2)
    }

    @Frozen
    func CRC4(check: UInt32, word: UInt32): UInt32 {
        this.hbuf[0] = UInt8(word & 0xFF)
        this.hbuf[1] = UInt8(((word) >> 8) & 0xFF)
        this.hbuf[2] = UInt8(((word) >> 16) & 0xFF)
        this.hbuf[3] = UInt8(((word) >> 24) & 0xFF)
        return crc32(check, this.hbuf, 0, 4)
    }

    /**
     * Decompressing Data.
     *
     * @param flush Decompressing Data.
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func inflate(flush: Int32): Int32 {
        message = ""
        if (mode == TYPE) {
            mode = TYPEDO
        }
        var ret: Int32 = Z_OK
        var len: UInt32 = 0
        var copy: Int64 = 0
        var copyfrom: Int64 = 0
        var copybuf: Array<UInt8> = NULL_ARR_UINT8
        var here: Code = Code(0,0,0)
        var link: Code = Code(0,0,0)
        var buf: Array<UInt8>
        var error: Bool
        if (mode != CHECK) {
            initout = avail_out
        }
        var initin: Int64 = avail_in
        while (true) {
            if(mode == HEAD) {
                /* Format of the parsing header: zlib gzip deflate */
                if (wrap == DEFLATE) {
                    mode = TYPEDO
                    continue
                }
                if (needBits(16)) {
                    return Z_BUF_ERROR
                }
                if ((wrap & 2) != 0 && hold == 0x8B1F) {
                    if (wbits == 0) {
                        wbits = 15
                    }
                    check = DEFAULT_CRC32
                    buf = [UInt8(hold & 0xFF), UInt8((hold >> 8) & 0xFF)]
                    check = CRC2(this.check, hold)
                    initBits()
                    mode = FLAGS
                    continue
                }
                if (let Some(v) <- head) {
                    v.done = -1
                }
                if ((wrap & 1) != 0) {
                    if ((((getBits(8) << 8) + (hold >> 8)) % 31) != 0) {
                        message = "incorrect header check"
                        mode = BAD
                        continue
                    }
                    if (getBits(4) != METHOD_DEFLATE) {
                        message = "unknown compression method"
                        mode = BAD
                        continue
                    }
                }
                dropBits(4)
                len = getBits(4) + 8
                if (wbits == 0) {
                    wbits = Int32(len)
                }
                if (len > 15 || Int32(len) > wbits) {
                    message = "invalid window size"
                    mode = BAD
                    continue
                }
                dmax = 1 << len
                flags = 0          /* indicate zlib header */
                check = DEFAULT_ADLER32
                adler = check
                mode = if ((hold & 0x200) != 0) {
                    DICTID
                } else {
                    TYPE
                }
                initBits()
            }
            // #ifdef GUNZIP
            if (mode == FLAGS) {
                if (needBits(16)) {
                    return Z_BUF_ERROR
                }
                flags = Int32(hold)
                if (UInt32(flags & 0xFF) != METHOD_DEFLATE) {
                    message = "unknown compression method"
                    mode = BAD
                    continue
                }
                if ((flags & 0xE000) != 0) {
                    message = "unknown header flags set"
                    mode = BAD
                    continue
                }
                if (let Some(v) <- head) {
                    v.text = Int32((hold >> 8) & 1)
                }
                if ((flags & 0x0200) != 0 && (this.wrap & 4) != 0) {
                    buf = [UInt8(hold & 0xFF), UInt8((hold >> 8) & 0xFF)]
                    check = CRC2(this.check, hold)
                }
                initBits()
                mode = TIME
            }
            if (mode == TIME) {
                if (needBits(32)) {
                    return Z_BUF_ERROR
                }
                if (let Some(v) <- head) {
                    v.time = Int64(hold)
                }
                if ((this.wrap & 4) != 0 && (flags & 0x0200) != 0) {
                    buf = [UInt8(hold & 0xFF), UInt8((hold >> 8) & 0xFF), UInt8((hold >> 16) & 0xFF), UInt8((hold >> 24) & 0xFF)]
                    check = CRC4(this.check, hold)
                }
                initBits()
                mode = OS
            }
            if (mode == OS) {
                if (needBits(16)) {
                    return Z_BUF_ERROR
                }
                if (let Some(v) <- head) {
                    v.xflags = Int32(hold & 0xFF)
                    v.os = Int32(hold >> 8)
                }
                if ((this.wrap & 4) != 0 && (flags & 0x0200) != 0) {
                    buf = [UInt8(hold & 0xFF), UInt8((hold >> 8) & 0xFF)]
                    check = CRC2(this.check, hold)
                }
                initBits()
                mode = EXLEN
            }
            if (mode == EXLEN) {
                if ((flags & 0x0400) != 0) {
                    if (needBits(16)) {
                        return Z_BUF_ERROR
                    }
                    length = hold
                    if (let Some(v) <- head) {
                        v.extra_len = hold
                    }
                    if ((this.wrap & 4) != 0 && (flags & 0x0200) != 0) {
                        buf = [UInt8(hold & 0xFF), UInt8((hold >> 8) & 0xFF)]
                        check = CRC2(this.check, hold)
                    }
                    initBits()
                } else {
                    if (let Some(v) <- head) {
                        v.extra = NULL_ARR_UINT8
                    }
                }
                mode = EXTRA
            }
            if (mode == EXTRA) {
                if ((flags & 0x0400) != 0) {
                    copy = Int64(length)
                    if (copy > avail_in) {
                        copy = avail_in
                    }
                    if (copy != 0) {
                        if (let Some(v) <- head) {
                            if (let Some(w) <- v.extra) {
                                let len = (v.extra_len) - (length)
                                if (len < v.extra_max) {
                                    for (i in 0..copy) {
                                        w[Int64(len) + i] = next_in[pos_in]
                                        pos_in++
                                    }
                                }
                            }
                        }

                        if ((this.wrap & 4) != 0 && (flags & 0x0200) != 0) {
                            check = crc32(check, next_in, pos_in - copy, copy)
                        }
                        avail_in -= copy
                        length -= UInt32(copy)
                    }
                    if (length != 0) {
                        break
                    }
                }
                length = 0
                mode = NAME
            }
            if (mode == NAME) {
                if ((flags & 0x0800) != 0) {
                    if (avail_in == 0) {
                        break // TODO
                    }
                    copy = 0
                    do {
                        len = UInt32(next_in[pos_in + copy])
                        copy++
                        if (let Some(v) <- head) {
                            if (let Some(w) <- v.name) {
                                w[Int64(this.length)] = UInt8(len & 0xFF)
                                this.length++
                            }
                        }
                    } while (len != 0 && copy < Int64(have))
                    if ((this.wrap & 4) != 0 && (flags & 0x0200) != 0) {
                        check = crc32(check, next_in, pos_in, copy)
                    }
                    avail_in -= copy
                    pos_in += copy
                    if (len != 0) {
                        break// TODO goto inf_leave
                    }
                } else {
                    if (let Some(v) <- head) {
                        v.name = NULL_ARR_UINT8
                    }
                }
                length = 0
                mode = COMMENT
            }
            if (mode == COMMENT) {
                if ((flags & 0x1000) != 0) {
                    if (avail_in == 0) {
                        break // TODO
                    }
                    copy = 0
                    do {
                        len = UInt32(next_in[pos_in + copy])
                        copy++
                        if (let Some(v) <- head) {
                            if (let Some(w) <- v.comment) {
                                if (this.length < v.comm_max) {
                                    w[Int64(this.length)] = UInt8(len & 0xFF)
                                    this.length++
                                }
                            }
                        }
                    } while(len != 0 && copy < Int64(have))
                    if ((this.wrap & 4) != 0 && (flags & 0x0200) != 0) {
                        check = crc32(check, next_in, pos_in, copy)
                    }
                    avail_in -= copy
                    pos_in += copy
                    if (len != 0) {
                        break// TODO goto inf_leave
                    }
                } else {
                    if (let Some(v) <- head) {
                        v.comment = NULL_ARR_UINT8
                    }
                }
                length = 0
                mode = HCRC
            }
            if (mode == HCRC) {
                if ((flags & 0x0200) != 0) {
                    if ( needBits(16)){
                        return Z_BUF_ERROR
                    }
                    if ((this.wrap & 4) != 0 && hold != (check & 0xFFFF)) {
                        message = "header crc mismatch"
                        mode = BAD
                        continue
                    }
                    initBits()
                }
                if (let Some(v) <- head) {
                    v.hcrc = (flags >> 9) & 1
                    v.done = 1
                }
                check = DEFAULT_CRC32
                adler = check
                mode = TYPE
            }
            // #ifdef GUNZIP end
            if (mode == DICTID) {
                /* Obtains the dictionary verification value. */
                if (needBits(32)) {
                    break
                }
                check = ((hold >> 24) & 0xFF) + ((hold >> 8) & 0xFF00) + ((hold & 0xFF00) << 8) + ((hold & 0xFF) << 24)
                adler = check
                initBits()
                mode = DICT
            }
            if (mode == DICT) {
                /* Determines whether to set the dictionary. If the dictionary is not set, Z_NEED_DICT is returned. */
                if (!havedict) {
                    return Z_NEED_DICT
                }
                check = DEFAULT_ADLER32
                adler = check
                mode = TYPE
            }
            if (mode == TYPE) {
                if (flush == Z_BLOCK || flush == Z_TREES) {
                    break
                }
                mode = TYPEDO
            }
            if (mode == TYPEDO) {
                /* Identify the compressed block type: direct storage, static huffman compression, and dynamic huffman compression. */
                if (last) {
                    byteBits()
                    mode = CHECK
                } else {
                    if (needBits(3)) {
                        break
                    }
                    last = if (getBits(1) != 0) { true } else { false }
                    dropBits(1)
                    match (getBits(2)) {
                        case 0 =>
                            mode = STORED
                        case 1 =>
                            mode = LEN_
                            lencodes = lenfix
                            lenbits = 9
                            distcodes = distfix
                            distbits = 5
                            if (flush == Z_TREES) {
                                dropBits(2)
                                break
                            }
                        case 2 =>
                            lencodes = lendyn
                            distcodes = distdyn
                            mode = TABLE
                        case _ =>
                            message = "invalid block type"
                            mode = BAD
                    }
                    dropBits(2)
                }
            }
            if (mode == STORED) {
                /* Decompress the compressed block in the storage format: Obtain the data length and check the correctness. */
                byteBits()
                if (needBits(32)) {
                    break
                }
                if ((hold & 0xFFFF) != ((hold >> 16) ^ 0xFFFF)) {
                    message = "invalid stored block lengths"
                    mode = BAD
                    continue
                }
                length = hold & 0xFFFF
                initBits()
                mode = COPY_
                if (flush == Z_TREES) {
                    break // TODO goto inf_leave
                }
                this.mode = COPY_
            }
            if (mode == COPY_) {
                mode = COPY
            }
            if (mode == COPY) {
                /* Decompress Storage Format Compressed Blocks: Copying Data */
                copy = Int64(length)
                if (copy > 0) {
                    if (copy > avail_in) { copy = avail_in }
                    if (copy > avail_out) { copy = avail_out }
                    if (copy == 0) {
                        break // TODO goto inf_leave
                    }
                    for (i in 0..copy) {
                        next_out[pos_out] = next_in[pos_in]
                        pos_out++
                        pos_in++
                    }
                    avail_in -= copy
                    avail_out -= copy
                    length -= UInt32(copy)
                    continue
                }
                mode = TYPE
                continue
            }
            if (mode == TABLE) {
                /*
                    * Decompress the dynamic huffman tree:
                    * parse the code length sequence length corresponding to the three trees.
                    */
                if (needBits(14)) {
                    break
                }
                nlen = getBits(5) + 257
                dropBits(5)
                ndist = getBits(5) + 1
                dropBits(5)
                ncode = getBits(4) + 4
                dropBits(4)
                if (nlen > 286 || ndist > 30) {
                    message = "too many length or distance symbols"
                    mode = BAD
                } else {
                    have = 0
                    mode = LENLENS
                }
            }
            if (mode == LENLENS) {
                /*
                * Decompress the dynamic huffman tree:
                * Obtain the code length sequence of the cl tree and construct the decompressed code table.
                */
                var isbreak = false
                while (have < ncode) {
                    if (needBits(3)) {
                        isbreak = true
                        break
                    }
                    codelens[bl_order[Int64(have)]] = UInt16(getBits(3))
                    have++
                    dropBits(3)
                }
                if (isbreak) {
                    break
                }
                while (have < 19) {
                    codelens[bl_order[Int64(have)]] = 0
                    have++
                }
                lenbits = 7
                error = inflateTable(TYPE_CODES, lenbits, 19, codelens, lencodes)
                if (error) {
                    message = "invalid code lengths set"
                    mode = BAD
                } else {
                    have = 0
                    mode = CODELENS
                }
            }
            if (mode == CODELENS) {
                /*
                    * Decompress the dynamic huffman tree:
                    * Decompress the code length sequence of the literal/length and
                    * distance trees to construct the literal/length and distance decompression code table.
                    */
                var isbreak = false
                while (have < nlen + ndist) {
                    while (true) {
                        here = lencodes[Int64(getBits(lenbits))]
                        if (UInt32(here.bits) <= bits) {
                            break
                        }
                        if (pullByte()) { // TODO BUG SEE
                            isbreak = true
                            break
                        }
                    }
                    if (isbreak) {
                        break
                    }
                    if (here.value < 16) {
                        dropBits(UInt32(here.bits))
                        codelens[Int64(have)] = here.value
                        have++
                    } else {
                        if (here.value == 16) {
                            if (needBits(UInt32(here.bits) + 2)) {
                                isbreak = true
                                break
                            }
                            dropBits(UInt32(here.bits))
                            if (have == 0) {
                                message = "invalid bit length repeat"
                                mode = BAD
                                continue
                            }
                            len = UInt32(codelens[Int64(have) - 1])
                            copy = 3 + Int64(getBits(2))
                            dropBits(2)
                        } else if (here.value == 17) {
                            if (needBits(UInt32(here.bits) + 3)) {
                                isbreak = true
                                break
                            }
                            dropBits(UInt32(here.bits))
                            len = 0
                            copy = 3 + Int64(getBits(3))
                            dropBits(3)
                        } else {
                            if (needBits(UInt32(here.bits) + 7)) {
                                isbreak = true
                                break
                            }
                            dropBits(UInt32(here.bits))
                            len = 0
                            copy = 11 + Int64(getBits(7))
                            dropBits(7)
                        }
                        if (have + UInt32(copy) > nlen + ndist) {
                            message = "invalid bit length repeat"
                            mode = BAD
                            continue
                        } else {
                            while (copy > 0) {
                                codelens[Int64(have)] = UInt16(len)
                                have++
                                copy--
                            }
                        }
                    }
                }
                if (isbreak) {
                    break
                }
                if (mode == BAD) { continue }
                if (codelens[256] == 0) {
                    message = "invalid code -- missing end-of-block"
                    mode = BAD
                    continue
                }
                lenbits = 9
                error = inflateTable(TYPE_LENS, lenbits, nlen, codelens, lencodes)
                if (error) {
                    message = "invalid literal/lengths set"
                    mode = BAD
                    continue
                }
                distbits = 6
                error = inflateTable(TYPE_DISTS, distbits, ndist, codelens, distcodes)
                if (error) {
                    message = "invalid distances set"
                    mode = BAD
                    continue
                } else {
                    mode = LEN_
                    if (flush == Z_TREES) {
                        break
                    }
                }
            }
            if (mode == LEN_) {
                mode = LEN
            }
            if (mode == LEN) {
                /* Decompress compressed blocks: Decompress length or original characters. */
                if (avail_in >= 6 && avail_out >= 258) {
                    inflateFast()
                    if (mode == TYPE) {
                        back = -1
                    }
                    continue
                }
                back = 0
                var isbreak = false
                while (true) {
                    here = lencodes[Int64(getBits(lenbits))]  // 定位到这里hold的值不对了, 28 正确为15
                    if (UInt32(here.bits) <= bits) {
                        break
                    }
                    if (pullByte()) {
                        isbreak = true
                        break
                    }
                }
                if (isbreak) {
                    break
                }
                if (here.option != 0 && (here.option & 0xF0) == 0) {
                    /* here is the link node of the level-2 table. */
                    link = here
                    while (true) {
                        here = lencodes[Int64(link.value) + Int64(getBits(UInt32(link.bits + link.option)) >> UInt32(link.bits))]
                        if (UInt32(link.bits + here.bits) <= bits) {
                            break
                        }
                        if (pullByte()) {
                            isbreak = true
                            break
                        }
                    }
                    if (isbreak) {
                        break
                    }
                    dropBits(UInt32(link.bits))
                    back += Int32(link.bits)
                }
                dropBits(UInt32(here.bits))
                back += Int32(here.bits)
                length = UInt32(here.value)
                if (here.option == 0) {
                    /* here is the original character. */
                    mode = LIT
                } else if ((here.option & 32) != 0) {
                    /* here is a block terminator */
                    back = -1
                    mode = TYPE
                } else if ((here.option & 64) != 0) {
                    /* here Invalid. */
                    message = "invalid literal/length code"
                    mode = BAD
                } else {
                    /* here is length */
                    extra = UInt32(here.option & 0x0F)
                    mode = LENEXT
                }
            }
            if (mode == LENEXT) {
                /* Decompress the compressed block: Decompress the extension bit of the length. */
                if (extra != 0) {
                    if (needBits(extra)) {
                        break
                    }
                    length += getBits(extra)
                    dropBits(extra)
                    back += Int32(extra)
                }
                was = length
                mode = DIST
            }
            if (mode == DIST) {
                /* Decompressing a compressed block: decompressing distance. */
                var isbreak = false
                while (true) {
                    here = distcodes[Int64(getBits(distbits))]
                    if (UInt32(here.bits) <= bits) {
                        break
                    }
                    if (pullByte()) {
                        isbreak = true
                        break
                    }
                }
                if (isbreak) {
                    break
                }
                if ((here.option & 0xF0) == 0) {
                    /* here is the link node of the level-2 table. */
                    link = here
                    while (true) {
                        here = distcodes[Int64(link.value) + Int64(getBits(UInt32(link.bits + link.option)) >> UInt32(link.bits))]
                        if (UInt32(link.bits + here.bits) < bits) {
                            break
                        }
                        if (pullByte()) {
                            isbreak = true
                            break
                        }
                    }
                    if (isbreak) {
                        break
                    }
                    dropBits(UInt32(link.bits))
                    back += Int32(link.bits)
                }
                dropBits(UInt32(here.bits))
                back += Int32(here.bits)
                if ((here.option & 64) != 0) {
                    /* here Invalid */
                    message = "invalid distance code"
                    mode = BAD
                } else {
                    /* here is distance */
                    offset = UInt32(here.value)
                    extra = UInt32(here.option & 0x0F)
                    mode = DISTEXT
                }
            }
            if (mode == DISTEXT) {
                /* Decompress the compressed block: decompress the extended bit of the distance. */
                if (extra != 0) {
                    if (needBits(extra)) {
                        break
                    }
                    offset += getBits(extra)
                    dropBits(extra)
                    back += Int32(extra)
                }
                if (offset > dmax) {
                    message = "invalid distance too far back1"
                    mode = BAD
                } else {
                    mode = MATCH
                }
            }
            if (mode == MATCH) {
                /* Decompress compressed blocks: Copy matching data. */
                if (avail_out == 0) {
                    break
                }
                copy = pos_out
                /* The matching start position is in the window. */
                if (Int64(offset) > copy) {
                    copy = Int64(offset) - copy
                    /* Remaining distance > Data size in the window, Error reporting. */
                    if (copy > Int64(whave)) {
                        message = "invalid distance too far back2"
                        mode = BAD
                        continue
                    } else if (copy > Int64(wnext)) {
                        /* The matching start position is in the [wnext, wsize) range. */
                        copy -= Int64(wnext)
                        copyfrom = Int64(wsize) - copy
                    } else {
                        /* The matching start position is in the range [0, wnext). */
                        copyfrom = Int64(wnext) - copy
                    }
                    if (copy > Int64(length)) {
                        copy = Int64(length)
                    }
                    copybuf = window
                } else {
                    /* The match start position is in the output buffer and is copied directly. */
                    copyfrom = copy - Int64(offset)
                    copy = Int64(length)
                    copybuf = next_out
                }
                if (copy > avail_out) {
                    /* The output buffer is insufficient. Copy part of the buffer first. */
                    copy = avail_out
                }
                avail_out -= copy
                length -= UInt32(copy)
                for (i in copyfrom..copyfrom + copy) {
                    next_out[pos_out] = copybuf[i]
                    pos_out++
                }
                if (length == 0) {
                    mode = LEN
                }
            }
            if (mode == LIT) {
                /* Decompress compressed blocks: Copy original characters. */
                if (avail_out == 0) {
                    break
                }
                next_out[pos_out] = UInt8(length & 0xFF)
                avail_out--
                pos_out++
                mode = LEN
            }
            if (mode == CHECK) {
                /* Check the verification value. */
                if (this.wrap != DEFLATE) {
                    if (needBits(32)){
                        return Z_BUF_ERROR
                    }
                    var newdatalen: Int64 = initout - avail_out
                    initout = avail_out
                    total_out += newdatalen
                    total += newdatalen
                    if ((this.wrap & 4) != 0 && newdatalen > 0) {
                        if (flags != 0) {
                            check = crc32(check, next_out, pos_out - Int64(newdatalen), newdatalen)
                        } else {
                            check = adler32(check, next_out, pos_out - Int64(newdatalen), newdatalen)
                        }
                        adler = check
                    }
                    if ((this.wrap & 4) != 0) {
                        var realcheck: UInt32 = hold
                        if (flags == 0) {
                            realcheck = ((hold >> 24) & 0xFF) + ((hold >> 8) & 0xFF00) + ((hold & 0xFF00) << 8) + ((hold & 0xFF) << 24)
                        }
                        if (realcheck != check) {
                            message = "incorrect data check"
                            mode = BAD
                            continue
                        }
                    }
                    initBits()
                }
                if (this.wbits == 31) {
                    mode = LENGTH
                } else{
                    mode = DONE
                }
            }
            if (mode == LENGTH) {
                /* Check Length */
                if (flags != 0 && this.wrap != DEFLATE) {
                    if (needBits(32)) {
                        return Z_BUF_ERROR
                    }
                    if ((this.wrap & 4) != 0 && hold != UInt32(total & 0xFFFFFFFF)) {
                        message = "incorrect length check"
                        mode = BAD
                        continue
                    }
                    initBits()
                }
                mode = DONE
            }
            if (mode == DONE) {
                message = "inflate completed"
                ret = Z_STREAM_END
                break  // TODO inf_leave
            }
            if (mode == BAD) {
                ret = Z_DATA_ERROR
                break  // TODO inf_leave
            }
            if (mode == MEM) { return Z_MEM_ERROR}
            if (mode >= SYNC || mode < HEAD) {
                return Z_STREAM_ERROR
            }
        }
        if (this.wsize != 0 || initout != this.avail_out && mode < BAD && (mode < CHECK || flush != Z_FINISH)) {
            updateWindow(next_out, pos_out, initout - this.avail_out)
        }
        initin -= avail_in
        initout -= avail_out
        total_in += initin
        total_out += initout
        total += initout
        var outputstart: Int64 = pos_out - initout
        if ((this.wrap & 4) != 0 && initout > 0) {
            if (flags != 0) {
                check = crc32(check, next_out, outputstart, initout)
            } else {
                check = adler32(check, next_out, outputstart, initout)
            }
            adler = check
        }

        data_type = Int32(bits)
        if (last) {
            data_type += 64
        }
        if (mode == TYPE) {
            data_type += 128
        }
        if (mode == LEN_ || mode == COPY_) {
            data_type += 256
        }
        if (((initin == 0 && initout == 0) || flush == Z_FINISH) && ret == Z_OK) {
            ret = Z_BUF_ERROR
        }
        return ret
    }

    /**
     * This command is invoked after the decompression is complete to check the decompression status.
     *
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func inflateEnd(): Int32 {
        this.window = NULL_ARR_UINT8
        this.head = None
        this.lencodes = NULL_ARR_Code
        this.distcodes = NULL_ARR_Code
        this.lendyn = NULL_ARR_Code
        this.distdyn = NULL_ARR_Code
        this.codelens = NULL_ARR_UINT16
        this.work = NULL_ARR_UINT16
        this.hbuf = NULL_ARR_UINT8
        return Z_OK
    }

    /**
     * Sets the decompression dictionary.
     * This command is invoked when the inflate function returns Z_NEED_DICT.
     * If a dictionary is set during compression, the same dictionary must be set before decompression.
     *
     * @param dict Dictionary data
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {
        if (mode < HEAD || mode > SYNC) {
            message = erroMsg(Z_STREAM_ERROR)
            return Z_STREAM_ERROR
        }
        if (this.wrap != DEFLATE && mode != DICT) {
            message = erroMsg(Z_STREAM_ERROR)
            return Z_STREAM_ERROR
        }
        /* check for correct dictionary identifier */
        if (mode == DICT) {
            var dictid: UInt32 = DEFAULT_ADLER32
            dictid = adler32(dictid, dict, 0, dict.size)
            if (dictid != check) {
                message = "dictionary data error"
                return Z_DATA_ERROR
            }
        }
        updateWindow(dict, dict.size, dict.size)
        havedict = true
        message = ""
        return Z_OK
    }

    /**
     * This method is used to obtain the header information of the gzip file after the gzip file is decompressed.
     *
     * @param gzhead Header information in gzip format
     *
     * @since 0.24.2
     */
    @Frozen
    public func getGzipHeader(): ?GZIPHeader {
        if (mode < HEAD || mode > SYNC) {
            return None
        }
        if ((this.wrap & 2) == 0) {
            return None
        } else {
            this.head?.done = 0
            return this.head
        }
    }

    /**
     * During decompression, invalid compressed data is skipped and decompressed from the next full refresh point.
     *
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @OverflowWrapping
    @Frozen
    public func inflateSync(): Int32 {
        /* Checking Parameters */
        if (mode < HEAD || mode > SYNC) {
            message = erroMsg(Z_STREAM_ERROR)
            return Z_STREAM_ERROR
        }
        if (avail_in == 0 && bits < 8) {
            return Z_BUF_ERROR
        }

        var len: Int64
        var buf: Array<UInt8> = Array<UInt8>(4, repeat: 0)

        /* if first time, start search in bit buffer */
        if (mode != SYNC) {
            mode = SYNC
            hold <<= bits & 7
            bits -= bits & 7
            len = 0
            while (bits >= 8) {
                buf[len] = UInt8(hold)
                len++
                hold >>= 8
                bits -= 8
            }
            have = 0
            syncSearch(have, buf, len)
        }

        /* search available input */
        len = syncSearch(have, next_in, avail_in)
        avail_in -= len
        pos_in += len
        total_in += len

        /* return no joy or set up to restart inflate() on a new block */
        if (have != 4) {
            return Z_DATA_ERROR
        }

        var t_in: Int64 = total_in
        var t_out: Int64 = total_out
        inflateReset()
        total_in = t_in
        total_out = t_out
        mode = TYPE
        return Z_OK
    }
    
    @Frozen
    private func initBits(): Unit {
        hold = 0
        bits = 0
    }
    
    @Frozen
    private func pullByte(): Bool {
        if (avail_in == 0) {
            return true
        }
        avail_in--
        hold += UInt32(next_in[pos_in]) << bits
        pos_in++
        bits += 8
        return false
    }
    
    @Frozen
    private func needBits(n: UInt32): Bool {
        while (bits < n) {
            if (pullByte()) {
                return true
            }
        }
        return false
    }

    @Frozen
    private func getBits(n: UInt32): UInt32 {
        return hold & ((1 << n) - 1)
    }

    @Frozen
    private func dropBits(n: UInt32): Unit {
        hold >>= n
        bits -= n
    }

    @Frozen
    private func byteBits(): Unit {
        hold >>= bits & 7
        bits -= bits & 7
    }

    @Frozen
    private func inflateTable(tabletype: UInt32, midcodelen: UInt32, symnums: UInt32, lens: Array<UInt16>, codetable: Array<Code>): Bool {
        var here: Code = Code(0,0,0)
        var left: Int32
        var max: UInt32
        var min: UInt32
        var root: UInt32
        var lstart: Int64 = 0
        if (tabletype == TYPE_DISTS) {
            lstart = Int64(nlen)
        }
        /* Counts the number of occurrences of each code length, which is stored in the count array. */
        var count: Array<UInt16> = Array<UInt16>(MAXBITS + 1, repeat: 0)
        for (i in lstart..lstart + Int64(symnums)) {
            count[Int64(lens[i])]++
        }
        /* The maximum code length whose frequency is greater than 0 is found. */
        max = UInt32(MAXBITS)
        while (max > 0) {
            if (count[Int64(max)] != 0) { break }
            max--
        }
        if (max == 0) {
            here = Code(64, 1, 0)
            codetable[0] = here
            if (tabletype == TYPE_DISTS) {
                distbits = 1
            } else {
                lenbits = 1
            }
            return false
        }
        root = midcodelen
        if (root > max) {
            root = max
        }
        /* Find the minimum code length whose frequency is greater than 0. */
        min = 1
        while (min < max) {
            if (count[Int64(min)] != 0) { break }
            min++
        }
        if (root < min) {
            root = min
        }
        /* Check the validity of the code length sequence. */
        left = 1
        for (i in 1..=MAXBITS) {
            left <<= 1
            left -= Int32(count[i])
            if (left < 0) {
                return true
            }
        }
        if (left > 0 && (tabletype == TYPE_CODES || max != 1)) {
            return true
        }
        /* Calculates the minimum code value corresponding to each code length and saves the value in the offs array. */
        var offs = Array<UInt16>(MAXBITS + 1, repeat: 0)
        for (i in 1..MAXBITS) {
            offs[i + 1] = offs[i] + count[i]
        }
        /* Sorted by code length and symbol order and saved in the work array. */
        for (i in lstart..lstart + Int64(symnums)) {
            if (lens[i] != 0) {
                work[Int64(offs[Int64(lens[i])])] = UInt16(i - lstart)
                offs[Int64(lens[i])]++
            }
        }
        var matchsym: UInt16
        var base: Array<UInt16>
        var extra: Array<UInt16>
        match  {
            case tabletype == TYPE_CODES =>
                base = NULL_ARR_UINT16
                extra = NULL_ARR_UINT16
                matchsym = 20
            case tabletype == TYPE_LENS =>
                base = lbase
                extra = lext
                matchsym = 257
            case tabletype == TYPE_DISTS =>
                base = dbase
                extra = dext
                matchsym = 0
            case _ => return true
        }
        var used: UInt32 = 1 << root
        if (tabletype == TYPE_LENS && used > ENOUGH_LENS ||
            tabletype == TYPE_DISTS && used > ENOUGH_DISTS) {
            return true
        }
        /* Work array subscript */
        var sym: Int64 = 0
        /* Code length */
        var len: UInt32 = min
        /* Start Code */
        var huff: UInt32 = 0
        /*
         * When a level-1 table is created, the value is 0.
         * When a level-2 table is created, the value is the maximum code length (threshold code length) of the level-1 table.
         */
        var drop: UInt32 = 0
        /*
         * Maximum code length of the current table
         * For the level-1 table, the code length threshold is midcodelen.
         * For the level-2 table, the code length threshold is the maximum code length of the previous table minus the threshold midcodelen.
         */
        var curr: UInt32 = root
        /* Increment between multiple virtual code values when the real code value is extended to the maximum code length in the current table */
        var incr: UInt32
        /* Current Table Size */
        var fill: UInt32
        /* Location */
        var pos: Int64
        /* Start subscript of the current table (all tables are stored in the same array) */
        var start: Int64 = 0
        var mask: UInt32 = used - 1
        var low: UInt32 = 0xFFFFFFFF
        while (true) {
            here.bits = UInt8((len - drop) & 0xFF)
            /* Symbols of Code Length Trees or literal */
            if (work[sym] + 1 < matchsym) {
                here.option = 0
                here.value = work[sym]
            } else if (work[sym] >= matchsym) {
                /* length or distance (Reference value + number of extended bit) */
                pos = Int64(work[sym] - matchsym)
                here.option = UInt8(extra[pos] & 0xFF)
                here.value = base[pos]
            } else {
                /* Block end symbol */
                here.option = 32 + 64
                here.value = 0
            }
            /*
             * When the code value is in the positive order, the increment is 1.
             * However, the Huffman encoding saves the value in the reverse order.
             * Therefore, the increment is 1 << len.
             * In the level-2 table, the maximum code length of the level-1 table needs to be subtracted from the value drop.
             */
            incr = 1 << (len - drop)
            /* Size of the current code table */
            fill = 1 << curr
            /* Saves the size of the current code table, which will be used when calculating the start position of the next code table. */
            min = fill
            /* Save the encoding information to the code table (the subscript is the extended virtual code value). */
            pos = start + Int64(huff >> drop)
            do {
                fill -= incr
                codetable[pos + Int64(fill)] = here
            } while (fill != 0)
            /*
             * Calculate the code value of the next character: In positive order, the code value of the current character plus 1 (huff + 1).
             * However, the reverse order value is used here.
             * The calculation logic is as follows: Find the first bit that is 0 from the most significant bit,
             * set this bit to 1, and set the preceding bits (high bits) to 0.
             * The search starts from the most significant bit.
             * Therefore, you can set the most significant bit to 1 and set the other bits to 0.
             * Then, you can determine whether the most significant bit is 0.
             */
            incr = 1 << (len - 1)
            /* Determine whether a bit is 0. */
            while ((huff & incr) != 0) {
                /* If the previous bit is 1, carry is generated. The next bit needs to be determined. */
                incr >>= 1
            }
            if (incr != 0) {
                /* High Position 0 (Because the most significant bits are all 1, add 1 and then carry it into 0.)
                 * The bit that does not carry is also set to 0.
                 */
                huff &= incr - 1
                /* This position without carrying 1 */
                huff += incr
            } else {
                huff = 0
            }
            sym++
            /*
             * Complete the construction of a character code table.
             * The number of characters corresponding to the current code length decreases by one.
             */
            count[Int64(len)]--
            if (count[Int64(len)] == 0) {
                /* End. Encoding information of all characters that appear has been saved to the code table. */
                if (len == max) { break }
                /* Obtains the code length of the next character. */
                len = UInt32(lens[lstart + Int64(work[sym])])
            }
            /*
             * When the code length exceeds the threshold code length,
             * the level-2 code table is constructed and information about the level-2 code table is initialized.
             */
            if (len > root && (huff & mask) != low) {
                if (drop == 0) {
                    drop = root
                }
                /* Start subscript of the next table */
                start += Int64(min)
                /* Calculate the size of the level-2 table and save it in the left. */
                curr = len - drop
                left = Int32(1 << curr)
                while (curr + drop < max) {
                    left -= Int32(count[Int64(curr + drop)])
                    /* left > 0 indicates that leaf nodes with longer code lengths are stored in the level-2 code table. */
                    if (left <= 0) { break }
                    curr++
                    left <<= 1
                }
                /* Check the size of the code table. */
                used += 1 << curr
                if ((tabletype == TYPE_LENS && used > ENOUGH_LENS) ||
                    (tabletype == TYPE_DISTS && used > ENOUGH_DISTS)) {
                    return true
                }
                /* The level-1 code table stores the information about the next level-2 code table. */
                low = huff & mask
                here.option = UInt8(curr & 0xFF)
                here.bits = UInt8(root & 0xFF)
                here.value = UInt16(start)
                codetable[Int64(low)] = here
            }
        }
        if (huff != 0) {
            here.option = 64
            here.bits = UInt8((len - drop) & 0xFF)
            here.value = 0
            codetable[Int64(huff)] = here
        }
        if (tabletype == TYPE_DISTS) {
            distbits = root
        } else {
            lenbits = root
        }
        return false
    }

    @Frozen
    private func inflateFast(): Unit {
        var here: Code = Code(0, 0, 0)
        var lmask: UInt32 = (1 << lenbits) - 1
        var dmask: UInt32 = (1 << distbits) - 1
        var len: UInt32 = 0
        var dist: UInt32 = 0
        var extra: UInt32 = 0
        var stopError = 0
        let last = this.avail_in - 5
        let end = this.avail_out - 257
        var copyfrom: UInt32 = 0
        var copybuf: Array<UInt8> = NULL_ARR_UINT8
        do {
            if (bits < 15) {
                try {
                    hold += UInt32(next_in[pos_in]) << bits
                } catch (e: IndexOutOfBoundsException) {
                    throw e
                }
                pos_in++
                avail_in--
                bits += 8
                hold += UInt32(next_in[pos_in]) << bits
                pos_in++
                avail_in--
                bits += 8
            }
            here = lencodes[Int64(hold & lmask)]
            hold >>= UInt32(here.bits)
            bits -= UInt32(here.bits)
            /* Link to the L2 code table of length */
            if (here.option != 0 && (here.option & 0xF0) == 0) {
                here = lencodes[Int64(here.value) + Int64(hold & ((1 << UInt32(here.option)) - 1))]
                hold >>= UInt32(here.bits)
                bits -= UInt32(here.bits)
            }
            /* Original character */
            if (here.option == 0) {
                next_out[pos_out] = UInt8(here.value & 0xFF)
                pos_out++
                avail_out--
            } else if ((here.option & 16) != 0) {
                /* length */
                len = UInt32(here.value)
                extra = UInt32(here.option & 0x0F)
                if (extra != 0) {
                    if (bits < extra) {
                        hold += UInt32(next_in[pos_in]) << bits
                        pos_in++
                        avail_in--
                        bits += 8
                    }
                    len += hold & ((1 << extra) - 1)
                    hold >>= extra
                    bits -= extra
                }
                if (bits < 15) {
                    hold += UInt32(next_in[pos_in]) << bits
                    pos_in++
                    avail_in--
                    bits += 8
                    hold += UInt32(next_in[pos_in]) << bits
                    pos_in++
                    avail_in--
                    bits += 8
                }
                /* distances */
                here = distcodes[Int64(hold & dmask)]
                hold >>= UInt32(here.bits)
                bits -= UInt32(here.bits)
                if ((here.option & 0xF0) == 0) {
                    here = distcodes[Int64(here.value) + Int64(hold & ((1 << UInt32(here.option)) - 1))]
                    hold >>= UInt32(here.bits)
                    bits -= UInt32(here.bits)
                }
                if ((here.option & 16) != 0) {
                    dist = UInt32(here.value)
                    extra = UInt32(here.option & 0x0F)
                    if (bits < extra) {
                        hold += UInt32(next_in[pos_in]) << bits
                        pos_in++
                        avail_in--
                        bits += 8
                        if (bits < extra) {
                            hold += UInt32(next_in[pos_in]) << bits
                            pos_in++
                            avail_in--
                            bits += 8
                        }
                    }
                    dist += hold & ((1 << extra) - 1)
                    if (dist > dmax) {
                        message = "invalid distance too far back3"
                        mode = BAD
                        break
                    }
                    hold >>= extra
                    bits -= extra
                    /*
                     * Copy the matching data from the front (output buffer or loop array window).
                     * 1.Match start position exceeds output buffer
                     */
                    if (dist > UInt32(pos_out)) {
                        extra = dist - UInt32(pos_out)
                        /* The match start position exceeds the window. */
                        if (extra > whave) {   //TODO whave 1042 实际是2057
                            message = "invalid distance too far back4"
                            mode = BAD
                            break
                        }
                        /*
                         * 1.1 Copy the data in the window.
                         * wnext = 0: The data in the window is an entire segment and is directly copied.
                         */
                        if (wnext == 0) {
                            /* Matching start position */
                            copyfrom = wsize - extra
                            if (len > extra) {
                                len -= extra
                            } else {
                                extra = len
                                len = 0
                            }
                            for (i in Int64(copyfrom)..Int64(copyfrom + extra)) {
                                next_out[pos_out] = window[i]
                                pos_out++
                                avail_out--
                            }
                        } else if (wnext < extra) {
                            /*
                             * If wnext is greater than 0 and the matching start position is after wnext,
                             * copy the data at the end of the window first.
                             */
                            copyfrom = wsize + wnext - extra
                            extra -= wnext
                            if (extra < len) {
                                len -= extra
                            } else {
                                extra = len
                                len = 0
                            }
                            for (i in Int64(copyfrom)..Int64(copyfrom + extra)) {
                                next_out[pos_out] = window[i]
                                pos_out++
                                avail_out--
                            }
                            /* Copy the data at the beginning of the window. */
                            if (len > 0) {
                                copyfrom = 0
                                if (len > wnext) {
                                    extra = wnext
                                    len -= wnext
                                } else {
                                    extra = len
                                    len = 0
                                }
                                for (i in Int64(copyfrom)..Int64(copyfrom + extra)) {
                                    next_out[pos_out] = window[i]
                                    pos_out++
                                    avail_out--
                                }
                            }
                        } else {
                            /* The matching start position is in front of wnext and is copied directly. */
                            copyfrom = wnext - extra
                            if (extra < len) {
                                len -= extra
                            } else {
                                extra = len
                                len = 0
                            }
                            for (i in Int64(copyfrom)..Int64(copyfrom + extra)) {
                                next_out[pos_out] = window[i]
                                pos_out++
                                avail_out--
                            }
                        }
                        /* 1.2 Copy the data on next_out. */
                        if (len > 0) {
                            copyfrom = 0
                            for (i in Int64(copyfrom)..Int64(copyfrom + len)) {
                                next_out[pos_out] = next_out[i]
                                pos_out++
                                avail_out--
                            }
                        }
                    /* 2. The matching start position is in the output buffer and is copied directly. */
                    } else {
                        copyfrom = UInt32(pos_out) - dist
                        for (i in Int64(copyfrom)..Int64(copyfrom + len)) {
                            next_out[pos_out] = next_out[i]
                            pos_out++
                            avail_out--
                        }
                        stopError = 0
                    }
                } else {
                    message = "invalid distance code"
                    mode = BAD
                    break
                }
            } else if ((here.option & 32) != 0) {
                mode = TYPE
                break
            } else {
                message = "invalid literal/length code"
                mode = BAD
                break
            }
        } while (pos_out < end && pos_in < last) 
        /* return unused bytes (on entry, bits < 8, so in won't go too far back) */
        len = bits >> 3
        this.pos_in -= Int64(len)
        this.avail_in += Int64(len)
        this.bits -= len << 3
        this.hold &= (1 << this.bits) - 1
    }    

    @Frozen
    @OverflowWrapping
    private func updateWindow(buf: Array<UInt8>, start: Int64, length: Int64): Unit {
        /* 1. If the amount of data to be updated is greater than wsize, copy the data at the end of wsize to the cyclic array window. */
        if (this.window.size == 0) {
            this.window = Array<Byte>(1 << this.wbits, repeat: 0)
        }
        if (this.wsize == 0) {
            this.wsize = 1 << this.wbits
            this.wnext = 0
            this.whave = 0
        }
        if (length >= Int64(wsize)) {
            let pos: Int64 = start - Int64(wsize)  // TODO
            for (i in 0..Int64(wsize)) {
                window[i] = buf[pos + i]
            }
            wnext = 0
            whave = wsize
        } else {/* 2. The amount of data to be updated is less than wsize. */
            /* 2.1 Copy data to the [wnext, wsize) range. */
            var dist: UInt32 = wsize - wnext
            if (Int64(dist) > length) {
                dist = UInt32(length)
            }
            var pos: Int64 = start - length
            for (i in Int64(wnext)..Int64(wnext + dist)) {
                window[i] = buf[pos]
                pos++
            }
            /* 2.2 The [wnext, wsize) range is insufficient. The remaining data is copied to [0,copy). */
            var copy: Int64 = length - Int64(dist)
            if (copy > 0) {
                pos = start - copy
                for (i in 0..copy) {
                    window[i] = buf[pos]
                    pos++
                }
                wnext = UInt32(copy)
                whave = wsize
            } else {/* 2.3 [wnext, wsize] is sufficient. You only need to update wnext and whave. */
                wnext += dist
                if (wnext == wsize) {
                    wnext = 0
                }
                if (whave < wsize) {
                    whave += dist
                }
            }
        }
    }

    @Frozen
    private func syncSearch(have: UInt32, buf: Array<UInt8>, length: Int64): Int64 {
        var got: UInt32
        got = have
        var next: Int64 = 0
        while (next < length && got < 4) {
            let res: UInt8 = if (got < 2) { 0 } else { 0xFF }
            if (buf[next] == res) {
                got++
            } else if (buf[next] != 0) {
                got = 0
            } else {
                got = 4 - got
            }
            next++
        }
        this.have = got
        return next
    }

    @Frozen
    private func inflateReset(): Int32 {
        if (mode < HEAD || mode > SYNC) {
            return Z_STREAM_ERROR
        }
        wsize = 0
        whave = 0
        wnext = 0
        total_in = 0
        total_out = 0
        total = 0
        mode = HEAD
        message = ""
        last = false
        havedict = false
        dmax = 32768
        head = None
        hold = 0
        bits = 0
        lencodes = NULL_ARR_Code
        distcodes = NULL_ARR_Code
        back = -1
        return Z_OK
    }
}
