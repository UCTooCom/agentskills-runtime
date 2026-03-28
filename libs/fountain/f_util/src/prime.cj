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
package f_util

/**
 * 快速幂取模
 * @param a
 * @param b
 * @param m
 * @return
 */
public func qpow(a: UInt64, b: UInt64, m: UInt64) {
    var aa = a
    var bb = b
    var ans = 1u64
    while (bb != 0) {
        if ((bb & 1) != 0) {
            ans = (ans * aa) % m
        }
        bb >>= 1
        aa = (aa * aa) % m
    }
    return ans
}

public func millerRabin(x: UInt64, p: UInt64) {
    var d = p - 1
    while ((d & 1) == 0) {
        d >>= 1
    }
    var t = qpow(x, d, p)
    while (d != p - 1) {
        if (t == 1 || t == p - 1) {
            return true
        }
        t = (t * t) % p
        d <<= 1
    }
    return false
}
/**
 * 判定素数
 * @param p
 * @return
 */
public func isPrime(p: UInt64) {
    if (p < 2) {
        return false
    }
    let a: Array<UInt64> = [2, 3, 5, 7, 11]
    for (i in 0..a.size) {
        if (p == a[i]) {
            return true
        }
        if (!millerRabin(a[i], p)) {
            return false
        }
    }
    return true
}
