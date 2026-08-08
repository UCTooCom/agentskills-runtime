/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file is about encodes a string into a byte array
 */

package charset4cj.charset.encoding

/**
 * Encoder for encode string into a byte array
 * @author freeonsky
 * @since 0.28.4
 */
public interface Encoder{

    /*
     * Encodes a string into a byte array
     *
     * @param str of String
     *
     * @return Type of Array<UInt8>
     * @since 0.28.4
     */
    func encode(str:String): Array<UInt8>
}

/**
* find the index of codePoint in charsetmapping, only used in charset module
*/
public func indexPointer(encodeMapping:Map<UInt32, UInt32>, decodeMapping:Array<UInt32>, codePoint:UInt32):Int64{
    var res:Int64 = -1
    if(!encodeMapping.isEmpty()){
        if(encodeMapping.contains(codePoint)){
            res = Int64(encodeMapping[codePoint])
        }
    }else{
        for(i in 0..decodeMapping.size){
            let item = match(decodeMapping.get(i)){
                case Some(c) => UInt32(c)
                case None => UInt32(r'\u{FFFF}')
            }
            if(item == codePoint){
                res = i
                break
            }
        }
    }
    return res
}