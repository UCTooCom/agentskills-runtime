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
   public func withExpiresAt(expiresAt: DateTime): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getExpiresAt(): DateTime
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

    // var customPtn = "yyyy/MM/dd HH:mm:ss ZZZZ"
    var customPtn = "yyyy/MM/dd HH:mm:ss OO"
    var t3 = DateTime.parse("2021-08-05T21:08:04+08:00")
    var t4 = DateTime.parse("2023/08/05 21:08:04 +08:00", customPtn).inUTC()

    @TestCase
    func testWithExpiresAt_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withKeyId(entry[0][1]) //中文字符
        jwtBuilder.withAudience(ins_1.convertArrAnyToArrString(arr_Str1))

        // public func withExpiresAt(expiresAt: DateTime): Builder
        jwtBuilder.withExpiresAt(t2) // 2023-08-05T00:00:00+08:00
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }

        // public func getExpiresAt(): DateTime
        strActual = jwtDecoder.getExpiresAt().toString()

        // println("strActual : ${strActual}")
        @Assert(strActual, t2.toString() )
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithExpiresAt_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        try {
            jwtBuilder.withAudience(Array<String>()) //空arr实例
        } catch (e1: Exception) {
            returnTag = 1
        }
        jwtBuilder.withExpiresAt(t4)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = jwtDecoder.getExpiresAt().toString()
        @Assert(strActual, t4.toString() )
        @Assert(returnTag, 0)
    }
}
