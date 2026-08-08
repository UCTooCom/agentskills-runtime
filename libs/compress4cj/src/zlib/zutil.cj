/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2025. All rights reserved.
 */

/**
 * @file
 *
 * Defines common constants/type/function for decompression/compression
 */
package compress4cj.zlib

/* Return codes for the compression/decompression functions. Negative values
 * are errors, positive values are used for special but normal events.
 */
public let Z_OK           :Int32 =  0
public let Z_STREAM_END   :Int32 =  1
public let Z_NEED_DICT    :Int32 =  2
public let Z_ERRNO        :Int32 = (-1)
public let Z_STREAM_ERROR :Int32 = (-2)
public let Z_DATA_ERROR   :Int32 = (-3)
public let Z_MEM_ERROR    :Int32 = (-4)
public let Z_BUF_ERROR    :Int32 = (-5)

/* Flush Type */

public let Z_NO_FLUSH      : Int32 = 0 // 不刷新输出，积累数据以优化压缩率	常规连续压缩
public let Z_PARTIAL_FLUSH : Int32 = 1 // 部分刷新输出，保留状态	实时流传输
public let Z_SYNC_FLUSH    : Int32 = 2 // 完全刷新并字节对齐	分块压缩（如 PNG）
public let Z_FULL_FLUSH    : Int32 = 3
public let Z_FINISH        : Int32 = 4 // 终止压缩流，完成所有输出	压缩结束
public let Z_BLOCK         : Int32 = 5
public let Z_TREES         : Int32 = 6
public let Z_UNKNOWN_FLUSH : Int32 = 17

/* Original File Data Type */
public let Z_UNKNOWN: Int32 = 0
public let Z_BINARY: Int32  = 1
public let Z_TEXT: Int32    = 2
public let Z_ASCII: Int32   = 3

/* Compression Policy */
public let Z_FILTERED: UInt32           = 1
public let Z_HUFFMAN_ONLY: UInt32       = 2
public let Z_RLE: UInt32                = 3
public let Z_FIXED: UInt32              = 4
public let Z_DEFAULT_STRATEGY: UInt32   = 0

/* Compression level: 0-9 */
public let LEVEL_NO_COMPRESSION: UInt32      = 0
public let LEVEL_BEST_SPEED: UInt32          = 1
public let LEVEL_DEFAULT_COMPRESSION: UInt32 = 6
public let LEVEL_BEST_COMPRESSION: UInt32    = 9

/* Compression level: 0-9 */
public let Z_NO_COMPRESSION: Int64      = 0
public let Z_BEST_SPEED: Int64          = 1
public let Z_BEST_COMPRESSION: Int64    = 9
public let Z_DEFAULT_COMPRESSION: Int64 = -1
/* Memory level: memlevel 1-9 */
public let MIN_MEM_LEVEL: UInt32 = 1
public let DEF_MEM_LEVEL: UInt32 = 8
public let MAX_MEM_LEVEL: UInt32 = 9

/* Number of Window Bits */
public let MIN_WINDOW_BITS: UInt32 = 8
public let DEF_WINDOW_BITS: UInt32 = 15
public let MAX_WINDOW_BITS: UInt32 = 15

/* compression algorithm for use: only deflate */
let METHOD_DEFLATE: UInt32 = 8

/* operation system type, value of os in GzHeader */
public let FAT_FILESYSTEM: Int32  = 0
public let AMIGA: Int32           = 1
public let VMS: Int32             = 2
public let OS_CODE: Int32         = 3
public let VM_CMS: Int32          = 4
public let ATARI_TOS: Int32       = 5
public let HPFS_FILESYSTEM: Int32 = 6
public let MACINTOSH: Int32       = 7
public let Z_SYSTEM: Int32        = 8
public let CP_M: Int32            = 9
public let TOPS_20: Int32         = 10
public let NTFS_FILESYSTEM: Int32 = 11
public let QDOS: Int32            = 12
public let ACORN_RISCOS: Int32    = 13
public let UNKNOWN_SYSTEM: Int32  = 255

/* Decompressing/Compressing Common Constants */
let STORED_BLOCK: UInt32 = 0
let STATIC_TREES: UInt32 = 1
let DYN_TREES: UInt32    = 2

let MIN_MATCH: UInt32 = 3
let MAX_MATCH: UInt32 = 258

let PRESET_DICT: UInt32 = 0x20

let error_msg: Array<String> = [
    "need dictionary",     /* Z_NEED_DICT       2  */
    "stream end",          /* Z_STREAM_END      1  */
    "",                    /* Z_OK              0  */
    "file error",          /* Z_ERRNO         (-1) */
    "stream error",        /* Z_STREAM_ERROR  (-2) */
    "data error",          /* Z_DATA_ERROR    (-3) */
    "insufficient memory", /* Z_MEM_ERROR     (-4) */
    "buffer error",        /* Z_BUF_ERROR     (-5) */
    ""
]

@Frozen
func erroMsg(err: Int32): String {
    let index: Int64 = if (err < -6 || err > 2) {
        9
    } else {
        2 - Int64(err)
    }
    return error_msg[index]
}

let bl_order: Array<Int64> = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

/* adler32 Verification */
let BASE: UInt32 = 65521
let NMAX: Int64 = 5552

@Frozen
func doWhenLen1(sum2:UInt32,adler:UInt32,buf: Array<UInt8>,startpos:Int64):UInt32{
    var sum22 = sum2
    var adler2 = adler

    adler2 += UInt32(buf[startpos])
    if (adler2 >= BASE) {
        adler2 -= BASE
    }
    sum22 += adler2
    if (sum22 >= BASE) {
        sum22 -= BASE
    }
    return adler2 | (sum22 << 16)
}

@Frozen
func doWhenLenLess16(sum2:UInt32,len:Int64,adler:UInt32,buf: Array<UInt8>,startpos:Int64):UInt32{
    var sum22 = sum2
    var startpos2 = startpos
    var adler2 = adler
    var i: Int64 = 0
    while(i < Int64(len)) {
        adler2 += UInt32(buf[startpos2])
        sum22 += adler2
        startpos2++
        i++
    }
    if (adler2 >= BASE) {
        adler2 -= BASE
    }
    sum22 %= BASE
    return adler2 | (sum22 << 16)
}

@Frozen
public func adler32(check: UInt32, buf: Array<UInt8>, start: Int64, length: Int64): UInt32 {
    var sum2: UInt32 = (check >> 16) & 0xFFFF
    var adler: UInt32 = check & 0xFFFF
    var startpos: Int64 = start
    var len: Int64 = length
    if (len == 1) {
        return doWhenLen1(sum2,adler,buf,startpos)
    } else if (len == 0) {
        return UInt32(1)
    } else if (len < 16) {
        return doWhenLenLess16(sum2,len,adler,buf,startpos)
    }
    var n: Int64
    while (len >= NMAX) {
        len -= NMAX
        n = NMAX / 16
        do {
            var i: Int64 = 0
            while(i < 16) {
                adler += UInt32(buf[startpos])
                sum2 += adler
                startpos++
                i++
            }
            n--
        } while (n > 0)
        adler %= BASE
        sum2 %= BASE
    }
    if (len > 0) {
        while (len >= 16) {
            len -= 16
            var j: Int64 = 0
            while(j < 16) {
                adler += UInt32(buf[startpos])
                sum2 += adler
                startpos++
                j++
            }
        }
        while (len > 0) {
            len--
            adler += UInt32(buf[startpos])
            sum2 += adler
            startpos++
        }
        adler %= BASE
        sum2 %= BASE
    }
    return adler | (sum2 << 16)
}

/* crc32 Verification */
let CRC_TABLE: Array<UInt32> = [
    0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419,
    0x706af48f, 0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4,
    0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07,
    0x90bf1d91, 0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de,
    0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7, 0x136c9856,
    0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9,
    0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4,
    0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
    0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3,
    0x45df5c75, 0xdcd60dcf, 0xabd13d59, 0x26d930ac, 0x51de003a,
    0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599,
    0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
    0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190,
    0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f,
    0x9fbfe4a5, 0xe8b8d433, 0x7807c9a2, 0x0f00f934, 0x9609a88e,
    0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
    0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed,
    0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
    0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3,
    0xfbd44c65, 0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,
    0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a,
    0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5,
    0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa, 0xbe0b1010,
    0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
    0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17,
    0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6,
    0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615,
    0x73dc1683, 0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8,
    0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1, 0xf00f9344,
    0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
    0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a,
    0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
    0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1,
    0xa6bc5767, 0x3fb506dd, 0x48b2364b, 0xd80d2bda, 0xaf0a1b4c,
    0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef,
    0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
    0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe,
    0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31,
    0x2cd99e8b, 0x5bdeae1d, 0x9b64c2b0, 0xec63f226, 0x756aa39c,
    0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
    0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b,
    0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
    0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1,
    0x18b74777, 0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,
    0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45, 0xa00ae278,
    0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7,
    0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc, 0x40df0b66,
    0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
    0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605,
    0xcdd70693, 0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8,
    0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b,
    0x2d02ef8d
]

@Frozen
public func crc32(value: UInt32, buf: Array<UInt8>, start: Int64, length: Int64): UInt32 {
    if (length <= 0) {
        return value
    }
    var crc: UInt32 = value ^ 0xFFFFFFFF
    var startpos: Int64 = start
    var len: Int64 = length
    while (len >= 8) {
        len -= 8
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
    }
    while (len > 0) {
        len--
        crc = (crc >> 8) ^ CRC_TABLE[Int64((UInt8(crc & 0xFF) ^ buf[startpos]))]
        startpos++
    }
    return crc ^ 0xFFFFFFFF
}

/* Compressed file format: gzip zlib deflate */
let DEFLATE = 0 // cjlint-ignore !G.ENU.01 description
let ZLIB = 1    // cjlint-ignore !G.ENU.01 description
let GZIP = 2    // cjlint-ignore !G.ENU.01 description

let NULL_ARR_UINT8 = Array<UInt8>()
let NULL_ARR_UINT16 = Array<UInt16>()
let NULL_ARR_UINT32 = Array<UInt32>()
let NULL_ARR_CTData = Array<CTData>()
let NULL_ARR_Code = Array<Code>()
let DEFAULT_CRC32 = crc32(0, NULL_ARR_UINT8, 0, 0)
let DEFAULT_ADLER32 = adler32(0, NULL_ARR_UINT8, 0, 0)


/*
  gzip header information passed to and from zlib routines.  See RFC 1952
  for more details on the meanings of these fields.
*/
public class GZIPHeader {
    public var text: Int32              /* true if compressed data believed to be text */
    public var time: Int64              /* modification time */
    public var xflags: Int32            /* extra flags (not used when writing a gzip file) */
    public var os: Int32                /* operating system */
    public var extra: ?Array<Byte>      /* pointer to extra field or Z_NULL if none */
    public var extra_len: UInt32        /* pointer to extra size field or Z_NULL if none */
    public var extra_max: UInt32        /* space at extra (only when reading header) */
    public var name: ?Array<Byte>       /* pointer to zero-terminated file name or Z_NULL */
    public var name_max: UInt32         /* space at name (only when reading header) */
    public var comment: ?Array<Byte>    /* pointer to zero-terminated comment or Z_NULL */
    public var comm_max: UInt32         /* space at comment (only when reading header) */
    public var hcrc: Int32              /* true if there was or will be a header crc */
    public var done: Int64              /* true when done reading gzip header (not used when writing a gzip file) */

    public init() {
        this.text = 0
        this.time = 0
        this.xflags = 0
        this.os = 255
        this.extra = None
        this.extra_len = 0
        this.extra_max = 0
        this.name = None
        this.name_max = 0
        this.comment = None
        this.comm_max = 0
        this.hcrc = 0
        this.done = 0
    }
}

