package kaca_json.examples

import kaca_json.*

main(): Int64 {
    let valid = "{foo:'bar', trailing:[1,2,3,], hex:0x10}"
    let invalid = "{foo:}"

    let value = JSON.parseJson5(valid)
    println(JSON.stringify(value, 2))

    match (JSON.parseJson5OrNull(invalid)) {
        case Some(_) => println("unexpected json5 success")
        case None => println("json5 invalid input rejected")
    }

    0
}
