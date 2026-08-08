// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main(){
    let jwtStr = JWT.create()
        .withClaim("JsonInt", JsonInt(11))
        .withClaim("JsonBool", JsonBool(true))
        .withClaim("JsonFloat", JsonFloat(1.1))
        .withClaim("JsonString", JsonString("str"))
        .withClaim("JsonArray", JsonArray([JsonString("str"), JsonInt(11), JsonFloat(1.1)]))
        .withClaim("JsonObject", JsonObject(HashMap<String, JsonValue>([("k1", JsonString("v1"))])))
        .sign(Algorithm.none())
    println(jwtStr)

    let map = JWTDecoder(jwtStr).getClaims()
    for ((k,v) in map) {
        println("${k}: ${v}")
    }
    0
}
