/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * Single byte character set encoder
 */

package charset4cj.charset.singlebyte

/**
 * Single byte character set encoder
 * @author freeonsky
 * @since 0.28.4
 */
class SingleByteEncoder <: Encoder {
    // Todo currently uses 0x1a uniformly, and each single byte character set has a different replacement
    private let replacement:UInt8 = 0x1a

    SingleByteEncoder(private let encodeMapping:Map<UInt32, UInt32>,
                      private let decodeMapping:Array<UInt32>){}

    /**
     * Encodes a string into a byte array
     *
     * @param str of String
     *
     * @return Type of Array<UInt8>
     * @since 0.28.4
     */
    public func encode(str:String): Array<UInt8>{
        var buf:Array<Rune> = str.toRuneArray()
        let ref = Array<UInt8>(buf.size, repeat:0)
        var i = 0
        for(character in buf){
            if(UInt32(character) <= 0x7F){
                ref[i] = UInt8(UInt32(character))
            }else{
                var index = indexPointer(encodeMapping, decodeMapping, UInt32(character))
                if(index < 0){
                    throw EncoderException("can't encode character "+character.toString()+" character maps to <undefined>")
                }else{
                    ref[i] = UInt8(index) + 0x80
                }
            }
            i += 1
        }
        return ref
    }
}
