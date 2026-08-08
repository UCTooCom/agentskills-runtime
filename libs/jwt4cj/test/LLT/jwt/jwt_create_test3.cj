// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main() {
    let map = HashMap<String, Any>()
    let m1: Map<String, Any> = HashMap()
    m1.add("1","11")
    map.add("m1", m1)
    let token = JWT.create().withClaim("map", map).sign(Algorithm.none())
    println(token)
    0
}
