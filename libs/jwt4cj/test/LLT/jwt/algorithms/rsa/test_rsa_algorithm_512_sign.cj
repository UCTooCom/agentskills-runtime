// DEPENDENCE: test_rsa_privateKey_02.pem
// DEPENDENCE: test_rsa_publicKey_02.pem
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import jwt4cj.*
internal import std.posix.*
internal import std.fs.*

main() {

    let src: Array<UInt8> = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toArray()
    let src_header: Array<UInt8> = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9".toArray()
    let src_payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toArray()
    var path: String = getcwd()
    let pri_key: String = "${path}/test_rsa_privateKey_02.pem"
    let pub_key: String = "${path}/test_rsa_publicKey_02.pem"
    var rsa = Algorithm.RSA512(RSAKeyProviderFileImpl(pri_key))
    var rsa2 = Algorithm.RSA512(RSAKeyProviderFileImpl(pri_key, pub_key))
    let ret = rsa.sign(src)
    let ret2 = rsa2.sign(src_header, src_payload)
    if (Base64Util.urlEncode(ret) == Base64Util.urlEncode(ret2)) {
        rsa2.getSigningKeyId()
        rsa2.toString()
        rsa2.sign(src_header, src_payload)
        println("签名后的值为:" + "${Base64Util.urlEncode(ret)}")
        println("两种方式的签名结果是一致的..")
        return 0
    }
    return 1
}
