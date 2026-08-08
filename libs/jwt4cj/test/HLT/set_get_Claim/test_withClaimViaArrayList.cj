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
   public func withClaim(name: String, list: ArrayList<Any>): Builder
   public func withNullClaim(name: String): Builder
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
    let arrL_String: ArrayList<Any> = ins_1.generateSourceDataWithString()[1]
    let arrL_Bool: ArrayList<Any> = ins_1.generateSourceDataWithBool()[1]
    let arrL_JsonValue: ArrayList<Any> = ins_1.generateSourceDataWithJsonValue()[1]
    let arrL_Time: ArrayList<Any> = ins_1.generateSourceDataWithTime()[1]
    let arrL_Cla_1: ArrayList<Any> = ins_1.generateSourceDataWithCla_1()[1]

    let entry: (ArrayList<String>, ArrayList<Any>) = ins_1.getMapEntry(map_String)
    let arrStr: Array<String> = [ins_1.s3, ins_1.s4, ins_1.s5, ins_1.s6, ins_1.s7, ins_1.s8, ins_1.s9, ins_1.s10]
    var claimMap: Map<String, Claim> = HashMap<String, Claim>()
    var token = ""
    var t1: DateTime = DateTime.now()
    var t2 = DateTime.parse("2021-08-05T21:08:04+08:00")

    @TestCase
    func testWithClaimViaArrayList_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        // public func withClaim(name: String, list: ArrayList<Any>): Builder
        jwtBuilder.withClaim(arrStr[0], arrL_String) // arrL_String:ArrayList<Any>
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual.toRuneArray().size, 406)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss\"Hello Cangjie Lang\"")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaArrayList_002(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        // public func withClaim(name: String, list: ArrayList<Any>): Builder
        jwtBuilder.withClaim(arrStr[0], arrL_Bool) // arrL_Bool:ArrayList<Any>
        jwtBuilder.withClaim(arrStr[1], arrL_JsonValue) // arrL_JsonValue:ArrayList<Any>
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual, "[true,false,true,false]")
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[1]) {
                str_1 = v.toString()
            }
        }
        println(arrStr[1])
        println(str_1)
        println(str_1.size)
        println((arrL_JsonValue as ToString)?.toString().size)
        @Assert(str_1.size,172-11)
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaArrayList_003(): Unit {
        returnTag = -1
        strActual = ""
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        jwtBuilder.withClaim(arrStr[0], arrL_Time) // arrL_Time:ArrayList<Any>
        try {
            jwtBuilder.withClaim(arrStr[2], arrL_Cla_1) // arrL_Cla_1:ArrayList<Any>
        } catch (e1: Exception) {
            @Assert(e1.toString(), "IllegalArgumentException: Expected list containing Map, List, Bool, Int64, Float64, String and Time")
            returnTag = 0
        }
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual.size, 45)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        @Assert(claimMap.size,2) // name为 arrStr[2]时异常
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[2]) {
                str_1 = v.toString()
            }
        }
        @Assert(str_1.size,0)
        @Assert(strActual,"iss\"Hello Cangjie Lang\"")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaArrayList_004(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        let arr_Int64: Array<Int64> = [12, -236, 598144] //Array<Int64>
        let arrL_Float64: ArrayList<Any> = ArrayList<Any>([0.0012, -2.36, 598.144]) //ArrayList<Float64>
        try {
            jwtBuilder.withClaim(arrStr[0], ArrayList<Any>([arr_Int64, arr_Int64])) // arrL_:ArrayList<Array<Any>>
        } catch (e1: Exception) {
            returnTag = 1
        }
        try {
            jwtBuilder.withClaim(arrStr[2], ArrayList<Any>([arrL_Float64, arrL_Float64])) // arrL_ArrayList<ArrayList<Any>>
        } catch (e2: Exception) {
            returnTag = 2
        }
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 3
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual, "[[12,-236,598144],[12,-236,598144]]")
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[2]) {
                str_1 = v.toString()
            }
        }
        @Assert(str_1,"[[0.0012,-2.36,598.144],[0.0012,-2.36,598.144]]")
        @Assert(strActual,"iss\"Hello Cangjie Lang\"你好仓颉！【】")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaArrayList_005(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2] //HashMap<String, Any>
        let map_map_D2_String: HashMap<String, Any> = HashMap<String, Any>(
            [("map_String_D2_1", map_String), ("map_String_D2_2", map_String)])
        try {
            jwtBuilder.withClaim(arrStr[0], ArrayList<Any>([map_map_D2_String])) // arrL_:ArrayList<HashMap<String, HashMap<String, Any>>>
        } catch (e1: Exception) {
            returnTag = 1
        }
        try {
            jwtBuilder.withNullClaim(arrStr[2])
        } catch (e2: Exception) {
            returnTag = 2
        }
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 3
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual.toRuneArray().size, 1469)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var str_1 = ""
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[2]) {
                str_1 = v.toString()
            }
        }
        @Assert(str_1,"null")
        @Assert(strActual,"iss\"Hello Cangjie Lang\"你好仓颉！【】")
        @Assert(returnTag, 0)
    }
}
