// 3rd_party_lib:yaml4cj/build/yaml4cj
// data_file:test_all.json:test_all1.json:test_all2.json:test_all3.json:test_all4.json
import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import stdx.encoding.json.*
import std.unittest.*
import std.unittest.testmacro.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
@Test
class Yaml_Decode {
    @TestCase
    func yaml_Ecode001(): Unit {
        var expect = ##"{"name":"Google","ag2":true,"school":"\f","school1":10,"url":"http:192.168.11.128"}"##
        let pathname: String = "test_all1.json"
        var fs: File = File(pathname, ReadWrite)
        var res: String = String.fromUtf8(File.readFrom(pathname))
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
        var decodeRes: String = decode(encodeRes).toString()
        @Assert(decodeRes,expect)
    }

    @TestCase
    func yaml_Ecode002(): Unit {
        var expect = 
            ##"{"username":"xiaoming","password":123456,"info":"配置","NAME_PSW":{"name":"xiaoming","password":123456},"list":["Ruby","Perl","Python"],"lists":[10,20,[100,200],10,20,{"name":"tom","password":123456}],"name":"TOM","info1":[10,20,30],"info2":"HELLO word","info3":"HELLO\nwoord","name1":"tom","name2":"tom","DATA":"conf.yaml","key111":true}"##
        let pathname: String = "test_all.json"
        var fs: File = File(pathname, ReadWrite)
        var res: String = String.fromUtf8(File.readFrom(pathname))
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
        var decodeRes: String = decode(encodeRes).toString()
        @Assert(decodeRes,expect)
    }

    @TestCase
    func yaml_Ecode003(): Unit {
        var expect = 
            ##"{"links":[{"name":"Google","ag2":true,"school":"\f","url":"http:192.168.11.128"},{"name":"百度","url":"http:192.168.11.128"}]}"##
        let pathname: String = "test_all2.json"
        var fs: File = File(pathname, ReadWrite)
        var res: String = String.fromUtf8(File.readFrom(pathname))
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
        var decodeRes: String = decode(encodeRes).toString()
        @Assert(decodeRes,expect)
    }

    @TestCase
    func yaml_Ecode004(): Unit {
        var expect = ##"[{"id":1,"username":"李四"},{"id":2,"age":888}]"##
        let pathname: String = "test_all3.json"
        var fs: File = File(pathname, ReadWrite)
        var res: String = String.fromUtf8(File.readFrom(pathname))
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
        var decodeRes: String = decode(encodeRes).toString()
        @Assert(decodeRes,expect)
    }

    @TestCase
    func yaml_Ecode005(): Unit {
        var expect = 
            ##"{"name":"Google","ag2":true,"school":["仓颉","足球"],"school1":10,"url":"http:192.168.11.128"}"##
        let pathname: String = "test_all4.json"
        var fs: File = File(pathname, ReadWrite)
        var res: String = String.fromUtf8(File.readFrom(pathname))
        var encodeRes: Array<UInt8> = encode(JsonValue.fromStr(res))
        var decodeRes: String = decode(encodeRes).toString()
        @Assert(decodeRes,expect)
    }
}
