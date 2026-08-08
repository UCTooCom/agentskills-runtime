package kaca_json.examples

import kaca_json.*

main(): Int64 {
    let input = "{name:'Bob',hex:0x10,list:[1,2,3,],note:'ok'}"
    let value = JSON.parseJson5(input)

    println(JSON.stringify(value))

    match (JSON.pathFirst(value, "$.hex")) {
        case Some(v) => println("hex=${v.requireInt()}")
        case None => println("hex not found")
    }

    0
}
