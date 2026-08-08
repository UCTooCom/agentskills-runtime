// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import jwt4cj.*

main() {
    let hmac1 = Algorithm.HMAC256("pri_key")
    let hmac2 = Algorithm.HMAC384("pri_key")
    let hmac3 = Algorithm.HMAC512("pri_key")
    let header: Array<UInt8> = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9".toArray()
    let payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ".toArray()
    var ret: Array<UInt8> = hmac1.sign(header, payload)
    hmac2.sign(header, payload)
    hmac3.sign(header, payload)
    println(Base64Util.urlEncode(ret))
    0
}
