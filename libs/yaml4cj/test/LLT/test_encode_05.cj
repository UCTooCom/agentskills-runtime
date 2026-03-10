// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
main() {
    var str: String = ###"{key: !<%00> "http%3A%2F%2Fbaidu.com"}"###
    var res: Array<UInt8> = str.toArray()
    var jv = decode(res)

    if(jv.toString() != "{\"key\":\"http%3A%2F%2Fbaidu.com\"}") {
        return -1
    }
   
    return 0
}
