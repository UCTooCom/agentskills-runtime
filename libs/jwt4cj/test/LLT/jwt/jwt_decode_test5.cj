// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

let header = ###"{"alg": "none","typ": "JWT"}"###
let payload = ###"{"k1": "v1"}"###

main() {
    let hb64 = Base64Util.urlEncode(header)
    let pb64 = Base64Util.urlEncode(payload)
    let token = "${hb64}.${pb64}."
    let decoded = JWT().decodeJwt(token)
    if(decoded.getHeader() != hb64){
        return 1
    }
    if(decoded.getPayload() != pb64){
        return 2
    }
    0
}
