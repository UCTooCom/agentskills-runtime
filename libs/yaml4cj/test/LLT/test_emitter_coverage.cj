// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import std.collection.*
import stdx.encoding.json.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
main() {
    try {
        testEncode(JsonValue.fromStr("{\"a\":\" 1 \n- \n123\n456\"}"))

        testEncode(JsonString("---"))
        testEncode(JsonString("..."))
        testEncode(JsonString("- 123"))
        testEncode(
            JsonString(
                ###"key: |+
  a
  b
  c"###
            )
        )
        testEncode(
            JsonString(
                ###"key: |-
  a
  b
  c"###
            )
        )
        testEncode(
            JsonString(
                ###"key: >+
  a
  b
  c"###
            )
        )
        testEncode(
            JsonString(
                ###"key: >-
  a
  b
  c"###
            )
        )
        testEncode(JsonString("\n"))
        testEncode(JsonString("\'1"))
        testEncode(JsonString("\"1"))
        testEncode(JsonString(##"\"1"##))
        testEncode(JsonString("a: &a"))
        testEncode(
            JsonString(
                ###"a: 
          b: &b 1 
          c: *b"###
            )
        )
        testEncode(
            JsonString(
                ###"%YAML 1.1
paper:
   uuid: 8a8cbf60-e067-11e3-8b68-0800200c9a66
   name: On formally undecidable propositions of  Principia Mathematica and related systems I.
   author: Kurt Gödel.
tags:
   - tag:
      uuid: 98fb0d90-e067-11e3-8b68-0800200c9a66
      name: Mathematics
   - tag:
      uuid: 3f25f680-e068-11e3-8b68-0800200c9a66
      name: Logic"###
            )
        )
        testEncode(
            JsonString(
                ###"port: &ports
  adapter:  postgres
  host:     localhost

development:
  database: myapp_development
  <<: *ports"###
            )
        )
        testEncode(JsonArray([JsonString("1"), JsonInt(123), JsonFloat(3.14)]))
        testEncode(JsonString("123\r\n456测试"))
        testEncode(
            JsonObject(
                HashMap<String, JsonValue>(
                    [
                        ("ð", JsonString("ñòó")),
                        ("_", JsonString("a")),
                        ("1", JsonInt(1)),
                        ("1.0", JsonFloat(3.14)),
                        ("true", JsonBool(true)),
                        ("!!map", JsonObject(
                                HashMap<String, JsonValue>(
                                    [
                                        ("ð", JsonString("ñòó")),
                                        ("_", JsonString("a")),
                                        ("1", JsonInt(1)),
                                        ("1.0", JsonFloat(3.14)),
                                        ("true", JsonBool(true))
                                    ]
                                )
                            )),
                        ("#array#", JsonArray([JsonString("1"), JsonInt(123), JsonFloat(3.14)]))
                    ]
                )
            )
        )
        testEncode(
            JsonString(
                "!!map {\n ? !!str \"strip\" \n : !!str \"# text\", \n ? !!str \"clip\" \n : !!str \"# text\\n\", \n ? !!str \"keep\" \n : !!str \"# text\\n\", \n }"
            )
        )
    } catch (e: Exception) {
        // e.printStackTrace()
    }
    return 0
}

func testEncode(j: JsonValue) {
    var a = encode(j)
    // println(String.fromUtf8(a))
}
