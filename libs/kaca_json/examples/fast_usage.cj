package kaca_json.examples

import kaca_json.*

main(): Int64 {
    let input = "{\"items\":[1,2,3],\"meta\":{\"ok\":true}}"

    let fast = JSON.parseFast(input)
    let value = fast.toJsonValue()
    println(JSON.stringify(value))

    let bytes = unsafe { input.rawData() }
    let valueFromBytes = JSON.parseFast(bytes).toJsonValue()
    match (JSON.pathFirst(valueFromBytes, "$.items[0]")) {
        case Some(v) => println("first item=${v.requireInt()}")
        case None => println("first item not found")
    }

    match (JSON.parseFastOrNull("{\"items\":")) {
        case Some(_) => println("unexpected fast success")
        case None => println("fast parser rejected invalid input")
    }

    0
}
