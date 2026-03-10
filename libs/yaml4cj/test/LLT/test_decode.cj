// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
main() {
    var arr: Array<String> = [
        "{\"a: &a [00,00,00,00,00,00,00,00,00]\n\",\"yaml: document contains excessive aliasing\"}",
        "{\"b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]\n\",\"yaml: document contains excessive aliasing\"}",
        "{\"_: 10\", \"!!int\", 10}",
        "{\"_: null\", \"!!null\", nil}"
        // "\u{ff}\u{fe}\u{f1}\u{00}o\u{00}\u{f1}\u{00}o\u{00}:\u{00} \u{00}v\u{00}e\u{00}r\u{00}y\u{00} \u{00}y\u{00}e\u{00}s\u{00}\n\u{00}",
        // "\u{fe}\u{ff}\u{00}\u{f1}\u{00}o\u{00}\u{f1}\u{00}o\u{00}:\u{00} \u{00}v\u{00}e\u{00}r\u{00}y\u{00} \u{00}y\u{00}e\u{00}s\u{00}\n",
		// "\u{ff}\u{fe}\u{f1}\u{00}o\u{00}\u{f1}\u{00}o\u{00}:\u{00} \u{00}v\u{00}e\u{00}r\u{00}y\u{00} \u{00}y\u{00}e\u{00}s\u{00} \u{00}=\u{d8}\u{d4}\u{df}\n\u{00}",
        // "\u{fe}\u{ff}\u{00}\u{f1}\u{00}o\u{00}\u{f1}\u{00}o\u{00}:\u{00} \u{00}v\u{00}e\u{00}r\u{00}y\u{00} \u{00}y\u{00}e\u{00}s\u{00} \u{d8}=\u{df}\u{d4}\u{00}\n"
    ]
    for(i in 0..arr.size) {
        let b = arr[i].toArray()
        //let c = Array<UInt8>(b.size, {n=>UInt8(b[n])})
        let r = decode(b)
        println(r)
    }
    
    return 0
}
