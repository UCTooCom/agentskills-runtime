// 3rd_party_lib:jwt4cj/build/jwt4cj
//dependence:../utils_test/createsourcedata.cj
//data_file:../utils_test/test_rsa_publicKey.pem
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
   public func sign(algorithm: Algorithm): String
   public func getHeader(): String
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var jwtHeader: String = ""
    var strActual: String = ""
    let ins_1: SourceData = SourceData()
    let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2]
    let map_Bool: HashMap<String, Any> = ins_1.generateSourceDataWithBool()[2]
    let map_JsonValue: HashMap<String, Any> = ins_1.generateSourceDataWithJsonValue()[2]
    let map_Time: HashMap<String, Any> = ins_1.generateSourceDataWithTime()[2]
    let map_Cla_1: HashMap<String, Any> = ins_1.generateSourceDataWithCla_1()[2]

    var nj = ins_1.getMapEntry(map_String)

    let path: String = getcwd()

    // let pri_key_rsa: String = "${path}/test_rsa_privateKey.pem"
    // let pub_key_rsa: String = "${path}/../utils_test/test_rsa_publicKey.pem"
    // let pri_key_ecdsa: String = "${path}/test_rsa_privateKey.pem"
    // let pub_key_ecdsa: String = "${path}/test_rsa_publicKey.pem"
    var token: String = ""

    @TestCase
    func testSetHeader_001(): Unit { //
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_String).withHeader(HashMap<String, Any>([("nj[0][1]", "@$饕餮%*")]))

        //public func sign(algorithm: Algorithm): String
        jwtStr = jwtBuilder.sign(Algorithm.none()) //不经过加密,jwtStr以"."结尾
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }

        //public func getHeader(): String
        jwtHeader = jwtDecoder.getHeader()
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)

        // println("strActual : ${strActual}")
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withHeader(HashMap<String, Any>([("map_Bool", "@$饕餮%*" is String)]))
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        jwtHeader = jwtDecoder.getHeader()
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)

        //  println("strActual : ${strActual}")
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_003(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_JsonValue)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC384("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        jwtHeader = jwtDecoder.getHeader()
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)

        //  println("strActual : ${strActual}")
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_004(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Time)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC512("Cangjie"))
        let jwtDecoder = JWTDecoder(jwtStr)
        jwtHeader = jwtDecoder.getHeader()
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_005(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        try {
            jwtBuilder.withHeader(map_Cla_1)
            jwtStr = jwtBuilder.sign(Algorithm.HMAC512("Cangjie"))
        } catch (e1: Exception) {
            println("e1: ${e1}")
            @Assert(e1.toString().contains("value type not support"), true)
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_006(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        try {
            jwtBuilder.withHeader(HashMap<String, Any>([("map_Int64_1", -2654648), ("map_Int64_2", 235654841)]))
        } catch (e1: Exception) {
            returnTag = 1
        }
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        jwtHeader = jwtDecoder.getHeader()
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_007(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        try {
            jwtBuilder.withHeader(HashMap<String, Any>([("map_Float64_1", -2.654648), ("map_Float64_2", 23.5654841)]))
        } catch (e1: Exception) {
            println("e1: ${e1}")
            returnTag = 1
        }
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        jwtHeader = jwtDecoder.getHeader()
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_008(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        let map_Array_String: Array<Any> = ins_1.generateSourceDataWithString()[0] //Array<String>
        try {
            jwtBuilder.withHeader(HashMap<String, Any>([("map_Array<String>", map_Array_String)]))
            jwtStr = jwtBuilder.sign(Algorithm.HMAC384("admin"))
        } catch (e1: Exception) {
            println("e1: ${e1}")
            returnTag = 1
        }
        let jwtDecoder = JWTDecoder(jwtStr)
        jwtHeader = jwtDecoder.getHeader()
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_009(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        let map_ArrayList_String: ArrayList<Any> = ins_1.generateSourceDataWithString()[1] //ArrayList<String>
        let map_ArrayList_D2_String: ArrayList<Any> = ArrayList<Any>([map_ArrayList_String, map_ArrayList_String])
        try {
            jwtBuilder.withHeader(HashMap<String, Any>([("map_ArrayList<ArrayList<String>>", map_ArrayList_D2_String)]))
            jwtStr = jwtBuilder.sign(Algorithm.HMAC384("admin"))
        } catch (e1: Exception) {
            println("e1: ${e1}")
            returnTag = 1
        }
        let jwtDecoder = JWTDecoder(jwtStr)
        jwtHeader = jwtDecoder.getHeader()
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testSetHeader_0010(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2] //HashMap<String, Any>
        let map_map_D2_String: HashMap<String, Any> = HashMap<String, Any>(
            [("map_String_D2_1", map_String), ("map_String_D2_2", map_String)])
        try {
            jwtBuilder.withHeader(HashMap<String, Any>([("map_map_D3_String", map_map_D2_String)]))
            jwtStr = jwtBuilder.sign(Algorithm.HMAC384("admin"))
        } catch (e1: Exception) {
            println("e1: ${e1}")
            returnTag = 1
        }
        let jwtDecoder = JWTDecoder(jwtStr)
        jwtHeader = jwtDecoder.getHeader()
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = ins_1.getClaimData(Enu_JWT.HEADER, jwtStr)
        @Assert(jwtHeader, strActual)
        @Assert(returnTag, 0)
    }
}
