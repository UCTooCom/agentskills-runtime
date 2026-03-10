// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import stdx.encoding.json.*
import std.collection.*

//func encode(input: JsonValue): Array<UInt8>
main() {
    var res0: String = ##"[false,true,1,1.0,1.1,1.2,2,2.0,2.1,"",".1",".2",".a","1","2","a!10","a/0001","a/002","a/3","a/10","a/11","a/0012","a/100","a~10","ab/1","b/1","b/01","b/2","b/02","b/3","b/03","b1","b01","b3","c2.10","c10.2","d1","d7","d7abc","d12","d12a"]"##
    var res1: String = ##"["_:\n  hi: there\n"]"##
    var res2: String = ##"["_:\n- 1\n- A\n"]"##
    var res3: String = ##"["_: 10\n", 10]"##
    var res4: String = ##"["_: BAR!\n", "BAR!"]"##
    var res5: String = ##"["_: null\n", "nil"]"##
    var res6: String = ##"["v: hi","a: <foo>\n","a: \"1:1\"\n","a: \"\\0\"\n","a: !!binary gIGC\n"]"##
    var res7: String = ##"["v: hi\n","123\n","a:\n- 1\n- 2\n","{}\n","a: {x: 0}\n","t2: 2018-01-09T10:40:47Z\nt4: 2098-01-09T10:40:47Z\n","a: [1, 2]\n","a: {b: c, d: e}\n","a: 1\nb: 2\nc: 3\n"]"##
    var res8: String = ##"["v: true\n","v: \"\"\n","v:\n- A\n- B\n","v:\n- A\n- |-\n  B\n  C\n","v:\n- A\n- 1\n- B:\n  - 2\n  - 3\n","a:\n  b: c\n"]"##
    var res9: String = ##"["b: 2\na: 1\nd: 4\nc: 3\nsub:\n  e: 5\n","a: 你好\n","a: 2015-02-24T18:19:39Z\n","a: 2015-02-24T18:19:39Z\n","a: 2015-02-24T18:19:39.123456789-03:00\n","a: \"2015-02-24T18:19:39Z\"\n","a: 'Hello #comment'\n","a: '你好 #comment'\n"]"##
    var res10: String = ##"{"a": "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890 abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890 "}"##
    var res11: String = ##"{}"##
    var arr: ArrayList<String> = ArrayList<String>()
    arr.add(res0)
    arr.add(res1)
    arr.add(res2)
    arr.add(res3)
    arr.add(res4)
    arr.add(res5)
    arr.add(res6)
    arr.add(res7)
    arr.add(res8)
    arr.add(res9)
    arr.add(res10)
    arr.add(res11)
    println(arr)
    for(i in 0..arr.size) {
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(arr[i]))
        var decodeRes: String = decode(encodeRes).toString()
        println(decodeRes)
    }     
    return 0
}
