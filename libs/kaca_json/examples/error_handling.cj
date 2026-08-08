package kaca_json.examples

import kaca_json.*

main(): Int64 {
    let valid = "{\"ok\":true}"
    let invalid = "{invalid}"

    let fromText = JSON.parseOrNull(valid)
    match (fromText) {
        case Some(_) => println("parseOrNull(text): success")
        case None => println("parseOrNull(text): failed")
    }

    let bytes = unsafe { valid.rawData() }
    let fromBytes = JSON.parse(bytes)
    println("parse(bytes) -> ${JSON.stringify(fromBytes)}")

    match (JSON.parseOrNull(invalid)) {
        case Some(_) => println("unexpected success")
        case None => println("invalid json rejected")
    }

    try {
        JSON.parse(invalid)
        println("unexpected parse success")
    } catch (_: Exception) {
        println("parse throws on invalid input")
    }

    0
}
