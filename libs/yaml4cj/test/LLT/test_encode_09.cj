// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
main() {
    var str: String = ###"{:"-"}"###
    var res: Array<UInt8> = str.toArray()
    try {
        decode(res)
    }catch(e: Exception) {
        if(!e.toString().contains("yaml: did not find expected node content")) {
            return -1
        }
    }
    return 0
}
