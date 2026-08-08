/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file is about Big5 encoding
 */
package charset4cj.charset.traditionchinese

/**
 * big5-hkscs encoding
 * @author freeonsky
 * @since 0.28.4
 */
public class BIG5HKSCSCharset <: Charset{
    public static let instance = BIG5HKSCSCharset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    private init(){
        super("big5-hkscs", "big5-hkscs")
        // this.labels = ["big5-hkscs"]
        // this.name = "big5-hkscs"
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        BIG5Encoder(true)
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        BIG5Decoder()
    }
}


/**
 * Big5 encoding
 * @author freeonsky
 * @since 0.28.4
 */
public class BIG5Charset <: Charset{
    public static let instance = BIG5Charset()
    /**
     * The Function is init constructor
     *
     * @since 0.28.4
     */
    public init(){
        super("Big5", "big5", "cn-big5", "csbig5", "x-x-big5")
        // this.labels = ["big5", "cn-big5", "csbig5", "x-x-big5"]
        // this.name = "Big5"
    }

    /**
     * The Function is newEncoder
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder{
        BIG5Encoder(false)
    }

    /**
     * The Function is newDecoder
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder{
        BIG5Decoder()
    }
}

/*
 * The class is BIG5Encoder inherited from Encoder
 * @author freeonsky
 * @since 0.28.4
 */
class BIG5Encoder <: Encoder {
    private let hkscs:Bool
    init(hkscs:Bool){
        this.hkscs = hkscs
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
                var index = indexBig5Pointer(codePoint)
                if(index >= 0){
                    var pointer = UInt32(index)
                    let lead = pointer / 157 + 0x81
                    let trail = UInt8(pointer % 157)
                    let offset:UInt8 = if(trail < 0x3F) {0x40} else {0x62}
                    ref[position] = UInt8(lead)
                    ref[position+1] = UInt8(trail + offset)
                    position += 2
                }else{
                    throw EncoderException("can't encode character "+ch.toString()+" character maps to <undefined>")
                }
            }
        }
        return ref[0..position]
    }
    private func indexBig5Pointer(codePoint:UInt32):Int64{
        let encodeMapping = Big5EncodeMapping
        let decodeMapping = Big5DecodeMapping
        var res:Int64 = -1
        if(!encodeMapping.isEmpty()){
            if(encodeMapping.contains(codePoint)){
                res = Int64(encodeMapping[codePoint])
            }
        }else{
            if (codePoint == 0x2550 || codePoint == 0x255E ||
                codePoint == 0x2561 || codePoint == 0x256A ||
                codePoint == 0x5341 || codePoint == 0x5345) {
                for(i in (decodeMapping.size-1)..=0 : -1){
                    let item = decodeMapping[i]
                    if(item == codePoint){
                        res = i
                        break
                    }
                }
                return res
            }
            for(i in 0..decodeMapping.size){
                if(!hkscs){
                    if(i < (0xA1 - 0x81) * 157){
                        continue
                    }
                }
                let item = decodeMapping[i]
                if(item == codePoint){
                    res = i
                    break
                }
            }
        }
        return res
    }
}

/*
 * gb18030 Character set decoder
 * gb18030 The single byte part is the same as ASCII
 *         The double byte part is ordinary Chinese characters
 *         The four byte part is mapped with Unicode through a table
 *
 * @author freeonsky
 * @since 0.28.4
 */
class BIG5Decoder <: Decoder{
    init(){}
    // Replace character when decoding error
    private let replacement = r'\u{FFFD}'
    private let table = Big5DecodeMapping

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
                var offset = assignOffset(u1)
                var pointer:Int64 = 0
                pointer = assignPointer(u0, u1, pointer, offset)
                if(pointer == 1133){
                    dest[destIndex] = r'\u{00CA}'
                    dest[destIndex + 1] = r'\u{0304}'
                    destIndex += 2
                    srcIndex += 2
                    continue
                }
                if(pointer == 1135){
                    dest[destIndex] = r'\u{00CA}'
                    dest[destIndex + 1] = r'\u{030C}'
                    destIndex += 2
                    srcIndex += 2
                    continue
                }
                if(pointer == 1164){
                    dest[destIndex] = r'\u{00EA}'
                    dest[destIndex + 1] = r'\u{0304}'
                    destIndex += 2
                    srcIndex += 2
                    continue
                }
                if(pointer == 1166){
                    dest[destIndex] = r'\u{00EA}'
                    dest[destIndex + 1] = r'\u{030C}'
                    destIndex += 2
                    srcIndex += 2
                    continue
                }
                let codePointOp = table.get(pointer)
                if(codePointOp != None){
                    dest[destIndex] = Rune(codePointOp.getOrThrow())
                    destIndex += 1
                    srcIndex += 2
                    continue
                }else{
                    if(u1 >= 0x00 && u1 <= 0x7F){
                        //skip u0
                        srcIndex += 1
                    }else{
                        srcIndex += 2
                    }
                    dest[destIndex] = replacement
                    destIndex += 1
                    continue
                }
            }
            dest[destIndex] = replacement
            destIndex += 1
            srcIndex += 1
            continue
        }
        return (srcIndex, destIndex)
    }

    private func assignOffset(u1: UInt8): Int64 {
        var offset: Int64
        if (u1 < 0x7F) {
            offset = 0x40
        } else {
            offset = 0x62
        }
        return offset
    }

    private func assignPointer(u0: UInt8,u1: UInt8, p: Int64, offset: Int64): Int64 {
        var pointer = p
        if((u1 >= 0x40 && u1 <= 0x7E) || (u1 >= 0xA1 && u1 <= 0xFE)){
            pointer = Int64(u0 - 0x81) * 157 + Int64(u1) - offset
            return pointer
        }
        return p
    }
}
