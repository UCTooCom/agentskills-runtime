// DEPENDENCE: test_tag.yaml
// DEPENDENCE: test_tag01.yaml
// DEPENDENCE: test_tag02.yaml
// DEPENDENCE: test_tag03.yaml
// DEPENDENCE: test_tag04.yaml
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.env.*
import std.collection.*
import std.fs.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
main() {
    var path: String = getWorkingDirectory().toString()
    var arr: Array<String> = [
        "${path}/test_tag.yaml",
        "${path}/test_tag01.yaml",
        "${path}/test_tag02.yaml",
        "${path}/test_tag03.yaml",
        "${path}/test_tag04.yaml"
        ]
    
    for(i in 0..arr.size) {
        var fs: File = File(arr[i], ReadWrite)
        if (fs.canRead()) {
            var res = File.readFrom(arr[i])
            fs.close()
            var jv = decode(res)
            if(jv.toString().size == 0) {
                return -1
            }

        } else {
            println("open fail")
        }
    }
  
    return 0
}
