/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * UTF32 Rune set
 */
package charset4cj.charset.unicode

/**
 * UTF32 Rune set
 * @author freeonsky
 * @since 0.28.4
 */
public class UTF32Charset <: Charset{
    public static let beInstance = UTF32Charset(true, "UTF-32BE", "utf-32be")
    public static let leInstance = UTF32Charset(false, "UTF-32LE", "utf-32le")
    // Whether it is big end mode, be = true big end mode; Be = false small end mode
    private let be:Bool

    /**
     * The Function is init constructor
     *
     * @param be of Bool
     *
     * @since 0.28.4
     */
    private init(be:Bool, name: String, labels: Array<String>){
        super(name, labels)
        this.be = be
        // if(be){
        //     this.labels = ["utf-32be"]
        //     this.name = "UTF-32BE"
        // }else{
        //     this.labels = ["utf-32le"]
        //     this.name = "UTF-32LE"
        // }
    }
    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        UTF32Encoder(be)
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        UTF32Decoder(be)
    }
}

/*
 * UTF-32 encoder
 * function: Encode Unicode codepoint into utf32 byte sequence
 * @author freeonsky
 * @since 0.28.4
 */
class UTF32Encoder <: Encoder {
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
            var u0 = UInt8((codePoint >> 24) & 0xFF)
            var u1 = UInt8((codePoint >> 16) & 0xFF)
            var u2 = UInt8((codePoint >> 8) & 0xFF)
            var u3 = UInt8(codePoint & 0xFF)

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
                res[position] = u3
                position += 1
                res[position] = u2
                position += 1
                res[position] = u1
                position += 1
                res[position] = u0
                position += 1
            }
        }
        return res[0..position]
    }
}


/*
 * UTF32 Decoder
 * function: Decode the utf32 byte sequence into a Unicode codepoint array
 * @author freeonsky
 * @since 0.28.4
 */
class UTF32Decoder <: Decoder{
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
            // Not enough digits
            if(srcIndex+3 > srcLimit){
                return (srcIndex, destIndex)
            }
            var u0 = src[srcIndex];
            var u1 = src[srcIndex + 1]
            var u2 = src[srcIndex + 2]
            var u3 = src[srcIndex + 3]
            var codeUnit:UInt32 = if(be){
                (UInt32(u0) << 24) + (UInt32(u1) << 16) + (UInt32(u2) << 8) + UInt32(u3)
            }else{
                (UInt32(u3) << 24) + (UInt32(u2) << 16) + (UInt32(u1) << 8) + UInt32(u0)
            }
            dest[destIndex] = Rune(codeUnit)
            destIndex += 1
            srcIndex += 4
            continue
        }
        (srcIndex, destIndex)
    }
}
