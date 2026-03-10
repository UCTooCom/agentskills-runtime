// DEPENDENCE: test!!.yaml
// DEPENDENCE: test!!02.yaml
// DEPENDENCE: test!!03.yaml
// DEPENDENCE: test01.yaml
// DEPENDENCE: test02.yaml
// DEPENDENCE: test03.yaml
// DEPENDENCE: testcomma.yaml
// DEPENDENCE: testcomma2.yaml
// DEPENDENCE: testcomments.yaml
// DEPENDENCE: testend.yaml
// DEPENDENCE: testlist.yaml
// DEPENDENCE: testmap.yaml
// DEPENDENCE: testn.yaml
// DEPENDENCE: testpointer.yaml
// DEPENDENCE: testquestionmarkandspace01.yaml
// DEPENDENCE: testquestionmarkandspace02.yaml
// DEPENDENCE: testquestionmarkandspace03.yaml
// DEPENDENCE: testyaml01.yaml
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
    let pathname: String = "${path}/test_all.yaml"

    var arr: Array<String> = [
        "${path}/test!!.yaml",
        "${path}/test!!02.yaml",
        "${path}/test!!03.yaml",
        "${path}/test01.yaml",
        "${path}/test02.yaml",
        "${path}/test03.yaml",
        "${path}/testcomma.yaml",
        "${path}/testcomma2.yaml",
        "${path}/testcomments.yaml",
        "${path}/testend.yaml",
        "${path}/testlist.yaml",
        "${path}/testmap.yaml",
        "${path}/testn.yaml",
        "${path}/testpointer.yaml",
        "${path}/testquestionmarkandspace01.yaml",
        "${path}/testquestionmarkandspace02.yaml",
        "${path}/testquestionmarkandspace03.yaml",
        "${path}/testyaml01.yaml"
        ]
    
    for(i in 0..arr.size) {
        var fs: File = File(arr[i], ReadWrite)
        if (fs.canRead()) {
            var res = File.readFrom(arr[i])
            fs.close()
            var jv = decode(res, true)
            if(jv.toString().size == 0) {
                return -1
            }

        } else {
            println("open fail")
        }
    }
  
    return 0
}
