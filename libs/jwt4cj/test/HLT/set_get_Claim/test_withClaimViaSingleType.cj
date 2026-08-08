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
   public func withClaim(name: String, value: Bool): Builder
   public func withClaim(name: String, value: Int64): Builder
   public func withClaim(name: String, value: Float64): Builder
   public func withClaim(name: String, value: String): Builder
   public func withClaim(name: String, value: Time): Builder
   public func sign(algorithm: Algorithm): String
   public func getToken(): String
   public func getClaim(name: String): Claim
 */
@Test
public class JWTTest {
    var returnTag: Int64 = -1
    var jwtStr: String = ""
    var strActual: String = ""
    let ins_1: SourceData = SourceData()
    let map_String: HashMap<String, Any> = ins_1.generateSourceDataWithString()[2]
    let map_Bool: HashMap<String, Any> = ins_1.generateSourceDataWithBool()[2]
    let entry: (ArrayList<String>, ArrayList<Any>) = ins_1.getMapEntry(map_String)
    let arrStr: Array<String> = [ins_1.s3, ins_1.s4, ins_1.s5, ins_1.s6, ins_1.s7, ins_1.s8, ins_1.s9, ins_1.s10]

    var token = ""
    var t1: DateTime = DateTime.fromUnixTimeStamp(DateTime.now().toUnixTimeStamp().toSeconds()*Duration.second)
    var t2 = DateTime.parse("2021-08-05T21:08:04Z")

    @TestCase
    func testWithClaimViaSingleType_Bool(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withIssuer(entry[0][1]) //中文字符

        // public func withClaim(name: String, value: Bool): Builder
        jwtBuilder.withClaim(arrStr[0], true)
        jwtStr = jwtBuilder.sign(Algorithm.none())

        // println("jwtStr : ${jwtStr}")
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }

        // public func getClaim(name: String): Claim
        strActual = jwtDecoder.getClaim(arrStr[0]).toString()
        @Assert(strActual, "true")

        /* ############################################ */
        jwtStr = jwtBuilder.sign(Algorithm.none()) //二次签名
        let jwtDecoder2 = JWTDecoder(jwtStr)
        strActual = jwtDecoder2.getClaim(arrStr[0]).toString()
        @Assert(strActual, "true")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaSingleType_Int64(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str  
        jwtBuilder.withClaim(arrStr[1], 50324984)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[1]).toString()
        @Assert(strActual, "50324984")

        /* ############################################ */
        jwtBuilder.withClaim(arrStr[1], -64) //重新设置Claim值，name相同
        jwtStr = jwtBuilder.sign(Algorithm.none()) //二次签名
        let jwtDecoder2 = JWTDecoder(jwtStr)
        strActual = jwtDecoder2.getClaim(arrStr[1]).toString()
        @Assert(strActual, "-64")
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaSingleType_String(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str  
        jwtBuilder.withClaim(arrStr[2], arrStr[4])
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        strActual = jwtDecoder.getClaim(arrStr[2]).toString()
        @Assert(strActual, arrStr[4])
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaSingleType_Float64(): Unit {
        returnTag = -1
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool).withIssuer("withIssuer")
        jwtBuilder.withClaim(arrStr[3], -50.324984)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        @Assert(token , jwtStr)
        strActual = jwtDecoder.getClaim(arrStr[3]).toString()
        @Assert(strActual, "-50.324984")
        var tag: Bool = jwtDecoder.getClaim(arrStr[1]).isMissing() // //未设置name为arrStr[1]的Claim值
        if (tag == true) {
            returnTag = 0
        }
        @Assert(returnTag, 0)
    }

    @TestCase
    func testWithClaimViaSingleType_Time(): Unit {
        returnTag = 0
        let jwtBuilder: Builder = JWT.create()
        jwtBuilder.withHeader(map_Bool)
        jwtBuilder.withIssuer(entry[0][4]) //拼接Str  
        jwtBuilder.withClaim(arrStr[5], t2)
        jwtBuilder.withClaim(arrStr[5], t1)
        jwtStr = jwtBuilder.sign(Algorithm.HMAC256("admin"))
        let jwtDecoder = JWTDecoder(jwtStr)
        token = jwtDecoder.getToken()
        if (token != jwtStr) {
            returnTag = 1
        }
        let claim_time = jwtDecoder.getClaim(arrStr[5]).asTime()

        // println("claim_time : ${claim_time}") 
        @Assert(claim_time.toString() , t1.toString())
        @Assert(returnTag, 0)
    }
}
