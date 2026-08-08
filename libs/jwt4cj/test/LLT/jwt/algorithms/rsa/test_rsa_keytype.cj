// DEPENDENCE: test_rsa_privateKey.pem
// DEPENDENCE: test_rsa_publicKey.pem
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import jwt4cj.*
internal import std.posix.*
internal import std.fs.*
internal import std.unittest.*
import std.unittest.testmacro.Assert
internal import stdx.crypto.keys.*

main() {
    let header = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9"
    let payload = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
    let secret = "Q_CatS3ATEdvyR_T_jCFVDzVSJKWZpi5xYScdji3D6JBY335_AjanEzJFERNKO-d1KVs8Rx2xyNm6N_fI8y1Fg"
    let token = "${header}.${payload}.${secret}"
    let src: Array<UInt8> = "${header}.${payload}".toArray()

    var path: String = getcwd()
    let pri_key: String = String.fromUtf8(File.readFrom("${path}/test_rsa_privateKey.pem"))
    let pub_key: String = String.fromUtf8(File.readFrom("${path}/test_rsa_publicKey.pem"))

    // let prikey: KeyType = MyKeyType({ => pri_key})
    // let pubkey: KeyType = MyKeyType({ => pub_key})
    // let kp: KeyProvider<KeyType, KeyType> = RSAKeyProviderFileImpl(prikey, pubkey)

    var pub: RSAPublicKey = RSAPublicKey.decodeFromPem(pub_key)
    var pri: RSAPrivateKey = RSAPrivateKey.decodeFromPem(pri_key)
    let kp: RSAKeyProvider<RSAPublicKey, RSAPrivateKey> = RSAKeyProviderImpl(pri, pub)

    let rsa = Algorithm.RSA256(kp)
    let signResBytes = rsa.sign(src)
    let signresStr = Base64Util.urlEncode(signResBytes)
    println(signresStr)
    println(secret)
    @Assert(signresStr, secret)

    let jd = JWTDecoder(token)
    rsa.verify(jd)

    0
}

// class MyKeyType <: KeyType {
//     let getter: () -> String
//     init(getter: () -> String) {
//         this.getter = getter
//     }
//     public override func getKeyFilePath(): String {
//         return getter()
//     }
// }
