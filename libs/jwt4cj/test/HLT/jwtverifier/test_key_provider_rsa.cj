// 3rd_party_lib:jwt4cj/build/jwt4cj
//data_file:test_rsa_privateKey.pem 
//data_file:test_rsa_publicKey.pem
internal import jwt4cj.*
internal import stdx.encoding.hex.*
internal import std.unittest.*
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import std.posix.*
internal import std.fs.*
internal import stdx.crypto.keys.*

@Test
public class JWTTest {
    var returnTag: Int64 = 0
    let header = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9"
    let payload = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"

    var path: String = getcwd()
    let pri_key: String = "${path}/test_rsa_privateKey.pem"
    let pub_key: String = "${path}/test_rsa_publicKey.pem"

    @TestCase
    func test_key_provider_rsa_256(): Unit {
        let secret =
        "PeuJlL-zJaeZUeECfSL5xxHr8YuX23qYoKZdKEeYuUSC1RDGh2YFIJlkYXBCOVku1OyYo4HFvnYh543aPvn78OruBtwRUPmdsWcaqxF9hVONFMYij1wIxKdoSqUGlvXZBRilVkDmqCPf59vWVGl5sBhaGtKRBuMwNO83bXOlSQZv_5FlrH7fdVpXe2ff14wvGYpCRyDO-sTuK9EdcFrafqKb6kdL8wY4-65Ya4lflAAHFrOBVxODYxRItgcWBy-pnPmo51qI05zUHGIyWczAOUc-hwVi4uYzzpeAdoGRKZbixOyPOqPgYc9o_Sb5QEOmtT4EDKkOpu_J0vDIn623vw"
        let token = "${header}.${payload}.${secret}"
        let src: Array<UInt8> = "${header}.${payload}".toArray()
        let privatekey = String.fromUtf8(File.readFrom(pri_key))
        var pri = RSAPrivateKey.decodeFromPem(privatekey)
        var pub = RSAPublicKey(pri)
        let kp: RSAKeyProvider<RSAPublicKey, RSAPrivateKey> = RSAKeyProviderImpl(pri, pub)
        let rsa = Algorithm.RSA256(kp)
        let signResBytes = rsa.sign(src)
        let signresStr = Base64Util.urlEncode(signResBytes)
        @Assert(signresStr, secret)
        let jd = JWTDecoder(token)
        try {
            rsa.verify(jd)
        } catch (e1: Exception) {
            returnTag = 1
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func test_key_provider_rsa_384(): Unit {
        let secret =
        "RGy5CnyyIxw3FcYtWBFJUQwgU1sIu9Vm_9TaWbxuhPjWQyIhaDH3tdC2lEseEZeh78tMHLgzYf7m3PLuFdkosdC-7_OCeFtIFqtmdFJHZPVWmnqlHEJuE95moYTtaKnUBXXomleRDtN4KB3obFwJe6q4R01IQgBjSKmmqW7oUBy1yiei5e39WKEX2_tGAoZax8sczANNAyQNrfwtRZDv1cBQ5wLRhRF3mEwAb78dgmJ7E30vXdzknKT2AUZEi1rc4cog-VVo4p9Kdhr5BrwuQ0jag9SUFQ8fab-YUNhp2OGBdhqrwyoXeemYHDAfZPfOpbaTfnAv285_FDSdIpf9IQ"
        let token = "${header}.${payload}.${secret}"
        let src: Array<UInt8> = "${header}.${payload}".toArray()
        let privatekey = String.fromUtf8(File.readFrom(pri_key))
        var pri = RSAPrivateKey.decodeFromPem(privatekey)
        var pub = RSAPublicKey(pri)
        // @Assert(pub, privatekey.getPublicKey())
        let kp: RSAKeyProvider<RSAPublicKey, RSAPrivateKey> = RSAKeyProviderImpl(pri, pub)
        let rsa = Algorithm.RSA384(kp)
        let signResBytes = rsa.sign(src)
        let signresStr = Base64Util.urlEncode(signResBytes)
        @Assert(signresStr, secret)
        let jd = JWTDecoder(token)
        try {
            rsa.verify(jd)
        } catch (e1: Exception) {
            returnTag = 1
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func test_key_provider_rsa_512(): Unit {
        let secret =
        "FwUyA4jkTtcCSpvbIpGyrzJAEpmaw6Z5k48XXySPnsUg-U8RNuqGGjpu9Q2phx4MiPS5DTR9auoAEXV6n4C8Tz2gWbI0u4u0ZKZ5cCVhhzah5qkboYgWSuMDnzIK3Ikf8hbKjl2XwP2v2pM1nKAXETLBXx_Ov13vsxr8WF17SzlrFAGp4WqCrrI4c_wAwjJaPueDyMo3NyJ3XBBSvd0RS4uN399bDVADtRDtYsy5KSrNsnxVYkIJk5v7iHNhMyoDnxXjfHyCcAAQe-awCbwtG5sc6WPrlIbZGGsy0mepQu_T3X2GytaCKviWOz4ZA2hQ6930wnZq5oF0Zi1rhz_VSQ"
        let token = "${header}.${payload}.${secret}"
        let src: Array<UInt8> = "${header}.${payload}".toArray()
        let privatekey = String.fromUtf8(File.readFrom(pri_key))
        var pri = RSAPrivateKey.decodeFromPem(privatekey)
        var pub = RSAPublicKey(pri)
        let kp: RSAKeyProvider<RSAPublicKey, RSAPrivateKey> = RSAKeyProviderImpl(pri, pub)
        let rsa = Algorithm.RSA512(kp)
        let signResBytes = rsa.sign(src)
        let signresStr = Base64Util.urlEncode(signResBytes)
        @Assert(signresStr, secret)
        let jd = JWTDecoder(token)
        try {
            rsa.verify(jd)
        } catch (e1: Exception) {
            returnTag = 1
        }
        @Assert(returnTag, 0)
    } 
}
