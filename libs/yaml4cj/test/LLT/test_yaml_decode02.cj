// DEPENDENCE: empty.yaml
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.env.*
import std.fs.*

main() {
    var path: String = getWorkingDirectory().toString()
    let pathname: String = "${path}/empty.yaml"
    var fs: File = File(pathname, ReadWrite)
    if (fs.canRead()) {
        var res: Array<UInt8> = File.readFrom(pathname)
        fs.close()
        var jv = decode(res)
        if(jv.toString().size == 0) {
                return -1
            }
    } else {
        println("open fail")
    }
    return 0
}
