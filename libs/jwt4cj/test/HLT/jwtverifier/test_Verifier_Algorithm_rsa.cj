// 3rd_party_lib:jwt4cj/build/jwt4cj
//dependence:../utils_test/createsourcedata.cj
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

/**
   public static func create(): Builder
   public func withHeader(headerClaims: Map<String, Any>): Builder
   public func withClaim(name: String, value: String): Builder
   public func withPayload(payloadClaims: Map<String, Any>): Builder
   public func sign(algorithm: Algorithm): String
   public func withIssuer(issuer: String): Verification
   public func withSubject(subject: String): Verification
   public func withAnyOfAudience(audience: Array<String>): Verification
   public func withAudience(audience: Array<String>): Verification
   public func withJWTId(jwtId: String): Verification
   public func withClaimPresence(name: String): Verification
   public func withClaim(name: String, value: String): Verification
   public func verify(jwt: DecodedJWT): DecodedJWT
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var strActual: String = ""
    let ins_1: SourceData = SourceData()
    var arrStr_header = ["k_header_1", "v_header_1", "kid", "keyId", "alg", "none", "typ", "JWT", "cty", "JWT"]
    var arrStr_payload = ["iss", "iss_payload", "sub", "subject_payload", "jti", "jwtId_payload", "k_String", "abaaba"]

    var token: String = ""
    let path: String = getcwd()
    let pri_key: String = "${path}/test_rsa_privateKey.pem"
    let pub_key: String = "${path}/test_rsa_publicKey.pem"
    let alg_rsa_256 = Algorithm.RSA256(RSAKeyProviderFileImpl(pri_key, pub_key))
    let alg_rsa_384 = Algorithm.RSA384(RSAKeyProviderFileImpl(pri_key, pub_key))
    let alg_rsa_512 = Algorithm.RSA512(RSAKeyProviderFileImpl(pri_key, pub_key))

    let require256 = JWT.require(alg_rsa_256)
    let require384 = JWT.require(alg_rsa_384)
    let require512 = JWT.require(alg_rsa_512)

    var claimMap: Map<String, Claim> = HashMap<String, Claim>()
    @TestCase
    func testVerifier_Algorithm_rsa_256(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withAudience(["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"])
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload")
        jwtStr = jwtBuilder.sign(alg_rsa_256)
        require256.withIssuer(["iss_payload", "other"])
        require256.withSubject("subject_payload")
        require256.withAnyOfAudience(["aud1", "\"Hello Cangjie Lang\"", "你好仓颉！【】"]) // 合法子集
        require256.withAudience(["\"Hello Cangjie Lang\"", "你好仓颉！【】"]) // 合法子集
        require256.withJWTId("withJWTId") // withJWTId
        require256.withClaimPresence("k_String")

        require256.withClaim("typ", "JWT")
        require256.withClaim("k_header_1", "v_header_1")
        require256.withClaim("jti", "withJWTId")
        require256.withClaim("kid", "keyId")

        try {
            require256.withIssuer(["other"])
            let builder: JWTVerifier = require256.build()
            builder.verify(JWTDecoder(jwtStr))
            ()
        } catch (e1: Exception) {
            @Assert(e1.toString().contains("The Token's Signature resulted invalid when verified using the Algorithm: exception func in verify"), true)
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_rsa_384(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withAudience(["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"])
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload")
        jwtStr = jwtBuilder.sign(alg_rsa_384)
        require384.withSubject("subject_payload")
        try {
            require384.withAudience(["\"Hello Cangjie Lang\"", "不包含"]) 
            let builder: JWTVerifier = require384.build()
            builder.verify(JWTDecoder(jwtStr))
            ()
        } catch (e1: Exception) {
            @Assert(e1.toString().contains("The Token's Signature resulted invalid when verified using the Algorithm: exception func in verify"), true)
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_rsa_512(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withAudience(["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"])
        let strArrL: ArrayList<String> = ArrayList<String>(
            ["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"])
        require512.withAnyOfAudience(strArrL) 
        jwtStr = jwtBuilder.sign(alg_rsa_512)
        try {
            require512.withAnyOfAudience(["aud1", "other"]) // 合法子集
            let builder: JWTVerifier = require512.build()
            builder.verify(JWTDecoder(jwtStr))
            ()
        } catch (e1: Exception) {
            @Assert(e1.toString().contains("The Token's Signature resulted invalid when verified using the Algorithm: exception func in verify"), true)
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }
}
