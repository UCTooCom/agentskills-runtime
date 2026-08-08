package kaca_json.examples

import kaca_json.*

main(): Int64 {
    let input = "{\"user\":{\"name\":\"cj\",\"age\":3},\"active\":true}"
    let value = JSON.parse(input)

    let name = JSON.pathFirst(value, "$.user.name")
    match (name) {
        case Some(v) => println("name=${v.requireString()}")
        case None => println("name not found")
    }

    println(JSON.stringify(value, 2))
    0
}
