/**
 * @file
 * THis file is about judgement function.
 */

package yaml4cj.yaml

let inputRawBufferSize = 512

let inputBufferSize = inputRawBufferSize * 3

let outputBufferSize = 128

let outputRawBufferSize = (outputBufferSize * 2 + 2)

let initialStackSize = 16
let initialQueueSize = 16
let initialStringSize = 16

/**
 * The Function is isAlpha
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
/*func isAlpha(b: Array<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc >= r'0' && bc <= r'9' || bc >= r'A' && bc <= r'Z' || bc >= r'a' && bc <= r'z' || bc == r'_' || bc == r'-'
}*/

/**
 * The Function is isAlpha
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isAlpha(b: ArrayList<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc >= r'0' && bc <= r'9' || bc >= r'A' && bc <= r'Z' || bc >= r'a' && bc <= r'z' || bc == r'_' || bc == r'-'
}

/**
 * The Function is isDigit
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
/*func isDigit(b: Array<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc >= r'0' && bc <= r'9'
}*/

/**
 * The Function is isDigit
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isDigit(b: ArrayList<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc >= r'0' && bc <= r'9'
}

/**
 * The Function is asDigit
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Int64
 * @since 0.30.4
 */
/*@overflowWrapping
func asDigit(b: Array<UInt8>, i: Int64): Int64 {
    Int64(UInt32(b[i]) - UInt32('0'))
}*/

/**
 * The Function is asDigit
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Int64
 * @since 0.30.4
 */
@OverflowWrapping
func asDigit(b: ArrayList<UInt8>, i: Int64): Int64 {
    Int64(UInt32(b[i]) - UInt32(r'0'))
}

/**
 * The Function is isHex
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
/*func isHex(b: Array<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc >= r'0' && bc <= r'9' || bc >= r'A' && bc <= r'F' || bc >= r'a' && bc <= r'f'
}*/

/**
 * The Function is isHex
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isHex(b: ArrayList<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc >= r'0' && bc <= r'9' || bc >= r'A' && bc <= r'F' || bc >= r'a' && bc <= r'f'
}

/**
 * The Function is asHex
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Int64
 * @since 0.30.4
 */
/*@overflowWrapping
func asHex(b: Array<UInt8>, i: Int64): Int64 {
    asHex(b[i])
}*/

/**
 * The Function is asHex
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Int64
 * @since 0.30.4
 */
@OverflowWrapping
func asHex(b: ArrayList<UInt8>, i: Int64): Int64 {
    asHex(b[i])
}

@OverflowWrapping
func asHex(bi: UInt8): Int64 {
    let bc = Rune(UInt32(bi))
    if (bc >= r'A' && bc <= r'F') {
        Int64(UInt32(bi) - UInt32(r'A') + 10)
    } else if (bc >= r'a' && bc <= r'f') {
        Int64(UInt32(bi) - UInt32(r'a') + 10)
    } else {
        Int64(UInt32(bi) - UInt32(r'0'))
    }
}

/**
 * The Function is isAscii
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isAscii(b: Array<UInt8>, i: Int64): Bool {
    b[i] <= 0x7F
}

/**
 * The Function is isAscii
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isAscii(b: ArrayList<UInt8>, i: Int64): Bool {
    b[i] <= 0x7F
}

/**
 * The Function is isPrintable
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isPrintable(b: Array<UInt8>, i: Int64): Bool {
    (b[i] == 0x0A) || (b[i] >= 0x20 && b[i] <= 0x7E) || (b[i] == 0xC2 && b[i + 1] >= 0xA0) || (b[i] > 0xC2 && b[i] < 0xED)||
        (b[i] == 0xED && b[i + 1] < 0xA0) || (b[i] == 0xEE) || (b[i] == 0xEF && !(b[i + 1] == 0xBB && b[i + 2] == 0xBF) &&
        !(b[i + 1] == 0xBF && (b[i + 2] == 0xBE || b[i + 2] == 0xBF)))
}

/**
 * The Function is isPrintable
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
/*func isPrintable(b: ArrayList<UInt8>, i: Int64): Bool {
    (b[i] == 0x0A) || (b[i] >= 0x20 && b[i] <= 0x7E) || (b[i] == 0xC2 && b[i + 1] >= 0xA0) || (b[i] > 0xC2 && b[i] < 0xED)||
        (b[i] == 0xED && b[i + 1] < 0xA0) || (b[i] == 0xEE) || (b[i] == 0xEF && !(b[i + 1] == 0xBB && b[i + 2] == 0xBF) &&
        !(b[i + 1] == 0xBF && (b[i + 2] == 0xBE || b[i + 2] == 0xBF)))
}*/

/**
 * The Function is isZ
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
/*func isZ(b: Array<UInt8>, i: Int64): Bool {
    b[i] == 0x00
}*/

/**
 * The Function is isZ
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isZ(b: ArrayList<UInt8>, i: Int64): Bool {
    b[i] == 0x00
}

/**
 * The Function is isBom
 *
 * @param b of Array<UInt8>
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBom(b: Array<UInt8>): Bool {
    b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF
}

/**
 * The Function is isBom
 *
 * @param b of ArrayList<UInt8>
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBom(b: ArrayList<UInt8>): Bool {
    b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF
}

/**
 * The Function is isSpace
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isSpace(b: Array<UInt8>, i: Int64): Bool {
    UInt32(b[i]) == UInt32(r' ')
}

/**
 * The Function is isSpace
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isSpace(b: ArrayList<UInt8>, i: Int64): Bool {
    UInt32(b[i]) == UInt32(r' ')
}

/**
 * The Function is isTab
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isTab(b: Array<UInt8>, i: Int64): Bool {
    UInt32(b[i]) == UInt32(r'\t')
}

/**
 * The Function is isTab
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isTab(b: ArrayList<UInt8>, i: Int64): Bool {
    UInt32(b[i]) == UInt32(r'\t')
}

/**
 * The Function is isBlank
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBlank(b: Array<UInt8>, i: Int64): Bool {
    isSpace(b, i) || isTab(b, i)
}

/**
 * The Function is isBlank
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBlank(b: ArrayList<UInt8>, i: Int64): Bool {
    isSpace(b, i) || isTab(b, i)
}

/**
 * The Function is isBreak
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBreak(b: Array<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc == r'\r' || bc == r'\n' || (bi == 0xC2 && b[i + 1] == 0x85) || (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA8)||
        (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA9)
}

/**
 * The Function is isBreak
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBreak(b: ArrayList<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc == r'\r' || bc == r'\n' || (bi == 0xC2 && b[i + 1] == 0x85) || (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA8)||
        (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA9)
}

/**
 * The Function is isCRLF
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
/*func isCRLF(b: Array<UInt8>, i: Int64): Bool {
    UInt32(b[i]) == UInt32('\r') && UInt32(b[i + 1]) == UInt32('\n')
}*/

/**
 * The Function is isCRLF
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isCRLF(b: ArrayList<UInt8>, i: Int64): Bool {
    UInt32(b[i]) == UInt32(r'\r') && UInt32(b[i + 1]) == UInt32(r'\n')
}

/**
 * The Function is isBreakz
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBreakz(b: Array<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    (bc == r'\r' || bc == r'\n' || (bi == 0xC2 && b[i + 1] == 0x85) || (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA8)||
        (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA9) || // isZ:
    bi == 0)
}

/**
 * The Function is isBreakz
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBreakz(b: ArrayList<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    (bc == r'\r' || bc == r'\n' || (bi == 0xC2 && b[i + 1] == 0x85) || (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA8)||
        (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA9) || // isZ:
    bi == 0)
}

/**
 * The Function is isBlankz
 *
 * @param b of ArrayList<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBlankz(b: ArrayList<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc == r' ' || bc == r'\t' || bc == r'\r' || bc == r'\n' || (bi == 0xC2 && b[i + 1] == 0x85) || (bi == 0xE2 && b[i + 1] ==
        0x80 && b[i + 2] == 0xA8) || (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA9) || bi == 0
}

/**
 * The Function is isBlankz
 *
 * @param b of Array<UInt8>
 * @param i of Int64
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func isBlankz(b: Array<UInt8>, i: Int64): Bool {
    let bi = b[i]
    let bc = Rune(UInt32(bi))
    bc == r' ' || bc == r'\t' || bc == r'\r' || bc == r'\n' || (bi == 0xC2 && b[i + 1] == 0x85) || (bi == 0xE2 && b[i + 1] ==
        0x80 && b[i + 2] == 0xA8) || (bi == 0xE2 && b[i + 1] == 0x80 && b[i + 2] == 0xA9) || bi == 0
}

/**
 * The Function is width
 *
 * @param b of UInt8
 *
 * @return Type of Int64
 * @since 0.30.4
 */
func width(b: UInt8): Int64 {
    if ((b & 0x80) == 0x00) {
        1
    } else if ((b & 0xE0) == 0xC0) {
        2
    } else if ((b & 0xF0) == 0xE0) {
        3
    } else if ((b & 0xF8) == 0xF0) {
        4
    } else {
        0
    }
}

/**
 * The Function is containsChinese
 *
 * @param b of Array<UInt8>
 *
 * @return Type of Bool
 * @since 0.30.4
 */
func containsChinese(b: Array<UInt8>): Bool {
    if (b.size == 0) {
        return false
    }
    let str = String.fromUtf8(b)
    let arr = str.toRuneArray()
    for (c in arr) {
        let f = UInt32(c)
        if (f >= 0x4E00 && f <= 0x9FA5) {
            return true
        }
    }
    false
}
