// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main() {
    let map = HashMap<String, Any>()

    // let m1: Map<String, Any> = HashMap()
    // m1.add("1", "11")
    // map.add("m1", m1)
    let nullNode: JsonValue = JsonNull()
    let a2 = ArrayList<Any>(["asd", true, 1, 3.14, DateTime.ofEpoch(second: 1673835090, nanosecond: 0), nullNode, JsonValue.fromStr(##""jsonstring""##)]
    )
    map.add("a2", a2)
    map.add("", nullNode)
    let token = JWT.create().withClaim("map", map).sign(Algorithm.none())
    println(token)
    0
}
