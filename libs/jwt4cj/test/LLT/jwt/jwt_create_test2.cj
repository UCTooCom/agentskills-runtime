// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main() {
    if (!f1()) {
        return 1
    }
    if (!f2()) {
        return 2
    }
    if (!f3()) {
        return 3
    }

    0
}
func f1() {
    let map: HashMap<String, Any> = HashMap()
    map.add("any", C())
    try {
        JWT.create().withClaim("map", map).sign(Algorithm.none())
    } catch (e: IllegalArgumentException) {
        return true
    }
    false
}
func f2() {
    let arr: ArrayList<Any> = ArrayList()
    arr.add(C())
    try {
        JWT.create().withClaim("arr", arr).sign(Algorithm.none())
    } catch (e: IllegalArgumentException) {
        return true
    }
    false
}
func f3() {
    let map: HashMap<String, Any> = HashMap()
    map.add("any", C())
    try {
        JWT.create().withPayload(map).sign(Algorithm.none())
    } catch (e: IllegalArgumentException) {
        return true
    }
    false
}
class C {}
