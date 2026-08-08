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
   public func withNotBefore(notBefore: DateTime): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getType(): String
   public func getAlgorithm(): String
   public func getSignature(): String
   public func getNotBefore(): DateTime
   public init() ::class JWT
   public func decodeJwt(token: String): DecodedJWT
   public static func decode(token: String): DecodedJWT
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var strActual: String = ""
    let ins_1: SourceData = SourceData()
    let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2]
    let arr_Str1: Array<Any> = ins_1.generateSourceDataWithString()[0]
    let map_Bool: HashMap<String, Any> = ins_1.generateSourceDataWithBool()[2]
    let entry: (ArrayList<String>, ArrayList<Any>) = ins_1.getMapEntry(map_String)

    var token = ""
    var t1: DateTime = DateTime.now()
    var t2 = DateTime.ofUTC(year: 2023, month: Month.August, dayOfMonth: 5)
    var customPtn = "yyyy/MM/dd HH:mm:ss OO"
    var t3 = DateTime.parse("2021-08-05T21:08:04Z")
    var t4 = DateTime.parse("2022/02/16 21:08:04 +08:00", customPtn).inUTC()

    @TestCase
    func testWithNotBefore_001(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withKeyId(entry[0][1]) //中文字符
        jwtBuilder.withHeader(HashMap<String, Any>([("map_Int64_1", -2654648)]))
        jwtBuilder.withAudience(ins_1.convertArrAnyToArrString(arr_Str1))

        // public func withNotBefore(notBefore: DateTime): Builder
        jwtBuilder.withNotBefore(t2) // 2023-08-05T00:00:00+08:00
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()

        // public func getType(): String
        strActual = jwtDecoder.getType()
        @Assert(strActual, "JWT")

        // public func getAlgorithm(): String
        strActual = jwtDecoder.getAlgorithm()
        @Assert(strActual, "none")
        @Assert(token,jwtStr)

        // public func getSignature(): String
        strActual = jwtDecoder.getSignature()
        @Assert(strActual, "")

        // public func getNotBefore(): DateTime
        strActual = jwtDecoder.getNotBefore().toString()
        @Assert(strActual, t2.toString() )
        try {
            // public func getContentType(): String
            strActual = jwtDecoder.getContentType()
        } catch (e1: Exception) {
            println("e1 : ${e1}")
            returnTag = 0
        }

        /* ################################################ */
        // println("token : ${token}")
        jwtBuilder.withHeader(HashMap<String, Any>([(HeaderParams.CONTENT_TYPE, "content_type:jwt")])) //设置CONTENT_TYPE
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder2 = JWTDecoder(jwtStr)
        try {
            strActual = jwtDecoder2.getContentType()
        } catch (e2: Exception) {
            // e2.printStackTrace()
            returnTag = 1
        }
        @Assert(strActual, "content_type:jwt")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithNotBefore_002(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withAudience(["2021-08-05T21:08:04Z"])
        jwtBuilder.withNotBefore(t3)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        @Assert(token,jwtStr)
        try {
            strActual = jwtDecoder.getIssuedAt().toString() //未设置 获取抛异常
        } catch (e1: Exception) {
            // println("e1 : ${e1}")
            @Assert(e1.toString(), "NoneValueException")
            returnTag = 0
        }
        strActual = jwtDecoder.getNotBefore().toString()
        @Assert(strActual, t3.toString() )

        /* ################################################ */
        token = "CnsKICAiazEiOiAidjEiLAogICJraWQiOiAiYWxnb3JpdGhtLmdldFNpZ25pbmdLZXlJZCgpIiwKICAiYWxnIjogIm5vbmUiLAogICJ0eXAiOiAiSldUIiwKICAiY3R5IjogIkpXVCIKfQo.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAxNjczODM1MDkwLAogICJuYmYiOiAxNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiaW50NjQiOiA2NCwKICAiZmxvYXQ2NCI6IDMuMTQwMDAwLAogICJTdHJpbmciOiAiYWJhYWJhIiwKICAidGltZSI6IDE2NzM4NTAwMDAsCiAgIm1hcCI6IHsKICAgICJtazIiOiAibXYyIgogIH0sCiAgImxpc3QiOiBbCiAgICA1Ni41MTAwMDAsCiAgICA0MS45NjAwMDAKICBdLAogICJudWxsIjogbnVsbCwKICAiYXJyYXlzdHJpbmciOiBbCiAgICAiYXN0cjEiLAogICAgImFzdHIyIgogIF0sCiAgImFycmF5aW50IjogWwogICAgNjg0LAogICAgNjQKICBdLAogICJwazEiOiAicHYxIiwKICAicGsyIjogInB2MiIKfQ==."
        let jwtDecoder2 = JWT.decode(token) // public static func decode(token: String): DecodedJWT
        try {
            strActual = jwtDecoder2.getContentType()
        } catch (e2: Exception) {
            // println("e2 : ${e2}")
            returnTag = 1
        }
        @Assert(strActual, "JWT")
        @Assert(returnTag, 0)
    }
}
