/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

package charset4cj.charset.japanese

class ISO2022JPEncoder <: Encoder {
    // ASCII:0 | Roman:1 | katakana:2 | JIS:3
    private var state = 0
    /**
     * Encodes a string into a byte array
     *
     * @param str of String
     *
     * @return Type of Array<UInt8>
     * @since 0.35.2
     */
    public func encode(str:String): Array<UInt8> {
        if(str.size == 0){
            return Array<UInt8>()
        }
        let ref = Array<UInt8>(str.size * 4 + 10, repeat:0)
        var position = 0
        var srcIndex = 0
        var arr = str.toRuneArray()
        while(srcIndex < arr.size){
            var ch = arr[srcIndex]
            srcIndex += 1
            var codePoint:UInt32 = UInt32(ch)
            // ASCII:0 | Roman:1 | katakana:2 | JIS:3
            if((state == 0 || state == 1) && (codePoint == 0x0E || codePoint == 0x0F || codePoint == 0x1B)){
                // skip
                continue
            }
            if(state == 0 && codePoint >= 0x00 && codePoint <= 0x7F){
                ref[position] = UInt8(codePoint)
                position += 1
                continue
            }
            if((state == 1 && codePoint >= 0x00 && codePoint <= 0x7F && (codePoint != 0x5C && codePoint != 0x7E)) ||(codePoint == 0xA5 || codePoint == 0x203E)){
                if(codePoint >= 0x00 && codePoint <= 0x7F){
                    ref[position] = UInt8(codePoint)
                }
                if(codePoint == 0xA5){
                    ref[position] = UInt8(0x5C)
                }
                if(codePoint == 0x203E){
                    ref[position] = UInt8(0x7E)
                }
                position += 1
                continue
            }
            // If code point is an ASCII code point, and ISO-2022-JP encoder state is not ASCII, prepend code point to ioQueue,
            // set ISO-2022-JP encoder state to ASCII, and return three bytes 0x1B 0x28 0x42.
            if(codePoint >= 0x00 && codePoint <= 0x7F && state != 0){
                srcIndex -= 1
                state = 0
                ref[position] = 0x1B
                ref[position + 1] = 0x28
                ref[position + 2] = 0x42
                position += 3
                continue
            }
            // If code point is either U+00A5 or U+203E, and ISO-2022-JP encoder state is not Roman, prepend code point to ioQueue,
            // set ISO-2022-JP encoder state to Roman, and return three bytes 0x1B 0x28 0x4A.
            if((codePoint == 0xA5 || codePoint == 0x203E) && state != 1){
                srcIndex -= 1
                state = 1
                ref[position] = 0x1B
                ref[position + 1] = 0x28
                ref[position + 2] = 0x4A
                position += 3
                continue
            }
            if(codePoint == 0x2212){
                codePoint = 0xFF0D
            }
            if(codePoint >= 0xFF61 && codePoint <= 0xFF9F){
                if(codePoint == 0x309B){
                    codePoint = 0xFF9E
                }
                if(codePoint == 0x309C){
                    codePoint = 0xFF9F
                }
                ref[position] = UInt8(codePoint - 0xFF61)
                position += 1
                continue
            }
            let pointer = indexPointer(jis0208EncodeMapping, jis0208DecodeMapping, codePoint)
            if(pointer <= 0){
                if(state == 3){
                    srcIndex -= 1
                    state = 0
                    ref[position] = 0x1B
                    ref[position + 1] = 0x28
                    ref[position + 2] = 0x42
                    position += 3
                    continue
                }
                throw EncoderException("can't encode character "+ch.toString()+" character maps to <undefined>")
            }
            if(state != 3){
                srcIndex -= 1
                state = 3
                ref[position] = 0x1B
                ref[position + 1] = 0x24
                ref[position + 2] = 0x42
                position += 3
                continue
            }
            let lead = pointer / 94 + 0x21
            let trail = pointer % 94 + 0x21
            ref[position] = UInt8(lead)
            ref[position + 1] = UInt8(trail)
            position += 2

            if(srcIndex == str.size){
                if(state != 0){
                    state = 0
                    ref[position] = 0x1B
                    ref[position + 1] = 0x28
                    ref[position + 2] = 0x42
                    position += 3
                }
            }
            continue
        }
        return ref[0..position]
    }
}

enum State {
    ASCII | Roman | katakana | JIS
}

/**
 * ISO-2022-JP Character set decoder
 * not implement ISO-2022-JP-1, ISO-2022-JP-2, ISO-2022-JP-3
 * @author freeonsky
 * @since 0.28.4
 */
class ISO2022JPDecoder <: Decoder{
    // Replace character when decoding error
    private let replacement = r'\u{FFFD}'
    // ASCII:0 | Roman:1 | katakana:2 | JIS:3
    private var state = 0

    /**
     * Decode ISO-2022-JP byte array SRC into character array dest
     *   ESC ( B to ASCII start byte:0X1B,0x28,0x42
     *   ESC ( J to JIS X 0201-Roman  start byte: 0X1B,0x28,0x4A
     *   ESC ( I to JIS X 0201 katakana Nonstandard start byte:0X1B,0x28,0x49
     *   ESC $ @ to JIS X 0208-1978  start byte:0X1B,0x24,0x40
     *   ESC $ B to JIS X 0208-1983  start byte:0X1B,0x24,0x42
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
        // Index being processed by SRC
        var srcIndex = srcOffset
        // Dest index being processed
        var destIndex = destStart
        while(srcIndex <= srcLimit){
            if(destIndex >= dest.size){
                return (srcIndex, destIndex)
            }
            let u0 = src[srcIndex];
            if(u0 == 0x1B){
                if(srcIndex + 3 > srcLimit){
                    // when escape Rune sequese < 3 ， return
                    return (srcIndex, destIndex)
                }
                let u1 = src[srcIndex + 1]
                let u2 = src[srcIndex + 2]
                // ESC ( B to ASCII start byte:0X1B,0x28,0x42
                if(u1 == 0x28 && u2 == 0x42){
                    state = 0
                    srcIndex += 3
                // ESC ( J to JIS X 0201-Roman  start byte: 0X1B,0x28,0x4A
                }else if(u1 == 0x28 && u2 == 0x4A){
                    state = 1
                    srcIndex += 3
                // ESC ( I to JIS X 0201 katakana Nonstandard start byte:0X1B,0x28,0x49
                }else if(u1 == 0x28 && u2 == 0x49){
                    state = 2
                    srcIndex += 3
                // ESC $ @ to JIS X 0208-1978  start byte:0X1B,0x24,0x40
                // ESC $ B to JIS X 0208-1983  start byte:0X1B,0x24,0x42
                }else if(u1 == 0x24 && (u2 == 0x40 || u2 == 0x42)){
                    state = 3
                    srcIndex += 3
                }else{
                    // error
                    dest[destIndex] = replacement
                    destIndex += 1
                    srcIndex += 1
                }
            }else{
                // ASCII:0 | Roman:1 | katakana:2 | JIS:3
                if(state == 0){
                    if(u0 >=0x00 && u0 <= 0x7F && u0 != 0x0E && u0 != 0x0F){
                        dest[destIndex] = Rune(u0)
                    }else{
                        dest[destIndex] = replacement
                    }
                    destIndex += 1
                    srcIndex += 1
                }else if(state == 1){// Roman:1
                    if(u0 == 0x5C){
                        dest[destIndex] = Rune(0xA5)
                    }else if(u0 == 0x7E){
                        dest[destIndex] = Rune(0x203E)
                    }else if(u0 >=0x00 && u0 <= 0x7F && u0 != 0x0E && u0 != 0x0F){
                        dest[destIndex] = Rune(u0)
                    }else{
                        dest[destIndex] = replacement
                    }
                    destIndex += 1
                    srcIndex += 1
                }else if(state == 2){ // katakana:2
                    if(u0 >= 0x21 && u0 <= 0x5F){
                        dest[destIndex] = Rune(UInt32(0xFF61) - UInt32(0x21) + UInt32(u0))
                    }else{
                        dest[destIndex] = replacement
                    }
                    destIndex += 1
                    srcIndex += 1
                }else if(state == 3){ // JIS:3
                    if(srcIndex + 2 > srcLimit){
                        // when escape Rune sequese < 3 ， return
                        return (srcIndex, destIndex)
                    }
                    let u1 = src[srcIndex + 1]
                    if(u0 >= 0x21 && u0 <= 0x7E && u1 >= 0x21 && u1 <= 0x7E){
                        let pointer:Int64 = Int64(u0 - 0x21) * 94 + Int64(u1) - 0x21
                        dest[destIndex] = match(jis0208DecodeMapping.get(pointer)){
                            case Some(c) => Rune(c)
                            case None => replacement
                        }
                        srcIndex += 2
                        destIndex += 1
                    }
                }
            }

        }
        return (srcIndex, destIndex)
    }
}
