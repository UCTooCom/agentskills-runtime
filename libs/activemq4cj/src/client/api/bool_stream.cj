/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq4cj.client.api

public class BoolStream {
    private var data: Array<Byte> = Array<Byte>(48, repeat: 0)
    //总字节数
    private var arrayLimit: Int16 = 0
    //数组位置
    private var arrayPos: Int16 = 0
    //字节位置
    private var bytePos: Int16 = 0

    public func readBool(): Bool {
        let byte: Byte = data[Int64(arrayPos)]
        let rc: Bool = ((byte >> bytePos) & 0x01) != 0
        bytePos++;
        if (bytePos >= 8) {
            bytePos = 0
            arrayPos++;
        }
        return rc
    }

    public func writeBool(value: Bool): Unit {
        if (bytePos == 0) {
            arrayLimit++
            if (Int64(arrayLimit) >= data.size) {
                //扩容
                let d = Array<Byte>(data.size * 2, repeat: 0)
                data.copyTo(d, 0, 0, data.size)
                data = d
            }
        }
        if (value) {
            //或运算设置bytePos处为1
            data[Int64(arrayPos)] |= 0x01 << bytePos
        }
        bytePos++
        if (bytePos >= 8) {
            bytePos = 0
            arrayPos++
        }
    }

    public func marshal(dataOut: ByteBuffer): Unit {
        if (arrayLimit < 64) {
            dataOut.put(UInt8(arrayLimit))
        } else if (arrayLimit < 256) { // max value of unsigned byte
            dataOut.put(UInt8(0xC0))
            dataOut.put(UInt8(arrayLimit))
        } else {
            dataOut.put(UInt8(0x80))
            dataOut.putInt16(arrayLimit)
        }
        dataOut.put(data, 0, Int64(arrayLimit))
    }

    public func unmarshal(dataIn: ByteBuffer): Unit {
        arrayLimit = Int16(dataIn.getByte() & 0xFF)
        if (arrayLimit == 0xC0) {
            arrayLimit = Int16(dataIn.getByte() & 0xFF)
        } else if (arrayLimit == 0x80) {
            arrayLimit = dataIn.getInt16()
        }
        if (data.size < Int64(arrayLimit)) {
            data = Array<Byte>(Int64(arrayLimit), repeat: 0)
        }
        dataIn.get(data, 0, Int64(arrayLimit))
        clear()
    }

    public func clear(): Unit {
        arrayPos = 0
        bytePos = 0
    }

    public func marshalledSize(): Int32 {
        if (arrayLimit < 64) {
            return 1 + Int32(arrayLimit)
        } else if (arrayLimit < 256) {
            return 2 + Int32(arrayLimit)
        } else {
            return 3 + Int32(arrayLimit)
        }
    }
}
