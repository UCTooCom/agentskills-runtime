/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2021-2025. All rights reserved.
 */

/**
 * @file
 *
 * This is a class library that implements compression functions.
 * Provides streaming compression interfaces such as deflateInit, deflate, deflateEnd, deflateBound, setGzipHeader, and setDictionary.
 */

package compress4cj.zlib

/* Some constants */
let LENGTH_CODES: UInt32 = 29
let LITERALS: UInt32 = 256
let L_CODES: UInt32 = LITERALS + 1 + LENGTH_CODES
let D_CODES: UInt32 = 30
let BL_CODES: UInt32 = 19
let HEAP_SIZE: UInt32 = 2 * L_CODES + 1
let MAX_BITS: UInt32 = 15
let BUF_SIZE: UInt32 = 16
let TOO_FAR: UInt32 = 4096

let MIN_LOOKAHEAD: UInt32 = MAX_MATCH + MIN_MATCH + 1
let MAX_STORED: UInt32 = 65535

let MAX_BL_BITS: UInt32 = 7
let END_BLOCK: Int64 = 256
let REP_3_6: Int64 = 16
let REPZ_3_10: Int64 = 17
let REPZ_11_138: Int64 = 18

let SMALLEST: Int64 = 1

/* Compressed state */
let INIT_STATE: UInt32    = 42
let GZIP_STATE: UInt32    = 57
let EXTRA_STATE: UInt32   = 69
let NAME_STATE: UInt32    = 73
let COMMENT_STATE: UInt32 = 91
let HCRC_STATE: UInt32    = 103
let BUSY_STATE: UInt32    = 113
let FINISH_STATE: UInt32  = 666

/*
 * Compressed Block Status
 * return value of the deflateStored deflateFast deflateSlow function
 */
let NEED_MORE: UInt32      = 201
let BLOCK_DONE: UInt32     = 202
let FINISH_STARTED: UInt32 = 203
let FINISH_DONE: UInt32    = 204

let freq_code = 0
let dad_len = 1

type CTData = Array<UInt16>

class StaticTreeDesc {
    @Frozen
    StaticTreeDesc(var static_tree: Array<CTData>, var extra_bits: Array<UInt8>, var extra_base: UInt32, var max_element: UInt32, var max_length: UInt32) {}
}

class TreeDescription {
    @Frozen
    TreeDescription(var dyn_tree: Array<CTData>, var max_code: UInt32, var static_desc: StaticTreeDesc) {}
}

let good_length = 0
let max_lazy = 1
let nice_length = 2
let max_chain = 3
let deflate_func = 4

/* Static Huffman compression code table of literal length */
let static_ltree: Array<CTData> = [
    [12,8],[140,8],[76,8],[204,8],[44,8],[172,8],[108,8],[236,8],
    [28,8],[156,8],[92,8],[220,8],[60,8],[188,8],[124,8],[252,8],
    [2,8],[130,8],[66,8],[194,8],[34,8],[162,8],[98,8],[226,8],
    [18,8],[146,8],[82,8],[210,8],[50,8],[178,8],[114,8],[242,8],
    [10,8],[138,8],[74,8],[202,8],[42,8],[170,8],[106,8],[234,8],
    [26,8],[154,8],[90,8],[218,8],[58,8],[186,8],[122,8],[250,8],
    [6,8],[134,8],[70,8],[198,8],[38,8],[166,8],[102,8],[230,8],
    [22,8],[150,8],[86,8],[214,8],[54,8],[182,8],[118,8],[246,8],
    [14,8],[142,8],[78,8],[206,8],[46,8],[174,8],[110,8],[238,8],
    [30,8],[158,8],[94,8],[222,8],[62,8],[190,8],[126,8],[254,8],
    [1,8],[129,8],[65,8],[193,8],[33,8],[161,8],[97,8],[225,8],
    [17,8],[145,8],[81,8],[209,8],[49,8],[177,8],[113,8],[241,8],
    [9,8],[137,8],[73,8],[201,8],[41,8],[169,8],[105,8],[233,8],
    [25,8],[153,8],[89,8],[217,8],[57,8],[185,8],[121,8],[249,8],
    [5,8],[133,8],[69,8],[197,8],[37,8],[165,8],[101,8],[229,8],
    [21,8],[149,8],[85,8],[213,8],[53,8],[181,8],[117,8],[245,8],
    [13,8],[141,8],[77,8],[205,8],[45,8],[173,8],[109,8],[237,8],
    [29,8],[157,8],[93,8],[221,8],[61,8],[189,8],[125,8],[253,8],
    [19,9],[275,9],[147,9],[403,9],[83,9],[339,9],[211,9],[467,9],
    [51,9],[307,9],[179,9],[435,9],[115,9],[371,9],[243,9],[499,9],
    [11,9],[267,9],[139,9],[395,9],[75,9],[331,9],[203,9],[459,9],
    [43,9],[299,9],[171,9],[427,9],[107,9],[363,9],[235,9],[491,9],
    [27,9],[283,9],[155,9],[411,9],[91,9],[347,9],[219,9],[475,9],
    [59,9],[315,9],[187,9],[443,9],[123,9],[379,9],[251,9],[507,9],
    [7,9],[263,9],[135,9],[391,9],[71,9],[327,9],[199,9],[455,9],
    [39,9],[295,9],[167,9],[423,9],[103,9],[359,9],[231,9],[487,9],
    [23,9],[279,9],[151,9],[407,9],[87,9],[343,9],[215,9],[471,9],
    [55,9],[311,9],[183,9],[439,9],[119,9],[375,9],[247,9],[503,9],
    [15,9],[271,9],[143,9],[399,9],[79,9],[335,9],[207,9],[463,9],
    [47,9],[303,9],[175,9],[431,9],[111,9],[367,9],[239,9],[495,9],
    [31,9],[287,9],[159,9],[415,9],[95,9],[351,9],[223,9],[479,9],
    [63,9],[319,9],[191,9],[447,9],[127,9],[383,9],[255,9],[511,9],
    [0,7],[64,7],[32,7],[96,7],[16,7],[80,7],[48,7],[112,7],
    [8,7],[72,7],[40,7],[104,7],[24,7],[88,7],[56,7],[120,7],
    [4,7],[68,7],[36,7],[100,7],[20,7],[84,7],[52,7],[116,7],
    [3,8],[131,8],[67,8],[195,8],[35,8],[163,8],[99,8],[227,8]
]

/*
 * Compressed code table of the distance interval number in the static huffman policy
 * Fixed 5 bits indicate the range number from 0 to 29. The code value is in reverse order.
 */
let static_dtree: Array<CTData> = [
    [0,5],[16,5],[8,5],[24,5],[4,5],
    [20,5],[12,5],[28,5],[2,5],[18,5],
    [10,5],[26,5],[6,5],[22,5],[14,5],
    [30,5],[1,5],[17,5],[9,5],[25,5],
    [5,5],[21,5],[13,5],[29,5],[3,5],
    [19,5],[11,5],[27,5],[7,5],[23,5]
]

/* Mapping between distance values and ranges */
let dist_code: Array<UInt8> = [
    0,  1,  2,  3,  4,  4,  5,  5,  6,  6,  6,  6,  7,  7,  7,  7,  8,  8,  8,  8,
    8,  8,  8,  8,  9,  9,  9,  9,  9,  9,  9,  9, 10, 10, 10, 10, 10, 10, 10, 10,
    10, 10, 10, 10, 10, 10, 10, 10, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
    11, 11, 11, 11, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 13, 13, 13, 13,
    13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    13, 13, 13, 13, 13, 13, 13, 13, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,  0,  0, 16, 17,
    18, 18, 19, 19, 20, 20, 20, 20, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22, 22, 22,
    23, 23, 23, 23, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    28, 28, 28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29,
    29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29,
    29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29,
    29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29
]

/* Mapping between literal length values and ranges */
let length_code: Array<UInt8> = [
    0,  1,  2,  3,  4,  5,  6,  7,  8,  8,  9,  9, 10, 10, 11, 11, 12, 12, 12, 12,
    13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16,
    17, 17, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19,
    19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20,
    21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22,
    22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 23, 23, 23, 23, 23, 23, 23, 23,
    23, 23, 23, 23, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 28
]

/* Mapping between literal length ranges and basic values */
let base_length: Array<UInt32> = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 0
]

/* Mapping between distance range numbers and basic values */
let base_dist: Array<UInt32> = [
    0,     1,     2,     3,     4,     6,     8,    12,    16,    24,
    32,    48,    64,    96,   128,   192,   256,   384,   512,   768,
    1024,  1536,  2048,  3072,  4096,  6144,  8192, 12288, 16384, 24576
]

/* Mapping between the range number and the number of extended bits */
let extra_lbits: Array<UInt8> = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
let extra_dbits: Array<UInt8> = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
let extra_blbits: Array<UInt8> = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 7]

let static_l_desc = StaticTreeDesc(static_ltree, extra_lbits,  LITERALS + UInt32(1), L_CODES,  MAX_BITS)
let static_d_desc = StaticTreeDesc(static_dtree, extra_dbits,  0,                    D_CODES,  MAX_BITS)
let static_bl_desc = StaticTreeDesc(NULL_ARR_CTData,          extra_blbits, 0,                    BL_CODES, MAX_BL_BITS)

/**
 * This class Deflate implements the compression function.
 *
 * @since 0.24.2
 */
public class Deflate <: Stream {

    /* Compressed state */
    private var status: UInt32 = INIT_STATE

    private var lit_bufsize: Int64 = 1 << (DEF_MEM_LEVEL + 6)

    /* Wait for the buffer to save the compressed data */
    private var pending_buf: Array<UInt8> = NULL_ARR_UINT8
    private var pending_buf_size: Int64 = lit_bufsize * 4

    /* Read position of pending_buf */
    private var pending_start: Int64 = 0

    /* Number of bytes in pending_buf that are not read to the output buffer */
    private var pending: Int64 = 0

    /* Compressed data outer wrapper type: ZLIB format, GZIP format, or DEFLATE */
    private var wrap: Int64 = ZLIB

    /* Header information in GZIP format */
    private var gzhead: GZIPHeader = GZIPHeader()
    private var gzindex: Int64 = 0

    /* compression algorithm: Only one DEFLATE = 8 */
    private var method: UInt32 = METHOD_DEFLATE
    private var last_flush: Int32 = -2

    /* Controls the size of the sliding window and the size of the prev array */
    private var w_bits: Int64 = 15

    /* 1 << w_bits */
    private var w_size: UInt32 = 1 << w_bits

    /* Mask = w_size - 1 */
    private var w_mask: UInt32 = w_size - 1

    /* Sliding window, compression table */
    private var window: Array<UInt8> = NULL_ARR_UINT8

    /* Sliding window size = w_size * 2 */
    private var window_size: UInt32 = w_size * 2

    /* prev [current position] = previous position (hash value is the same as current position) */
    private var prev: Array<UInt16> = NULL_ARR_UINT16

    /* head [hash value] = position */
    private var head: Array<UInt16> = NULL_ARR_UINT16

    /* Hash value */
    private var ins_h: UInt16 = 0

    /* Number of bits of the hash value */
    private var hash_bits: UInt32 = DEF_MEM_LEVEL + 7

    /* 1 << hash_bits */
    private var hash_size: UInt32 = 1 << hash_bits

    /* hash_mask = hash_size - 1 */
    private var hash_mask: UInt32 = hash_size - 1

    /* Number of left scrolling bits of the rolling hash */
    private var hash_shift: UInt32 = ((hash_bits + MIN_MATCH - 1) / MIN_MATCH)

    /* Uncompressed data in the sliding window */
    private var lookahead: UInt32 = 0
    private var block_start: Int64 = 0

    /* Current compression position (in sliding window) */
    private var strstart: UInt32 = 0
    private var match_start: Int64 = 0
    private var match_length: UInt32 = MIN_MATCH - 1
    private var prev_start: UInt32 = 0
    private var prev_length: UInt32 = MIN_MATCH - 1
    private var match_available: Bool = false


    static let configuration_table: Array<(UInt32,UInt32,UInt32,UInt32,(Deflate, Int32) -> UInt32)> = [
        /*      good lazy nice chain */
        /* 0 */ (0,  0,   0,   0,    deflateStored),  /* store only */
        /* 1 */ (4,  4,   8,   4,    deflateFast), /* max speed, no lazy matches */
        /* 2 */ (4,  5,   16,  8,    deflateFast),
        /* 3 */ (4,  6,   32,  32,   deflateFast),
        /* 4 */ (4,  4,   16,  16,   deflateSlow),/* lazy matches */
        /* 5 */ (8,  16,  32,  32,   deflateSlow),
        /* 6 */ (8,  16,  128, 128,  deflateSlow),
        /* 7 */ (8,  32,  128, 256,  deflateSlow),
        /* 8 */ (32, 128, 258, 1024, deflateSlow),
        /* 9 */ (32, 258, 258, 4096, deflateSlow)/* max compression */
        ]

    /* Compression level 0 - 9 */
    private var level: Int64 = 6

    /* Number of forward search times in the longest match (following the prev chain) */
    private var max_chain_length: UInt32 = configuration_table[Int64(level)][3]

    /* The value is the same as max_chain_length. This parameter is used when level is less than 4. */
    private var max_insert_length: UInt32 = max_chain_length

    /* Maximum number of times that a lazy match moves backwards */
    private var max_lazy_match: UInt32 = configuration_table[Int64(level)][1]

    /*
     * Good matching length.
     * If the length is greater than or equal to this length, the current chain_length is reduced.
     */
    private var good_length: UInt32 = configuration_table[Int64(level)][0]

    /*
     * Very good match length.
     * If the length is greater than or equal to this length, the longest match ends.
     */
    private var nice_length: UInt32 = configuration_table[Int64(level)][2]

    /* Compression Policy */
    private var strategy: UInt32 = Z_DEFAULT_STRATEGY

    private var dyn_ltree: Array<CTData> = NULL_ARR_CTData
    private var dyn_dtree: Array<CTData> = NULL_ARR_CTData
    private var bl_tree: Array<CTData> = NULL_ARR_CTData

    private var l_desc: TreeDescription = TreeDescription(dyn_ltree, 0, static_l_desc)
    private var d_desc: TreeDescription = TreeDescription(dyn_dtree, 0, static_d_desc)
    private var bl_desc: TreeDescription = TreeDescription(bl_tree,  0, static_bl_desc)

    private var bl_count: Array<UInt16> = NULL_ARR_UINT16

    private var heap: Array<UInt32> = NULL_ARR_UINT32
    private var heap_len: UInt32 = 0
    private var heap_max: Int64 = Int64(HEAP_SIZE)
    private var depth: Array<UInt8> = NULL_ARR_UINT8

    private var sym_buf: Array<UInt8> = pending_buf
    private var sym_next: Int64 = lit_bufsize
    private var sym_end: Int64 = (lit_bufsize - 1) * 3 + lit_bufsize

    private var opt_len: UInt32 = 0
    private var static_len: UInt32 = 0
    private var insert: UInt32 = 0

    private var bits_buf: UInt16 = 0
    private var bits_valid: UInt32 = 0
    private var high_water: UInt64 = 0

    private var max_dist: UInt32 = w_size - MIN_LOOKAHEAD

    private var stored_len: UInt32 = 0
    private var stored_state: UInt32 = 0

    var finished: Bool = false

    @Frozen
    public init() {}

    @Frozen
    public func deflateInit(level: Int64): Int32 {
        return this.deflateInit2(level, 15, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY)
    }

    @Frozen
    public func deflateInit(level: Int64, wbits: Int64): Int32 {
        return this.deflateInit2(level, wbits, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY)
    }

    @Frozen
    public func deflateInit2(lev: Int64, wbits: Int64, memLevel: UInt32, strategy: UInt32): Int32 {
        var level = lev
        var wrap = 1
        if (level == Z_DEFAULT_COMPRESSION) {
            level = 6
        }
        var windowBits = wbits
        if (windowBits < 0) { /* suppress zlib wrapper */
            wrap = 0
            if (windowBits < -15) {
                return Z_STREAM_ERROR
            }
            windowBits = -windowBits;
        } else if (windowBits > 15) { /* write gzip wrapper instead */
            wrap = 2
            windowBits -= 16;
        }
        if (memLevel < 1 || memLevel > MAX_MEM_LEVEL ||
            windowBits < 8 || windowBits > 15 || level < 0 || level > 9 ||
            strategy > Z_FIXED || (windowBits == 8 && wrap != 1)) {
            return Z_STREAM_ERROR;
        }
        if(windowBits == 8) {
            windowBits = 9
        }
        this.status = INIT_STATE
        this.wrap = wrap
        // s->gzhead = Z_NULL;
        this.w_bits = windowBits
        this.w_size = 1 << windowBits
        this.w_mask = this.w_size - 1
        this.hash_bits = memLevel + 7
        this.hash_size = 1 << hash_bits
        this.hash_mask = hash_size - 1
        this.hash_shift = ((hash_bits + MIN_MATCH - 1) / MIN_MATCH)
        this.window_size = w_size * 2
        try {
            this.window = Array<UInt8>(Int64(window_size), repeat: 0)
            this.prev = Array<UInt16>(Int64(w_size), repeat: 0)
            this.head = Array<UInt16>(Int64(hash_size), repeat: 0)
            this.high_water = 0
            this.lit_bufsize = 1 << (memLevel + 6)
            this.pending_buf = Array<UInt8>(this.lit_bufsize * 4, repeat: 0)
            this.pending_buf_size = this.lit_bufsize * 4
            this.bl_count = Array<UInt16>(Int64(MAX_BITS + 1), repeat: 0)
            this.bl_tree = Array<CTData>(Int64(2 * BL_CODES + 1), {_ => [0,0]})
            this.dyn_dtree = Array<CTData>(Int64(2 * D_CODES + 1), {_ => [0,0]})
            this.dyn_ltree = Array<CTData>(Int64(HEAP_SIZE), {_ => [0,0]})
            this.heap = Array<UInt32>(Int64(HEAP_SIZE), repeat: 0)
            this.depth = Array<UInt8>(Int64(HEAP_SIZE), repeat: 0)
        } catch (e: Exception) {
            this.status = FINISH_STATE
            this.message = erroMsg(Z_MEM_ERROR)
            deflateEnd()
            return Z_MEM_ERROR
        }
        this.sym_buf = this.pending_buf //TODO + this.lit_bufsize

        this.sym_end = (this.lit_bufsize - 1) * 3;
        this.level = Int64(level)
        this.strategy = UInt32(strategy)
        this.bl_desc = TreeDescription(bl_tree, 0, static_bl_desc)
        this.d_desc = TreeDescription(dyn_dtree, 0, static_d_desc)
        this.l_desc = TreeDescription(dyn_ltree, 0, static_l_desc)
        treeInit()
        return deflateReset()
    }

    @Frozen
    func deflateReset(): Int32 {
        var ret = deflateResetKeep()
        if (ret == Z_OK) {
            return ret
        }
        return ret
    }


    @Frozen
    func deflateResetKeep(): Int32 {
        this.total_in = 0
        this.total_out = 0
        this.data_type = 2  // Z_UNKNOWN
        this.pending = 0
        // this.pending_out = this.pending_buf
        if(this.wrap < 0) {
            this.wrap = -this.wrap
        }
        this.status = if (this.wrap == 2) {
            GZIP_STATE
        } else {
            INIT_STATE
        }
        this.adler = if (this.wrap == 2) {
            DEFAULT_CRC32
        } else {
            DEFAULT_ADLER32
        }
        this.last_flush = -2
        return Z_OK
    }


    @Frozen
    func hcrcUpdate(beg: Int64) {
        if (gzhead.hcrc != 0 && pending > beg) {
            adler = crc32(adler, pending_buf, beg, pending_start + pending - beg)
        }
    }

    /**
     * Compressing data.
     *
     * @param flush Compressing data
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func deflate(flush: Int32): Int32 {
        if (deflateStateCheck() == 1 || flush > Z_BLOCK || flush < Z_NO_FLUSH) {
            return Z_STREAM_ERROR
        }
        if (avail_out == 0 ||
            (avail_in != 0 && next_in.size == 0) ||
            (status == FINISH_STATE && flush != Z_FINISH)) {
            message = erroMsg(Z_STREAM_ERROR)
            return Z_STREAM_ERROR
        }
        if (avail_out == 0) {
            message = erroMsg(Z_BUF_ERROR)
            return Z_BUF_ERROR
        }
        let old_flush: Int32 = last_flush
        last_flush = flush
        if (pending != 0) {
            flushPending()
            if (avail_out == 0) {
                last_flush = Z_UNKNOWN_FLUSH
                return Z_OK
            }
        }
        /*
         else if (strm->avail_in == 0 && RANK(flush) <= RANK(old_flush) &&
               flush != Z_FINISH) {
         */
        else if (avail_in == 0 && flush != Z_FINISH) {
            /* to do: Repeated useless Z_FINISH calls return Z_STREAM_END */
            message = erroMsg(Z_BUF_ERROR)
            return Z_BUF_ERROR
        }
        if (status == FINISH_STATE && avail_in != 0) {
            message = erroMsg(Z_BUF_ERROR)
            return Z_BUF_ERROR
        }
        if (status == INIT_STATE && this.wrap == 0) {
            status = BUSY_STATE
        }
        if (status == INIT_STATE) {
            var header: UInt32 = (method + UInt32((w_bits - 8) << 4)) << 8
            var level_flags: UInt32
            if (strategy >= Z_HUFFMAN_ONLY || level < 2) {
                level_flags = 0
            } else if (level < 6) {
                level_flags = 1
            } else if (level == 6) {
                level_flags = 2
            } else {
                level_flags = 3
            }
            header |= (level_flags << 6)
            if (strstart != 0) {
                header |= PRESET_DICT
            }
            header += 31 - (header % 31)
            putShortMSB(UInt16(header))
            if (strstart != 0) {
                putShortMSB(UInt16(adler >> 16))
                putShortMSB(UInt16(adler & 0xFFFF))
            }
            adler = DEFAULT_ADLER32
            status = BUSY_STATE
            flushPending()
            if (pending != 0) {
                last_flush = Z_UNKNOWN_FLUSH
                return Z_OK
            }
        }
        // start GZIP
        if (status == GZIP_STATE) {
            adler = DEFAULT_CRC32
            /* to do: Currently, the done flag is used. Then, check whether the done flag has other functions. */
            putByte(31)
            putByte(139)
            putByte(8)
            if (gzhead.done == 0) {
                putByte(0)
                putByte(0)
                putByte(0)
                putByte(0)
                putByte(0)
                let uu: UInt8= if (level == 9) {
                    2
                } else if (strategy >= Z_HUFFMAN_ONLY || level < 2) {
                    4
                } else {
                    0
                }
                putByte(uu)
                putByte(UInt8(OS_CODE))
                status = BUSY_STATE
                flushPending()
                if (pending != 0) {
                    last_flush = Z_UNKNOWN_FLUSH
                    return Z_OK
                }
            } else {
                putByte(if (gzhead.text != 0) { 1 } else { 0 } +
                        if (gzhead.hcrc != 0) { 2 } else { 0 } +
                        if (let Some(v) <- gzhead.extra) { 0 } else { 4 } +
                        if (let Some(v) <- gzhead.name) { 0 } else { 8 } +
                        if (let Some(v) <- gzhead.comment) { 0 } else { 16 })
                putByte(UInt8(gzhead.time & 0xFF))
                putByte(UInt8((gzhead.time >> 8) & 0xFF))
                putByte(UInt8((gzhead.time >> 16) & 0xFF))
                putByte(UInt8((gzhead.time >> 24) & 0xFF))
                putByte(if (level == 9) { 2 } else if (strategy != Z_FILTERED || level < 2) { 4 } else { 0 })
                putByte(UInt8(gzhead.os & 0xFF))
                if (let Some(gzhead_extra) <- gzhead.extra) {
                    putByte(UInt8(gzhead.extra_len & 0xFF))
                    putByte(UInt8((gzhead.extra_len >> 8) & 0xFF))
                }
                if (gzhead.hcrc != 0) {
                    adler = crc32(adler, pending_buf, pending_start, pending)
                }
                gzindex = 0
                status = EXTRA_STATE
            }
        }
        if (status == EXTRA_STATE) {
            if (let Some(gzhead_extra) <- gzhead.extra) {
                var beging: Int64 = pending_start + pending
                var left: Int64 = (gzhead_extra.size & 0xFFFF) - gzindex
                while (pending_start + pending + left > pending_buf_size) {
                    var copy: Int64 = pending_buf_size - pending
                    for (i in 0..copy) {
                        pending_buf[pending_start + pending] = gzhead_extra[gzindex]
                        gzindex++
                        pending++ // SEE
                    }
                    // if (gzhead.hcrc != 0 && pending_start + pending > beging) {
                    //     adler = crc32(adler, pending_buf, beging, pending_start + pending - beging)
                    // }
                    this.hcrcUpdate(beging)
                    flushPending()
                    if (pending != 0) {
                        last_flush = Z_UNKNOWN_FLUSH
                        return Z_OK
                    }
                    beging = 0
                    left -= copy
                }
                for (i in 0..left) {
                    pending_buf[pending_start + pending] = gzhead_extra[gzindex]
                    pending++
                    gzindex++
                }
                // if (gzhead.hcrc != 0 && pending > beging) {
                //     adler = crc32(adler, pending_buf, beging, pending_start + pending - beging)
                // }
                this.hcrcUpdate(beging)
                gzindex = 0
            }
            status = NAME_STATE
        }
        if (status == NAME_STATE) {
            var gzhead_name: Array<Byte> = NULL_ARR_UINT8
            if (let Some(v) <- gzhead.name) {
                gzhead_name = v
            }
            if (gzhead_name.size > 0) {
                var begin: Int64 = pending_start + pending
                var pos: Int64
                do {
                    pos = pending_start + pending
                    if (pos == pending_buf_size) {
                        // if (gzhead.hcrc != 0 && pos > begin) {
                        //     adler = crc32(adler, pending_buf, begin, pos - begin)
                        // }
                        this.hcrcUpdate(begin)
                        flushPending()
                        if (pending != 0) {
                            last_flush = Z_UNKNOWN_FLUSH
                            return Z_OK
                        }
                        begin = 0
                    }
                    putByte(gzhead_name[Int64(gzindex)])
                    gzindex++
                } while (gzindex < gzhead_name.size)
                // putByte(0)
                this.hcrcUpdate(begin)
                gzindex = 0
                // pos = pending_start + pending
                // if (gzhead.hcrc != 0 && pos > begin) {
                    // adler = crc32(adler, pending_buf, begin, pos - begin)
                // }
            }
            status = COMMENT_STATE
        }
        if (status == COMMENT_STATE) {
            var gzhead_comment: Array<Byte> = NULL_ARR_UINT8
            if (let Some(v) <- gzhead.comment) {
                gzhead_comment = v
            }
            if (gzhead_comment.size > 0) {
                var begin: Int64 = pending_start + pending
                var pos: Int64
                do {
                    pos = pending_start + pending
                    if (pos == pending_buf_size) {
                        // if (gzhead.hcrc != 0 && pos > begin) {
                        //     adler = crc32(adler, pending_buf, begin, pos - begin)
                        // }
                        this.hcrcUpdate(begin)
                        flushPending()
                        if (pending != 0) {
                            last_flush = Z_UNKNOWN_FLUSH
                            return Z_OK
                        }
                        begin = 0
                    }
                    putByte(gzhead_comment[Int64(gzindex)])
                    gzindex++
                } while (gzindex < gzhead_comment.size)
                this.hcrcUpdate(begin)
                // putByte(0)
                // gzindex = 0
                // pos = pending_start + pending
                // if (gzhead.hcrc != 0 && pos > begin) {
                //     adler = crc32(adler, pending_buf, begin, pos - begin)
                // }
            }
            status = HCRC_STATE
        }
        if (status == HCRC_STATE) {
            if (gzhead.hcrc != 0) {
                if (pending_start + pending + 2 > pending_buf_size) {
                    flushPending()
                    if (pending != 0) {
                        last_flush = Z_UNKNOWN_FLUSH
                        return Z_OK
                    }
                }
                putByte(UInt8(adler & 0xFF))
                putByte(UInt8((adler >> 8) & 0xFF))
                adler = DEFAULT_CRC32
            }
            status = BUSY_STATE
            flushPending()
            if (pending != 0) {
                last_flush = Z_UNKNOWN_FLUSH
                return Z_OK
            }
        }
        // end GZIP
        if (avail_in != 0 || lookahead != 0 || (flush != Z_NO_FLUSH && status != FINISH_STATE)) {
            var bstate: UInt32
            if (level == 0) {
                bstate = deflateStored(this, flush)
            } else if (strategy == Z_HUFFMAN_ONLY) {
                bstate = deflateHuffman(flush)
            } else if (strategy == Z_RLE) {
                bstate = deflateRLE(flush)
            } else {
                bstate = configuration_table[Int64(level)][4](this, flush)
            }

            if (bstate == FINISH_STARTED || bstate == FINISH_DONE) {
                status = FINISH_STATE
            }
            if (bstate == NEED_MORE || bstate == FINISH_STARTED) {
                if (avail_out == 0) {
                    last_flush = Z_UNKNOWN_FLUSH
                }
                return Z_OK
            }
            if (bstate == BLOCK_DONE) {
                if (flush == Z_PARTIAL_FLUSH) {
                    flushEmptyStaticBlock()
                } else if (flush != Z_BLOCK) {
                    storedBlock(0, 0, false)
                    if (flush == Z_FULL_FLUSH) {
                        for (i in 0..head.size) {
                            head[i] = 0
                        }
                        if (lookahead == 0) {
                            strstart = 0
                            block_start = 0
                            insert = 0
                        }
                    }
                }
                flushPending()
                if (avail_out == 0) {
                    last_flush = Z_UNKNOWN_FLUSH
                    return Z_OK
                }
            }
        }
        if (flush != Z_FINISH) {
            return Z_OK
        }
        if (this.wrap <= 0) {
            message = erroMsg(Z_STREAM_END)
            this.finished = true
            return Z_STREAM_END
        }
        match (wrap) {
            /* to do: wrap */
            case 0 =>
                this.finished = true
                return Z_STREAM_END
            case 2 =>
                putByte(UInt8(adler & 0xFF))
                putByte(UInt8((adler >> 8) & 0xFF))
                putByte(UInt8((adler >> 16) & 0xFF))
                putByte(UInt8((adler >> 24) & 0xFF))
                putByte(UInt8(total_in & 0xFF))
                putByte(UInt8((total_in >> 8) & 0xFF))
                putByte(UInt8((total_in >> 16) & 0xFF))
                putByte(UInt8((total_in >> 24) & 0xFF))
            case _ =>
                putShortMSB(UInt16(adler >> 16))
                putShortMSB(UInt16(adler & 0xFFFF))
        }
        flushPending()
        /* to do: wrap */
        if (this.wrap > 0) {
            this.wrap = -this.wrap
        }
        if (pending != 0) {
            return Z_OK
        }
        message = erroMsg(Z_STREAM_END)
        this.finished = true
        return Z_STREAM_END
    }

    /**
     * This command is invoked after the compression is complete to check the compression status.
     *
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func deflateEnd(): Int32 { // TODO
        if (deflateStateCheck() != 0) {
            message = erroMsg(Z_STREAM_ERROR)
            return Z_STREAM_ERROR
        }
        if (status == BUSY_STATE) {
            message = erroMsg(Z_DATA_ERROR)
            return Z_DATA_ERROR
        }
        this.finished = true
        return Z_OK
    }

    func deflateStateCheck(): UInt32 {
        if (this.status != INIT_STATE &&
            this.status != GZIP_STATE &&
            this.status != EXTRA_STATE &&
            this.status != NAME_STATE &&
            this.status != COMMENT_STATE &&
            this.status != HCRC_STATE &&
            this.status != BUSY_STATE &&
            this.status != FINISH_STATE){
                return 1
        }
        return 0
    }

    /**
     * Calculate the maximum size of compressed data based on the source data size.
     *
     * @param sourceLen Source data size
     * @return Int64 Returns a value of the Int64 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func deflateBound(sourceLen: Int64): Int64 {
        var fixedlen = sourceLen + (sourceLen >> 3) + (sourceLen >> 8) + (sourceLen >> 9) + 4
        var storelen = sourceLen + (sourceLen >> 5) + (sourceLen >> 7) + (sourceLen >> 11) + 7
        if (deflateStateCheck() != 0) {
            return if(fixedlen > storelen) {
                fixedlen
            } else {
                storelen
            } + 6
        }
        // var complen: Int64 = sourceLen + ((sourceLen + 7) >> 3) + ((sourceLen + 63) >> 6) + 5
        var wraplen: Int64 = 0
        match (wrap) {
            case 0 => wraplen = 0
            case 1    => wraplen = 6 + if (strstart > 0) { 4 } else { 0 }
            case 2    =>
                wraplen = 18

                if (let Some(gzhead_extra) <- gzhead.extra) {
                    wraplen += 2 + Int64(gzhead.extra_len)
                }
                if (let Some(gzhead_name) <- gzhead.name) {
                    wraplen += gzhead_name.size
                }
                if (let Some(gzhead_comment) <- gzhead.comment) {
                    wraplen += gzhead_comment.size
                }

                if (gzhead.hcrc != 0) {
                    wraplen += 2
                }
            case _ => wraplen = 6
        }
        if (w_bits != 15 || hash_bits != 8 + 7) {
            return if (w_bits <= Int64(hash_bits) && level != 0) {
                fixedlen
            } else {
                storelen
            } + wraplen
        }
        return sourceLen + (sourceLen >> 12) + (sourceLen >> 14) + (sourceLen >> 25) + 13 - 6 + wraplen
    }

    /**
     * After initialization is complete and before compression starts, call this function to set the dictionary.
     * The zlib file format supports the dictionary.
     *
     * @param dict Set dictionary data
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func setDictionary(dict: Array<UInt8>): Int32 {
        if (status < INIT_STATE || status > FINISH_STATE || dict.size == 0) {
            return Z_STREAM_ERROR
        }
        var wrap: Int64 = this.wrap
        match (wrap) {
            case 2 =>
                return Z_STREAM_ERROR
            case 1 =>
                if (status != INIT_STATE || lookahead > 0) {
                    return Z_STREAM_ERROR
                }
                adler = adler32(adler, dict, 0, dict.size)
            case 0 =>
                if (lookahead > 0) {
                    return Z_STREAM_ERROR
                }
            case _ => ()
        }
        this.wrap = 0
        var start: Int64 = 0
        if (dict.size >= Int64(w_size)) {
            if (wrap == 0) {
                for (i in 0..head.size) {
                    head[i] = 0
                }
                strstart = 0
                block_start = 0
                insert = 0
            }
            start = dict.size - Int64(w_size)
        }

        var avail: Int64 = avail_in
        var posin: Int64 = pos_in
        var next: Array<UInt8> = next_in
        avail_in = dict.size - start
        pos_in = start
        next_in = dict
        fillWindow()
        var str: UInt32
        var n: UInt32
        while (lookahead >= MIN_MATCH) {
            str = strstart
            n = lookahead - (MIN_MATCH - 1)
            do {
                updateHash(ins_h, window[Int64(str + MIN_MATCH - 1)])
                prev[Int64(str & w_mask)] = head[Int64(ins_h)]
                head[Int64(ins_h)] = UInt16(str)
                str++
                n--
            } while (n > 0)
            strstart = str
            lookahead = MIN_MATCH - 1
            fillWindow()
        }
        strstart += lookahead
        block_start = Int64(strstart)
        insert = lookahead
        lookahead = 0
        match_length = MIN_MATCH - 1
        prev_length = MIN_MATCH - 1
        match_available = false
        next_in = next
        avail_in = avail
        pos_in = posin
        this.wrap = wrap
        return Z_OK
    }

    /**
     * This command is used to set the header information in the gzip format when the compressed file is in the gzip format.
     *
     * @param gzhead Header information in gzip format
     * @return UInt32 Returns a value of the UInt32 type.
     *
     * @since 0.24.2
     */
    @Frozen
    public func deflateSetHeader(gzhead: GZIPHeader): Int32 {
        if (deflateStateCheck() != 0 || this.wrap != 2) {
            return Z_STREAM_ERROR
        }
        this.gzhead = gzhead
        return Z_OK
    }

    @Frozen
    private func putByte(data: UInt8): Unit {
        pending_buf[Int64(pending_start + pending)] = data
        pending++
    }

    @Frozen
    private func putShortMSB(data: UInt16): Unit {
        putByte(UInt8(data >> 8))
        putByte(UInt8(data & 0xFF))
    }

    @Frozen
    private func putShort(data: UInt16): Unit {
        putByte(UInt8(data & 0xFF))
        putByte(UInt8(data >> 8))
    }

    @Frozen
    private func sendBits(value: UInt32, length: UInt32): Unit {
        if (length > BUF_SIZE - bits_valid) {
            bits_buf |= UInt16((value << bits_valid) & 0xFFFF)
            putShort(bits_buf)
            bits_buf = UInt16((value >> (BUF_SIZE - bits_valid)) & 0xFFFF)
            bits_valid = bits_valid + length - BUF_SIZE
        } else {
            bits_buf |= UInt16((value << bits_valid) & 0xFFFF)
            bits_valid += length
        }
    }

    @Frozen
    private func flushPending(): Unit {
        bitsFlush()
        var len: Int64 = pending
        if (len > Int64(avail_out)) {
            len = avail_out
        }
        if (len == 0) {
            return
        }
        for (i in 0..len) {
            next_out[pos_out] = pending_buf[pending_start]
            pos_out++
            pending_start++
        }
        avail_out -= len
        total_out += len
        pending -= Int64(len)
        if (pending == 0) {
            pending_start = 0
        }
    }

    @Frozen
    private func tallyDistance(distance: UInt32, length: UInt32): Bool {
        var dist: UInt32 = distance
        pending_buf[sym_next] = UInt8(dist & 0xFF)
        sym_next++
        pending_buf[sym_next] = UInt8((dist >> 8) & 0xFF)
        sym_next++
        pending_buf[sym_next] = UInt8(length & 0xFF)
        sym_next++
        dist--
        dyn_ltree[Int64(length_code[Int64(length)]) + Int64(LITERALS) + 1][freq_code]++
        if (dist < 256) {
            dyn_dtree[Int64(dist_code[Int64(dist)])][freq_code]++
        } else {
            dyn_dtree[Int64(dist_code[256 + Int64(dist >> 7)])][freq_code]++
        }
        return sym_next == sym_end + lit_bufsize
    }

    @Frozen
    private func tallyLiteral(c: UInt8): Bool {
        sym_buf[sym_next] = 0
        sym_next++
        sym_buf[sym_next] = 0
        sym_next++
        sym_buf[sym_next] = c
        sym_next++
        dyn_ltree[Int64(c)][freq_code]++
        return sym_next == sym_end + lit_bufsize
    }

    // configuration_table
    @Frozen
    private static func deflateStored(_: Deflate, _: Int32): UInt32 {
        return FINISH_DONE
    }

    @Frozen
    private func deflateHuffman(flush: Int32): UInt32 {
        var bflush: Bool
        while (true) {
            if (lookahead == 0) {
                fillWindow()
                if (lookahead == 0) {
                    if (flush == Z_NO_FLUSH) {
                        return NEED_MORE
                    }
                    break
                }
            }
            match_length = 0
            bflush = tallyLiteral(window[Int64(strstart)])
            lookahead--
            strstart++
            if (bflush) {
                flushBlock(block_start, Int64(strstart) - block_start, false)
                block_start = Int64(strstart)
                flushPending()
                if (avail_out == 0) {
                    return NEED_MORE
                }
            }
        }
        insert = 0
        if (flush == Z_FINISH) {
            flushBlock(block_start, Int64(strstart) - block_start, true)
            block_start = Int64(strstart)
            flushPending()
            if (avail_out == 0) {
                return FINISH_STARTED
            }
            return FINISH_DONE
        }
        if (sym_next == sym_end) {
            flushBlock(block_start, Int64(strstart) - block_start, false)
            block_start = Int64(strstart)
            flushPending()
            if (avail_out == 0) {
                return NEED_MORE
            }
            return BLOCK_DONE
        }
        return NEED_MORE
    }

    @Frozen
    private func deflateRLE(flush: Int32): UInt32 {
        var bflush: Bool
        var prev: UInt8
        var scanPos: Int64
        var scanEnd: Int64
        while (true) {
            if (lookahead <= MAX_MATCH) {
                fillWindow()
                if (lookahead <= MAX_MATCH && flush == Z_NO_FLUSH) {
                    return NEED_MORE
                }
                if (lookahead == 0) {
                    break
                }
            }
            match_length = 0
            if (lookahead >= MIN_MATCH && strstart > 0) {
                scanPos = Int64(strstart) - 1
                prev = window[Int64(scanPos)]
                if (lookahead > MAX_MATCH) {
                    scanEnd = Int64(strstart + MAX_MATCH)
                } else {
                    scanEnd = Int64(strstart + lookahead)
                }
                while (scanPos < scanEnd) {
                    if (prev != window[scanPos]) {
                        break
                    }
                    scanPos++
                }
                match_length = UInt32(scanPos) - strstart
            }
            if (match_length >= MIN_MATCH) {
                bflush = tallyDistance(1, match_length - MIN_MATCH)
                lookahead -= match_length
                strstart += match_length
                match_length = 0
            } else {
                bflush = tallyLiteral(window[Int64(strstart)])
                lookahead--
                strstart++
            }
            if (bflush) {
                flushBlock(block_start, Int64(strstart) - block_start, false)
                block_start = Int64(strstart)
                flushPending()
                if (avail_out == 0) {
                    return NEED_MORE
                }
            }
        }
        insert = 0
        if (flush == Z_FINISH) {
            flushBlock(block_start, Int64(strstart) - block_start, true)
            block_start = Int64(strstart)
            flushPending()
            if (avail_out == 0) {
                return FINISH_STARTED
            }
            return FINISH_DONE
        }
        if (sym_next == sym_end) {
            flushBlock(block_start, Int64(strstart) - block_start, false)
            block_start = Int64(strstart)
            flushPending()
            if (avail_out == 0) {
                return NEED_MORE
            }
            return BLOCK_DONE
        }
        return NEED_MORE
    }

    @Frozen
    private func deflateQuick(_: Int32): UInt32 {
        return FINISH_DONE
    }

    // configuration_table
    @Frozen
    private static func deflateFast(that: Deflate, flush: Int32): UInt32 {
        var hash_head: UInt32 = 0
        var bflush: Bool
        while (true) {
            if (that.lookahead < MIN_LOOKAHEAD) {
                that.fillWindow()
                if (that.lookahead < MIN_LOOKAHEAD && flush == Z_NO_FLUSH) {
                    return NEED_MORE
                }
                if (that.lookahead == 0) {
                    break
                }
            }
            hash_head = 0
            if (that.lookahead >= MIN_MATCH) {
                hash_head = that.insertString(that.strstart)
            }
            if (hash_head != 0 && (that.strstart - hash_head) <= that.max_dist) {
                that.match_length = that.longestMatch(hash_head)
            }
            if (that.match_length >= MIN_MATCH) {
                bflush = that.tallyDistance(UInt32(Int64(that.strstart) - that.match_start), that.match_length - MIN_MATCH)
                that.lookahead -= that.match_length
                if (that.match_length <= that.max_insert_length && that.lookahead >= MIN_MATCH) {
                    that.match_length--
                    do {
                        that.strstart++
                        that.insertString(that.strstart)
                        that.match_length--
                    } while (that.match_length != 0)
                    that.strstart++
                } else {
                    that.strstart += that.match_length
                    that.match_length = 0
                    that.ins_h = UInt16(that.window[Int64(that.strstart)])
                    that.updateHash(that.ins_h, that.window[Int64(that.strstart) + 1])
                }
            } else {
                bflush = that.tallyLiteral(that.window[Int64(that.strstart)])
                that.lookahead--
                that.strstart++
            }
            if (bflush) {
                that.flushBlock(that.block_start, Int64(that.strstart) - that.block_start, false)
                that.block_start = Int64(that.strstart)
                that.flushPending()
                if (that.avail_out == 0) {
                    return NEED_MORE
                }
            }
        }
        that.insert = if (that.strstart < MIN_MATCH - 1) { that.strstart } else { MIN_MATCH - 1 }
        if (flush == Z_FINISH) {
            that.flushBlock(that.block_start, Int64(that.strstart) - that.block_start, true)
            that.block_start = Int64(that.strstart)
            that.flushPending()
            if (that.avail_out == 0) {
                return FINISH_STARTED
            }
            return FINISH_DONE
        }
        /* to do: Compress the block into one block only when it is full. Check whether Z_FIXED has a bug. */
        if (that.sym_next == that.sym_end) {
            that.flushBlock(that.block_start, Int64(that.strstart) - that.block_start, false)
            that.block_start = Int64(that.strstart)
            that.flushPending()
            if (that.avail_out == 0) {
                return NEED_MORE
            }
            return BLOCK_DONE
        }
        return NEED_MORE
    }

    @Frozen
    private func deflateMedium(_: UInt32): UInt32 {
        return FINISH_DONE
    }

    // configuration_table
    @Frozen
    private static func deflateSlow(that: Deflate, flush: Int32): UInt32 {
        var hash_head: UInt32 = 0
        var bflush: Bool = false
        while (true) {
            if (that.lookahead < MIN_LOOKAHEAD) {
                that.fillWindow()
                if (that.lookahead < MIN_LOOKAHEAD && flush == Z_NO_FLUSH) {
                    return NEED_MORE
                }
                if (that.lookahead == 0) {
                    break
                }
            }
            hash_head = 0
            if (that.lookahead >= MIN_MATCH) {
                hash_head = that.insertString(that.strstart)
            }

            that.prev_length = that.match_length
            that.prev_start = if (that.match_start > 0) { UInt32(that.match_start) } else { 0 }
            that.match_length = MIN_MATCH - 1
            if (hash_head != 0 && that.prev_length < that.max_lazy_match && that.strstart - hash_head <= that.max_dist) {
                that.match_length = that.longestMatch(hash_head)
                /* to do: I don't know why. */
                if ((that.strategy == Z_FILTERED && that.match_length <= 5) ||
                    (that.match_length == MIN_MATCH && UInt32(Int64(that.strstart) - that.match_start) > TOO_FAR)) {
                    that.match_length = MIN_MATCH - 1
                }
            }
            if (that.prev_length >= MIN_MATCH && that.match_length <= that.prev_length) {
                var max_insert: UInt32 = that.strstart + that.lookahead - MIN_MATCH

                bflush = that.tallyDistance(that.strstart - 1 - that.prev_start, that.prev_length - MIN_MATCH)
                that.lookahead -= that.prev_length - 1
                that.prev_length -= 2
                do {
                    that.strstart++
                    if (that.strstart <= max_insert) {
                        that.updateHash(that.ins_h, that.window[Int64(that.strstart) + 2])
                        that.prev[Int64(that.strstart & that.w_mask)] = that.head[Int64(that.ins_h)]
                        that.head[Int64(that.ins_h)] = UInt16(that.strstart)
                    }
                    that.prev_length--
                } while (that.prev_length != 0)
                that.match_available = false
                that.match_length = MIN_MATCH - 1
                that.strstart++
                if (bflush) {
                    that.flushBlock(that.block_start, Int64(that.strstart) - that.block_start, false)
                    that.block_start = Int64(that.strstart)
                    that.flushPending()
                    if (that.avail_out == 0) {
                        return NEED_MORE
                    }
                }
            } else if (that.match_available) {
                bflush = that.tallyLiteral(that.window[Int64(that.strstart) - 1])
                if (bflush) {
                    that.flushBlock(that.block_start, Int64(that.strstart) - that.block_start, false)
                    that.block_start = Int64(that.strstart)
                    that.flushPending()
                }
                that.strstart++
                that.lookahead--
                if (that.avail_out == 0) {
                    return NEED_MORE
                }
            } else {
                that.match_available = true
                that.strstart++
                that.lookahead--
            }
        }
        if (that.match_available) {
            bflush = that.tallyLiteral(that.window[Int64(that.strstart) - 1])
            that.match_available = false
        }
        that.insert = if (that.strstart < MIN_MATCH - 1) { that.strstart } else { MIN_MATCH - 1 }
        if (flush == Z_FINISH) {
            that.flushBlock(that.block_start, Int64(that.strstart) - that.block_start, true)
            that.block_start = Int64(that.strstart)
            that.flushPending()
            if (that.avail_out == 0) {
                return FINISH_STARTED
            }
            return FINISH_DONE
        }
        if (that.sym_next == that.sym_end) {
            that.flushBlock(that.block_start, Int64(that.strstart) - that.block_start, false)
            that.block_start = Int64(that.strstart)
            that.flushPending()
            if (that.avail_out == 0) {
                return NEED_MORE
            }
            return BLOCK_DONE
        }
        return NEED_MORE
    }

    @Frozen
    private func fillWindow(): Unit {
        var n: UInt32
        var more: UInt32
        var offset: UInt32
        do {
            more = window_size - lookahead - strstart
            if (strstart >= window_size - MIN_LOOKAHEAD) {
                offset = w_size - more
                for (i in 0..Int64(offset)) {
                    window[i] = window[i + Int64(w_size)]
                }
                match_start -= Int64(w_size)
                strstart -= w_size
                block_start -= Int64(w_size)
                if (insert > strstart) {
                    insert = strstart
                }
                let off = UInt16(w_size)
                for (i in 0..head.size) {
                    let j = head[i]
                    head[i] = if (j > off) { j - off } else { 0 }
                }
                for (i in 0..prev.size) {
                    let j = prev[i]
                    prev[i] = if (j > off) { j - off } else { 0 }
                }
                more += w_size
            }
            if (avail_in == 0) {
                break
            }
            n = readBuf(window, strstart + lookahead, more)
            lookahead += n
            /* to do: */
            if (lookahead + insert >= MIN_MATCH) {
                var str: Int64 = Int64(strstart - insert)
                updateHash(UInt16(window[str]), window[str + 1])
                while (insert != 0) {
                    updateHash(ins_h, window[str + Int64(MIN_MATCH) - 1])
                    prev[str & Int64(w_mask)] = head[Int64(ins_h)]
                    head[Int64(ins_h)] = UInt16(str)
                    str++
                    insert--
                    if (lookahead + insert < MIN_MATCH) {
                        break
                    }
                }
            }
        } while (lookahead < MIN_LOOKAHEAD && avail_in != 0)
    }

    @Frozen
    private func updateHash(hash: UInt16, c: UInt8): Unit {
        ins_h = ((hash << hash_shift) ^ UInt16(c)) & UInt16(hash_mask)
    }

    @Frozen
    private func insertString(pos: UInt32): UInt32 {
        updateHash(ins_h, window[Int64(pos) + 2])
        let prev_pos: UInt32 = UInt32(head[Int64(ins_h)])
        prev[Int64(pos & w_mask)] = UInt16(prev_pos)
        head[Int64(ins_h)] = UInt16(pos)
        return prev_pos
    }

    @Frozen
    private func readBuf(buf: Array<UInt8>, start: UInt32, size: UInt32): UInt32 {
        var len: Int64 = avail_in
        if (len > Int64(size)) {
            len = Int64(size)
        }
        if (len == 0) {
            return 0
        }
        avail_in -= len
        for (i in 0..len) {
            buf[Int64(start) + i] = next_in[pos_in]
            pos_in++
        }
        match (wrap) {
            case 2 => adler = crc32(adler, buf, Int64(start), len)
            case 1 => adler = adler32(adler, buf, Int64(start), len)
            case _ => ()
        }
        total_in += len
        return UInt32(len)
    }

    @Frozen
    private func longestMatch(curmatch: UInt32): UInt32 {
        var len: UInt32
        var cur_match: UInt32 = curmatch
        var chain_length: UInt32 = max_chain_length
        var best_len: UInt32 = prev_length
        var nice_len: UInt32 = nice_length
        var limit: UInt32 = if (strstart > max_dist) {strstart - max_dist} else { 0 }
        var cur_pos: UInt32 = strstart
        var max_pos: UInt32 = strstart + if (lookahead >= MAX_MATCH) { MAX_MATCH } else { lookahead }
        if (prev_length >= good_length) {
            chain_length >>= 2
        }
        if (nice_len > lookahead) {
            nice_len = lookahead
        }
        do {
            var match_pos: UInt32 = cur_match
            if (window[Int64(match_pos + best_len)] != window[Int64(cur_pos + best_len)] || 
                window[Int64(match_pos + best_len - 1)] != window[Int64(cur_pos + best_len - 1)] || 
                window[Int64(match_pos)] != window[Int64(cur_pos)] || 
                window[Int64(match_pos + 1)] != window[Int64(cur_pos + 1)]) {
                cur_match = UInt32(prev[Int64(cur_match & w_mask)])
                chain_length--
                /* The break code is added to the language bug. To do: The code is deleted after this problem is solved. */
                if (cur_match > limit && chain_length != 0) {
                    continue
                }
                break
            }
            match_pos += 2
            cur_pos += 2
            while (cur_pos < max_pos) {
                if (window[Int64(match_pos)] != window[Int64(cur_pos)]) {
                    break
                }
                cur_pos++
                match_pos++
            }
            len = cur_pos - strstart
            cur_pos = strstart
            if (len > best_len) {
                match_start = Int64(cur_match)
                best_len = len
                if (len >= nice_len) {
                    break
                }
            }
            cur_match = UInt32(prev[Int64(cur_match & w_mask)])
            chain_length--
        } while (cur_match > limit && chain_length != 0)
        if (best_len > lookahead) {
            return lookahead
        }
        return best_len
    }

    @Frozen
    private func treeInit(): Unit {
        initStaticTree()
        l_desc.dyn_tree = dyn_ltree
        l_desc.static_desc = static_l_desc
        d_desc.dyn_tree = dyn_dtree
        d_desc.static_desc = static_d_desc
        bl_desc.dyn_tree = bl_tree
        bl_desc.static_desc = static_bl_desc
        bits_buf = 0
        bits_valid = 0
        initBlock()
    }

    /* to do */
    @Frozen
    private func initStaticTree() {}

    @Frozen
    private func initBlock(): Unit {
        for (i in 0..Int64(L_CODES)) {
            dyn_ltree[i][freq_code] = 0
        }
        for (i in 0..Int64(D_CODES)) {
            dyn_dtree[i][freq_code] = 0
        }
        for (i in 0..Int64(BL_CODES)) {
            bl_tree[i][freq_code] = 0
        }
        dyn_ltree[END_BLOCK][freq_code] = 1
        opt_len = 0
        static_len = 0
        sym_next = lit_bufsize
    }

    @Frozen
    private func bitsReverse(code: UInt32, len: Int32): UInt32 {
        var result: UInt32 = 0
        var val: UInt32 = code
        var length: Int32 = len
        do {
            result |= val & 1
            val >>= 1
            result <<= 1
            length -= 1
        } while (length > 0)
        return result >> 1
    }

    @Frozen
    private func bitsFlush(): Unit {
        if (bits_valid == 16) {
            putShort(bits_buf)
            bits_buf = 0
            bits_valid = 0
        } else if (bits_valid >= 8) {
            putByte(UInt8(bits_buf & 0xFF))
            bits_buf >>= 8
            bits_valid -= 8
        }
    }

    @Frozen
    private func bitsFlushAlign(): Unit {
        if (bits_valid > 8) {
            putShort(bits_buf)
        } else if (bits_valid > 0) {
            putByte(UInt8(bits_buf & 0xFF))
        }
        bits_buf = 0
        bits_valid = 0
    }

    @Frozen
    private func flushBlock(start: Int64, stored_lenb: Int64, last: Bool): Unit {
        var opt_lenb: UInt32 = 0
        var static_lenb: UInt32 = 0
        var max_bindex: UInt32 = 0
        if (level > 0) {
            match (data_type) {
                case 0 => data_type = detectDataType()
                case _ => ()
            }
            buildTree(l_desc)
            buildTree(d_desc)
            max_bindex = buildBLTree()
            opt_lenb = (opt_len + 3 + 7) >> 3
            static_lenb = (static_len + 3 + 7) >> 3
            if (static_lenb <= opt_lenb) {
                opt_lenb = static_lenb
            }
        } else {
            static_lenb = UInt32(stored_lenb) + 5
            opt_lenb = static_lenb
        }
        var last_val: UInt32 = if (last) { 1 } else { 0 }
        if (stored_lenb + 4 <= Int64(opt_lenb) && start >= 0) {
            storedBlock(UInt32(start), UInt32(stored_lenb), last)
        } else if (strategy == Z_FIXED || static_lenb == opt_lenb) {
            sendBits((STATIC_TREES << 1) + last_val, 3)
            compressBlock(static_ltree, static_dtree)
        } else {
            sendBits((DYN_TREES << 1) + last_val, 3)
            sendAllTrees(l_desc.max_code + 1, d_desc.max_code + 1, max_bindex + 1)
            compressBlock(dyn_ltree, dyn_dtree)
        }
        initBlock()
        if (last) {
            bitsFlushAlign()
        }
    }

    @Frozen
    private func flushEmptyStaticBlock(): Unit {
        sendBits(STATIC_TREES << 1, 3)
        sendBits(UInt32(static_ltree[END_BLOCK][freq_code]), UInt32(static_ltree[END_BLOCK][dad_len]))
        bitsFlush()
    }

    @Frozen
    private func detectDataType(): Int32 {
        var black_mask: UInt32 = 0xF3FFC07F
        for (i in 0..=31) {
            if ((black_mask & 1) != 0 && dyn_ltree[i][freq_code] != 0) {
                return Z_BINARY
            }
        }
        if (dyn_ltree[9][freq_code] != 0 || dyn_ltree[10][freq_code] != 0 || dyn_ltree[13][freq_code] != 0) {
            return Z_TEXT
        }
        for (i in 32..Int64(LITERALS)) {
            if (dyn_ltree[i][freq_code] != 0) {
                return Z_TEXT
            }
        }
        return Z_BINARY
    }

    @Frozen
    private func downHeap(tree: Array<CTData>, pos: Int64): Unit {
        var k: Int64 = pos
        var v: Int64 = Int64(heap[k])
        var j: Int64 = Int64(k << 1)
        var n: Int64
        var m: Int64
        while (j <= Int64(heap_len)) {
            n = Int64(heap[j + 1])
            m = Int64(heap[j])
            if (j < Int64(heap_len) && (tree[n][freq_code] < tree[m][freq_code] ||
               (tree[n][freq_code] == tree[m][freq_code] && depth[n] <= depth[m]))) {
                j++
            }
            n = v
            m = Int64(heap[j])
            if (tree[n][freq_code] < tree[m][freq_code] ||
               (tree[n][freq_code] == tree[m][freq_code] && depth[n] <= depth[m])) {
                break
            }
            heap[k] = heap[j]
            k = j
            j <<= 1
        }
        heap[k] = UInt32(v)
    }

    @Frozen
    private func genBitLength(desc: TreeDescription): Unit {
        var tree: Array<CTData> = desc.dyn_tree
        var max_code: Int64 = Int64(desc.max_code)
        var stree: Array<CTData> = desc.static_desc.static_tree
        var extra: Array<UInt8> = desc.static_desc.extra_bits
        var base: Int64 = Int64(desc.static_desc.extra_base)
        var max_length: Int64 = Int64(desc.static_desc.max_length)
        for (i in 0..=Int64(MAX_BITS)) {
            bl_count[i] = 0
        }
        tree[Int64(heap[heap_max])][dad_len] = 0
        var n: Int64
        var m: Int64
        var bits: Int64
        var xbits: UInt32
        var overflow: Int32 = 0
        var freq: UInt16
        var start: Int64 = heap_max + 1
        for (i in start..Int64(HEAP_SIZE)) {
            n = Int64(heap[i])
            bits = Int64(tree[Int64(tree[n][dad_len])][dad_len] + 1)
            if (bits > max_length) {
                bits = max_length
                overflow++
            }
            tree[n][dad_len] = UInt16(bits)

            if (n > max_code) {
                continue
            }
            bl_count[bits]++
            xbits = 0
            if (n >= base) {
                xbits = UInt32(extra[n - base])
            }
            freq = tree[n][freq_code]
            opt_len += UInt32(freq) * (UInt32(bits) + xbits)
            if (stree.size > 0) {
                static_len += UInt32(freq) * (UInt32(stree[n][dad_len]) + UInt32(xbits))
            }
        }
        if (overflow == 0) {
            return
        }
        do {
            bits = max_length - 1
            while (bl_count[bits] == 0) {
                bits--
            }
            bl_count[bits]--
            bl_count[bits + 1] = bl_count[bits + 1] + 2
            bl_count[max_length]--
            overflow -= 2
        } while (overflow > 0)
        var h: Int64 = Int64(HEAP_SIZE)
        bits = max_length
        while (bits != 0) {
            n = Int64(bl_count[bits])
            while (n != 0) {
                h--
                m = Int64(heap[h])
                if (m > max_code) {
                    continue
                }
                if (tree[m][dad_len] != UInt16(bits)) {
                    if (UInt32(bits) >= UInt32(tree[m][dad_len])) {
                        opt_len += (UInt32(bits) - UInt32(tree[m][dad_len])) * UInt32(tree[m][freq_code])
                    } else {
                        opt_len += (UInt32(tree[m][dad_len]) - UInt32(bits)) * UInt32(tree[m][freq_code])
                    }
                    tree[m][dad_len] = UInt16(bits)
                }
                n--
            }
            bits--
        }
    }

    @Frozen
    private func genCodes(tree: Array<CTData>, max_code: UInt32, bl_count: Array<UInt16>): Unit {
        var code: UInt32 = 0
        var max_bits: Int64 = Int64(MAX_BITS)
        var next_code: Array<UInt16> = Array<UInt16>(max_bits + 1, { i => 0 })
        for (i in 1..=max_bits) {
            code = (code + UInt32(bl_count[i - 1])) << 1
            next_code[i] = UInt16(code)
        }
        var len: UInt16
        for (i in 0..=Int64(max_code)) {
            len = tree[i][dad_len]
            if (len == 0) {
                continue
            }
            tree[i][freq_code] = UInt16(bitsReverse(UInt32(next_code[Int64(len)]), Int32(len)))
            next_code[Int64(len)] = next_code[Int64(len)] + 1
        }
    }

    @Frozen
    private func buildTree(desc: TreeDescription): Unit {
        var tree: Array<CTData> = desc.dyn_tree
        var stree: Array<CTData> = desc.static_desc.static_tree
        var element: Int64 = Int64(desc.static_desc.max_element)
        var max_code: Int32 = -1
        var node: Int64
        heap_len = 0
        heap_max = Int64(HEAP_SIZE)
        for (i in 0..element) {
            if (tree[i][freq_code] != 0) {
                heap_len++
                heap[Int64(heap_len)] = UInt32(i)
                max_code = Int32(i)
                depth[i] = 0
            } else {
                tree[i][dad_len] = 0
            }
        }
        while (heap_len < 2) {
            heap_len++
            if (max_code < 2) {
                max_code++
                heap[Int64(heap_len)] = UInt32(max_code)
                node = Int64(max_code)
            } else {
                heap[Int64(heap_len)] = 0
                node = 0
            }
            tree[node][freq_code] = 1
            depth[node] = 0
            opt_len--
            if (stree.size > 0) {
                static_len -= UInt32(stree[node][dad_len])
            }
        }
        desc.max_code = UInt32(max_code)
        for (i in Int64(heap_len/2)..=1:-1) {
            downHeap(tree, i)
        }
        node = element
        var top1: Int64
        var top2: Int64
        do {
            top1 = Int64(heap[SMALLEST])
            heap[SMALLEST] = heap[Int64(heap_len)]
            heap_len--
            downHeap(tree, SMALLEST)
            top2 = Int64(heap[SMALLEST])
            heap_max--
            heap[heap_max] = UInt32(top1)
            heap_max--
            heap[heap_max] = UInt32(top2)
            tree[node][freq_code] = tree[top1][freq_code] + tree[top2][freq_code]
            depth[node] = UInt8(if (depth[top1] >= depth[top2]) { depth[top1] + 1 } else { depth[top2] + 1 })
            tree[top1][dad_len] = UInt16(node)
            tree[top2][dad_len] = UInt16(node)
            heap[SMALLEST] = UInt32(node)
            node++
            downHeap(tree, SMALLEST)
        } while (heap_len >= 2)
        heap_max--
        heap[heap_max] = heap[SMALLEST]
        genBitLength(desc)
        genCodes(tree, UInt32(max_code), bl_count)
    }

    @Frozen
    private func scanTree(tree: Array<CTData>, max_code: UInt32): Unit {
        var prevlen: Int32 = -1
        var curlen: Int32
        var nextlen: Int32 = Int32(tree[0][dad_len])
        var count: Int32 = 0
        var max_count: Int32 = 7
        var min_count: Int32 = 4
        if (nextlen == 0) {
            max_count = 138
            min_count = 3
        }
        tree[Int64(max_code) + 1][dad_len] = UInt16(0xFFFF)
        for (n in 0..=Int64(max_code)) {
            curlen = nextlen
            nextlen = Int32(tree[n + 1][dad_len])
            count++
            if (count < max_count && curlen == nextlen) {
                continue
            } else if (count < min_count) {
                bl_tree[Int64(curlen)][freq_code] += UInt16(count)
            } else if (curlen != 0) {
                if (curlen != prevlen) {
                    bl_tree[Int64(curlen)][freq_code]++
                }
                bl_tree[REP_3_6][freq_code]++
            } else if (count <= 10) {
                bl_tree[REPZ_3_10][freq_code]++
            } else {
                bl_tree[REPZ_11_138][freq_code]++
            }
            count = 0
            prevlen = curlen
            if (nextlen == 0) {
                max_count = 138
                min_count = 3
            } else if (curlen == nextlen) {
                max_count = 6
                min_count = 3
            } else {
                max_count = 7
                min_count = 4
            }
        }
    }

    @Frozen
    private func buildBLTree(): UInt32 {
        scanTree(dyn_ltree, l_desc.max_code)
        scanTree(dyn_dtree, d_desc.max_code)
        buildTree(bl_desc)
        var max_bindex: UInt32 = BL_CODES - 1
        while (max_bindex >= 3) {
            if (bl_tree[bl_order[Int64(max_bindex)]][dad_len] != 0) {
                break
            }
            max_bindex--
        }
        opt_len += 3 * (max_bindex + 1) + 5 + 5 + 4
        return max_bindex
    }

    @Frozen
    private func storedBlock(s: UInt32, l: UInt32, las: Bool): Unit {
        var start = Int64(s)
        var len = UInt16(l)
        var last_val: UInt32 = if (las) { 1 } else { 0 }
        sendBits((STORED_BLOCK << 1) + last_val, 3)
        bitsFlushAlign()
        putShort(len & 0xFFFF)
        putShort((!len) & 0xFFFF) // TODO put_short(s, (ush)~stored_len);
        if (len > 0) {
            for (i in 0..len) {
                pending_buf[Int64(pending_start + pending)] = window[start]
                pending++
                start++
            }
        }
    }

    @Frozen
    private func compressBlock(ltree: Array<CTData>, dtree: Array<CTData>): Unit {
        var dist: UInt32
        var sx: Int64 = lit_bufsize

        var lc: Int64
        var code: Int64
        var extra: UInt32
        var index: Int64
        if (sym_next != lit_bufsize) {
            do {
                dist = UInt32(sym_buf[sx]) & 0xFF
                sx++
                dist += (UInt32(sym_buf[sx]) & 0xFF) << 8
                sx++
                lc = Int64(sym_buf[sx])
                sx++
                if (dist == 0) {
                    sendBits(UInt32(ltree[lc][freq_code]), UInt32(ltree[lc][dad_len]))
                } else {
                    code = Int64(length_code[lc])
                    index = code + Int64(LITERALS) + 1
                    sendBits(UInt32(ltree[index][freq_code]), UInt32(ltree[index][dad_len]))
                    extra = UInt32(extra_lbits[code])
                    if (extra != 0) {
                        lc -= Int64(base_length[code])
                        sendBits(UInt32(lc), extra)
                    }
                    dist--
                    if (dist < 256) {
                        code = Int64(dist_code[Int64(dist)])
                    } else {
                        code = Int64(dist_code[256 + (Int64(dist) >> 7)])
                    }
                    sendBits(UInt32(dtree[code][freq_code]), UInt32(dtree[code][dad_len]))
                    extra = UInt32(extra_dbits[code])
                    if (extra != 0) {
                        dist -= base_dist[code]
                        sendBits(dist, extra)
                    }
                }
            } while (sx < sym_next)
        }
        sendBits(UInt32(ltree[END_BLOCK][freq_code]), UInt32(ltree[END_BLOCK][dad_len]))
    }

    @Frozen
    private func sendTree(tree: Array<CTData>, max_code: UInt32): Unit {
        var max_count: UInt32 = 7
        var min_count: UInt32 = 4
        var curlen: Int64
        var nextlen: Int64 = Int64(tree[0][dad_len])
        var count: UInt32 = 0
        var prevlen: Int64 = -1
        if (nextlen == 0) {
            max_count = 138
            min_count = 3
        }
        for (n in 0..=Int64(max_code)) {
            curlen = nextlen
            nextlen = Int64(tree[n + 1][dad_len])
            count++
            if (count < max_count && curlen == nextlen) {
                continue
            } else if (count < min_count) {
                do {
                    sendBits(UInt32(bl_tree[curlen][freq_code]), UInt32(bl_tree[curlen][dad_len]))
                    count--
                } while (count != 0)
            } else if (curlen != 0) {
                if (curlen != prevlen) {
                    sendBits(UInt32(bl_tree[curlen][freq_code]), UInt32(bl_tree[curlen][dad_len]))
                    count--
                }
                sendBits(UInt32(bl_tree[REP_3_6][freq_code]), UInt32(bl_tree[REP_3_6][dad_len]))
                sendBits(count - 3, 2)
            } else if (count <= 10) {
                sendBits(UInt32(bl_tree[REPZ_3_10][freq_code]), UInt32(bl_tree[REPZ_3_10][dad_len]))
                sendBits(count - 3, 3)
            } else {
                sendBits(UInt32(bl_tree[REPZ_11_138][freq_code]), UInt32(bl_tree[REPZ_11_138][dad_len]))
                sendBits(count - 11, 7)
            }
            count = 0
            prevlen = curlen
            if (nextlen == 0) {
                max_count = 138
                min_count = 3
            } else if (curlen == nextlen) {
                max_count = 6
                min_count = 3
            } else {
                max_count = 7
                min_count = 4
            }
        }
    }

    @Frozen
    private func sendAllTrees(lcodes: UInt32, dcodes: UInt32, blcodes: UInt32): Unit {
        sendBits(lcodes - 257, 5)
        sendBits(dcodes - 1, 5)
        sendBits(blcodes - 4, 4)
        for (i in 0..Int64(blcodes)) {
            sendBits(UInt32(bl_tree[bl_order[i]][dad_len]), 3)
        }
        sendTree(dyn_ltree, lcodes - 1)
        sendTree(dyn_dtree, dcodes - 1)
    }
}
