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
    var s: Array<UInt8> = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toArray()
    let header: Array<UInt8> = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9".toArray()
    let payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toArray()
    let ecdsa = Algorithm.ECDSA256(ECDSAKeyProviderFileImpl(pri_key))
    let ec = Algorithm.ECDSA256(ECDSAKeyProviderFileImpl(pri_key, pub_key))
    println("*****************************************************************************")
    println("签名开始前，传入的原文数组内容是:" + "${s}")
    let ret = ecdsa.sign(s)
    let ret2 = ec.sign(header, payload)
    println("*****************************************************************************")
    var str = Base64Util.urlEncode(ret)
    var str2 = Base64Util.urlEncode(ret2)
    println("打印生成的签名值使用Base64加密后是:" + str)
    println("打印生成的签名值使用Base64加密后是:" + str2)
    let token = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0." + str
    let ecdsa2 = Algorithm.ECDSA256(ECDSAKeyProviderFileImpl(pub_key))
    var jd = JWTDecoder(token)
    ecdsa2.verify(jd)
    return 0
}
