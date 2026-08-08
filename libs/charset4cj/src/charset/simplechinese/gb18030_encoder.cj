/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file is about GB18030Encoder
 */

package charset4cj.charset.simplechinese

/**
 * The class is GB18030Encoder inherited from Encoder
 * GB18030  single byte part is the same as ASCII
 *          The double byte part is ordinary Chinese characters
 *          The four byte part is mapped with Unicode through a table
 * @author freeonsky
 * @since 0.28.4
 */
class GB18030Encoder <: Encoder {
    private let gbk:Bool

    init(gbk: Bool){
        this.gbk = gbk
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
        let ref = Array<UInt8>(str.size * 4, repeat:0)
        var position = 0
        var arr = str.toRuneArray()
        let replacement:UInt8 = 0x3F
        for(ch in arr){
            var codePoint:UInt32 = UInt32(ch)
            // If code point is an ASCII code point, return a byte whose value is code point.
            if(codePoint <= 0x7F){
                ref[position] = UInt8(codePoint)
                position += 1
            // If code point is U+E5E5, return 0xA3 0xA0
            }else if(codePoint == 0xE5E5){
                ref[position] = 0xA3
                position += 1
                ref[position] = 0xA0
                position += 1
            // If is GBK is true and code point is U+20AC, return byte 0x80.
            }else if(gbk && codePoint == 0x20AC){
                ref[position] = 0x80
                position += 1
            }else{
                // double byte part
                var index = indexPointer(gb18030EncodeMapping, gb18030DecodeMapping, codePoint)
                if(index >= 0){
                    let pointer = UInt32(index)
                    let lead = pointer / 190 + 0x81
                    let trail = pointer % 190
                    let offset:UInt32 = if(trail < 0x3F){ 0x40 } else { 0x41 }
                    ref[position] = UInt8(lead)
                    position += 1
                    ref[position] = UInt8(trail + offset)
                    position += 1
                    continue
                }
                //todo If is GBK is true, return error with code point.
                if(gbk){
                    ref[position] = replacement
                    position += 1
                    continue
                }
                // four byte part
                var pointer = indexGB18030RangesPointerFor(codePoint)
                var byte1 = UInt8(pointer / 10 / 126 / 10)
                pointer = pointer - UInt32(byte1) * 10 * 126 * 10
                var byte2 = UInt8(pointer / 10 / 126)
                pointer = pointer - UInt32(byte2) * 10 * 126
                var byte3 = UInt8(pointer / 10);
                var byte4:UInt32 = pointer - UInt32(byte3) * 10
                ref[position] = UInt8(byte1 + 0x81)
                ref[position + 1] = UInt8(byte2 + 0x30)
                ref[position + 2] = UInt8(byte3 + 0x81)
                ref[position + 3] = UInt8(byte4 + 0x30)
                position += 4
                continue
            }
        }
        return ref[0..position]
    }
    private func indexGB18030RangesPointerFor(code_point:UInt32):UInt32 {
        // 1. If code point is U+E7C7, return pointer 7457.
        if (code_point == 0xE7C7) {
            return 7457
        }

        // 2. Let offset be the last code point in index gb18030 ranges
        // that is equal to or less than code point and let pointer offset
        // be its corresponding pointer.
        var offset:UInt32 = 0;
        var pointer_offset:UInt32 = 0;
        var idx = gb18030_rangesMapping;

        for(entry in idx){
            if (entry[1] <= code_point) {
                offset = entry[1];
                pointer_offset = entry[0];
            } else {
            break;
            }
        }

        // 3. Return a pointer whose value is pointer offset + code point - offset.
        return pointer_offset + code_point - offset;
    }
}
