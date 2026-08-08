// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main(){
    let map = HashMap<String, Any>()
    map.add("String", "String1")
    map.add("Bool", true)
    map.add("Int64", 64)
    map.add("Float64", 3.14)
    map.add("Time", DateTime.ofEpoch(second: 1673820000, nanosecond: 0))
    map.add("Array", JsonValue.fromStr("[true]"))
    map.add("Object", JsonValue.fromStr(##"{"k":"v"}"##))

    let res = ###"{
  "String": "String1",
  "Bool": true,
  "Int64": 64,
  "Float64": 3.14,
  "Time": 1673820000,
  "Array": [
    true
  ],
  "Object": {
    "k": "v"
  }
}"###
    let ser = PayloadSerializer()
    let str = ser.serialize(PayloadClaimsHolder(map))
    if(str != res){
        println(str)
        
        return 1
    }
    0
}
