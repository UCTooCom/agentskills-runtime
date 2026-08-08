// DEPENDENCE: test_ecdsa_privateKey.pem
// DEPENDENCE: test_ecdsa_publicKey.pem
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

internal import std.posix.*
internal import jwt4cj.*

main() {  
    var path: String = getcwd()
    let pri_key: String = "${path}/test_ecdsa_privateKey.pem"
    let pub_key: String = "${path}/test_ecdsa_publicKey.pem"
    var s: Array<UInt8> = "eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toArray()
    let header: Array<UInt8> = "eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9".toArray()
    let payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toArray()
    let ecdsa = Algorithm.ECDSA384(ECDSAKeyProviderFileImpl(pri_key))
    Algorithm.ECDSA384(ECDSAKeyProviderFileImpl(pri_key, pub_key))
    println("*****************************************************************************")
    println("签名开始前，传入的原文数组内容是:" + "${s}")
    let ret = ecdsa.sign(s)
    ecdsa.sign(header, payload)
    println("*****************************************************************************")
    var str = Base64Util.urlEncode(ret)
    println("打印生成的签名值使用Base64加密后是:" + "${str}")
    let token = "eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0." + str
    let ecdsa2 = Algorithm.ECDSA384(ECDSAKeyProviderFileImpl(pub_key))
    var jd = JWTDecoder(token)
    ecdsa2.verify(jd)
    return 0
}
