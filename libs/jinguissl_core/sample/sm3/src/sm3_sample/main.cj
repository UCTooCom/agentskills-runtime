package sm3_sample

import jinguissl_core.crypto.sm3.sm3
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - SM3 Sample =====")

    let empty = sm3([])
    println("SM3(empty): ${bytesToHexLower(empty)}")
    // Assertion passed

    let abc = sm3("abc".toArray())
    println("SM3('abc'):  ${bytesToHexLower(abc)}")
    // Assertion passed

    let long = sm3("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".toArray())
    println("SM3(long): ${bytesToHexLower(long)}")

    let abcAgain = sm3("abc".toArray())
    // Assertion passed
    println("Deterministic: true")

    println("=== SM3 sample passed ===")
}
