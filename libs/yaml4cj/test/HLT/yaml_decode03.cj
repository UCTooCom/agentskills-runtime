// 3rd_party_lib:yaml4cj/build/yaml4cj
import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Yaml_Decode {
    @TestCase
    func yaml_Ecode000(): Unit {
        let expect: String = ##"{}"##
        let data = "{}:".toArray()
        println(data)

        //let jsonValue5 = decode(q)
        @Assert(decode(data).toString(),expect)
    }

    @TestCase
    func yaml_Ecode001(): Unit { //待确定
        let expect1: String = ##"{}"##
        let data1 = 
            "{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}".
        toArray()
        println(data1)
        @Assert(decode(data1).toString(),expect1)
    }

    @TestCase
    func yaml_Ecode002(): Unit {
        let expect2: String = ##"{"()&*!/:":null}"##
        let data2 = "{()&*!/:}".toArray()
        println(data2)

        //let jsonValue5 = decode(q)
        @Assert(decode(data2).toString().replace("\\u0026", "&"),expect2)
    }

    @TestCase
    func yaml_Ecode003(): Unit {
        let expect3: String = ##"{}"##
        let data3 = "{}()&*!/:".toArray()
        println(data3)

        //let jsonValue5 = decode(q)
        @Assert(decode(data3).toString(),expect3)
    }

    @TestCase
    func yaml_Ecode004(): Unit { //An exception has occurred:Exception: yaml: did not find expected whitespace or line break
        try {
            let expect4: String = ##"{}"##
            let data4 = "{!&*}".toArray()
            println(data4)

            //let jsonValue5 = decode(q)
            @Assert(decode(data4).toString(),expect4)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected whitespace or line break")
        }
    }

    @TestCase
    func yaml_Ecode005(): Unit {
        try {
            let expect5: String = ##"{}"## //An exception has occurred:Exception: yaml: did not find expected alphabetic or numeric character
            let data5 = "&".toArray()
            println(data5)

            //let jsonValue5 = decode(q)
            @Assert(decode(data5).toString(),expect5)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected alphabetic or numeric character")
        }
    }

    @TestCase
    func yaml_Ecode006(): Unit {
        let expect6: String = ##""""##
        let data6 = "!".toArray()
        println(data6)

        //let jsonValue5 = decode(q)
        @Assert(decode(data6).toString(),expect6)
    }

    @TestCase
    func yaml_Ecode007(): Unit {
        let expect7: String = ##"{}"##
        let data7 = "{}:".toArray()
        println(data7)

        //let jsonValue5 = decode(q)
        @Assert(decode(data7,true).toString(),expect7)
    }

    @TestCase
    func yaml_Ecode008(): Unit { //An exception has occurred:Exception: yaml: did not find expected key
        try {
            let expect8: String = ##"{}"##
            let data8 = ":".toArray()
            println(data8)

            //let jsonValue5 = decode(q)
            @Assert(decode(data8,false).toString(),expect8)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected key")
        }
    }

    @TestCase
    func yaml_Ecode009(): Unit {
        let expect9: String = ##"{}"##
        let data9 = 
            "{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}".
        toArray()
        println(data9)
        @Assert(decode(data9,true).toString(),expect9)
    }

    @TestCase
    func yaml_Ecode010(): Unit {
        let expect10: String = ##"{}"##
        let data10 = 
            "{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}".
        toArray()
        println(data10)
        @Assert(decode(data10,false).toString(),expect10)
    }

    @TestCase
    func yaml_Ecode011(): Unit {
        let expect11: String = ##"{}"##
        let data11 = "{}()&*!/:".toArray()
        println(data11)

        //let jsonValue5 = decode(q)
        @Assert(decode(data11,true).toString(),expect11)
    }

    @TestCase
    func yaml_Ecode012(): Unit {
        let expect12: String = ##"{}"##
        let data12 = "{}()&*!/:".toArray()
        println(data12)

        //let jsonValue5 = decode(q)
        @Assert(decode(data12,false).toString(),expect12)
    }

    @TestCase
    func yaml_Ecode013(): Unit {
        try {
            let expect13: String = ##"{}"## //An exception has occurred:Exception: yaml: did not find expected alphabetic or numeric character
            let data13 = "&".toArray()
            println(data13)

            //let jsonValue5 = decode(q)
            @Assert(decode(data13,true).toString(),expect13)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected alphabetic or numeric character")
        }
    }

    @TestCase
    func yaml_Ecode014(): Unit {
        try {
            let expect14: String = ##"{}"## //An exception has occurred:Exception: yaml: did not find expected alphabetic or numeric character
            let data14 = "&".toArray()
            println(data14)

            //let jsonValue5 = decode(q)
            @Assert(decode(data14,false).toString(),expect14)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected alphabetic or numeric character")
        }
    }

    @TestCase
    func yaml_Ecode015(): Unit {
        try {
            let expect15: String = ##"null"## //An exception has occurred:Exception: yaml: did not find expected alphabetic or numeric character
            let data15 = "".toArray()
            println(data15)

            //let jsonValue5 = decode(q)
            @Assert(decode(data15,true).toString(),expect15)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected alphabetic or numeric character")
        }
    }

    @TestCase
    func yaml_Ecode016(): Unit {
        try {
            let expect16: String = ##"null"## //An exception has occurred:Exception: yaml: did not find expected alphabetic or numeric character
            let data16 = "".toArray()
            println(data16)

            //let jsonValue5 = decode(q)
            @Assert(decode(data16,false).toString(),expect16)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected alphabetic or numeric character")
        }
    }

    @TestCase
    func yaml_Ecode017(): Unit { //An exception has occurred:Exception: yaml: did not find expected key
        try {
            let expect17: String = ##"{}"##
            let data17 = ":".toArray()
            println(data17)

            //let jsonValue5 = decode(q)
            @Assert(decode(data17,true).toString(),expect17)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected key")
        }
    }

    @TestCase
    func yaml_Ecode018(): Unit { //An exception has occurred:Exception: yaml: did not find expected key
        try {
            let expect18: String = ##"{}"##
            let data18 = ":".toArray()
            println(data18)

            //let jsonValue5 = decode(q)
            @Assert(decode(data18,false).toString(),expect18)
        } catch (e: Exception) {
            @Assert(e.toString(),"Exception: yaml: did not find expected key")
        }
    }
}
