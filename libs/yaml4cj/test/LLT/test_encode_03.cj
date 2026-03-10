// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*
import stdx.encoding.json.*
import std.collection.*

//func encode(input: JsonValue): Array<UInt8>
main() {
    var res0: String = ##"{"ñoño":"very yes"}"##
    var res1: String = ##"{"ñoño": "very yes 🟔"}"##
    var res2: String = ##"{"a: &a [00,00,00,00,00,00,00,00,00] ":null,"yaml: document contains excessive aliasing":null}"##
    var res3: String = ##"{"b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a] ":null,"yaml: document contains excessive aliasing":null}"##
    var res4: String = ##"{"_: 10":null,"!!int":null,"10":null}"##
    var res5: String = ##"{"_: null":null,"!!null":null,"nil":null}"##
    var arr: ArrayList<String> = ArrayList<String>()
    arr.add(res0)
    arr.add(res1)
    for(i in 0..arr.size) {
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(arr[i]))
        var decodeRes: String = decode(encodeRes).toString()
        println(decodeRes)
    }     
    return 0
}
