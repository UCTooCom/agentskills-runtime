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
   public func withClaim(name: String, map: Map<String, Any>): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getClaim(name: String): Claim
   public func getClaims(): Map<String, Claim>
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var strActual: String = ""
    let ins_1: SourceData = SourceData()
    let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2]
    let map_Bool: HashMap<String, Any> = ins_1.generateSourceDataWithBool()[2]
    let map_JsonValue: HashMap<String, Any> = ins_1.generateSourceDataWithJsonValue()[2]
    let map_Time: HashMap<String, Any> = ins_1.generateSourceDataWithTime()[2]
    let map_Cla_1: HashMap<String, Any> = ins_1.generateSourceDataWithCla_1()[2]

    let entry: (ArrayList<String>, ArrayList<Any>) = ins_1.getMapEntry(map_String)
    let arrStr: Array<String> = [ins_1.s3, ins_1.s4, ins_1.s5, ins_1.s6, ins_1.s7, ins_1.s8, ins_1.s9, ins_1.s10]
    var claimMap: Map<String, Claim> = HashMap<String, Claim>()
    var token = ""
    var t1: DateTime = DateTime.now()
    var t2 = DateTime.parse("2021-08-05T21:08:04+08:00")

    @TestCase
    func testWithClaimViaMap_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        jwtBuilder.withClaim(arrStr[0], map_String) //map_String:HashMap<String, Any>
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual.toRuneArray().size, 714)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss\"Hello Cangjie Lang\"")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str
        jwtBuilder.withClaim(arrStr[0], map_Bool) // map_Bool:HashMap<String, Any>
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual.toRuneArray().size, 194)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss\"Hello Cangjie Lang\"")
        /* ############################################ */
        jwtBuilder.withClaim(arrStr[0], HashMap<String, Any>([("map_Bool", "@$饕餮%*" is String)])) //重新设置Claim值，name相同
        jwtStr = jwtBuilder.sign(Algorithm.none()) //二次签名
        let jwtDecoder2 = JWTDecoder(jwtStr)
        strActual = jwtDecoder2.getClaim(arrStr[0]).toString()
        @Assert(strActual, "{\"map_Bool\":true}")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_003(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str
        jwtBuilder.withClaim("", map_JsonValue) // map_JsonValue:HashMap<String, Any> & name 为空str
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim("iss").toString()
        @Assert(strActual, "\"Hello Cangjie Lang\"你好仓颉！【】")
        strActual = jwtDecoder.getClaim("").toString()
        println(strActual)
        @Assert(strActual.toRuneArray().size, 466-4-3-4-4-3-4)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_004(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str
        jwtBuilder.withClaim(arrStr[2], map_Time) // map_Time:HashMap<String, Any>
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        @Assert(strActual.toRuneArray().size, 215)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for (k in claimMap.keys()) {
            strActual += k
            if (k == "iss") {
                str_1 = claimMap[k].toString()
            }
        }
        @Assert(str_1, "\"Hello Cangjie Lang\"你好仓颉！【】")
        @Assert(strActual, "iss你好仓颉！【】")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_005(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str
        try {
            jwtBuilder.withClaim(arrStr[2], map_Cla_1) // map_Cla_1:HashMap<String, Any>
        } catch (e1: Exception) {
            @Assert(e1.toString(), "IllegalArgumentException: Expected map containing Map, List, Bool, Int64, Float64, String and Time")
            returnTag = 0
        }
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        try {
            strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        } catch (e2: Exception) {
            @Assert(e2.toString(),"Exception: The Claim is not present in the JWT.")
            returnTag = 0
        }
        try {
            claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        } catch (e3: Exception) {
            returnTag = 3
        }
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_006(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str
        jwtBuilder.withClaim(arrStr[2], HashMap<String, Any>([("map_Int64_1", -2654648), ("map_Int64_2", 235654841)]))
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        @Assert(strActual.toRuneArray().size, 48)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[2]) {
                str_1 += v.toString()
            }
        }
        @Assert(str_1, "{\"map_Int64_1\":-2654648,\"map_Int64_2\":235654841}")
        @Assert(strActual, "iss你好仓颉！【】")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_007(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str
        jwtBuilder.withClaim(arrStr[2], HashMap<String, Any>([("map_Float64_1", -2.654648), ("map_Float64_2", 23.5654841)]
        ))
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        @Assert(strActual.toRuneArray().size, 53)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[2]) {
                str_1 += v.toString()
            }
        }
        @Assert(str_1, "{\"map_Float64_1\":-2.654648,\"map_Float64_2\":23.565484}")
        @Assert(strActual, "iss你好仓颉！【】")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_008(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str
        let map_ArrayL_Int64: ArrayList<Any> = ArrayList<Any>([12, -236, 598144]) //Array<Int64>
        jwtBuilder.withClaim(arrStr[2], HashMap<String, Any>([("map_ArrayList<Int64>", map_ArrayL_Int64)]))
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        @Assert(strActual.size, 41)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[2]) {
                str_1 += v.toString()
            }
        }
        @Assert(str_1, "{\"map_ArrayList<Int64>\":[12,-236,598144]}")
        @Assert(strActual, "iss你好仓颉！【】")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_009(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str  
        let map_Array_Int64: Array<Int64> = [12, -236, 598144] //Array<Int64>
        try {
            jwtBuilder.withClaim(arrStr[2], HashMap<String, Any>([("map_Array<Int64>", map_Array_Int64)]))
        } catch (e1: Exception) {
            e1.printStackTrace()
            returnTag = 1
        }
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        @Assert(strActual.toRuneArray().size, 37)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[2]) {
                str_1 += v.toString()
            }
        }
        @Assert(str_1, "{\"map_Array<Int64>\":[12,-236,598144]}")
        @Assert(strActual, "iss你好仓颉！【】")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaMap_010(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str  
        let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2] //HashMap<String, Any>
        let map_map_D2_String: HashMap<String, Any> = HashMap<String, Any>(
            [("map_String_D2_1", map_String), ("map_String_D2_2", map_String)])
        try {
            jwtBuilder.withClaim(arrStr[2], HashMap<String, Any>([("map_map_D3_String", map_map_D2_String)]))
        } catch (e1: Exception) {
            returnTag = 1
        }
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 2
        }
        strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        @Assert(strActual.toRuneArray().size, 1489)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss你好仓颉！【】")

        /* ############################################### */
        try {
            jwtBuilder.withClaim(arrStr[2], HashMap<String, Any>()) // 空map
        } catch (e2: Exception) {
            returnTag = 3
        }
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder2 = JWTDecoder(jwtStr)
        strActual = jwtDecoder2.getClaim(arrStr[2]).toString()
        @Assert(strActual, "{}")
        claimMap = jwtDecoder2.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss你好仓颉！【】")
        @Assert(returnTag, 0)
    }
}
