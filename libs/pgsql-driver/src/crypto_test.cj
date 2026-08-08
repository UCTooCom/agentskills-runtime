/*
 * crypto_test.cj —— 使用 RFC / 公认测试向量验证自带密码学原语的正确性。
 * 这些用例不依赖数据库，可单独 `cjpm test --filter *crypto*` 运行。
 */

package pgsql

import std.unittest.*
import std.unittest.testmacro.*

// 将 ASCII 字符串转为字节数组的小工具。
func bytesOf(s: String): Array<Byte> {
    return s.toArray()
}

@Test
func testSha256Vectors() {
    // 标准空串与 "abc" 向量（FIPS 180-4 附录 B）。
    @Expect(toHex(sha256(bytesOf(""))), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    @Expect(toHex(sha256(bytesOf("abc"))), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    // 跨越多个分组的长输入。
    @Expect(
        toHex(sha256(bytesOf("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))),
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
    )
}

@Test
func testMd5Vectors() {
    // RFC 1321 附录测试向量。
    @Expect(toHex(md5(bytesOf(""))), "d41d8cd98f00b204e9800998ecf8427e")
    @Expect(toHex(md5(bytesOf("abc"))), "900150983cd24fb0d6963f7d28e17f72")
    @Expect(toHex(md5(bytesOf("message digest"))), "f96b697d7cb7938d525a2f31aaf161d0")
}

@Test
func testHmacSha256Vectors() {
    // RFC 4231 测试向量来源的经典 "key" / fox 句子。
    let mac = hmacSha256(bytesOf("key"), bytesOf("The quick brown fox jumps over the lazy dog"))
    @Expect(toHex(mac), "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")
}

@Test
func testPbkdf2Vectors() {
    // RFC 6070 风格向量（HMAC-SHA-256 变体）。
    let dk1 = pbkdf2HmacSha256(bytesOf("password"), bytesOf("salt"), 1, 32)
    @Expect(toHex(dk1), "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
    let dk2 = pbkdf2HmacSha256(bytesOf("password"), bytesOf("salt"), 4096, 32)
    @Expect(toHex(dk2), "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
}

@Test
func testBase64RoundTrip() {
    // 经典 "foobar" 渐进式向量，覆盖 0/1/2 个填充字节的三种情况。
    @Expect(base64Encode(bytesOf("")), "")
    @Expect(base64Encode(bytesOf("f")), "Zg==")
    @Expect(base64Encode(bytesOf("fo")), "Zm8=")
    @Expect(base64Encode(bytesOf("foo")), "Zm9v")
    @Expect(base64Encode(bytesOf("foob")), "Zm9vYg==")
    @Expect(base64Encode(bytesOf("fooba")), "Zm9vYmE=")
    @Expect(base64Encode(bytesOf("foobar")), "Zm9vYmFy")
    // 解码应还原原文。
    @Expect(String.fromUtf8(base64Decode("Zm9vYmFy")), "foobar")
    @Expect(String.fromUtf8(base64Decode("Zm8=")), "fo")
}
