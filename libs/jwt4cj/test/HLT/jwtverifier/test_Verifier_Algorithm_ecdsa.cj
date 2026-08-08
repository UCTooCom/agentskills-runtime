// 3rd_party_lib:jwt4cj/build/jwt4cj
//dependence:../utils_test/createsourcedata.cj
//data_file:test_ecdsa_privateKey.pem
//data_file:test_ecdsa_publicKey.pem
internal import jwt4cj.*
internal import std.unittest.*
internal import std.unittest.*
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import std.posix.*
internal import std.fs.*

@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var jwtPayload: String = ""
    var strActual: String = ""
    let ins_1: SourceData = SourceData()
    var arrStr_header = ["k_header_1", "v_header_1", "kid", "keyId", "alg", "none", "typ", "JWT", "cty", "JWT"]
    var arrStr_payload = ["iss", "iss_payload", "sub", "subject_payload", "jti", "jwtId_payload", "k_String", "abaaba"]

    let path: String = getcwd()
    let pri_key: String = "${path}/test_ecdsa_privateKey.pem"
    let pub_key: String = "${path}/test_ecdsa_publicKey.pem"
    let alg_ecdsa_256 = Algorithm.ECDSA256(ECDSAKeyProviderFileImpl(pri_key, pub_key))
    let alg_ecdsa_384 = Algorithm.ECDSA384(ECDSAKeyProviderFileImpl(pri_key, pub_key))
    let alg_ecdsa_512 = Algorithm.ECDSA512(ECDSAKeyProviderFileImpl(pri_key, pub_key))

    let require256 = JWT.require(alg_ecdsa_256);
    let require384 = JWT.require(alg_ecdsa_384);
    let require512 = JWT.require(alg_ecdsa_512);
    var claimMap: Map<String, Claim> = HashMap<String, Claim>()

    @TestCase
    func testVerifier_Algorithm_ecdsa_256(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withAudience(["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"])
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload")
        jwtStr = jwtBuilder.sign(alg_ecdsa_256)
        require256.withIssuer("iss_payload")
        require256.withSubject("subject_payload")
        require256.withAnyOfAudience(["aud1", "\"Hello Cangjie Lang\"", "你好仓颉！【】"]) // 合法子集
        require256.withAudience(["\"Hello Cangjie Lang\"", "你好仓颉！【】"]) // 合法子集
        require256.withJWTId("withJWTId") // withJWTId
        require256.withClaimPresence("k_String")
        require256.withClaim("typ", "JWT")
        require256.withClaim("k_header_1", "v_header_1")
        require256.withClaim("jti", "withJWTId")
        require256.withClaim("kid", "keyId")
        let builder: JWTVerifier = require256.build()

        //  public func verify(jwt: DecodedJWT): DecodedJWT
        try {
            builder.verify(JWTDecoder(jwtStr))
            ()
        } catch (e1: Exception) {
            returnTag = 1
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_ecdsa_384(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtStr = jwtBuilder.sign(alg_ecdsa_384)
        require384.withSubject("subject_payload")
        try {
            require384.acceptExpiresAt(125309)
            require384.acceptLeeway(125309) //default 
            require384.acceptIssuedAt(1200)
            let builder: JWTVerifier = require384.build()
            builder.verify(JWTDecoder(jwtStr))
            ()
        } catch (e1: Exception) {
            returnTag = 1
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_ecdsa_512(): Unit {
        returnTag = -1

        // withNotBefore 2086-06-02T13:44:50+08:00
        let token =
            "ewogICJrMSI6ICJ2MSIsCiAgImtpZCI6ICJrZXlJZCIsCiAgImFsZyI6ICJub25lIiwKICAidHlwIjogIkpXVCIKfQ.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAzNjczODM1MDkwLAogICJuYmYiOiAzNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiaW50NjQiOiA2NCwKICAiZmxvYXQ2NCI6IDMuMTQwMDAwLAogICJTdHJpbmciOiAiYWJhYWJhIiwKICAidGltZSI6IDE2NzM4NTAwMDAsCiAgIm1hcCI6IHsKICAgICJtazIiOiAibXYyIgogIH0sCiAgImxpc3QiOiBbCiAgICA1Ni41MTAwMDAsCiAgICA0MS45NjAwMDAKICBdLAogICJudWxsIjogbnVsbCwKICAiYXJyYXlzdHJpbmciOiBbCiAgICAiYXN0cjEiLAogICAgImFzdHIyIgogIF0sCiAgImFycmF5aW50IjogWwogICAgNjg0LAogICAgNjQKICBdLAogICJwazEiOiAicHYxIiwKICAicGsyIjogInB2MiIKfQ."

        /* ########################JWTVerifier########################### */
        require512.acceptExpiresAt(125309)
        require512.acceptLeeway(125309) //default 
        require512.acceptIssuedAt(1200)
        try {
            require512.acceptNotBefore(-121545)
            let builder: JWTVerifier = require512.build()
            builder.verify(token)
        } catch (e1: Exception) {
            @Assert(e1.toString(), "IllegalArgumentException: Leeway value can't be negative.")
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }
}
