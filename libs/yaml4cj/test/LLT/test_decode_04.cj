// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
main() {
    var str: Array<UInt8> = "\u{fe}\u{ff}\u{00}\u{f1}\u{00}o\u{00}\u{f1}\u{00}o\u{00}fsaf\u{00}".toArray()

    try {
        decode(str)
    }catch(e: Exception) {
        if(!e.toString().contains("yaml: control characters are not allowed")) {
            return -1
        }
        return 0
    }

    return -2
}
