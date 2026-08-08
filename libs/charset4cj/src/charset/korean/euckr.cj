/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file is about charset korean
 */

package charset4cj.charset.korean

/**
 * EUC-KR korean encoding
 * @author freeonsky
 * @since 0.28.4
 */
public class EUCKRCharset <: Charset{
    public static let instance = EUCKRCharset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("EUC-KR", ["cseuckr",  "csksc56011987",  "euc-kr",  "iso-ir-149",  "korean",  "ks_c_5601-1987",  "ks_c_5601-1989",  "ksc5601",  "ksc_5601",  "windows-949"])
        // this.labels = ["cseuckr",  "csksc56011987",  "euc-kr",  "iso-ir-149",  "korean",  "ks_c_5601-1987",  "ks_c_5601-1989",  "ksc5601",  "ksc_5601",  "windows-949"]
        // this.name = "EUC-KR"
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        EUCKREncoder()
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        EUCKRDecoder()
    }
}

/*
 * The class is EUCKREncoder inherited from Encoder
 * @author freeonsky
 * @since 0.28.4
 */
class EUCKREncoder <: Encoder {
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
        let ref = Array<UInt8>(str.size * 2, repeat:0)
        var position = 0
        var arr = str.toRuneArray()
        for(ch in arr){
            var codePoint:UInt32 = UInt32(ch)
            // If code point is an ASCII code point, return a byte whose value is code point.
            if(codePoint <= 0x7F){
                ref[position] = UInt8(codePoint)
                position += 1
            }else{
                var index = indexPointer(EUC_KREncodeMapping, EUC_KRDecodeMapping, codePoint)
                if(index >= 0){
                    var pointer = UInt32(index)
                    let lead = pointer / 190 + 0x81
                    let trail = pointer % 190 + 0x41
                    ref[position] = UInt8(lead)
                    ref[position+1] = UInt8(trail)
                    position += 2
                }else{
                    throw EncoderException("can't encode character "+ch.toString()+" character maps to <undefined>")
                }
            }
        }
        return ref[0..position]
    }
}

/*
 * euc-kr Character set decoder
 * euc-kr The single byte part is the same as ASCII
 *         The double byte part is ordinary cjk characters
 */

/*
 * The class is EUCKRDecoder inherited from Decoder
 * @author freeonsky
 * @since 0.28.4
 */
class EUCKRDecoder <: Decoder{
    // Replace character when decoding error
    private let replacement = r'\u{FFFD}'
    private let table = EUC_KRDecodeMapping

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
        // Index being processed by SRC
        var srcIndex = srcOffset
        // Dest index being processed
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
            }else if(u0 >= 0x81 && u0 <= 0xFE){
                if(srcIndex + 1 > srcLimit){
                    // If only half of the double bytes are in SRC, return and wait for the subsequent data to enter SRC for reprocessing
                    return (srcIndex, destIndex)
                }

                var u1 = src[srcIndex+1]
                var pointer:Int64 = 0
                var codePoint:Rune = r'\u{0}'
                if(u1 >= 0x41 && u1 <= 0xFE){
                    pointer = Int64(Int64(u0 - 0x81) * 190 + Int64(u1) - 0x41)
                    let c = table[pointer]
                    if(c == 0){
                        codePoint = replacement
                    }else{
                        codePoint = Rune(c)
                    }
                }else{
                    codePoint = replacement
                }
                dest[destIndex] = codePoint
                srcIndex += 2
                destIndex += 1
                continue
            } else {
                throw DecoderException("can't decode the src: " + "${src.toString()}")
            }
        }
        return (srcIndex, destIndex)
    }
}
