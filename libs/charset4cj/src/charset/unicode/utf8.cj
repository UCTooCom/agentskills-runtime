/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * UTF8 character set
 */
package charset4cj.charset.unicode

/**
 * UTF8 character set
 * @author freeonsky
 * @since 0.28.4
 */
public class UTF8Charset <: Charset{
    public static let instance = UTF8Charset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("UTF-8", "unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8", "utf-8", "utf8", "x-unicode20utf8")
        // this.labels = ["unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8", "utf-8", "utf8", "x-unicode20utf8"]
        // this.name = "UTF-8"
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        UTF8Encoder()
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        UTF8Decoder()
    }
}

/*
 * UTF-8 encoder
 * function: 将unicode codepoint encode utf8 byte sequence
 * utf8 code point（codepoint）Mapping relationship with code:
 * 0x00000000 - 0x0000007F:
 *     0xxxxxxx
 *
 * 0x00000080 - 0x000007FF:
 *     110xxxxx 10xxxxxx
 *
 * 0x00000800 - 0x0000FFFF:
 *     1110xxxx 10xxxxxx 10xxxxxx
 *
 * 0x00010000 - 0x001FFFFF:
 *     11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
 * @author freeonsky
 * @since 0.28.4
 */
class UTF8Encoder <: Encoder {
    init(){}
    /**
     * Encodes a string into a byte array
     *
     * @param str of String
     *
     * @return Type of Array<UInt8>
     * @since 0.28.4
     */
    public func encode(str:String): Array<UInt8>{
        if(str.size == 0){
            return Array<UInt8>()
        }
        // Create an array of return values. The maximum length of the array is 4 times that of str.size
        var res = Array<UInt8>(str.size * 4, repeat:0)
        // First unprocessed subscript of array
        var position = 0
        var arr = str.toRuneArray()
        for(ch in arr){
            var codepoint = UInt32(ch)
            if(codepoint <= 0x7F){
                res[position] = UInt8(codepoint)
                position += 1
            }else if(codepoint >= 0x80 && codepoint <= 0x7FF){
                res[position] = UInt8(0xC0 | ((codepoint >> 6) & 0x1F))
                position += 1
                res[position] = UInt8(0x80 | (codepoint & 0x3F))
                position += 1
            }else if(codepoint >= 0x800 && codepoint <= 0xFFFF){
                res[position] = UInt8(0xE0 | ((codepoint >> 12) & 0x0F))
                position += 1
                res[position] = UInt8(0x80 | ((codepoint >> 6) & 0x3F))
                position += 1
                res[position] = UInt8(0x80 | (codepoint & 0x3F))
                position += 1
            }else{
                res[position] = UInt8(0xF0 | ((codepoint >> 18) & 0x07))
                position += 1
                res[position] = UInt8(0x80 | ((codepoint >> 12) & 0x3F))
                position += 1
                res[position] = UInt8(0x80 | ((codepoint >> 6) & 0x3F))
                position += 1
                res[position] = UInt8(0x80 | (codepoint & 0x3F))
                position += 1
            }
        }
        return res[0..position]
    }
}

/*
 * UTF8 decoder
 * function: Decode the utf8 byte sequence into a Unicode codepoint array
 * @author freeonsky
 * @since 0.28.4
 */
class UTF8Decoder <: Decoder{
    private let replacement = r'\u{FFFD}'
    init(){}
    /**
     * Decode byte array SRC into character array dest
     *
     * @param src input byte array
     * @param dest output Rune array
     *
     * @return Type of (Int64, Int64): (srcIndex, destIndex)
     *         srcIndex Next unprocessed SRC subscript
     *         destIndex Next unhandled dest subscript
     * @since 0.28.4
     */
    public func decode(src:Array<UInt8>, dest:Array<Rune>): (Int64, Int64) {
        var srcOffset:Int64 = 0
        var srcLimit:Int64 = src.size - 1
        var destStart:Int64 = 0
        var srcIndex = srcOffset
        var destIndex = destStart
        while(srcIndex <= srcLimit){
            if(destIndex >= dest.size){
                return (srcIndex, destIndex)
            }
            var u0 = src[srcIndex];
            // Single byte
            if(u0 <= 0x7F){
                var c = Rune(UInt32(u0))
                dest[destIndex] = c
                destIndex += 1
                srcIndex += 1
                continue
            }else if(u0 > 0x7F && u0 <= 0b11011111){
                // Double byte
                if(srcIndex+1 <= srcLimit){
                    var u1 = src[srcIndex+1]
                    dest[destIndex] = assignCharForU1(u0, u1)
                    destIndex += 1
                    srcIndex += 2
                    continue
                }else{
                    // If only half of the double bytes are in SRC, return and wait for the subsequent data to enter SRC for reprocessing
                    return (srcIndex, destIndex)
                }
            }else if(u0 > 0b11011111 && u0 <= 0b11101111){
                // Three bytes
                if(srcIndex + 2 <= srcLimit){
                    var u1 = src[srcIndex+1]
                    var u2 = src[srcIndex + 2]
                    dest[destIndex] = assignCharForU2(u0, u1, u2)
                    srcIndex += 3
                    destIndex += 1
                    continue
                }else{
                    // If only part of the three bytes is in SRC, return and wait for the subsequent data to enter SRC for reprocessing
                    return (srcIndex, destIndex)
                }
            }else if(u0 > 0b11101111 && u0 <= 0b11110111){
                // Four bytes
                if(srcIndex + 3 <= srcLimit){
                    var u1 = src[srcIndex+1]
                    var u2 = src[srcIndex + 2]
                    var u3 = src[srcIndex + 3]
                    dest[destIndex] = assignCharForU3(u0, u1, u2, u3)
                    srcIndex += 4
                    destIndex += 1
                    continue
                }else{
                    // If only a part of the four bytes is in SRC, return and wait for the subsequent data to enter SRC for reprocessing
                    return (srcIndex, destIndex)
                }
            }else{
                // Replace with fffd after error
                dest[destIndex] = replacement
                srcIndex += 1
                destIndex += 1
                continue
            }
        }
        (srcIndex, destIndex)
    }

    private func assignCharForU1(u0: UInt8, u1: UInt8): Rune {
        if(u1 <= 0b10111111) {
            var codePoint = UInt32(UInt32(u0 & 0b00011111) << 6) + UInt32(u1 & 0b00111111)
            return Rune(codePoint)
        }else {
            // Replace with fffd after error
            return replacement
        }
    }

    private func assignCharForU2(u0: UInt8, u1: UInt8, u2: UInt8): Rune {
        if(u1 <= 0b10111111 && u2 <= 0b10111111){
            var codePoint = UInt32(UInt32(u0 & 0b00001111) << 12) + UInt32(UInt32(u1 & 0b00111111) << 6) + UInt32(u2 & 0b00111111)
            return Rune(codePoint)
        }else{
        // Replace with fffd after error
        return replacement
        }
    }

    private func assignCharForU3(u0: UInt8, u1: UInt8, u2: UInt8, u3: UInt8): Rune {
        if(u1 <= 0b10111111 && u2 <= 0b10111111 && u3 <= 0b10111111){
            var codePoint = UInt32(UInt32(u0 & 0b00000111) << 18) + UInt32(UInt32(u1 & 0b00111111) << 12) + UInt32(UInt32(u2 & 0b00111111) << 6) + UInt32(u2 & 0b00111111)
            return Rune(codePoint)
        }else{
            // Replace with fffd after error
            return replacement
        }
    }
}
