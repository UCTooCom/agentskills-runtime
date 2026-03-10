// 3rd_party_lib:yaml4cj/build/yaml4cj
import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import stdx.encoding.json.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Yaml_Decode {
    @TestCase
    func yaml_Ecode(): Unit {
        let expect: String = ##"{"a":{"b":["c","d","e"]},"f":"ghi"}"##
        let data: Array<UInt8> = [97,58,10,32,32,32,98,58,10,32,32,32,32,32,32,45,32,99,10,32,32,32,32,32,32,45,32,32,100,10,32,32,32,
                                 32,32,32,45,32,101,10,102,58,10,32,32,32,32,32,32,34,103,104,105,34]
        @Assert(decode(data).toString(),expect)
    }

    @TestCase
    func yaml_Ecode1(): Unit {
        let expect1: String = ##"{"b":["c","d","e"]}"##
        let data1: Array<UInt8> = [98,58,10,32,32,32,32,32,32,45,32,99,10,32,32,32,32,32,32,45,32,32,100,10,32,32,32,32,32,32,45,32,101,10]
        println(decode(data1).toString())
        @Assert(decode(data1).toString(),expect1)
    }

    @TestCase
    func yaml_Ecode2(): Unit {
        let expect2: String = ##""""##
        let data2: Array<UInt8> = [33]
        println(decode(data2).toString())
        @Assert(decode(data2).toString(),expect2)
    }

    @TestCase
    func yaml_Ecode3(): Unit {
        let expect3: String = ##"{}"##
        let data3: Array<UInt8> = [123, 32, 125]
        println(decode(data3).toString())
        @Assert(decode(data3).toString(),expect3)
    }

    @TestCase
    func yaml_Ecode4(): Unit {
        let expect4: String = ##"{"a a":null}"##
        let data4: Array<UInt8> = [123, 97, 10, 32, 32, 32, 32, 32, 32, 97, 125]
        println(decode(data4).toString())
        @Assert(decode(data4).toString(),expect4)
    }

    @TestCase
    func yaml_Ecode5(): Unit {
        let expect5: String = ##"{"a":null}"##
        let data5: Array<UInt8> = [123, 97, 125]
        println(decode(data5).toString())
        @Assert(decode(data5).toString(),expect5)
    }

    @TestCase
    func yaml_Ecode6(): Unit {
        try {
            let expect6: String = ##"{"a":null}"##
            let data6: Array<UInt8> = [254]
            println(decode(data6).toString())
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: invalid leading UTF-8 octet")
        }
    }


    @TestCase
    func yaml_Ecode8(): Unit {
        let expect8: String = ##"null"##
        let data8: Array<UInt8> = [32]
        println(decode(data8).toString())
        @Assert(decode(data8,true).toString(),expect8)
    }

    @TestCase
    func yaml_Ecode10(): Unit {
        let expect10: String = ##"{"a":{"b":["c","d","e"]},"f":"ghi"}"##
        let data10: Array<UInt8> = [97,58,10,32,32,32,98,58,10,32,32,32,32,32,32,45,32,99,10,32,32,32,32,32,32,45,32,32,
                                   100,10,32,32,32,32,32,32,45,32,101,10,102,58,10,32,32,32,32,32,32,34,103,104,105,34]
        println(decode(data10).toString())
        @Assert(decode(data10,true).toString(),expect10)
    }

    @TestCase
    func yaml_Ecode11(): Unit {
        let expect11: String = ##"{"a":{"b":["c","d","e"]},"f":"ghi"}"##
        let data11: Array<UInt8> = [97,58,10,32,32,32,98,58,10,32,32,32,32,32,32,45,32,99,10,32,32,32,32,32,32,45,32,32,
                                100,10,32,32,32,32,32,32,45,32,101,10,102,58,10,32,32,32,32,32,32,34,103,104,105,34]
        println(decode(data11).toString())
        @Assert(decode(data11,false).toString(),expect11)
    }

    @TestCase
    func yaml_Ecode12(): Unit {
        let expect12: String = ##"null"##
        let data12: Array<UInt8> = []
        println(decode(data12).toString())
        @Assert(decode(data12,false).toString(),expect12)
    }
}
