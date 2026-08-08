// 3rd_party_lib:jwt4cj/build/jwt4cj
//dependence:../utils_test/createsourcedata.cj
internal import jwt4cj.*
internal import stdx.encoding.hex.*
internal import std.unittest.*
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
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
    let require256 = JWT.require(Algorithm.HMAC256("Algorithm.HMAC256"));
    let require384 = JWT.require(Algorithm.HMAC384("Algorithm.HMAC384"));
    let require512 = JWT.require(Algorithm.HMAC512("Algorithm.HMAC512"));
    var claimMap: Map<String, Claim> = HashMap<String, Claim>()

    @TestCase
    func testVerifier_Algorithm_hmac_256(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withArrayClaim("arrayClaim", [521239, -125, 3654])
        jwtBuilder.withClaim("arrLClaim_int64", ArrayList<Any>([521239, -125, 3654]))
        jwtBuilder.withClaim("arrLClaim_str", ArrayList<Any>(["521239", "-125", "3654"]))
        jwtBuilder.withAudience(["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"])
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload")
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("Algorithm.HMAC256"))

        /* ########################JWTVerifier########################### */
        require256.withIssuer("iss_payload")
        require256.withSubject("subject_payload")
        require256.withArrayClaim("arrayClaim", [521239, -125, 3654]) // public func withArrayClaim(name: String, items: Array<Int64>): Verification 
        require256.withArrayClaim("arrLClaim_int64", [521239, -125, 3654]) // public func withArrayClaim(name: String, items: ArrayList<Int64>): Verification
        require256.withArrayClaim("arrLClaim_str", ["521239", "-125", "3654"]) // public func withArrayClaim(name: String, items: ArrayList<String>): Verification
        let builder: JWTVerifier = require256.build()
        try {
            builder.verify(jwtStr)
            ()
        } catch (e1: Exception) {
            returnTag = 1
        }
        try {
            require256.withNullClaim("k_String")
            let builder: JWTVerifier = require256.build()
            builder.verify(jwtStr)
            ()
        } catch (e2: Exception) {
            // println("e2: ${e2}")
            @Assert(e2.toString().contains("The Claim 'k_String' value doesn't match the required one"), true)
            returnTag = 0
        }

        /* ############################################## */
        jwtBuilder.withExpiresAt(DateTime.ofUTC(year: 2022, month: Month.August, dayOfMonth: 5)) // 已过期
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("Algorithm.HMAC256"))
        try {
            require256.acceptExpiresAt(10)
            let builder: JWTVerifier = require256.build()
            builder.verify(jwtStr)
            ()
        } catch (e3: Exception) {
            @Assert(e3.toString().contains("The Token has expired on 2022-08-05T00:00:00Z."), true)
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_hmac_384(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withArrayClaim("arrayClaim", [521239, -125, 3654])
        jwtBuilder.withClaim("aud", ArrayList<Any>(["aud_1", "aud_2", "aud_3"]))
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload")
        jwtStr = jwtBuilder.sign(Algorithm.HMAC384("Algorithm.HMAC384"))

        /* ########################JWTVerifier########################### */
        require384.withSubject("subject_payload")
        require384.withAnyOfAudience(["aud_1", "aud_2", "aud_3"]) // 合法子集
        require384.withIssuer("iss_payload")
        require384.withClaimPresence("k_String")
        require384.withClaim("typ", "JWT")
        let builder: JWTVerifier = require384.build()
        try {
            builder.verify(jwtStr)
            ()
        } catch (e1: Exception) {
            returnTag = 1
        }
        try {
            require384.withAudience(["aud_1", "aud_2", "我没在列表里"])
            let builder: JWTVerifier = require384.build()
            builder.verify(jwtStr)
            ()
        } catch (e2: Exception) {
            @Assert(e2.toString().contains("The Claim 'aud' value doesn't contain the required audience"), true)
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_hmac_512(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withArrayClaim("arrayClaim", [521239, -125, 3654])
        jwtBuilder.withClaim("aud", ArrayList<Any>(["aud_1", "aud_2", "aud_3"]))
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload")
        jwtBuilder.withIssuedAt(DateTime.parse("2023-04-05T21:08:04+08:00"))
        jwtStr = jwtBuilder.sign(Algorithm.HMAC512("Algorithm.HMAC384")) //签名算法与验签解密算法不一致

        /* ########################JWTVerifier########################### */
        try {
            require512.ignoreIssuedAt()
            let builder: JWTVerifier = require512.build()
            builder.verify(jwtStr)
            ()
        } catch (e1: Exception) {
            // println("e1: ${e1}")
            @Assert(e1.toString().contains("The Token's Signature resulted invalid when verified using the Algorithm: HMAC exception"), true)
            returnTag = 0
        }

        /* ########################JWTVerifier########################### */
        jwtStr = jwtBuilder.sign(Algorithm.HMAC512("Algorithm.HMAC512"))
        require512.withArrayClaim("arrayClaim", [521239, -125, 3654])
        require512.withArrayClaim("arrayClaim", [521239, -125])
        require512.acceptLeeway(10)
        try {
            require512.acceptIssuedAt(120)
            let builder: JWTVerifier = require512.build()
            builder.verify(jwtStr)
            ()
        } catch (e1: Exception) {
            // println("e1: ${e1}")
            @Assert(e1.toString().contains("The Token can't be used before 2023-04-05T13:08:04Z"), true)
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }
}
