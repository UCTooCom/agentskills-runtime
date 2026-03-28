/*
 * Copyright 2010 The Go Authors. All rights reserved.
 *
 * Portions of this file are derived from golang.org/x/crypto/blowfish,
 * which is licensed under a BSD-style license.
 * The original license can be found in the LICENSE.BSD file in this repository.
 *
 * Copyright 2025 Dacec
 *
 * The remainder of this file, and the project as a whole (unless otherwise noted),
 * is licensed under the MIT License.
 * The full MIT License text can be found in the LICENSE.MIT file in this repository.
 */
package blowfish

// 以大端序从b中循环读取一个UInt32，pos修改为下一个代码读取的位置
func getNextWord(b: Array<Byte>, pos: Box<Int64>): UInt32 {
    var w = 0u32
    var j = pos.value
    for (_ in 0..4) {
        w = w << 8 | UInt32(b[j])
        j++
        if (j >= b.size) {
            j = 0
        }
    }
    pos.value = j
    return w
}
