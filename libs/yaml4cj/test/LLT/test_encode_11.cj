// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
main() {
    var str: String = ###"{"key: !<%e0%00> "http%3A%2F%2Fbaidu.com"}"###
    var res: Array<UInt8> = str.toArray()
    
    try {
        decode(res)
    }catch(e: Exception) {
        if(!e.toString().contains("yaml: line 1: did not find expected ',' or '}'")) {
            return -1
        }
    }
    return 0
}
