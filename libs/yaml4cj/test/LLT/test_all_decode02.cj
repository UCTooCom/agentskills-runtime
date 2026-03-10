// DEPENDENCE: test_all.yaml
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import std.env.*
import std.fs.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
main() {
    var path: String = getWorkingDirectory().toString()
    let pathname: String = "${path}/test_all.yaml"
    var fs: File = File(pathname, ReadWrite)
    if (fs.canRead()) {
        var res: Array<UInt8> = File.readFrom(pathname)
        fs.close()
        var jv = decode(res, true)
        let str = ##"{"username":"xiaoming","password":123456,"info":"配置","NAME_PSW":{"name":"xiaoming","password":123456},"list":["Ruby","Perl","Python"],"lists":[10,20,[100,200],10,20,{"name":"tom","password":123456}],"name":"TOM","info1":[10,20,30],"info2":"HELLO word","info3":"HELLO\nwoord","name1":"tom","name2":"tom","DATA":"conf.yaml","key":"a b c"}"##
        if(jv.toString() != str) {
            return -1
        }
    } else {
        println("open fail")
    }
    return 0
}
