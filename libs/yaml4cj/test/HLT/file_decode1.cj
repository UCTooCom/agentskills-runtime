// 3rd_party_lib:yaml4cj/build/yaml4cj
// data_file:file_26.yaml:file_27.yaml:file_30.yaml:file_31.yaml:file_32.yaml:file_35.yaml:file_40.yaml:file_42.yaml:file_43.yaml:file_44.yaml:file_45.yaml:file_46.yaml:file_51.yaml:file_53.yaml:file_54.yaml:file_56.yaml:file_57.yaml
// data_file:file_1.yaml:file_2.yaml:file_4.yaml:file_5.yaml:file_6.yaml:file_7.yaml:file_9.yaml:file_12.yaml:file_13.yaml:file_15.yaml:file_16.yaml:file_18.yaml:file_19.yaml:file_21.yaml:file_25.yaml 
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
    func yaml_Decode02(): Unit { 
        var expect = 
            ##"[
    {
        "name": "Empty Lines Between Mapping Elements",
        "from": "NimYAML tests",
        "tags": "whitespace mapping",
        "yaml": "one: 2\n\n\nthree: 4\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :one\n   =VAL :2\n   =VAL :three\n   =VAL :4\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"one\": 2,\n  \"three\": 4\n}\n",
        "dump": "one: 2\nthree: 4\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_2.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode04(): Unit {
        var expect = 
            ##"[
    {
        "name": "Tab after document header",
        "from": "@perlpunk",
        "tags": "header whitespace",
        "yaml": "---»scalar\n",
        "tree": "+STR\n +DOC ---\n  =VAL :scalar\n -DOC\n-STR\n",
        "json": "\"scalar\"\n",
        "dump": "--- scalar\n...\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_4.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode05(): Unit { //有缺陷
        var expect = 
            ##"[
    {
        "name": "Spec Example 6.6. Line Folding",
        "from": "http:192.168.11.128#id2779289",
        "tags": "folded spec whitespace scalar 1.3-err",
        "yaml": ">-\n  trimmed\n\n\n  as\n  space\n",
        "tree": "+STR\n +DOC\n  =VAL >trimmed\\n\\n\\nas space\n -DOC\n-STR\n",
        "json": "\"trimmed\\n\\n\\nas space\"\n",
        "dump": ">-\n  trimmed\n\n\n\n  as space\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_5.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode06(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 8.6. Empty Scalar Chomping",
        "from": "http:192.168.11.128#id2795596",
        "tags": "spec folded literal whitespace",
        "yaml": "strip: >-\n\nclip: >\n\nkeep: |+\n↵\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :strip\n   =VAL >\n   =VAL :clip\n   =VAL >\n   =VAL :keep\n   =VAL |\\n\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"strip\": \"\",\n  \"clip\": \"\",\n  \"keep\": \"\\n\"\n}\n",
        "dump": "strip: \"\"\nclip: \"\"\nkeep: |2+\n\n...\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_6.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode07(): Unit {
        var expect = 
            ##"[
    {
        "name": "Inline tabs in double quoted",
        "from": "@ingydotnet",
        "tags": "double whitespace",
        "yaml": "\"1 inline\\ttab\"\n",
        "tree": "+STR\n +DOC\n  =VAL \"1 inline\\ttab\n -DOC\n-STR\n",
        "json": "\"1 inline\\ttab\"\n"
    },
    {
        "yaml": "\"2 inline\\——»tab\"\n",
        "tree": "+STR\n +DOC\n  =VAL \"2 inline\\ttab\n -DOC\n-STR\n",
        "json": "\"2 inline\\ttab\"\n",
        "dump": "\"2 inline\\ttab\"\n"
    },
    {
        "yaml": "\"3 inline———»tab\"\n",
        "tree": "+STR\n +DOC\n  =VAL \"3 inline\\ttab\n -DOC\n-STR\n",
        "json": "\"3 inline\\ttab\"\n",
        "dump": "\"3 inline\\ttab\"\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_7.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode09(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 8.7. Literal Scalar",
        "from": "http:192.168.11.128#id2795789",
        "tags": "spec literal scalar whitespace 1.3-err",
        "yaml": "|\n literal\n ——»text\n↵\n↵\n",
        "tree": "+STR\n +DOC\n  =VAL |literal\\n\\ttext\\n\n -DOC\n-STR\n",
        "json": "\"literal\\n\\ttext\\n\"\n",
        "dump": "|\n  literal\n  —»text\n"
    }
]"##
        var a = expect.replace(" ", "")

        //println(a)
        let pathname: String = "file_9.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode12(): Unit {
        var expect = 
            ##"[
    {
        "name": "Directive variants",
        "from": "@ingydotnet",
        "tags": "directive",
        "also": "ZYU8",
        "fail": true,
        "yaml": "%YAML 1.1#...\n---\n",
        "tree": "+STR\n"
    },
    {
        "fail": true,
        "yaml": "%YAML 1.2\n---\n%YAML 1.2\n---\n",
        "dump": null
    },
    {
        "yaml": "%YAML  1.1\n---\n",
        "tree": "+STR\n +DOC ---\n  =VAL :\n -DOC\n-STR\n",
        "json": "null\n",
        "dump": "---\n"
    },
    {
        "yaml": "%YAML ——» 1.1\n---\n"
    },
    {
        "yaml": "%YAML 1.1  # comment\n---\n"
    },
    {
        "note": "These 2 are reserved directives",
        "yaml": "%YAM 1.1\n---\n"
    },
    {
        "yaml": "%YAMLL 1.1\n---\n"
    }
]"##
        var a = expect.replace(" ", "")

        //println(a)
        let pathname: String = "file_12.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode13(): Unit {
        var expect = 
            ##"[
    {
        "name": "Block Scalar Strip",
        "from": "NimYAML tests",
        "tags": "literal scalar whitespace 1.3-err",
        "yaml": "|-\n ab\n\u2423\n\u2423\n...\n",
        "tree": "+STR\n +DOC\n  =VAL |ab\n -DOC ...\n-STR\n",
        "json": "\"ab\"\n",
        "dump": "|-\n  ab\n...\n"
    }
]"##
        var c = '\u{2423}'.toString()
        println(c)
        var a = expect.replace(" ", "").replace(##"\u2423"##, c)
        println(a)
        let pathname: String = "file_13.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode15(): Unit {
        var expect = 
            ##"[
    {
        "name": "Multiline plain value with tabs on empty lines",
        "from": "@perlpunk",
        "tags": "scalar whitespace",
        "yaml": "key:\n  value\n  with\n  —»\n  tabs\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :key\n   =VAL :value with\\ntabs\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"key\": \"value with\\ntabs\"\n}\n",
        "dump": "key: 'value with\n\n  tabs'\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_15.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode016(): Unit {
        var expect = 
            ##"[
    {
        "name": "Empty Lines at End of Document",
        "from": "NimYAML tests",
        "tags": "empty-key whitespace",
        "yaml": ":\n↵\n↵\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :\n   =VAL :\n  -MAP\n -DOC\n-STR\n",
        "emit": ":\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_16.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode18(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 8.1. Block Scalar Header",
        "from": "http:192.168.11.128#id2793888",
        "tags": "spec literal folded comment scalar",
        "yaml": "- | # Empty header↓\n literal\n- >1 # Indentation indicator↓\n  folded\n- |+ # Chomping indicator↓\n keep\n\n- >1- # Both indicators↓\n  strip\n",
        "tree": "+STR\n +DOC\n  +SEQ\n   =VAL |literal\\n\n   =VAL > folded\\n\n   =VAL |keep\\n\\n\n   =VAL > strip\n  -SEQ\n -DOC\n-STR\n",
        "json": "[\n  \"literal\\n\",\n  \" folded\\n\",\n  \"keep\\n\\n\",\n  \" strip\"\n]\n",
        "dump": "- |\n  literal\n- >2\n   folded\n- |+\n  keep\n\n- >2-\n   strip\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_18.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode19(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 6.11. Multi-Line Comments",
        "from": "http:192.168.11.128#id2780696",
        "tags": "spec comment",
        "yaml": "key:    # Comment\n        # lines\n  value\n↵\n↵\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :key\n   =VAL :value\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"key\": \"value\"\n}\n",
        "dump": "key: value\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_19.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode21(): Unit {
        var expect = 
            ##"[
    {
        "name": "Tab at beginning of line followed by a flow mapping",
        "from": "IRC",
        "tags": "flow whitespace",
        "yaml": "———»{}\n",
        "tree": "+STR\n +DOC\n  +MAP {}\n  -MAP\n -DOC\n-STR\n",
        "json": "{}\n",
        "dump": "{}\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_21.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode25(): Unit {
        var expect = 
            ##"[
    {
        "name": "Single character streams",
        "from": "@ingydotnet",
        "tags": "sequence",
        "yaml": "-∎\n",
        "tree": "+STR\n +DOC\n  +SEQ\n   =VAL :\n  -SEQ\n -DOC\n-STR\n",
        "json": "[null]\n",
        "dump": "-\n"
    },
    {
        "tags": "mapping",
        "yaml": ":∎\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :\n   =VAL :\n  -MAP\n -DOC\n-STR\n",
        "json": null,
        "dump": ":\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_25.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode26(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 7.9. Single Quoted Lines [1.3]",
        "from": "PRH3, modified for YAML 1.3",
        "tags": "single spec scalar whitespace 1.3-mod",
        "yaml": "---\n' 1st non-empty\n 3rd non-empty '\n",
        "tree": "+STR\n +DOC ---\n -DOC\n-STR\n",
        "json": "\" 1st non-empty\\n2nd non-empty 3rd non-empty \"\n",
        "dump": "' 1st non-empty\n\n  2nd non-empty 3rd non-empty '\n",
        "emit": "--- ' 1st non-empty\n\n  2nd non-empty 3rd non-empty '\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_26.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode27(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 8.7. Literal Scalar [1.3]",
        "from": "M9B4, modified for YAML 1.3",
        "tags": "spec literal scalar whitespace 1.3-mod",
        "yaml": "--- |\n literal\n ——»text\n↵\n↵\n",
        "tree": "+STR\n +DOC ---\n  =VAL |literal\\n\\ttext\\n\n -DOC\n-STR\n",
        "json": "\"literal\\n\\ttext\\n\"\n",
        "dump": "\"literal\\n\\ttext\\n\"\n",
        "emit": "--- |\n  literal\n  —»text\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_27.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode30(): Unit { //有缺陷
        var expect = 
            ##"[
    {
        "name": "Folded Block Scalar",
        "from": "NimYAML tests",
        "tags": "folded scalar 1.3-err",
        "tree": "+STR\n +DOC\n  =VAL >ab cd\\nef\\n\\ngh\\n\n -DOC\n-STR\n",
        "json": "\"ab cd\\nef\\n\\ngh\\n\"\n",
        "dump": ">\n  ab cd\n\n  ef\n\n\n  gh\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_30.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode31(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 6.16. “TAG” directive",
        "from": "http:192.168.11.128#id2782252",
        "tags": "spec header tag",
        "yaml": "%TAG !yaml! tag:yaml.org,2002:\n---\n!yaml!str \"foo\"\n",
        "tree": "+STR\n +DOC ---\n  =VAL <tag:yaml.org,2002:str> \"foo\n -DOC\n-STR\n",
        "json": "\"foo\"\n",
        "dump": "--- !!str \"foo\"\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_31.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode32(): Unit {
        var expect = 
            ##"[
    {
        "name": "Legal tab after indentation",
        "from": "@ingydotnet",
        "tags": "indent whitespace",
        "yaml": "x:\n - x\n  ——»x\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :x\n   +SEQ\n    =VAL :x x\n   -SEQ\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"x\": [\n    \"x x\"\n  ]\n}\n",
        "dump": "x:\n- x x\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_32.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode35(): Unit {
        var expect = 
            ##"[
    {
        "name": "Tabs in various contexts",
        "from": "@ingydotnet",
        "tags": "whitespace",
        "fail": true,
        "yaml": "foo: |\n————»\nbar: 1\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :foo\n"
    },
    {
        "yaml": "foo: |\n ———»\nbar: 1\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :foo\n   =VAL |\\t\\n\n   =VAL :bar\n   =VAL :1\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"foo\": \"\\t\\n\",\n  \"bar\": 1\n}\n",
        "dump": "foo: |\n  ———»\nbar: 1\n"
    },
    {
        "yaml": "- [\n————»\n foo\n ]\n",
        "tree": "+STR\n +DOC\n  +SEQ\n   +SEQ []\n    =VAL :foo\n   -SEQ\n  -SEQ\n -DOC\n-STR\n",
        "json": "[\n  [\n    \"foo\"\n  ]\n]\n",
        "dump": "- - foo\n"
    },
    {
        "fail": true,
        "yaml": "- [\n————»foo,\n foo\n ]\n",
        "tree": "+STR\n +DOC\n  +SEQ\n   +SEQ []\n",
        "json": null
    },
    {
        "fail": true,
        "yaml": "-———»-\n"
    },
    {
        "fail": true,
        "yaml": "- ——»-\n"
    },
    {
        "fail": true,
        "yaml": "?———»-\n"
    },
    {
        "fail": true,
        "yaml": "? -\n:———»-\n"
    },
    {
        "fail": true,
        "yaml": "?———»key:\n"
    },
    {
        "fail": true,
        "yaml": "? key:\n:———»key:\n"
    },
    {
        "yaml": "-———»-1\n",
        "tree": "+STR\n +DOC\n  +SEQ\n   =VAL :-1\n  -SEQ\n -DOC\n-STR\n",
        "json": "[\n  -1\n]\n",
        "dump": "- -1\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_35.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode40(): Unit {
        var expect = 
            ##"[
    {
        "name": "Leading tab content in literals",
        "from": "@ingydotnet",
        "tags": "indent literal whitespace",
        "yaml": "foo: |-\n ——»bar\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :foo\n   =VAL |\\tbar\n  -MAP\n -DOC\n-STR\n",
        "json": "{\"foo\":\"\\tbar\"}\n",
        "dump": "foo: |-\n  ——»bar\n"
    },
    {
        "yaml": "foo: |-\n ——»bar∎\n"
    }
]"##
        var a = expect.replace(" ", "")

        //println(a)
        let pathname: String = "file_40.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode42(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 6.2. Indentation Indicators",
        "from": "http:192.168.11.128#id2778101",
        "tags": "explicit-key spec libyaml-err indent whitespace sequence upto-1.2",
        "yaml": "? a\n: -»b\n  -  -—»c\n     - d\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :a\n   +SEQ\n    =VAL :b\n    +SEQ\n     =VAL :c\n     =VAL :d\n    -SEQ\n   -SEQ\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"a\": [\n    \"b\",\n    [\n      \"c\",\n      \"d\"\n    ]\n  ]\n}\n",
        "dump": "a:\n- b\n- - c\n  - d\n"
    }
]"##
        var a = expect.replace(" ", "")

        //println(a)
        let pathname: String = "file_42.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode43(): Unit {
        var expect = 
            ##"[
    {
        "name": "Empty Stream",
        "from": "http:192.168.11.128",
        "tags": "edge",
        "yaml": "∎\n",
        "tree": "+STR\n-STR\n",
        "json": ""
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_43.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode44(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 8.9. Folded Scalar [1.3]",
        "from": "G992, modified for YAML 1.3",
        "tags": "spec folded scalar 1.3-mod",
        "yaml": "--- >\n folded\n text\n↵\n↵\n",
        "tree": "+STR\n +DOC ---\n  =VAL >folded text\\n\n -DOC\n-STR\n",
        "json": "\"folded text\\n\"\n",
        "dump": ">\n  folded text\n",
        "emit": "--- >\n  folded text\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_44.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode45(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 6.14. “YAML” directive",
        "from": "http:192.168.11.128#id2781929",
        "tags": "spec directive",
        "yaml": "%YAML 1.3 # Attempt parsing\n          # with a warning\n---\n\"foo\"\n",
        "tree": "+STR\n +DOC ---\n  =VAL \"foo\n -DOC\n-STR\n",
        "json": "\"foo\"\n",
        "dump": "--- \"foo\"\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_45.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode46(): Unit {
        var expect = 
            ##"[
    {
        "name": "Various trailing tabs",
        "from": "@perlpunk",
        "tags": "comment whitespace",
        "yaml": "a: b———»\nseq:———»\n - a———»\nc: d———»#X\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :a\n   =VAL :b\n   =VAL :seq\n   +SEQ\n    =VAL :a\n   -SEQ\n   =VAL :c\n   =VAL :d\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"a\": \"b\",\n  \"seq\": [\n    \"a\"\n  ],\n  \"c\": \"d\"\n}\n",
        "dump": "a: b\nseq:\n- a\nc: d\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_46.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }


    @TestCase
    func yaml_Decode53(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 2.17. Quoted Scalars",
        "from": "http:192.168.11.128#id2761245",
        "tags": "spec scalar",
        "yaml": "unicode: \"Sosa did fine.\\u263A\"\ncontrol: \"\\b1998\\t1999\\t2000\\n\"\nhex esc: \"\\x0d\\x0a is \\r\\n\"\n\nsingle: '\"Howdy!\" he cried.'\nquoted: ' # Not a ''comment''.'\ntie-fighter: '|\\-*-/|'\n",
        "tree": "+STR\n +DOC\n  +MAP\n   =VAL :unicode\n   =VAL \"Sosa did fine.☺\n   =VAL :control\n   =VAL \"\\b1998\\t1999\\t2000\\n\n   =VAL :hex esc\n   =VAL \"\\r\\n is \\r\\n\n   =VAL :single\n   =VAL '\"Howdy!\" he cried.\n   =VAL :quoted\n   =VAL ' # Not a 'comment'.\n   =VAL :tie-fighter\n   =VAL '|\\\\-*-/|\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"unicode\": \"Sosa did fine.☺\",\n  \"control\": \"\\b1998\\t1999\\t2000\\n\",\n  \"hex esc\": \"\\r\\n is \\r\\n\",\n  \"single\": \"\\\"Howdy!\\\" he cried.\",\n  \"quoted\": \" # Not a 'comment'.\",\n  \"tie-fighter\": \"|\\\\-*-/|\"\n}\n",
        "dump": "unicode: \"Sosa did fine.\\u263A\"\ncontrol: \"\\b1998\\t1999\\t2000\\n\"\nhex esc: \"\\r\\n is \\r\\n\"\nsingle: '\"Howdy!\" he cried.'\nquoted: ' # Not a ''comment''.'\ntie-fighter: '|\\-*-/|'\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_53.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode54(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 8.9. Folded Scalar",
        "from": "http:192.168.11.128#id2796371",
        "tags": "spec folded scalar 1.3-err",
        "yaml": ">\n folded\n text\n↵\n↵\n",
        "tree": "+STR\n +DOC\n  =VAL >folded text\\n\n -DOC\n-STR\n",
        "json": "\"folded text\\n\"\n",
        "dump": ">\n  folded text\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_54.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode56(): Unit {
        var expect = 
            ##"[
    {
        "name": "Literal unicode",
        "from": "@perlpunk",
        "tags": "scalar",
        "yaml": "---\nwanted: love ♥ and peace ☮\n",
        "tree": "+STR\n +DOC ---\n  +MAP\n   =VAL :wanted\n   =VAL :love ♥ and peace ☮\n  -MAP\n -DOC\n-STR\n",
        "json": "{\n  \"wanted\": \"love ♥ and peace ☮\"\n}\n",
        "dump": "---\nwanted: \"love \\u2665 and peace \\u262E\"\n"
    }
]"##
        var a = expect.replace(" ", "")
        let pathname: String = "file_56.yaml"
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toJsonString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

    @TestCase
    func yaml_Decode57(): Unit {
        var expect = 
            ##"[
    {
        "name": "Spec Example 7.12. Plain Lines",
        "from": "http:192.168.11.128#id2789986",
        "tags": "spec scalar whitespace upto-1.2",
        "yaml": "1st non-empty\n",
        "tree": "+STR\n +DOC\n  =VAL :1st non-empty\\n2nd non-empty 3rd non-empty\n -DOC\n-STR\n",
        "json": "\"1st non-empty\\n2nd non-empty 3rd non-empty\"\n",
        "dump": "'1st non-empty\n\n  2nd non-empty 3rd non-empty'\n"
    }
]"##
        var a = expect.replace(" ", "")
        println(a)
        let pathname: String = "file_57.yaml"
        println(pathname)
        var fs: File = File(pathname, ReadWrite)
        var res: Array<UInt8> = File.readFrom(pathname)
        var jv = decode(res)
        println(jv.toString())
        @Assert(jv.toJsonString().replace(" ",""),a)
    }

}
