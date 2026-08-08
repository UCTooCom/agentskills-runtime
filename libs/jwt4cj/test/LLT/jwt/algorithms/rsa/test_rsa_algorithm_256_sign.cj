// DEPENDENCE: test_rsa_privateKey.pem
// DEPENDENCE: test_rsa_publicKey.pem
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import jwt4cj.*
internal import std.posix.*
internal import std.fs.*

main() {

    let src: Array<UInt8> = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ".toArray()
    let src_header: Array<UInt8> = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9".toArray()
    let src_payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ".toArray()
    var path: String = getcwd()
    let pri_key: String = "${path}/test_rsa_privateKey.pem"
    let pub_key: String = "${path}/test_rsa_publicKey.pem"
    var rsa = Algorithm.RSA256(RSAKeyProviderFileImpl(pri_key))
    var rsa2 = Algorithm.RSA256(RSAKeyProviderFileImpl(pri_key, pub_key))
    let ret = rsa.sign(src)
    let ret2 = rsa2.sign(src_header, src_payload)
    var str = Base64Util.urlEncode(ret)
    var str2 = Base64Util.urlEncode(ret2)
    println("打印生成的签名值使用Base64加密后是:" + str)
    println("打印生成的签名值使用Base64加密后是:" + str2)
    if (Base64Util.urlEncode(ret) == Base64Util.urlEncode(ret2)) {
        println("签名后的值为:" + "${Base64Util.urlEncode(ret)}")
        println("两种方式的签名结果是一致的..")
        return 0
    }
    return 1
}
