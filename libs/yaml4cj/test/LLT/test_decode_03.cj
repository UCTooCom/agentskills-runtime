// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
main() {
    var str: String = ###"
anchors:
  list:
    - &CENTER { \"x\": 1, \"y\": 2 }
    - &LEFT   { \"x\": 0, \"y\": 2 }
    - &BIG    { \"r\": 10 }
    - &SMALL  { \"r\": 1 }
# All the following maps are equal:
plain:
  # Explicit keys
  \"x\": 1
  \"y\": 2
  \"r\": 10
  label: center/big
mergeOne:
  # Merge one map
  << : *CENTER
  \"r\": 10
  label: center/big
mergeMultiple:
  # Merge multiple maps
  << : [ *CENTER, *BIG ]
  label: center/big
override:
  # Override
  << : [ *BIG, *LEFT, *SMALL ]
  \"x\": 1
  label: center/big
shortTag:
  # Explicit short merge tag
  !!merge \"<<\" : [ *CENTER, *BIG ]
  label: center/big
longTag:
  # Explicit merge long tag
  !<tag:yaml.org,2002:merge> \"<<\" : [ *CENTER, *BIG ]
  label: center/big
inlineMap:
  # Inlined map 
  << : {\"x\": 1, \"y\": 2, \"r\": 10}
  label: center/big
inlineSequenceMap:
  # Inlined map in sequence
  << : [ *CENTER, {\"r\": 10} ]
  label: center/big
"###
    var res: Array<UInt8> = str.toArray()
    var jv = decode(res)
    // println(jv.toString())

    
      
    return 0
}
