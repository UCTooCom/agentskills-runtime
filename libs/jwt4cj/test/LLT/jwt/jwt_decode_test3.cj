// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

let header = ###"{"alg": "none","typ": "JWT"}"###
let payload = ###"{"k1": "v1"}"###

main() {
    let wrong = header + "}"
    let headerB64 = Base64Util.urlEncode(wrong)
    let payloadB64 = Base64Util.urlEncode(payload)
    let token = "${headerB64}.${payloadB64}."
    try {
        JWT.decode(token)
    } catch (e: JWTDecodeException) {
        println(e.message)
        if (e.message == "The string '${wrong}' doesn't have a valid JSON format.") {
            return 0
        }
    }
    1
}
