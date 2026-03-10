// DEPENDENCE: test_all.json
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
import yaml4cj.yaml.*
import stdx.encoding.json.*
import std.collection.*

main () {
    let jsonValue = JsonObject(HashMap<String, JsonValue>([("strKey", JsonString("strValue")), ("intKey", JsonInt(1008))]))
    let data = encode(jsonValue)
    println(String.fromUtf8(data))
}

