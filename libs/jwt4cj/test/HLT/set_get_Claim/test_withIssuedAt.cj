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
   public func withIssuedAt(issuedAt: DateTime): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getIssuedAt(): DateTime
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
    var t3 = DateTime.parse("2021-08-05T13:08:04Z")
    var t4 = DateTime.parse("2022/02/16 21:08:04 +10:00", customPtn)

    @TestCase
    func testWithIssuedAt_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withKeyId(entry[0][1]) //中文字符
        jwtBuilder.withAudience(ins_1.convertArrAnyToArrString(arr_Str1))
        // public func withIssuedAt(issuedAt: DateTime): Builder
        jwtBuilder.withIssuedAt(t2) // 2023-08-05T00:00:00+08:00
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        // public func getIssuedAt(): DateTime
        strActual = jwtDecoder.getIssuedAt().toString()
        @Assert(strActual, t2.toString() )
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithIssuedAt_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        try {
            jwtBuilder.withAudience(["2021-08-05T21:08:04+08:00"])
        } catch (e1: Exception) {
            returnTag = 1
        }
        jwtBuilder.withIssuedAt(t3)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = jwtDecoder.getIssuedAt().toString()
        @Assert(strActual, t3.toString())
        @Assert(returnTag, 0)
    }
}
