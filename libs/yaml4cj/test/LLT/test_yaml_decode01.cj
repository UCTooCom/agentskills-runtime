// DEPENDENCE: testunknownnode.yaml
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.env.*
import std.fs.*

main() {
    var path: String = getWorkingDirectory().toString()
    let pathname: String = "${path}/testunknownnode.yaml"
    var fs: File = File(pathname, ReadWrite)
    if (fs.canRead()) {
        var res: Array<UInt8> = File.readFrom(pathname)
        fs.close()
        try{
            var jv = decode(res)
        }catch(e: Exception) {
            println(e.toString())
            return 0
        }
    } else {
        println("open fail")
    }
    return 1
}
