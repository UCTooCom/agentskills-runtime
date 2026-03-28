/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_jwt

import stdx.encoding.base64.*
import stdx.encoding.hex.*
import f_jwt.exception.*

func fromBase64(src: String): Array<Byte> {
    fromBase64String(src).getOrThrow {JWTException('${src} is not base64')}
}

func fromBase64ToString(src: String) {
    String.fromUtf8(fromBase64(src))
}

func fromHex(src: String): Array<Byte> {
    fromHexString(src).getOrThrow {JWTException('${src} is not hex')}
}

func toBase64(src: Array<Byte>): String {
    toBase64String(src)
}

func toBase64(src: String): String {
    toBase64(unsafe { src.rawData() })
}

func bytesForSign(header: String, payload: String): Array<Byte> {
    bytesForSign(unsafe { header.rawData() }, unsafe { payload.rawData() })
}

func bytesForSign(header: Array<Byte>, payload: Array<Byte>): Array<Byte> {
    let headerSize = header.size
    Array<Byte>(headerSize + payload.size) {
        i => if (i < headerSize) {
            header[i]
        } else {
            payload[i - headerSize]
        }
    }
}
