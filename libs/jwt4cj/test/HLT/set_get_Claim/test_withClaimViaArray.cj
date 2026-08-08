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
   public func withArrayClaim(name: String, items: Array<String>): Builder
   public func withArrayClaim(name: String, items: Array<Int64>): Builder
   public func withNullClaim(name: String): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getClaim(name: String): Claim
   public func getClaims(): Map<String, Claim>
   public func getHeaderClaim(name: String): Claim
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var strActual: String = ""
    let ins_1: SourceData = SourceData()
    let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2]
    let arrL_Bool: ArrayList<Any> = ins_1.generateSourceDataWithBool()[1]
    let entry: (ArrayList<String>, ArrayList<Any>) = ins_1.getMapEntry(map_String)
    let arrStr: Array<String> = [ins_1.s3, ins_1.s4, ins_1.s5, ins_1.s6, ins_1.s7, ins_1.s8, ins_1.s9, ins_1.s10]
    var claimMap: Map<String, Claim> = HashMap<String, Claim>()
    var token = ""

    @TestCase
    func testWithClaimViaArray_001(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        jwtBuilder.withArrayClaim(arrStr[0], arrStr) // arr_String:Array<String> 
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual.toRuneArray().size, 250)
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss\"Hello Cangjie Lang\"")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaArray_002(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        jwtBuilder.withKeyId(entry[0][5])
        jwtBuilder.withArrayClaim(arrStr[1], [12, 98948465, -2654]) // arr_String:Array<Int64> 
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        @Assert(token,jwtStr)
        strActual = jwtDecoder.getClaim(arrStr[1]).toString()
        @Assert(strActual, "[12,98948465,-2654]")
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        var res: Int64 = 0
        for ((k, v) in claimMap) {
            strActual += k
            if (k == arrStr[1]) {
                res = v.toString().size
            }
        }
        @Assert(res,19)
        strActual = jwtDecoder.getHeaderClaim("kid").toString()
        @Assert(strActual.toRuneArray().size, 95)
        var tag: Bool = jwtDecoder.getHeaderClaim(entry[0][5]).isMissing() // name:entry[0][5] 不存在
        if (tag == true) {
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaArray_003(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符
        jwtBuilder.withArrayClaim(arrStr[0], Array<Int64>()) // Kong arr 
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        @Assert(token, jwtStr)
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual, "[]")
        claimMap = jwtDecoder.getClaims() //Map<String, Claim>
        strActual = ""
        for (k in claimMap.keys()) {
            strActual += k
        }
        @Assert(strActual, "iss\"Hello Cangjie Lang\"")

        /* ########################################### */
        jwtBuilder.withArrayClaim(arrStr[0], Array<Int64>(521239, repeat: 110)) // Kong arr 
        jwtBuilder.withJWTId("withJWTId_Payload") // 设置Payload 的Claim对象
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder2 = JWTDecoder(jwtStr)
        strActual = jwtDecoder2.getClaim(arrStr[0]).toString()
        @Assert(strActual.toRuneArray().size, 2084957)
        var tag: Bool = jwtDecoder2.getHeaderClaim(RegisteredClaims.JWT_ID).isMissing() //JWT_ID为 Payload 的Claim对象，getHeaderClaim的name无对应的HeaderClaim
        if (tag == true) {
            returnTag = 0
        }
        /* ########################################### */
        jwtBuilder.withHeader(HashMap<String, Any>([(HeaderParams.CONTENT_TYPE, "content_type:jwt")])) //设置CONTENT_TYPE
        jwtStr = jwtBuilder.sign(Algorithm.none())
        let jwtDecoder3 = JWTDecoder(jwtStr)
        strActual = jwtDecoder3.getHeaderClaim(HeaderParams.CONTENT_TYPE).toString()
        @Assert(strActual, "content_type:jwt")
        @Assert(returnTag, 0)
    }
}
