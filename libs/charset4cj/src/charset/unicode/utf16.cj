/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * UTF16 character set
 */
package charset4cj.charset.unicode

/**
 * UTF16 character set
 * @author freeonsky
 * @since 0.28.4
 */
public class UTF16Charset <: Charset{
    public static let beInstance = UTF16Charset(true, "UTF-16BE", "unicodefffe", "utf-16be")
    public static let leInstance = UTF16Charset(false, "UTF-16LE", "csunicode", "iso-10646-ucs-2", "ucs-2", "unicode", "unicodefeff", "utf-16", "utf-16le","utf16")
    // Whether it is big end mode, be = true big end mode; Be = false small end mode
    private let be:Bool

    /**
     * The Function is init constructor
     *
     * @param be of Bool
     *
     * @since 0.28.4
     */
    private init(be: Bool, name: String, labels: Array<String>){
        super(name, labels)
        this.be = be
        // if(be){
        //     this.labels = ["unicodefffe", "utf-16be"]
        //     this.name = "UTF-16BE"
        // }else{
        //     this.labels = ["csunicode", "iso-10646-ucs-2", "ucs-2", "unicode", "unicodefeff", "utf-16", "utf-16le"]
        //     this.name = "UTF-16LE"
        // }
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        UTF16Encoder(be)
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        UTF16Decoder(be)
    }
}

/*
 * UTF-16 encoder
 * function: Encode Unicode codepoint into utf16 byte sequence
 * @author freeonsky
 * @since 0.28.4
 */
class UTF16Encoder <: Encoder {
    // Whether it is big end mode, be = true big end mode; Be = false small end mode
    private let be:Bool

    /*
     * The Function is init constructor
     *
     * @param be of Bool
     *
     * @since 0.28.4
     */
    init(be:Bool){
        this.be = be
    }

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
            var codePoint:UInt32 = UInt32(ch)
            // Double byte
            if(codePoint <= 0xFFFF){
                var high = UInt8((codePoint >> 8) & 0xFF)
                var low = UInt8(codePoint & 0xFF)
                if(be){
                    res[position] = high
                    position += 1
                    res[position] = low;
                    position += 1
                }else{
                    res[position] = low
                    position += 1
                    res[position] = high;
                    position += 1
                }
            }else{
                // Four bytes
                codePoint -= 0x10000;
                var surrogateHigh:UInt16 = 0xD800 + UInt16((codePoint >> 10) & 0x3FF)
                var surrogateLow:UInt16 = 0xDC00 + UInt16(codePoint & 0x3FF)
                var u0 = UInt8((surrogateHigh >> 8 ) & 0xFF)
                var u1 = UInt8(surrogateHigh & 0xFF)
                var u2 = UInt8((surrogateLow >> 8) & 0xFF)
                var u3 = UInt8(surrogateLow & 0xFF)
                if(be){
                    res[position] = u0
                    position += 1
                    res[position] = u1
                    position += 1
                    res[position] = u2
                    position += 1
                    res[position] = u3
                    position += 1
                }else{
                    res[position] = u1
                    position += 1
                    res[position] = u0
                    position += 1
                    res[position] = u3
                    position += 1
                    res[position] = u2
                    position += 1
                }
            }
        }
        return res[0..position]
    }
}


/*
 * UTF16 decoder
 * function: Decode the utf16 byte sequence into a Unicode codepoint array
 * @author freeonsky
 * @since 0.28.4
 */
class UTF16Decoder <: Decoder{
    private let replacement = r'\u{FFFD}'
    // Whether it is big end mode, be = true big end mode; Be = false small end mode
    private let be:Bool

    init(be:Bool){
        this.be = be
    }

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
            // Not enough digits
            if(srcIndex+1 > srcLimit){
                return (srcIndex, destIndex)
            }
            var u1 = src[srcIndex + 1]
            // [0xd800, 0xdc00) high
            // [0xdc00, 0xe000) low
            var codeUnit:UInt32 = 0
            if(be){
                codeUnit = (UInt32(u0) << 8) + UInt32(u1)
            }else{
                codeUnit = (UInt32(u1) << 8) + UInt32(u0)
            }
            // 4 bytes
            if(codeUnit >=0xd800 && codeUnit < 0xe000){
                if(srcIndex+3 > srcLimit){
                    // Not enough digits
                    return (srcIndex, destIndex)
                }
                var u2 = src[srcIndex + 2]
                var u3 = src[srcIndex + 3]
                var codeUnit2:UInt32 = 0
                if(be){
                    codeUnit2 = (UInt32(u2) << 8) + UInt32(u3)
                }else{
                    codeUnit2 = (UInt32(u3) << 8) + UInt32(u2)
                }
                var codePoint:UInt32 = 0x10000 + (UInt32(codeUnit - 0xD800) << 10) + codeUnit2 - 0xDC00
                dest[destIndex] = Rune(codePoint)
                srcIndex += 4
                destIndex += 1
                continue
            }else{
                // Double byte
                dest[destIndex] = Rune(codeUnit)
                srcIndex += 2
                destIndex += 1
                continue
            }
        }
        (srcIndex, destIndex)
    }
}
