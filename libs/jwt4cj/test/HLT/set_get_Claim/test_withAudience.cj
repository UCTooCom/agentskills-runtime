// DEPENDENCE: ../utils_test/createsourcedata.cj
// EXEC: cjc %import-path %L %l %f createsourcedata.cj --test
// EXEC: export cjHeapSize=1GB && ./main
internal import jwt4cj.*
internal import stdx.encoding.hex.*
internal import std.unittest.*
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import std.fs.*

/**
   public static func create(): Builder
   public func withAudience(audience: Array<String>): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getAudience(): ArrayList<String>
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
    @TestCase
    func testWithAudience_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withKeyId(entry[0][1]) //中文字符
        //public func withAudience(audience: Array<String>): Builder
        jwtBuilder.withAudience(ins_1.convertArrAnyToArrString(arr_Str1))
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        // public func getAudience(): ArrayList<String>
        strActual = jwtDecoder.getAudience()[0]
        @Assert(strActual, "\"Hello Cangjie Lang\"你好仓颉！【】" )
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithAudience_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        try {
            jwtBuilder.withAudience(Array<String>()) //空arr实例
        } catch (e1: Exception) {
            returnTag = 1
        }
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        let arrLStr: ArrayList<String> = jwtDecoder.getAudience()
        @Assert(arrLStr.size, 0)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithAudience_003(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withAudience(ins_1.getRandomStrArr(999999)) //超长Arrstr
        jwtStr = jwtBuilder.sign(Algorithm.HMAC512("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        let arrLStr: ArrayList<String> = jwtDecoder.getAudience()
        @Assert(arrLStr.size, 999999)
        @Assert(returnTag, 0)
    }
}
