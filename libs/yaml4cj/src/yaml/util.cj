/**
 * @file
 * This file is about judgement function.
 */

package yaml4cj.yaml

/**
 * The Function is eq
 *
 * @param a of Int64
 * @param b of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func eq(a: Int64, b: Int64): Bool {
    a == b
}

/**
 * The Function is ne
 *
 * @param a of Int64
 * @param b of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func ne(a: Int64, b: Int64): Bool {
    a != b
}

/**
 * The Function is eq
 *
 * @param a of Hashable
 * @param b of Hashable
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func eq(a: Hashable, b: Hashable): Bool {
    a.hashCode() == b.hashCode()
}

/**
 * The Function is ne
 *
 * @param a of Hashable
 * @param b of Hashable
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func ne(a: Hashable, b: Hashable): Bool {
    a.hashCode() != b.hashCode()
}

/**
 * The Function is genHashCode
 *
 * @param arr of Array<Hashable>
 * @param name of String, and the Default value is ""
 *
 * @return Type of Int64
 * @since 0.30.4
 */
/* func genHashCode(arr: Array<Hashable>, name!: String = ""): Int64 {
    var dfh: DefaultHasher = DefaultHasher()
    dfh.write("name=${name}:{")
    for (i in 0..arr.size) {
        dfh.write("index=${i}:code=${arr[i].hashCode()}")
    }
    dfh.write("}[length=${arr.size}]")
    return dfh.finish()
   }*/

/**
 * The Function is min
 *
 * @param x of Int64
 * @param y of Int64
 *
 * @return Type of Int64
 * @since 0.30.4
 */
func min(x: Int64, y: Int64): Int64 {
    if (x > y) {
        y
    } else {
        x
    }
}

interface Indexable<T> {
    operator func [](idx: Int64): T
    operator func [](idx: Int64, value!: T): Unit

    func length(): Int64
}
extend<T> Array<T> <: Indexable<T> {
    public func length(): Int64 {
        this.size
    }
}
extend<T> ArrayList<T> <: Indexable<T> {
    public func length(): Int64 {
        this.size
    }
}

/**
 * The Function is copy<T>
 *
 * @param dst of Array<T>
 * @param src of Array<T>
 * @param dstStart of Int64, and the Default value is 0
 * @param dstEnd of Int64, and the Default value is dst.size
 * @param srcStart of Int64, and the Default value is 0
 * @param srcEnd of Int64, and the Default value is src.size
 *
 * @return Type of Int64
 * @since 0.30.4
 */
func copy<T>(
    dst: Indexable<T>,
    src: Indexable<T>,
    dstStart!: Int64 = 0,
    dstEnd!: Int64 = dst.length(),
    srcStart!: Int64 = 0,
    srcEnd!: Int64 = src.length()
): Int64 {
    let n = min(min(dst.length(), dstEnd - dstStart), min(src.length(), srcEnd - srcStart))
    for (i in 0..n) {
        dst[i + dstStart] = src[i + srcStart]
    }
    n
}

/**
 * The Function is failf
 *
 * @param msg of String
 *
 * @return Type of Unit
 * @since 0.30.4
 */
func failf(msg: String): Unit {
    throw YamlError("yaml: ${msg}")
}

/**
 * The Function is startsWith
 *
 * @param s of Array<UInt8>
 * @param prefix of Array<UInt8>
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func startsWith(s: Array<UInt8>, prefix: Array<UInt8>): Bool {
    if (s.size < prefix.size) {
        return false
    }
    String.fromUtf8(prefix) == (String.fromUtf8(s[0..prefix.size]))
}

let RuneSelf: UInt32 = 0x80
let locb: UInt8 = 0b10000000
let hicb: UInt8 = 0b10111111
let xx: UInt8 = 0xF1
let asx: UInt8 = 0xF0
let s1: UInt8 = 0x02
let s2: UInt8 = 0x13
let s3: UInt8 = 0x03
let s4: UInt8 = 0x23
let s5: UInt8 = 0x34
let s6: UInt8 = 0x04
let s7: UInt8 = 0x44
let first: Array<UInt8> = [
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    asx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s1,
    s2,
    s3,
    s3,
    s3,
    s3,
    s3,
    s3,
    s3,
    s3,
    s3,
    s3,
    s3,
    s3,
    s4,
    s3,
    s3,
    s5,
    s6,
    s6,
    s6,
    s7,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx,
    xx
]
let acceptRanges: Array<Array<UInt8>> = [
    [locb, hicb],
    [0xA0, hicb],
    [locb, 0x9F],
    [0x90, hicb],
    [locb, 0x8F]
]

/**
 * The Function is utf8ValidString
 *
 * @param ns of String
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func utf8ValidString(ns: String): Bool {
    var p = ns.toArray()
    var i = 0
    while ((p.size - i) >= 8) {
        let first32 = UInt32(p[i + 0]) | (UInt32(p[i + 1]) << 8) | (UInt32(p[i + 2]) << 16) | (UInt32(p[i + 3]) << 24)
        let second32 = UInt32(p[i + 4]) | (UInt32(p[i + 5]) << 8) | (UInt32(p[i + 6]) << 16) | (UInt32(p[i + 7]) << 24)
        if (((first32 | second32) & 0x80808080) != 0) {
            break
        }
        i += 8
    }
    p = if (i >= p.size) {
        []
    } else {
        p[i..p.size]
    }
    i = 0
    let n = p.size
    while (i < n) {
        let pi = p[i]
        if (UInt32(pi) < RuneSelf) {
            i++
            continue
        }
        let x = first[Int64(pi)]
        if (x == xx) {
            return false
        }
        var size = Int64(x & 7)
        if (i + size > n) {
            return false
        }
        let accept = acceptRanges[Int64(x >> 4)]
        if (p[i + 1] < accept[0] || accept[1] < p[i + 1]) {
            return false
        } else if (size == 2) {}
        else if (p[i + 2] < locb || hicb < p[i + 2]) {
            return false
        } else if (size == 3) {}
        else if (p[i + 3] < locb || hicb < p[i + 3]) {
            return false
        }
        i += size
    }
    true
}
