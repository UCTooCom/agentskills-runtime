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
   public func withJWTId(jwtId: String): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getId(): String
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var jwtProp: String = ""
    let ins_1: SourceData = SourceData()
    let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2]
    let map_Bool: HashMap<String, Any> = ins_1.generateSourceDataWithBool()[2]
    let entry: (ArrayList<String>, ArrayList<Any>) = ins_1.getMapEntry(map_String)

    var token = ""
    @TestCase
    func testWithSubject_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        // public func withJWTId(jwtId: String): Builder
        jwtBuilder.withJWTId("\"Hello Cangjie \nLang\"") //转义字符 
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        // public func getId(): String
        jwtProp = jwtDecoder.getId()
        @Assert(jwtProp, "\"Hello Cangjie \nLang\"")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithSubject_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withIssuer( //拼接Str
                    entry[0][5])
        jwtBuilder.withJWTId("") //空字符   
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        jwtProp = jwtDecoder.getId()
        @Assert(jwtProp, "")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithSubject_003(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withSubject("$%^&^(*&)(#@#@|||<>)") //特殊字符   
            .withJWTId("$%^&^(*&)(#@#@|||<>)") //特殊字符   
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        jwtProp = jwtDecoder.getId()
        @Assert(jwtProp, "$%^&^(*&)(#@#@|||<>)")
        @Assert(returnTag, 0)
    }
}
