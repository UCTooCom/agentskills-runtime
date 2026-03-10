// 3rd_party_lib:yaml4cj/build/yaml4cj
// data_file:9HCY.yaml:2AUY.yaml:2CMS.yaml:2EBW.yaml:2G84.yaml:2JQS.yaml:2LFX.yaml:2SXE.yaml:2XXW.yaml:3ALJ.yaml:3GZX.yaml:3HFZ.yaml:3MYT.yaml:3R3P.yaml:3RLN.yaml:3UYS.yaml:4ABK.yaml:4CQQ.yaml
// data_file:4EJS.yaml:5WE3.yaml:4FJ6.yaml:4GC6.yaml:4H7K.yaml:4HVU.yaml:4JVG.yaml:4MUZ.yaml:4V8U.yaml:4UYU.yaml:4WA9.yaml:5BVJ.yaml:5C5M.yaml:5KJE.yaml:5MUD.yaml:5NYZ.yaml:5T43.yaml:5TRB.yaml
// data_file:5TYM.yaml:5U3A.yaml:6BFJ.yaml:6CK3.yaml:6H3V.yaml:6JQW.yaml:6JTT.yaml:6JWB.yaml:6KGN.yaml:6LVF.yaml:6M2F.yaml:6PBE.yaml:6S55.yaml:6SLA.yaml:6VJK.yaml:6WLZ.yaml:6XDY.yaml
// data_file:6ZKB.yaml:7BMT.yaml:7BUB.yaml:7FWL.yaml:7LBH.yaml:7MNF.yaml:7T8X.yaml:7TMG.yaml:7W2P.yaml:7Z25.yaml:7ZZ5.yaml:8KB6.yaml:8CWC.yaml:8MK2.yaml:8QBE.yaml:8UDB.yaml:8XDJ.yaml
// data_file:8XYN.yaml:3HFZ.yaml:9BXH.yaml:9C9N.yaml:9CWY.yaml:9DXL.yaml:9FMG.yaml:9HCY.yaml
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
    func yaml_Decode(): Unit {
        var expect = 
            ##"[{"name":"Tags in Block Sequence","from":"NimYAML tests","tags":"tag sequence","yaml":" - !!str a\n - b\n - !!int 42\n - d\n","tree":"+STR\n +DOC\n  +SEQ\n   =VAL <tag:yaml.org,2002:str> :a\n   =VAL :b\n   =VAL <tag:yaml.org,2002:int> :42\n   =VAL :d\n  -SEQ\n -DOC\n-STR\n","json":"[\n  \"a\",\n  \"b\",\n  42,\n  \"d\"\n]\n","dump":"- !!str a\n- b\n- !!int 42\n- d\n"}]"##
        let pathname: String = "2AUY.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode01(): Unit {
        var expect = 
            ##"[{"name":"Invalid mapping in plain multiline","from":"@perlpunk","tags":"error mapping","fail":true,"yaml":"this\n is\n  invalid: x\n","tree":"+STR\n +DOC\n"}]"##
        let pathname: String = "2CMS.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode03(): Unit {
        var expect = 
            ##"[{"name":"Literal modifers","from":"@ingydotnet","tags":"literal scalar","fail":true,"yaml":"--- |0\n","tree":"+STR\n +DOC ---\n"},{"fail":true,"yaml":"--- |10\n"},{"yaml":"--- |1-∎\n","tree":"+STR\n +DOC ---\n  =VAL |\n -DOC\n-STR\n","json":"\"\"\n","emit":"--- \"\"\n"},{"yaml":"--- |1+∎\n","tree":"+STR\n +DOC ---\n  =VAL |\n -DOC\n-STR\n","emit":"--- \"\"\n"}]"##
        let pathname: String = "2G84.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode04(): Unit {
        var expect = 
            ##"[{"name":"Block Mapping with Missing Keys","from":"NimYAML tests","tags":"duplicate-key mapping empty-key","yaml":": a\n: b\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :\n   =VAL :a\n   =VAL :\n   =VAL :b\n  -MAP\n -DOC\n-STR\n"}]"##

        let pathname: String = "2JQS.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode05(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 6.13. Reserved Directives [1.3]","from":"6LVF, modified for YAML 1.3","tags":"spec directive header double 1.3-mod","yaml":"%FOO  bar baz # Should be ignored\n              # with a warning.\n---\n\"foo\"\n","tree":"+STR\n +DOC ---\n  =VAL \"foo\n -DOC\n-STR\n","json":"\"foo\"\n","dump":"---\n\"foo\"\n","emit":"--- \"foo\"\n"}]"##

        let pathname: String = "2LFX.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode06(): Unit {
        var expect = 
            ##"[{"name":"Anchors With Colon in Name","from":"Mailing List Discussion","tags":"alias edge mapping 1.3-err","yaml":"&a: key: &a value\nfoo:\n  *a:\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL &a: :key\n   =VAL &a :value\n   =VAL :foo\n   =ALI *a:\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"key\": \"value\",\n  \"foo\": \"key\"\n}\n","dump":"&a: key: &a value\nfoo: *a:\n"}]"##

        let pathname: String = "2SXE.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode08(): Unit {

        var expect = 
            ##"[{"name":"Block Sequence in Block Sequence","from":"NimYAML tests","tags":"sequence","yaml":"- - s1_i1\n  - s1_i2\n- s2\n","tree":"+STR\n +DOC\n  +SEQ\n   +SEQ\n    =VAL :s1_i1\n    =VAL :s1_i2\n   -SEQ\n   =VAL :s2\n  -SEQ\n -DOC\n-STR\n","json":"[\n  [\n    \"s1_i1\",\n    \"s1_i2\"\n  ],\n  \"s2\"\n]\n"}]"##

        let pathname: String = "3ALJ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)

    }
   
    @TestCase
    func yaml_Decode09(): Unit {
        var expect = 
            ##"[{"name":"xxx Example 7.1. Alias Nodes","from":"xxx://xxx.xxx.xxx/xxx/xxx/xxx.xxx#id2786448","tags":"mapping xxx alias","xxx":"First occurrence: &anchor Foo\nSecond occurrence: *anchor\nOverride anchor: &anchor Bar\nReuse anchor: *anchor\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :First occurrence\n   =VAL &anchor :Foo\n   =VAL :Second occurrence\n   =ALI *anchor\n   =VAL :Override anchor\n   =VAL &anchor :Bar\n   =VAL :Reuse anchor\n   =ALI *anchor\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"First occurrence\": \"Foo\",\n  \"Second occurrence\": \"Foo\",\n  \"Override anchor\": \"Bar\",\n  \"Reuse anchor\": \"Bar\"\n}\n"}]"##

        let pathname: String = "3GZX.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode10(): Unit {
        var expect = 
            ##"[{"name":"Invalid content after document end marker","from":"@perlpunk","tags":"error footer","fail":true,"yaml":"---\nkey: value\n... invalid\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :key\n   =VAL :value\n  -MAP\n -DOC ...\n"}]"##

        let pathname: String = "3HFZ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode11(): Unit {
        var expect = 
            ##"[{"name":"Plain Scalar looking like key, comment, anchor and tag","from":"http:192.168.11.128 via @ingydotnet","tags":"scalar","yaml":"---\nk:#foo\n &a !t s\n","tree":"+STR\n +DOC ---\n  =VAL :k:#foo &a !t s\n -DOC\n-STR\n","json":"\"k:#foo &a !t s\"\n","dump":"--- k:#foo &a !t s\n"}]"##

        let pathname: String = "3MYT.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode12(): Unit {
        var expect = 
            ##"[{"name":"Single block sequence with anchor","from":"@perlpunk","tags":"anchor sequence","yaml":"&sequence\n- a\n","tree":"+STR\n +DOC\n  +SEQ &sequence\n   =VAL :a\n  -SEQ\n -DOC\n-STR\n","json":"[\n  \"a\"\n]\n","dump":"&sequence\n- a\n"}]"##

        let pathname: String = "3R3P.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode13(): Unit {
        var expect = 
            ##"[{"name":"Leading tabs in double quoted","from":"@ingydotnet","tags":"double whitespace","yaml":"\"1 leading\n    \\ttab\"\n","tree":"+STR\n +DOC\n  =VAL \"1 leading \\ttab\n -DOC\n-STR\n","json":"\"1 leading \\ttab\"\n","emit":"\"1 leading \\ttab\"\n"},{"yaml":"\"2 leading\n    \\———»tab\"\n","tree":"+STR\n +DOC\n  =VAL \"2 leading \\ttab\n -DOC\n-STR\n","json":"\"2 leading \\ttab\"\n","emit":"\"2 leading \\ttab\"\n"},{"yaml":"\"3 leading\n    ————»tab\"\n","tree":"+STR\n +DOC\n  =VAL \"3 leading tab\n -DOC\n-STR\n","json":"\"3 leading tab\"\n","emit":"\"3 leading tab\"\n"},{"yaml":"\"4 leading\n    \\t  tab\"\n","tree":"+STR\n +DOC\n  =VAL \"4 leading \\t  tab\n -DOC\n-STR\n","json":"\"4 leading \\t  tab\"\n","emit":"\"4 leading \\t  tab\"\n"},{"yaml":"\"5 leading\n    \\———»  tab\"\n","tree":"+STR\n +DOC\n  =VAL \"5 leading \\t  tab\n -DOC\n-STR\n","json":"\"5 leading \\t  tab\"\n","emit":"\"5 leading \\t  tab\"\n"},{"yaml":"\"6 leading\n    ————»  tab\"\n","tree":"+STR\n +DOC\n  =VAL \"6 leading tab\n -DOC\n-STR\n","json":"\"6 leading tab\"\n","emit":"\"6 leading tab\"\n"}]"##

        let pathname: String = "3RLN.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode14(): Unit {
        var expect = 
            ##"[{"name":"Escaped slash in double quotes","from":"@perlpunk","tags":"double","yaml":"escaped slash: \"a\\/b\"\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :escaped slash\n   =VAL \"a/b\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"escaped slash\": \"a/b\"\n}\n","dump":"escaped slash: \"a/b\"\n"}]"##

        let pathname: String = "3UYS.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode15(): Unit {
        var expect = 
            ##"[{"name":"Flow Mapping Separate Values","from":"xxx://xxx.xxx/spexxc/xx/","tags":"flow mapping","yaml":"{\nunquoted : \"separate\",\nhttp:192.168.11.128,\nomitted value:,\n}\n","tree":"+STR\n +DOC\n  +MAP {}\n   =VAL :unquoted\n   =VAL \"separate\n   =VAL :xxxx://xxx.xxx\n   =VAL :\n   =VAL :omitted value\n   =VAL :\n  -MAP\n -DOC\n-STR\n","dump":"unquoted: \"separate\"\nxxx://xxx.xxx: null\nomitted value: null\n"}]"##

        let pathname: String = "4ABK.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode16(): Unit {
        var expect = 
            ##"[{"name":"xxx Example 2.18. Multi-line Flow Scalars","from":"xxx://xxx.xxx.xxx/xxx/xxx/xxx.xxx#id2761268","tags":"xxx scalar","xxx":"plain:\n  This unquoted scalar\n  spans many lines.\n\nquoted: \"So does this\n  quoted scalar.\\n\"\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :plain\n   =VAL :This unquoted scalar spans many lines.\n   =VAL :quoted\n   =VAL \"So does this quoted scalar.\\n\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"plain\": \"This unquoted scalar spans many lines.\",\n  \"quoted\": \"So does this quoted scalar.\\n\"\n}\n","dump":"plain: This unquoted scalar spans many lines.\nquoted: \"So does this quoted scalar.\\n\"\n"}]"##

        let pathname: String = "4CQQ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode17(): Unit {
        var expect = 
            ##"[{"name":"Invalid tabs as indendation in a mapping","from":"https://github.com/nodeca/js-yaml/issues/80","tags":"error mapping whitespace","fail":true,"yaml":"---\na:\n———»b:\n———»———»c: value\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :a\n"}]"##

        let pathname: String = "4EJS.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode18(): Unit {
        var expect = 
            ##"[{"name":"Nested implicit complex keys","from":"@perlpunk","tags":"complex-key flow mapping sequence","yaml":"---\n[\n  [ a, [ [[b,c]]: d, e]]: 23\n]\n","tree":"+STR\n +DOC ---\n  +SEQ []\n   +MAP {}\n    +SEQ []\n     =VAL :a\n     +SEQ []\n      +MAP {}\n       +SEQ []\n        +SEQ []\n         =VAL :b\n         =VAL :c\n        -SEQ\n       -SEQ\n       =VAL :d\n      -MAP\n      =VAL :e\n     -SEQ\n    -SEQ\n    =VAL :23\n   -MAP\n  -SEQ\n -DOC\n-STR\n","dump":"---\n- ? - a\n    - - ? - - b\n            - c\n        : d\n      - e\n  : 23\n"}]"##

        let pathname: String = "4FJ6.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode19(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 7.7. Single Quoted Characters","from":"http:192.168.11.128#id2788307","tags":"spec scalar 1.3-err","yaml":"'here''s to \"quotes\"'\n","tree":"+STR\n +DOC\n  =VAL 'here's to \"quotes\"\n -DOC\n-STR\n","json":"\"here's to \\\"quotes\\\"\"\n"}]"##

        let pathname: String = "4GC6.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode20(): Unit {
        var expect = 
            ##"[{"name":"Flow sequence with invalid extra closing bracket","from":"@perlpunk","tags":"error flow sequence","fail":true,"yaml":"---\n[ a, b, c ] ]\n","tree":"+STR\n +DOC ---\n  +SEQ\n   =VAL :a\n   =VAL :b\n   =VAL :c\n  -SEQ\n -DOC\n"}]"##

        let pathname: String = "4H7K.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode21(): Unit {
        var expect = 
            ##"[{"name":"Wrong indendation in Sequence","from":"@perlpunk","tags":"error sequence indent","fail":true,"yaml":"key:\n   - ok\n   - also ok\n  - wrong\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :key\n   +SEQ\n    =VAL :ok\n    =VAL :also ok\n   -SEQ\n"}]"##

        let pathname: String = "4HVU.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode22(): Unit {
        var expect = 
            ##"[{"name":"Scalar value with two anchors","from":"@perlpunk","tags":"anchor error mapping","fail":true,"yaml":"top1: &node1\n  &k1 key1: val1\ntop2: &node2\n  &v2 val2\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :top1\n   +MAP &node1\n    =VAL &k1 :key1\n    =VAL :val1\n   -MAP\n   =VAL :top2\n"}]"##

        let pathname: String = "4JVG.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode23(): Unit {
        var expect = 
            ##"[{"name":"Flow mapping colon on line after key","from":"@ingydotnet","tags":"flow mapping","yaml":"{\"foo\"\n: \"bar\"}\n","tree":"+STR\n +DOC\n  +MAP {}\n   =VAL \"foo\n   =VAL \"bar\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"foo\": \"bar\"\n}\n","emit":"\"foo\": \"bar\"\n"},{"yaml":"{\"foo\"\n: bar}\n","tree":"+STR\n +DOC\n  +MAP {}\n   =VAL \"foo\n   =VAL :bar\n  -MAP\n -DOC\n-STR\n","emit":"\"foo\": bar\n"},{"yaml":"{foo\n: bar}\n","tree":"+STR\n +DOC\n  +MAP {}\n   =VAL :foo\n   =VAL :bar\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"foo\": \"bar\"\n}\n","emit":"foo: bar\n"}]"##

        let pathname: String = "4MUZ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode24(): Unit {
        var expect = 
            ##"[{"name":"Colon in Double Quoted String","from":"NimYAML tests","tags":"mapping scalar 1.3-err","yaml":"\"foo: bar\\\": baz\"\n","tree":"+STR\n +DOC\n  =VAL \"foo: bar\": baz\n -DOC\n-STR\n","json":"\"foo: bar\\\": baz\"\n"}]"##

        let pathname: String = "4UYU.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode25(): Unit {
        var expect = 
            ##"[{"name":"Plain scalar with backslashes","from":"@perlpunk","tags":"scalar","yaml":"---\nplain\\value\\with\\backslashes\n","tree":"+STR\n +DOC ---\n  =VAL :plain\\\\value\\\\with\\\\backslashes\n -DOC\n-STR\n","json":"\"plain\\\\value\\\\with\\\\backslashes\"\n","dump":"--- plain\\value\\with\\backslashes\n"}]"##

        let pathname: String = "4V8U.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode26(): Unit {
        var expect = 
            ##"[{"name":"Literal scalars","from":"@ingydotnet","tags":"indent literal","yaml":"- aaa: |2\n    xxx\n  bbb: |\n    xxx\n","tree":"+STR\n +DOC\n  +SEQ\n   +MAP\n    =VAL :aaa\n    =VAL |xxx\\n\n    =VAL :bbb\n    =VAL |xxx\\n\n   -MAP\n  -SEQ\n -DOC\n-STR\n","json":"[\n  {\n    \"aaa\" : \"xxx\\n\",\n    \"bbb\" : \"xxx\\n\"\n  }\n]\n","dump":"---\n- aaa: |\n    xxx\n  bbb: |\n    xxx\n","emit":"- aaa: |\n    xxx\n  bbb: |\n    xxx\n"}]"##

        let pathname: String = "4WA9.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode27(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 5.7. Block Scalar Indicators","from":"http:192.168.11.128#id2773653","tags":"spec literal folded scalar","yaml":"literal: |\n  some\n  text\nfolded: >\n  some\n  text\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :literal\n   =VAL |some\\ntext\\n\n   =VAL :folded\n   =VAL >some text\\n\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"literal\": \"some\\ntext\\n\",\n  \"folded\": \"some text\\n\"\n}\n","dump":"literal: |\n  some\n  text\nfolded: >\n  some text\n"}]"##

        let pathname: String = "5BVJ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode28(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 7.15. Flow Mappings","from":"http:192.168.11.128#id2791018","tags":"spec flow mapping","yaml":"- { one : two , three: four , }\n- {five: six,seven : eight}\n","tree":"+STR\n +DOC\n  +SEQ\n   +MAP {}\n    =VAL :one\n    =VAL :two\n    =VAL :three\n    =VAL :four\n   -MAP\n   +MAP {}\n    =VAL :five\n    =VAL :six\n    =VAL :seven\n    =VAL :eight\n   -MAP\n  -SEQ\n -DOC\n-STR\n","json":"[\n  {\n    \"one\": \"two\",\n    \"three\": \"four\"\n  },\n  {\n    \"five\": \"six\",\n    \"seven\": \"eight\"\n  }\n]\n","dump":"- one: two\n  three: four\n- five: six\n  seven: eight\n"}]"##

        let pathname: String = "5C5M.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode29(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 7.13. Flow Sequence","from":"http:192.168.11.128#id2790506","tags":"spec flow sequence","yaml":"- [ one, two, ]\n- [three ,four]\n","tree":"+STR\n +DOC\n  +SEQ\n   +SEQ []\n    =VAL :one\n    =VAL :two\n   -SEQ\n   +SEQ []\n    =VAL :three\n    =VAL :four\n   -SEQ\n  -SEQ\n -DOC\n-STR\n","json":"[\n  [\n    \"one\",\n    \"two\"\n  ],\n  [\n    \"three\",\n    \"four\"\n  ]\n]\n","dump":"- - one\n  - two\n- - three\n  - four\n"}]"##

        let pathname: String = "5KJE.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode30(): Unit {
        var expect = 
            ##"[{"name":"Colon and adjacent value on next line","from":"@perlpunk","tags":"double flow mapping","yaml":"---\n{ \"foo\"\n  :bar }\n","tree":"+STR\n +DOC ---\n  +MAP {}\n   =VAL \"foo\n   =VAL :bar\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"foo\": \"bar\"\n}\n","dump":"---\n\"foo\": bar\n"}]"##

        let pathname: String = "5MUD.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode31(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 6.9. Separated Comment","from":"http:192.168.11.128#id2780342","tags":"mapping spec comment","yaml":"key:    # Comment\n  value\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :key\n   =VAL :value\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"key\": \"value\"\n}\n","dump":"key: value\n"}]"##

        let pathname: String = "5NYZ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode32(): Unit {
        var expect = 
            ##"[{"name":"Colon at the beginning of adjacent flow scalar","from":"@perlpunk","tags":"flow mapping scalar","yaml":"- { \"key\":value }\n- { \"key\"::value }\n","tree":"+STR\n +DOC\n  +SEQ\n   +MAP {}\n    =VAL \"key\n    =VAL :value\n   -MAP\n   +MAP {}\n    =VAL \"key\n    =VAL ::value\n   -MAP\n  -SEQ\n -DOC\n-STR\n","json":"[\n  {\n    \"key\": \"value\"\n  },\n  {\n    \"key\": \":value\"\n  }\n]\n","dump":"- key: value\n- key: :value\n","emit":"- \"key\": value\n- \"key\": :value\n"}]"##

        let pathname: String = "5T43.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode33(): Unit {
        var expect = 
            ##"[{"name":"Invalid document-start marker in doublequoted tring","from":"@perlpunk","tags":"header double error","fail":true,"yaml":"---\n\"\n---\n\"\n","tree":"+STR\n +DOC ---\n"}]"##

        let pathname: String = "5TRB.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode34(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 6.21. Local Tag Prefix","from":"http:192.168.11.128#id2783499","tags":"local-tag spec directive tag","yaml":"%TAG !m! !my-\n--- # Bulb here\n!m!light fluorescent\n...\n%TAG !m! !my-\n--- # Color here\n!m!light green\n","tree":"+STR\n +DOC ---\n  =VAL <!my-light> :fluorescent\n -DOC ...\n +DOC ---\n  =VAL <!my-light> :green\n -DOC\n-STR\n","json":"\"fluorescent\"\n\"green\"\n"}]"##

        let pathname: String = "5TYM.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode35(): Unit {
        var expect = 
            ##"[{"name":"Sequence on same Line as Mapping Key","from":"@perlpunk","tags":"error sequence mapping","fail":true,"yaml":"key: - a\n     - b\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :key\n"}]"##

        let pathname: String = "5U3A.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode36(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 8.17. Explicit Block Mapping Entries","from":"http:192.168.11.128#id2798425","tags":"explicit-key spec mapping comment literal sequence","yaml":"? explicit key # Empty value\n? |\n  block key\n: - one # Explicit compact\n  - two # block value\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :explicit key\n   =VAL :\n   =VAL |block key\\n\n   +SEQ\n    =VAL :one\n    =VAL :two\n   -SEQ\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"explicit key\": null,\n  \"block key\\n\": [\n    \"one\",\n    \"two\"\n  ]\n}\n","dump":"explicit key:\n? |\n  block key\n: - one\n  - two\n"}]"##

        let pathname: String = "5WE3.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode37(): Unit {
        var expect = 
            ##"[{"name":"Mapping, key and flow sequence item anchors","from":"@perlpunk","tags":"anchor complex-key flow mapping sequence","yaml":"---\n&mapping\n&key [ &item a, b, c ]: value\n","tree":"+STR\n +DOC ---\n  +MAP &mapping\n   +SEQ [] &key\n    =VAL &item :a\n    =VAL :b\n    =VAL :c\n   -SEQ\n   =VAL :value\n  -MAP\n -DOC\n-STR\n","dump":"--- &mapping\n? &key\n- &item a\n- b\n- c\n: value\n"}]"##

        let pathname: String = "6BFJ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode38(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 6.26. Tag Shorthands","from":"http:192.168.11.128#id2785009","tags":"spec tag local-tag","yaml":"%TAG !e! tag:example.com,2000:app/\n---\n- !local foo\n- !!str bar\n- !e!tag%21 baz\n","tree":"+STR\n +DOC ---\n  +SEQ\n   =VAL <!local> :foo\n   =VAL <tag:yaml.org,2002:str> :bar\n   =VAL <tag:example.com,2000:app/tag!> :baz\n  -SEQ\n -DOC\n-STR\n","json":"[\n  \"foo\",\n  \"bar\",\n  \"baz\"\n]\n"}]"##

        let pathname: String = "6CK3.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode39(): Unit {
        var expect = 
            ##"[{"name":"Backslashes in singlequotes","from":"@perlpunk","tags":"scalar single","yaml":"'foo: bar\\': baz'\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL 'foo: bar\\\\\n   =VAL :baz'\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"foo: bar\\\\\": \"baz'\"\n}\n","dump":"'foo: bar\\': baz'\n"}]"##

        let pathname: String = "6H3V.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }




    @TestCase
    func yaml_Decode41(): Unit {
        var expect = 
            ##"[{"name":"Flow sequence without closing bracket","from":"@perlpunk","tags":"error flow sequence","fail":true,"yaml":"---\n[ [ a, b, c ]\n","tree":"+STR\n +DOC ---\n  +SEQ []\n   +SEQ []\n    =VAL :a\n    =VAL :b\n    =VAL :c\n   -SEQ\n"}]"##

        let pathname: String = "6JTT.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode42(): Unit {
        var expect = 
            ##"[{"name":"Tags for Block Objects","from":"NimYAML tests","tags":"mapping sequence tag","yaml":"foo: !!seq\n  - !!str a\n  - !!map\n    key: !!str value\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :foo\n   +SEQ <tag:yaml.org,2002:seq>\n    =VAL <tag:yaml.org,2002:str> :a\n    +MAP <tag:yaml.org,2002:map>\n     =VAL :key\n     =VAL <tag:yaml.org,2002:str> :value\n    -MAP\n   -SEQ\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"foo\": [\n    \"a\",\n    {\n      \"key\": \"value\"\n    }\n  ]\n}\n","dump":"foo: !!seq\n- !!str a\n- !!map\n  key: !!str value\n"}]"##

        let pathname: String = "6JWB.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode43(): Unit {
        var expect = 
            ##"[{"name":"Anchor for empty node","from":"http:192.168.11.128301","tags":"alias anchor","yaml":"---\na: &anchor\nb: *anchor\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :a\n   =VAL &anchor :\n   =VAL :b\n   =ALI *anchor\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"a\": null,\n  \"b\": null\n}\n","dump":"---\na: &anchor\nb: *anchor\n"}]"##

        let pathname: String = "6KGN.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode44(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 6.13. Reserved Directives","from":"http:192.168.11.128#id2781445","tags":"spec directive header double 1.3-err","yaml":"%FOO  bar baz # Should be ignored\n              # with a warning.\n--- \"foo\"\n","tree":"+STR\n +DOC ---\n  =VAL \"foo\n -DOC\n-STR\n","json":"\"foo\"\n","dump":"--- \"foo\"\n"}]"##

        let pathname: String = "6LVF.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode45(): Unit {
        var expect = 
            ##"[{"name":"Aliases in Explicit Block Mapping","from":"NimYAML tests","tags":"alias explicit-key empty-key","yaml":"? &a a\n: &b b\n: *a\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL &a :a\n   =VAL &b :b\n   =VAL :\n   =ALI *a\n  -MAP\n -DOC\n-STR\n","dump":"&a a: &b b\n: *a\n"}]"##

        let pathname: String = "6M2F.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode46(): Unit {
        var expect = 
            ##"[{"name":"Zero-indented sequences in explicit mapping keys","from":"@perlpunk","tags":"explicit-key mapping sequence","yaml":"---\n?\n- a\n- b\n:\n- c\n- d\n","tree":"+STR\n +DOC ---\n  +MAP\n   +SEQ\n    =VAL :a\n    =VAL :b\n   -SEQ\n   +SEQ\n    =VAL :c\n    =VAL :d\n   -SEQ\n  -MAP\n -DOC\n-STR\n","emit":"---\n? - a\n  - b\n: - c\n  - d\n"}]"##

        let pathname: String = "6PBE.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode47(): Unit {
        var expect = 
            ##"[{"name":"Invalid scalar at the end of sequence","from":"@perlpunk","tags":"error mapping sequence","fail":true,"yaml":"key:\n - bar\n - baz\n invalid\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :key\n   +SEQ\n    =VAL :bar\n    =VAL :baz\n"}]"##

        let pathname: String = "6S55.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode48(): Unit {
        var expect = 
            ##"[{"name":"Allowed characters in quoted mapping key","from":"@perlpunk","tags":"mapping single double","yaml":"\"foo\\nbar:baz\\tx \\\\$%^&*()x\": 23\n'x\\ny:z\\tx $%^&*()x': 24\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL \"foo\\nbar:baz\\tx \\\\$%^&*()x\n   =VAL :23\n   =VAL 'x\\\\ny:z\\\\tx $%^&*()x\n   =VAL :24\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"foo\\nbar:baz\\tx \\\\$%^&*()x\": 23,\n  \"x\\\\ny:z\\\\tx $%^&*()x\": 24\n}\n","dump":"? \"foo\\nbar:baz\\tx \\\\$%^&*()x\"\n: 23\n'x\\ny:z\\tx $%^&*()x': 24\n"}]"##

        let pathname: String = "6SLA.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode49(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 2.15. Folded newlines are preserved for \"more indented\" and blank lines","from":"http:192.168.11.128/spec.html#id2761056","tags":"spec folded scalar 1.3-err","yaml":">\n Sammy Sosa completed another\n fine season with great stats.\n\n   63 Home Runs\n   0.288 Batting Average\n\n What a year!\n","tree":"+STR\n +DOC\n  =VAL >Sammy Sosa completed another fine season with great stats.\\n\\n  63 Home Runs\\n  0.288 Batting Average\\n\\nWhat a year!\\n\n -DOC\n-STR\n","json":"\"Sammy Sosa completed another fine season with great stats.\\n\\n  63 Home Runs\\n  0.288 Batting Average\\n\\nWhat a year!\\n\"\n","dump":">\n  Sammy Sosa completed another fine season with great stats.\n\n    63 Home Runs\n    0.288 Batting Average\n\n  What a year!\n"}]"##

        let pathname: String = "6VJK.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }



    @TestCase
    func yaml_Decode51(): Unit {
        var expect = 
            ##"[{"name":"Two document start markers","from":"@perlpunk","tags":"header","yaml":"---\n---\n","tree":"+STR\n +DOC ---\n  =VAL :\n -DOC\n +DOC ---\n  =VAL :\n -DOC\n-STR\n","json":"null\nnull\n","dump":"---\n---\n"}]"##

        let pathname: String = "6XDY.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode52(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 9.6. Stream","from":"http:192.168.11.128/spec.html#id2801896","tags":"spec header 1.3-err","yaml":"Document\n---\n# Empty\n...\n%YAML 1.2\n---\nmatches %: 20\n","tree":"+STR\n +DOC\n  =VAL :Document\n -DOC\n +DOC ---\n  =VAL :\n -DOC ...\n +DOC ---\n  +MAP\n   =VAL :matches %\n   =VAL :20\n  -MAP\n -DOC\n-STR\n","json":"\"Document\"\nnull\n{\n  \"matches %\": 20\n}\n","emit":"Document\n---\n...\n%YAML 1.2\n---\nmatches %: 20\n"}]"##

        let pathname: String = "6ZKB.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode53(): Unit {
        var expect = 
            ##"[{"name":"Node and Mapping Key Anchors [1.3]","from":"U3XV, modified for YAML 1.3","tags":"anchor comment mapping 1.3-mod","yaml":"---\ntop1: &node1\n  &k1 key1: one\ntop2: &node2 # comment\n  key2: two\ntop3:\n  &k3 key3: three\ntop4: &node4\n  &k4 key4: four\ntop5: &node5\n  key5: five\ntop6: &val6\n  six\ntop7:\n  &val7 seven\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :top1\n   +MAP &node1\n    =VAL &k1 :key1\n    =VAL :one\n   -MAP\n   =VAL :top2\n   +MAP &node2\n    =VAL :key2\n    =VAL :two\n   -MAP\n   =VAL :top3\n   +MAP\n    =VAL &k3 :key3\n    =VAL :three\n   -MAP\n   =VAL :top4\n   +MAP &node4\n    =VAL &k4 :key4\n    =VAL :four\n   -MAP\n   =VAL :top5\n   +MAP &node5\n    =VAL :key5\n    =VAL :five\n   -MAP\n   =VAL :top6\n   =VAL &val6 :six\n   =VAL :top7\n   =VAL &val7 :seven\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"top1\": {\n    \"key1\": \"one\"\n  },\n  \"top2\": {\n    \"key2\": \"two\"\n  },\n  \"top3\": {\n    \"key3\": \"three\"\n  },\n  \"top4\": {\n    \"key4\": \"four\"\n  },\n  \"top5\": {\n    \"key5\": \"five\"\n  },\n  \"top6\": \"six\",\n  \"top7\": \"seven\"\n}\n","dump":"---\ntop1: &node1\n  &k1 key1: one\ntop2: &node2\n  key2: two\ntop3:\n  &k3 key3: three\ntop4: &node4\n  &k4 key4: four\ntop5: &node5\n  key5: five\ntop6: &val6 six\ntop7: &val7 seven\n"}]"##

        let pathname: String = "7BMT.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode54(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 2.10. Node for “Sammy Sosa” appears twice in this document","from":"http:192.168.11.128/spec.html#id2760658","tags":"mapping sequence spec alias","yaml":"---\nhr:\n  - Mark McGwire\n  # Following node labeled SS\n  - &SS Sammy Sosa\nrbi:\n  - *SS # Subsequent occurrence\n  - Ken Griffey\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :hr\n   +SEQ\n    =VAL :Mark McGwire\n    =VAL &SS :Sammy Sosa\n   -SEQ\n   =VAL :rbi\n   +SEQ\n    =ALI *SS\n    =VAL :Ken Griffey\n   -SEQ\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"hr\": [\n    \"Mark McGwire\",\n    \"Sammy Sosa\"\n  ],\n  \"rbi\": [\n    \"Sammy Sosa\",\n    \"Ken Griffey\"\n  ]\n}\n","dump":"---\nhr:\n- Mark McGwire\n- &SS Sammy Sosa\nrbi:\n- *SS\n- Ken Griffey\n"}]"##

        let pathname: String = "7BUB.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode55(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 6.24. Verbatim Tags","from":"http:192.168.11.128/spec.html#id2784370","tags":"mapping spec tag unknown-tag","yaml":"!<tag:yaml.org,2002:str> foo :\n  !<!bar> baz\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL <tag:yaml.org,2002:str> :foo\n   =VAL <!bar> :baz\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"foo\": \"baz\"\n}\n","dump":"!!str foo: !bar baz\n"}]"##

        let pathname: String = "7FWL.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode56(): Unit {
        var expect = 
            ##"[{"name":"Multiline double quoted implicit keys","from":"@perlpunk","tags":"error double","fail":true,"yaml":"\"a\\nb\": 1\n\"c\n d\": 1\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL \"a\\nb\n   =VAL :1\n"}]"##

        let pathname: String = "7LBH.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode57(): Unit {
        var expect = 
            ##"[{"name":"Missing colon","from":"@perlpunk","tags":"error mapping","fail":true,"yaml":"top1:\n  key1: val1\ntop2\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :top1\n   +MAP\n    =VAL :key1\n    =VAL :val1\n   -MAP\n"}]"##

        let pathname: String = "7MNF.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode58(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 8.10. Folded Lines - 8.13. Final Empty Lines","from":"http:192.168.11.128/spec.html#id2796543","tags":"spec folded scalar comment 1.3-err","yaml":">\n\n folded\n line\n\n next\n line\n   * bullet\n\n   * list\n   * lines\n\n last\n line\n\n# Comment\n","tree":"+STR\n +DOC\n  =VAL >\\nfolded line\\nnext line\\n  * bullet\\n\\n  * list\\n  * lines\\n\\nlast line\\n\n -DOC\n-STR\n","json":"\"\\nfolded line\\nnext line\\n  * bullet\\n\\n  * list\\n  * lines\\n\\nlast line\\n\"\n","dump":">\n\n  folded line\n\n  next line\n    * bullet\n\n    * list\n    * lines\n\n  last line\n"}]"##

        let pathname: String = "7T8X.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode59(): Unit {
        var expect = 
            ##"[{"name":"Comment in flow sequence before comma","from":"@perlpunk","tags":"comment flow sequence","yaml":"---\n[ word1\n# comment\n, word2]\n","tree":"+STR\n +DOC ---\n  +SEQ []\n   =VAL :word1\n   =VAL :word2\n  -SEQ\n -DOC\n-STR\n","json":"[\n  \"word1\",\n  \"word2\"\n]\n","dump":"---\n- word1\n- word2\n"}]"##

        let pathname: String = "7TMG.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode60(): Unit {
        var expect = 
            ##"[{"name":"Block Mapping with Missing Values","from":"NimYAML tests","tags":"explicit-key mapping","yaml":"? a\n? b\nc:\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :a\n   =VAL :\n   =VAL :b\n   =VAL :\n   =VAL :c\n   =VAL :\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"a\": null,\n  \"b\": null,\n  \"c\": null\n}\n","dump":"a:\nb:\nc:\n"}]"##

        let pathname: String = "7W2P.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode61(): Unit {
        var expect = 
            ##"[{"name":"Bare document after document end marker","from":"@perlpunk","tags":"footer","yaml":"---\nscalar1\n...\nkey: value\n","tree":"+STR\n +DOC ---\n  =VAL :scalar1\n -DOC ...\n +DOC\n  +MAP\n   =VAL :key\n   =VAL :value\n  -MAP\n -DOC\n-STR\n","json":"\"scalar1\"\n{\n  \"key\": \"value\"\n}\n","dump":"--- scalar1\n...\nkey: value\n"}]"##

        let pathname: String = "7Z25.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode62(): Unit {
        var expect = 
            ##"[{"name":"Empty flow collections","from":"@perlpunk","tags":"flow mapping sequence","yaml":"---\nnested sequences:\n- - - []\n- - - {}\nkey1: []\nkey2: {}\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :nested sequences\n   +SEQ\n    +SEQ\n     +SEQ\n      +SEQ []\n      -SEQ\n     -SEQ\n    -SEQ\n    +SEQ\n     +SEQ\n      +MAP {}\n      -MAP\n     -SEQ\n    -SEQ\n   -SEQ\n   =VAL :key1\n   +SEQ []\n   -SEQ\n   =VAL :key2\n   +MAP {}\n   -MAP\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"nested sequences\": [\n    [\n      [\n        []\n      ]\n    ],\n    [\n      [\n        {}\n      ]\n    ]\n  ],\n  \"key1\": [],\n  \"key2\": {}\n}\n","dump":"---\nnested sequences:\n- - - []\n- - - {}\nkey1: []\nkey2: {}\n"}]"##

        let pathname: String = "7ZZ5.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode63(): Unit {
        var expect = 
            ##"[{"name":"Plain mapping key ending with colon","from":"@perlpunk","tags":"mapping scalar","yaml":"---\nkey ends with two colons::: value\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :key ends with two colons::\n   =VAL :value\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"key ends with two colons::\": \"value\"\n}\n","dump":"---\n'key ends with two colons::': value\n"}]"##

        let pathname: String = "8CWC.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode64(): Unit {
        var expect = 
            ##"[{"name":"Multiline plain flow mapping key without value","from":"@perlpunk","tags":"flow mapping","yaml":"---\n- { single line, a: b}\n- { multi\n  line, a: b}\n","tree":"+STR\n +DOC ---\n  +SEQ\n   +MAP {}\n    =VAL :single line\n    =VAL :\n    =VAL :a\n    =VAL :b\n   -MAP\n   +MAP {}\n    =VAL :multi line\n    =VAL :\n    =VAL :a\n    =VAL :b\n   -MAP\n  -SEQ\n -DOC\n-STR\n","json":"[\n  {\n    \"single line\": null,\n    \"a\": \"b\"\n  },\n  {\n    \"multi line\": null,\n    \"a\": \"b\"\n  }\n]\n","dump":"---\n- single line:\n  a: b\n- multi line:\n  a: b\n"}]"##

        let pathname: String = "8KB6.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode65(): Unit {
        var expect = 
            ##"[{"name":"Explicit Non-Specific Tag","from":"NimYAML tests","tags":"tag 1.3-err","yaml":"! a\n","tree":"+STR\n +DOC\n  =VAL <!> :a\n -DOC\n-STR\n","json":"\"a\"\n"}]"##

        let pathname: String = "8MK2.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode66(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 7.14. Flow Sequence Entries","from":"http:192.168.11.128/spec.html#id2790726","tags":"spec flow sequence","yaml":"[\n\"double\n quoted\", 'single\n           quoted',\nplain\n text, [ nested ],\nsingle: pair,\n]\n","tree":"+STR\n +DOC\n  +SEQ []\n   =VAL \"double quoted\n   =VAL 'single quoted\n   =VAL :plain text\n   +SEQ []\n    =VAL :nested\n   -SEQ\n   +MAP {}\n    =VAL :single\n    =VAL :pair\n   -MAP\n  -SEQ\n -DOC\n-STR\n","json":"[\n  \"double quoted\",\n  \"single quoted\",\n  \"plain text\",\n  [\n    \"nested\"\n  ],\n  {\n    \"single\": \"pair\"\n  }\n]\n","dump":"- \"double quoted\"\n- 'single quoted'\n- plain text\n- - nested\n- single: pair\n"}]"##

        let pathname: String = "8UDB.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode67(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 7.14. Flow Sequence Entries","from":"http:192.168.11.128/spec.html#id2790726","tags":"spec flow sequence","yaml":"[\n\"double\n quoted\", 'single\n           quoted',\nplain\n text, [ nested ],\nsingle: pair,\n]\n","tree":"+STR\n +DOC\n  +SEQ []\n   =VAL \"double quoted\n   =VAL 'single quoted\n   =VAL :plain text\n   +SEQ []\n    =VAL :nested\n   -SEQ\n   +MAP {}\n    =VAL :single\n    =VAL :pair\n   -MAP\n  -SEQ\n -DOC\n-STR\n","json":"[\n  \"double quoted\",\n  \"single quoted\",\n  \"plain text\",\n  [\n    \"nested\"\n  ],\n  {\n    \"single\": \"pair\"\n  }\n]\n","dump":"- \"double quoted\"\n- 'single quoted'\n- plain text\n- - nested\n- single: pair\n"}]"##

        let pathname: String = "8UDB.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode68(): Unit {
        var expect = 
            ##"[{"name":"Comment in plain multiline value","from":"https://gist.github.com/anonymous/deeb1ace28d5bf21fb56d80c13e2dc69 via @ingydotnet","tags":"error comment scalar","fail":true,"yaml":"key: word1\n#  xxx\n  word2\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :key\n   =VAL :word1\n"}]"##

        let pathname: String = "8XDJ.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode69(): Unit {
        var expect = 
            ##"[{"name":"Anchor with unicode character","from":"https://github.com/yaml/pyyaml/issues/94","tags":"anchor","yaml":"---\n- &😁 unicode anchor\n","tree":"+STR\n +DOC ---\n  +SEQ\n   =VAL &😁 :unicode anchor\n  -SEQ\n -DOC\n-STR\n","json":"[\n  \"unicode anchor\"\n]\n","dump":"---\n- &😁 unicode anchor\n"}]"##

        let pathname: String = "8XYN.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString().replace("\\u0026", "&"))
        @Assert(jv.toString().replace("\\u0026", "&"),expect)
    }

    @TestCase
    func yaml_Decode71(): Unit {
        var expect = 
            ##"[{"name":"Multiline doublequoted flow mapping key without value","from":"@perlpunk","tags":"double flow mapping","yaml":"---\n- { \"single line\", a: b}\n- { \"multi\n  line\", a: b}\n","tree":"+STR\n +DOC ---\n  +SEQ\n   +MAP {}\n    =VAL \"single line\n    =VAL :\n    =VAL :a\n    =VAL :b\n   -MAP\n   +MAP {}\n    =VAL \"multi line\n    =VAL :\n    =VAL :a\n    =VAL :b\n   -MAP\n  -SEQ\n -DOC\n-STR\n","json":"[\n  {\n    \"single line\": null,\n    \"a\": \"b\"\n  },\n  {\n    \"multi line\": null,\n    \"a\": \"b\"\n  }\n]\n","dump":"---\n- \"single line\":\n  a: b\n- \"multi line\":\n  a: b\n"}]"##

        let pathname: String = "9BXH.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode72(): Unit {
        var expect = 
            ##"[{"name":"Wrong indented flow sequence","from":"@perlpunk","tags":"error flow indent sequence","fail":true,"yaml":"---\nflow: [a,\nb,\nc]\n","tree":"+STR\n +DOC ---\n  +MAP\n   =VAL :flow\n   +SEQ []\n    =VAL :a\n"}]"##

        let pathname: String = "9C9N.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode73(): Unit {
        var expect = 
            ##"[{"name":"Invalid scalar at the end of mapping","from":"@perlpunk","tags":"error mapping sequence","fail":true,"yaml":"key:\n - item1\n - item2\ninvalid\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :key\n   +SEQ\n    =VAL :item1\n    =VAL :item2\n   -SEQ\n"}]"##

        let pathname: String = "9CWY.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode74(): Unit {
        var expect = 
            ##"[{"name":"Spec Example 9.6. Stream [1.3]","from":"6ZKB, modified for YAML 1.3","tags":"spec header 1.3-mod","yaml":"Mapping: Document\n---\n# Empty\n...\n%YAML 1.2\n---\nmatches %: 20\n","tree":"+STR\n +DOC\n  +MAP\n   =VAL :Mapping\n   =VAL :Document\n  -MAP\n -DOC\n +DOC ---\n  =VAL :\n -DOC ...\n +DOC ---\n  +MAP\n   =VAL :matches %\n   =VAL :20\n  -MAP\n -DOC\n-STR\n","json":"{\n  \"Mapping\": \"Document\"\n}\nnull\n{\n  \"matches %\": 20\n}\n","emit":"Mapping: Document\n---\n...\n%YAML 1.2\n---\nmatches %: 20\n"}]"##

        let pathname: String = "9DXL.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toString(),expect)
    }

    @TestCase
    func yaml_Decode75(): Unit {
        var expect = 
            ##"[
  {
    "name": "Multi-level Mapping Indent",
    "from": "https://github.com/ingydotnet/yaml-pegex-pm/blob/master/test/indent.tml",
    "tags": "mapping indent",
    "yaml": "a:\n  b:\n    c: d\n  e:\n    f: g\nh: i\n",
    "tree": "+STR\n +DOC\n  +MAP\n   =VAL :a\n   +MAP\n    =VAL :b\n    +MAP\n     =VAL :c\n     =VAL :d\n    -MAP\n    =VAL :e\n    +MAP\n     =VAL :f\n     =VAL :g\n    -MAP\n   -MAP\n   =VAL :h\n   =VAL :i\n  -MAP\n -DOC\n-STR\n",
    "json": "{\n  \"a\": {\n    \"b\": {\n      \"c\": \"d\"\n    },\n    \"e\": {\n      \"f\": \"g\"\n    }\n  },\n  \"h\": \"i\"\n}\n"
  }
]"##
        let pathname: String = "9FMG.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString(),expect)
    }

    @TestCase
    func yaml_Decode76(): Unit {
        var expect = 
            ##"[
  {
    "name": "Need document footer before directives",
    "from": "@ingydotnet",
    "tags": "directive error footer tag unknown-tag",
    "fail": true,
    "yaml": "!foo \"bar\"\n%TAG ! tag:example.com,2000:app/\n---\n!foo \"bar\"\n",
    "tree": "+STR\n +DOC\n  =VAL <!foo> \"bar\n"
  }
]"##

        let pathname: String = "9HCY.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString(),expect)
    }

}
