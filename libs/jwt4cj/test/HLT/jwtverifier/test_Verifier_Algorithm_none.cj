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
    var jsonStr_header = ##"{"k_header_1":"v_header_1","kid":"keyId","alg":"none","typ":"JWT","cty":"JWT"}"##
    var jsonStr_payload =
        ##"{"iss":"iss_payload","sub":"subject_payload","aud":["aud1","aud2","\"Hello Cangjie Lang\"","你好仓颉！【】"],"exp":3673835050,"nbf":1673835050,"iat":1673835000,"jti":"jwtId_payload","iat":"iat_payload","k_bool":true,"ddd":"dfdddff","k_int64":64,"k_float64":3.14,"k_String":"abaaba","k_time":1673850000,"k_map":{"mk2":"mv2"},"k_list":[56.51,41.96],"k_null":null,"k_arraystring":["astr1","astr2"],"arrayint":[684,64],"pk1":"pv1","pk2":"pv2"}"##
    var jv1: JsonValue = JsonValue.fromStr(jsonStr_header)
    var jv2: JsonValue = JsonValue.fromStr(jsonStr_payload)

    var token: String = ""
    let require = JWT.require(Algorithm.none())
    var claimMap: Map<String, Claim> = HashMap<String, Claim>()

    @TestCase
    func testVerifier_Algorithm_none_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        var t1 = DateTime.ofUTC(year: 2023, month: Month.August, dayOfMonth: 5)
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withClaim("k_Bool", true)
        jwtBuilder.withClaim("k_Int64", 1265)
        jwtBuilder.withClaim("k_float64", -12.365)
        jwtBuilder.withClaim("k_Time", t1)
        jwtBuilder.withAudience(["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"])
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload_1")
        jwtBuilder.withIssuer("iss_payload_2")
        jwtStr = jwtBuilder.sign(Algorithm.none()) //不经过加密,jwtStr以"."结尾

        /* ########################JWTVerifier########################### */
        require.withIssuer("iss_payload_2")
        require.withSubject("subject_payload")
        require.withClaim("k_Bool", true) // public func withClaim(name: String, value: Bool): Verification
        require.withClaim("k_Int64", 1265) // public func withClaim(name: String, value: Int64): Verification
        require.withClaim("k_float64", -12.365) // public func withClaim(name: String, value: Float64): Verification 
        require.withClaim("k_Time", t1)
        require.withAnyOfAudience(["aud1", "\"Hello Cangjie Lang\"", "你好仓颉！【】"]) // 合法子集
        require.withAudience(["\"Hello Cangjie Lang\"", "你好仓颉！【】"]) // 合法子集
        require.withJWTId("withJWTId") // withJWTId
        require.withClaimPresence("k_String")
        require.withArrayClaim("aud", ["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"]) // 全集
        require.withArrayClaim("aud", ["aud1", "aud2"]) // 子集
        require.withClaim("typ", "JWT")
        require.withClaim("k_header_1", "v_header_1")
        require.withClaim("jti", "withJWTId")
        require.withClaim("cty", "JWT")
        require.withClaim("kid", "keyId")

        let builder: JWTVerifier = require.build()
        try {
            JWT.decode("ewogICJhbGciOiAibm9uZSIsCiAgInR5cCI6ICJKV1QiCn0..") 
        } catch (e1: Exception) {
            @Assert(e1.toString(), "Exception: The string '' doesn't have a valid JSON format.")
        }
        try {
            let jwtDecoder: DecodedJWT = builder.verify(jwtStr)
            claimMap = jwtDecoder.getClaims() //Map<String, Claim>
            strActual = ""
            for(k in claimMap.keys()){
                strActual += k
            }
        } catch (e2: Exception) {
            returnTag = 1
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_none_002(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        ins_1.createClaim(jwtBuilder, arrStr_header, arrStr_payload)
        jwtBuilder.withClaim("iat", "iat12466") // 设置的Claim "iat"的属性值不符合其申明，在校验时会抛异常
        let strArr: Array<String> = ["aud1", "aud2", "\"Hello Cangjie Lang\"", "你好仓颉！【】"]
        jwtBuilder.withAudience(strArr)
        jwtBuilder.withJWTId("withJWTId")
        jwtBuilder.withIssuer("iss_payload_1")
        jwtStr = jwtBuilder.sign(Algorithm.none()) //不经过加密,jwtStr以"."结尾
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)
        @Assert(strActual, "ewogICJhbGciOiAibm9uZSIsCiAgInR5cCI6ICJKV1QiCn0")
        /* ########################JWTVerifier########################### */
        require.withJWTId("withJWTId") // withJWTId
        require.withClaimPresence("k_String")
        require.withClaim("k_header_1", "v_header_1")
        try {
            require.withClaim("iat", "iat12466") //异常
            let builder: JWTVerifier = require.build()
            builder.verify(jwtStr)
        } catch (e1: Exception) {
            @Assert(e1.toString(), "Exception: The claim 'iat' is not time.")
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_none_003(): Unit {
        returnTag = -1
        let require = JWT.require(Algorithm.none())
        // withNotBefore 2086-06-02T13:44:50+08:00
        let token =
            "ewogICJrMSI6ICJ2MSIsCiAgImtpZCI6ICJrZXlJZCIsCiAgImFsZyI6ICJub25lIiwKICAidHlwIjogIkpXVCIKfQ.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAzNjczODM1MDkwLAogICJuYmYiOiAzNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiaW50NjQiOiA2NCwKICAiZmxvYXQ2NCI6IDMuMTQwMDAwLAogICJTdHJpbmciOiAiYWJhYWJhIiwKICAidGltZSI6IDE2NzM4NTAwMDAsCiAgIm1hcCI6IHsKICAgICJtazIiOiAibXYyIgogIH0sCiAgImxpc3QiOiBbCiAgICA1Ni41MTAwMDAsCiAgICA0MS45NjAwMDAKICBdLAogICJudWxsIjogbnVsbCwKICAiYXJyYXlzdHJpbmciOiBbCiAgICAiYXN0cjEiLAogICAgImFzdHIyIgogIF0sCiAgImFycmF5aW50IjogWwogICAgNjg0LAogICAgNjQKICBdLAogICJwazEiOiAicHYxIiwKICAicGsyIjogInB2MiIKfQ."

        /* ########################JWTVerifier########################### */
        require.acceptExpiresAt(125309) // now -125309 > token exp ? F : S
        require.acceptLeeway(10) //default 
        require.acceptIssuedAt(1200) // now +125309 < token exp ? F : S    ignoreIssuedAt后不校验iss
        require.acceptNotBefore(121545) // now +125309 < token exp ? F : S
        let builder: JWTVerifier = require.build()
        try {
            builder.verify(token)
        } catch (e1: Exception) {
            @Assert(e1.toString(), "Exception: The Token can't be used before 2086-06-02T05:44:10Z.")
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testVerifier_Algorithm_none_004(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        let require = JWT.require(Algorithm.none())
        jwtBuilder.withClaim("k_1", "withJWTId")
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        strActual = jwtDecoder.getClaim("k_1").toString()

        let predicate = {
            claim: Claim, decodedJWT: DecodedJWT =>
            if (claim.isMissing() || decodedJWT.getSignature() == "") {
                return false
            }
            return true
        }

        require.withClaim("k_2", predicate)
        let builder: JWTVerifier = require.build()
        try {
            builder.verify(jwtStr)
            ()
        } catch (e1: Exception) {
            @Assert(e1.toString(), "Exception: The Claim 'k_2' value doesn't match the required one.")
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }
}
