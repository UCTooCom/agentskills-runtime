// 3rd_party_lib:yaml4cj/build/yaml4cj

import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import stdx.encoding.json.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Yaml_Decode {
    @TestCase
    func yaml_Ecode(): Unit {
        var expect: String = 
            ##"{
          "name": "Google",                                                                                                           
          "ag2": true,                                                               
          "school":"\f",                                                             
          "school1":10,                                                             
          "url": "http:192.168.11.128"}"##
        var data01: Array<Byte> = [
            110, 97, 109, 101, 58, 32, 71, 111, 111, 103, 108, 101, 10, 97, 103, 50, 58, 32, 116, 114, 117, 101, 10, 115, 99, 104, 111, 111, 108, 58, 32,
             34, 92, 102, 34, 10, 115, 99, 104, 111, 111, 108, 49, 58, 32, 49, 48, 10, 117, 114, 108, 58, 32, 104, 116, 116, 112, 58, 49, 57, 50, 46, 49, 
             54, 56, 46, 49, 49, 46, 49, 50, 56, 10]
        var JsonValue: JsonValue = JsonValue.fromStr(expect)
        @Assert(encode(JsonValue),data01)
    }

    @TestCase
    func yaml_Ecode01(): Unit {
        var data02: Array<Byte> = [
            115,116,114,75,101,121,58,32,115,116,114,86,97,108,117,101,10,105,110,116,75,101,121,58,32,49,48,48,56,10]
        let jsonValue1 = JsonObject(HashMap<String, JsonValue>([("strKey", JsonString("strValue")), ("intKey", JsonInt(1008))]))
        @Assert(encode(jsonValue1),data02)
    }

    @TestCase
    func yaml_Ecode02(): Unit { //对象格式
        var expect2: String = 
            ##"{
          "name": "Google",                                                                                                           
          "ag2": true,                                                               
          "school":["仓颉","足球"],                                                             
          "school1":10,                                                             
          "url": "http:192.168.11.128"}"##
        var data03: Array<Byte> = [
            110, 97, 109, 101, 58, 32, 71, 111, 111, 103, 108, 101, 10, 97, 103, 50, 58, 32, 116, 114, 117, 101, 10, 115, 99,
             104, 111, 111, 108, 58, 10, 45, 32, 34, 228, 187, 147, 233, 162, 137, 34, 10, 45, 32, 34, 232, 182, 179, 231, 144,
              131, 34, 10, 115, 99, 104, 111, 111, 108, 49, 58, 32, 49, 48, 10, 117, 114, 108, 58, 32, 104, 116, 116, 112, 58,
               49, 57, 50, 46, 49, 54, 56, 46, 49, 49, 46, 49, 50, 56, 10]
        var JsonValue2: JsonValue = JsonValue.fromStr(expect2)
        @Assert(encode(JsonValue2),data03)

    }

    @TestCase
    func yaml_Ecode03(): Unit {
        //数组+对象格式
        var expect3: String = 
            ##"{"links": [
      {
          "name": "Google",                                                                                                            
          "ag2": true,                                                               
          "school":"\f",                                                             
          "school1":10,                                                             
          "url": "http:192.168.11.128"
      },
      {
          "name": "百度",
          "url": "http:192.168.11.128"
      } ]}"##
        var data04: Array<Byte> = [
            108, 105, 110, 107, 115, 58, 10, 45, 32, 110, 97, 109, 101, 58, 32, 71, 111, 111, 103, 108, 101, 10, 32, 32, 97, 103, 50, 58, 32, 116, 114, 117,
             101, 10, 32, 32, 115, 99, 104, 111, 111, 108, 58, 32, 34, 92, 102, 34, 10, 32, 32, 115, 99, 104, 111, 111, 108, 49, 58, 32, 49, 48, 10, 32, 32,
              117, 114, 108, 58, 32, 104, 116, 116, 112, 58, 49, 57, 50, 46, 49, 54, 56, 46, 49, 49, 46, 49, 50, 56, 10, 45, 32, 110, 97, 109, 101, 58, 32, 
              34, 231, 153, 190, 229, 186, 166, 34, 10, 32, 32, 117, 114, 108, 58, 32, 104, 116, 116, 112, 58, 49, 57, 50, 46, 49, 54, 56, 46, 49, 49, 46,
               49, 50, 56, 10]
        var JsonValue3: JsonValue = JsonValue.fromStr(expect3)
        @Assert(encode(JsonValue3),data04)
    }

    @TestCase
    func yaml_Ecode04(): Unit {
        //简单json格式
        var expect4: String = ##"[1,"hi","仓颉","\b",null,true]"##
        var data05: Array<Byte> = [
            45, 32, 49, 10, 45, 32, 104, 105, 10, 45, 32, 34, 228, 187, 147, 233, 162, 137, 34, 10, 45, 32, 34, 92, 98, 34, 10, 45, 
            32, 110, 117, 108, 108, 10, 45, 32, 116, 114, 117, 101, 10]
        var JsonValue4: JsonValue = JsonValue.fromStr(expect4)
        @Assert(encode(JsonValue4),data05)
    }

    @TestCase
    func yaml_Ecode05(): Unit {
        //数组
        var expect5: String = 
            ##"[{
            "id":1,
            "username":"李四"
        },
        {
            "id":2,
            "age":888
        }
        ]"##
        var data06: Array<Byte> = [45,32,105,100,58,32,49,10,32,32,117,115,101,114,110,97,109,101,58,32,34,230,157,142,229,155,
                                   155,34,10,45,32,105,100,58,32,50,10,32,32,97,103,101,58,32,56,56,56,10]
        var JsonValue5: JsonValue = JsonValue.fromStr(expect5)
        @Assert(encode(JsonValue5),data06)
    }
}
