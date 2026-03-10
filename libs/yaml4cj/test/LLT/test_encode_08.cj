// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
main() {
    var str: String = ###"{key: !<%f8> "http%3A%2F%2Fbaidu.com"}"###
    var res: Array<UInt8> = str.toArray()

    try {
        decode(res)
    }catch(e: Exception) {
        if(!e.toString().contains("yaml: found an incorrect leading UTF-8 octet")) {
            return -1
        }
    }
   
    return 0
}
