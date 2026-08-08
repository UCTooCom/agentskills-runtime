package kaca_json.examples

import std.collection.*
import kaca_json.*

main(): Int64 {
    let source = JsonValue.JsonObject(HashMap<String, JsonValue>())
    source.put("name", "cj")
    source.put("age", 1)

    let tags = JsonValue.JsonArray(ArrayList<JsonValue>())
    tags.push("json")
    tags.push("strict")
    source.put("tags", tags)

    let ops = JsonPatch.createList()
    ops.add(JsonPatch.replace("/age", JsonValue.JsonNumber(2.0)))
    ops.add(JsonPatch.add("/active", JsonValue.JsonBool(true)))

    let patched = JsonPatch.apply(source, ops)
    println(JSON.stringify(patched, 2))
    0
}
