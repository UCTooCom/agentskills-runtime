/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file is about GB18030Decoder
 */

package charset4cj.charset.simplechinese

/**
 * gb18030  Character set decoder
 * GB18030  single byte part is the same as ASCII
 *          The double byte part is ordinary Chinese characters
 *          The four byte part is mapped with Unicode through a table
 * @author freeonsky
 * @since 0.28.4
 */
class GB18030Decoder <: Decoder{
    init(){}
    // Replace character when decoding error
    private let replacement = r'\u{FFFD}'
    private let table = gb18030DecodeMapping

    /**
     * Decode byte array SRC into character array dest
     *
     * @param src input byte array
     * @param dest output Rune array
     *
     * @return Type of (Int64, Int64):(srcIndex, destIndex)
     *         srcIndex: Next unprocessed SRC subscript
     *         destIndex: Next unhandled dest subscript
     * @since 0.28.4
     */
    public func decode(src:Array<UInt8>, dest:Array<Rune>): (Int64, Int64) {
        var srcOffset:Int64 = 0
        var srcLimit:Int64 = src.size - 1
        var destStart:Int64 = 0
        // src Processing index
        var srcIndex = srcOffset
        // dest Processing index
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
            }else if(u0 == 0x80){
                dest[destIndex] = Rune(0x20AC)
                destIndex += 1
                srcIndex += 1
                continue
            }else if(u0 >= 0x81 && u0 <= 0xFE){
                if(srcIndex + 1 > srcLimit){
                    // If only half of the double bytes are in SRC, return and wait for the subsequent data to enter SRC for reprocessing
                    return (srcIndex, destIndex)
                }

                var u1 = src[srcIndex+1]
                // Double byte
                if((u1 >= 0x40 && u1 <= 0x7E) || (u1 >= 0x80 && u1 <= 0xFE)){
                    var offset:UInt8 = if (u1 <= 0x7F){
                                            0x40
                                        }else{
                                            0x41
                                        }
                    var pointer = Int64(Int64(u0 - 0x81) * 190) + Int64(u1 - offset)
                    var codePoint = if(pointer < 23940){
                                        Rune(table[pointer])
                                    }else{
                                        replacement;
                                    }
                    dest[destIndex] = codePoint
                    destIndex += 1
                    srcIndex += 2
                    continue
                }else if(u1 >= 0x30 && u1 <= 0x39){
                    if(srcIndex + 3 > srcLimit){
                        // If only a part of the four bytes is in SRC, return and wait for the subsequent data to enter SRC for reprocessing
                        return (srcIndex, destIndex)
                    }
                    // Four bytes
                    var u2 = src[srcIndex + 2]
                    var u3 = src[srcIndex + 3]
                    if((u2 >= 0x81 && u2 <= 0xFE) && (u3 >= 0x30 || u3 <= 0x39)){
                        var pointer = Int64(u0 - 0x81) * (10 * 126 * 10) +
                                    Int64(u1 - 0x30) * (10 * 126) +
                                    Int64(u2 - 0x81) * 10 +
                                    Int64(u3) - 0x30
                        if(pointer == 7457){
                            dest[destIndex] = r'\u{E7C7}'
                            srcIndex += 4
                            destIndex += 1
                            continue
                        }else if(pointer > 39419 && pointer < 189000){
                            srcIndex += 4
                            destIndex += 1
                            dest[destIndex] = replacement
                            continue
                        }else{
                            var start = 0
                            var end = gb18030_rangesMapping.size
                            while(start < end){
                                var h = start + (end-start) / 2
                                if(pointer >= Int64(gb18030_rangesMapping[h][0])){
                                    start = h + 1
                                }else{
                                    end = h
                                }
                            }
                            var code:Array<UInt32> = gb18030_rangesMapping[start - 1]
                            var codePoint = UInt32(UInt32(pointer) + UInt32(code[1]) - UInt32(code[0]))
                            dest[destIndex] = Rune(codePoint)
                            destIndex += 1
                            srcIndex += 4
                            continue
                        }
                    }else{
                        // error
                        srcIndex += 4
                        destIndex += 1
                        dest[destIndex] = replacement
                        continue
                    }

                }else{
                    // Replace with fffd after error
                    dest[destIndex] = replacement
                    destIndex += 1
                    srcIndex += 1
                    continue
                }
            } else {
                throw DecoderException("can't decode the src: " + "${src.toString()}")
            }
        }
        return (srcIndex, destIndex)
    }
}
