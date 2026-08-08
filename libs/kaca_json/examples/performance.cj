package kaca_json.examples

import kaca_json.*

private func buildInput(): String {
    var text = "{\"items\":["
    var i: Int64 = 0
    while (i < 200) {
        if (i > 0) {
            text = text + ","
        }
        text = text + "{\"id\":${i},\"name\":\"item${i}\",\"ok\":true}"
        i++
    }
    text + "]}"
}

main(): Int64 {
    let input = buildInput()

    var strictScore: Int64 = 0
    var fastScore: Int64 = 0

    var i: Int64 = 0
    while (i < 500) {
        strictScore += JSON.parse(input).sizeOrZero()
        i++
    }

    var j: Int64 = 0
    while (j < 500) {
        fastScore += JSON.parseFast(input).toJsonValue().sizeOrZero()
        j++
    }

    println("strict score=${strictScore}")
    println("fast score=${fastScore}")
    0
}
