// DEPENDENCE: emitter.json
// DEPENDENCE: emitter2.json
// DEPENDENCE: emitter3.json
// DEPENDENCE: emitter4.json
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import std.collection.*
import stdx.encoding.json.*

main() {
    var path: String = getWorkingDirectory().toString()
    var arr: Array<String> = [
        "${path}/emitter.json"
        //"${path}/emitter2.json",
        //"${path}/emitter3.json",
        //"${path}/emitter4.json"
    ]

    for (i in 0..arr.size) {
        var fs: File = File(arr[i], ReadWrite)
        if (fs.canRead()) {
            var res: String = String.fromUtf8(File.readFrom(arr[i]))
            fs.close()
            var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
            var decodeRes: String = decode(encodeRes).toString()
            println("原：----------------${res}")
            println("JsonValue.fromStr():${JsonValue.fromStr(res).toString()}")
            println("后：----------------${decodeRes}")
            if (res != decodeRes) {
                return 1
            }
        } else {
            println("open fail")
        }
    }

    return 0
}
