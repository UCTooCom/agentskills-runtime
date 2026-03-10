// 3rd_party_lib:yaml4cj/build/yaml4cj
import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Yaml_Decode {
    @TestCase
    func yaml_Ecode(): Unit {
        let expect: String = ##"{"xzzzzzzzzz":null}"##
        let data = "{\u{78}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}}".toArray()
        println(data)
        @Assert(decode(data).toString(),expect)
    }

    @TestCase
    func yaml_Ecode01(): Unit {
        let expect1: String = ##"{"x":null}"##
        let data1 = "{\u{78}}".toArray()
        println(data1)
        @Assert(decode(data1).toString(),expect1)
    }

    @TestCase
    func yaml_Ecode02(): Unit {
        let expect2: String = ##"{"xzzzzz!zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz":null}"##
        let data2 = 
            "{\u{78}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{21}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}}".
        toArray()
        println(data2)
        @Assert(decode(data2).toString(),expect2)
    }

    @TestCase
    func yaml_Ecode03(): Unit {
        let expect3: String = ##"{}"##
        let data3 = "{}".toArray()
        println(data3)
        @Assert(decode(data3).toString(),expect3)
    }

    @TestCase
    func yaml_Ecode04(): Unit {
        try {
            let expect04: String = ##""""##
            let data04 = "{\u{21}}".toArray()
            println(data04)
            @Assert(decode(data04).toString(),expect04)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected whitespace or line break")
        }
    }

    @TestCase
    func yaml_Ecode05(): Unit {
        let expect05: String = ##""""##
        let data05 = "\u{21}".toArray()
        println(data05)
        @Assert(decode(data05,true).toString(),expect05)
    }

    @TestCase
    func yaml_Ecode06(): Unit {
        let expect06: String = ##""""##
        let data06 = "\u{21}".toArray()
        println(data06)
        @Assert(decode(data06,false).toString(),expect06)
    }

    @TestCase
    func yaml_Ecode07(): Unit {
        let expect07: String = ##""""##
        let data07 = "\u{21}".toArray()
        println(data07)
        @Assert(decode(data07,true).toString(),expect07)
    }

    @TestCase
    func yaml_Ecode08(): Unit {
        let expect08: String = ##""""##
        let data08 = "\u{21}".toArray()
        println(data08)
        @Assert(decode(data08,false).toString(),expect08)
    }

    @TestCase
    func yaml_Ecode09(): Unit {
        let expect9: String = ##""x,:zzzzz!zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz""##
        let data9 = 
            "\u{78},:\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{21}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}".
        toArray()
        println(data9)
        @Assert(decode(data9,true).toString(),expect9)
    }

    @TestCase
    func yaml_Ecode010(): Unit {
        let expect10: String = ##""x,:zzzzz!zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz""##
        let data10 = 
            "\u{78},:\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{21}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}\u{7A}".
        toArray()
        println(data10)
        @Assert(decode(data10,false).toString(),expect10)
    }
}
