// DEPENDENCE: test_other_encode.json
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.env.*
import std.collection.*
import std.fs.*
import stdx.encoding.json.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
main() {
    var path: String = getWorkingDirectory().toString()
    let pathname: String = "${path}/test_other_encode.json"
    var fs: File = File(pathname, ReadWrite)
    if (fs.canRead()) {
        var res: String = String.fromUtf8(File.readFrom(pathname))
        fs.close()
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
        var decodeRes: String = decode(encodeRes).toString().replace("\\u0026", "&")
        if(res != decodeRes) {
            return -1
        }

    } else {
        println("open fail")
    }
    return 0
}
