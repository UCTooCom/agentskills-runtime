// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
main() {
    var str: String = ###"{key: !<%ZZ> "http%3A%2F%2Fbaidu.com"}"###
    var res: Array<UInt8> = str.toArray()

    try {
        decode(res)
    }catch(e: Exception) {
        if(!e.toString().contains("yaml: did not find URI escaped octet")) {
            return -2
        }
        return 0
    }

    return -1
}
