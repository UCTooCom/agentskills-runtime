// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main(){
    let map = HashMap<String, Any>()
    map.add("String", "String1")
    map.add("Bool", true)
    map.add("Int64", 64)
    map.add("Float64", 3.14)
    map.add("Array", JsonValue.fromStr("[]"))
    map.add("Object", JsonValue.fromStr("{}"))

    let res = ###"{
  "String": "String1",
  "Bool": true,
  "Int64": 64,
  "Float64": 3.14,
  "Array": [],
  "Object": {}
}"###
    let ser = HeaderSerializer()
    let str = ser.serialize(HeaderClaimsHolder(map))
    if(str != res){
        return 1
    }
    0
}