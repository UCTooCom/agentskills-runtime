// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main() {
    let token = JWT.create().withClaim("iat", "123").sign(Algorithm.none())
    try {
        let d = JWT.decode(token)
        println(d.getIssuedAt())
    } catch (e: JWTDecodeException) {
        if (e.message == "The claim 'iat' is not time.") {
            return 0
        }
        e.printStackTrace()
    }
    1
}
