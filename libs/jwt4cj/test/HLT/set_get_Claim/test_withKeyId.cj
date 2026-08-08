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
   public func withKeyId(keyId: String): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getKeyId(): String
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var keyId: String = ""
    let ins_1: SourceData = SourceData()
    let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2]
    let map_Bool: HashMap<String, Any> = ins_1.generateSourceDataWithBool()[2]
    let entry: (ArrayList<String>, ArrayList<Any>) = ins_1.getMapEntry(map_String)

    var token = ""
    @TestCase
    func testWithKeyId_001(): Unit { //
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        // public func withKeyId(keyId: String): Builder
        jwtBuilder.withKeyId(entry[0][1]) //中文字符
        jwtStr = jwtBuilder.sign(Algorithm.none()) //不经过加密,jwtStr以"."结尾
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        // public func getKeyId(): String
        keyId = jwtDecoder.getKeyId()
        @Assert(keyId, entry[0][1])
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithKeyId_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withKeyId("\"Hello Cangjie \nLang\"") //转义字符   

        //public func sign(algorithm: Algorithm): String
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        keyId = jwtDecoder.getKeyId()
        var str_base: String = "\"Hello Cangjie \nLang\""
        @Assert(keyId, str_base)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithKeyId_003(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withKeyId("") //空字符   
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        keyId = jwtDecoder.getKeyId()
        var str_base: String = ""
        @Assert(keyId, str_base)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithKeyId_004(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withKeyId("$%^&^(*&)(#@#@|||<>)") //特殊字符   
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        keyId = jwtDecoder.getKeyId()
        var str_base: String = "$%^&^(*&)(#@#@|||<>)"
        @Assert(keyId, str_base)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithKeyId_005(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withKeyId(entry[0][2]) //多行  
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        keyId = jwtDecoder.getKeyId()
        @Assert(keyId, entry[0][2])
        jwtBuilder.withKeyId(entry[0][3]) //多行原始
        keyId = jwtDecoder.getKeyId() //未重新签名，jwtDecoder实例未变更，KeyId为旧值
        @Assert(keyId, entry[0][2])

        //重新签名
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder2 = JWTDecoder(jwtStr)
        keyId = jwtDecoder2.getKeyId()
        @Assert(keyId, entry[0][3])
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithKeyId_006(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withKeyId( //拼接Str
                                entry[0][4]).withKeyId(entry[0][5]) //连续设置keyId
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        keyId = jwtDecoder.getKeyId()
        @Assert(keyId, entry[0][5])
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithKeyId_007(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        var str_base: String = ins_1.generateString(10000)
        jwtBuilder.withHeader(map_Bool).withKeyId(str_base) //超长str
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        keyId = jwtDecoder.getKeyId()
        @Assert(keyId, str_base)
        @Assert(returnTag, 0)
    }
}
