// 3rd_party_lib:jwt4cj/build/jwt4cj
// 3rd_party_lib:jwt4cj/ci_lib/crypto4cj

internal import jwt4cj.*

internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import std.fs.*
internal import secodeFuzz.*
internal import std.unittest.*
import std.unittest.testmacro.*
internal import std.collection.ArrayList


func call_fuzz(name:String){
    let jwtBuilder :Builder = JWT.create()
    jwtBuilder.withClaim(name,true)
    var jwtStr = jwtBuilder.sign(Algorithm.none()) 
    let jwtDecoder = JWTDecoder(jwtStr)
    // public func getClaim(name: String): Claim
    jwtDecoder.getClaim(name)
    return
}

func unboundTest():Unit{
    var case_name = CString("Fuzz_JWTDecoder.getClaim")
    unsafe{
        DT_FUZZ_String(0,30000000,case_name,0,call_fuzz)
        case_name.free()
    }
}

main(){
    unboundTest()
    return
}