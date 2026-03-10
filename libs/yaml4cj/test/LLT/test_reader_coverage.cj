// DEPENDENCE: test_reader_coverage.yaml
// DEPENDENCE: test_decode_exception.yaml
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
import yaml4cj.yaml.*
import std.env.*
import std.fs.*
import stdx.encoding.json.*

//func decode(data: Array<UInt8>): JsonValue
//func decode(data: Array<UInt8>, strict: Bool): JsonValue
//func encode(input: JsonValue): Array<UInt8>
main() {
    var path: String = getWorkingDirectory().toString()
    let pathname: String = "${path}/test_reader_coverage.yaml"
    var fs: File = File(pathname, ReadWrite)
    if (fs.canRead()) {
        var res: Array<UInt8> = File.readFrom(pathname)
        fs.close()
        var jv = decode(res)

        // println(jv.toString())
        decode("# l: !!map {    ? &A1 !!str \"foo\"   : !!str \"bar\",    ? !!str &A2 \"baz\"   : *a1}".toArray())
    } else {
        println("open fail")
    }

    testDecode(
        [
            0x6C,
            0x3A,
            0x20,
            0x21,
            0x21,
            0x6D,
            0x61,
            0x70,
            0x20,
            0x7B,
            0x0A,
            0x20,
            0x20,
            0x20,
            0x3F,
            0x20,
            0x26,
            0x41,
            0x31,
            0x20,
            0x21,
            0x21,
            0x73,
            0x74,
            0x72,
            0x20,
            0x22,
            0x66,
            0x6F,
            0x6F,
            0x22,
            0x20,
            0x20,
            0x20,
            0x3A,
            0x20,
            0x21,
            0x21,
            0x73,
            0x74,
            0x72,
            0x20,
            0x22,
            0x62,
            0x61,
            0x72,
            0x22,
            0x2C,
            0x0A,
            0x20,
            0x20,
            0x20,
            0x3F,
            0x20,
            0x21,
            0x21,
            0x73,
            0x74,
            0x72,
            0x20,
            0x26,
            0x41,
            0x32,
            0x20,
            0x22,
            0x62,
            0x61,
            0x7A,
            0x22,
            0x20,
            0x20,
            0x20,
            0x3A,
            0x20,
            0x2A,
            0x61,
            0x31,
            0x0A,
            0x7D
        ]
    )

    testDecode(
        [
            0x61,
            0x3A,
            0x20,
            0xF8,
            0x62
        ]
    )

    testDecode(
        [
            0x61,
            0x3A,
            0x20,
            0x31,
            0x0A,
            0x62,
            0x3A,
            0x20,
            0x30,
            0x2E,
            0x30,
            0xC2,
            0x85,
            0x63,
            0x3A,
            0x20,
            0x66,
            0x61,
            0x6C,
            0x73,
            0x65,
            0xE2,
            0x80,
            0xA8,
            0x64,
            0x3A,
            0x20,
            0x27,
            0xE4,
            0xBB,
            0x93,
            0xE9,
            0xA2,
            0x89,
            0x27
        ]
    )

    testDecode(
        [
            0x61,
            0x3A,
            0x20,
            0xF8
        ]
    )

    testDecode([0x25, 0x21])

    testDecode([0x25, 0x54, 0x41, 0x21])

    testDecode([0x25, 0x59, 0x41, 0x4D, 0x4C, 0x20, 0x20, 0x31])

    testDecode([0x25, 0x59, 0x41, 0x4D, 0x4C, 0x20, 0x20, 0x31, 0x2E, 0x31, 0x31, 0x31])

    testDecode([0x25, 0x54, 0x41, 0x47])

    testDecode([0x25, 0x54, 0x41, 0x47, 0x20, 0x21, 0x74, 0x61, 0x67, 0x3A])

    testDecode(
        [
            0x25,
            0x54,
            0x41,
            0x47,
            0x20,
            0x21,
            0x20,
            0x74,
            0x61,
            0x67,
            0x3A,
            0x63,
            0x6C,
            0x61,
            0x72,
            0x6B,
            0x65,
            0x76,
            0x61,
            0x6E,
            0x73,
            0x2E,
            0x63,
            0x6F,
            0x6D,
            0x2C,
            0x32,
            0x30,
            0x30,
            0x32,
            0x3A
        ]
    )

    testDecode("%TAG !yaml! tag:yaml.org,2002:".toArray())

    testDecode("%TAH !yaml!".toArray())

    testDecode("%TAG !yaml! tag:yaml.org,2002:     #仓颉".toArray())

    testDecode("%TAG !yaml! tag:yaml.org,2002:   1".toArray())

    testDecode("%TAG !foo! tag:example.com,2015:app/仓颉".toArray())

    testDecode("%TAG !foo! 仓颉".toArray())

    testDecode(
        [
            0x0A,
            0x61,
            0x3A,
            0x20,
            0x26,
            0x61,
            0x20,
            0x20,
            0x62,
            0x3A,
            0x20,
            0x31,
            0x0A,
            0x20,
            0x20,
            0x63,
            0x3A,
            0x20,
            0x66,
            0x61,
            0x6C,
            0x73,
            0x65
        ]
    )

    testDecode(
        [
            0x0A,
            0x61,
            0x3A,
            0x20,
            0x26,
            0x0A,
            0x20,
            0x20,
            0x62,
            0x3A,
            0x20,
            0x31,
            0x0A,
            0x20,
            0x20,
            0x63,
            0x3A,
            0x20,
            0x66,
            0x61,
            0x6C,
            0x73,
            0x65
        ]
    )

    testDecode([0x61, 0x3A, 0x20, 0x26])

    testDecode(
        [
            0x21,
            0x3C,
            0x74,
            0x61,
            0x67,
            0x3A,
            0x63,
            0x6C,
            0x61,
            0x72,
            0x6B,
            0x65,
            0x76,
            0x61,
            0x6E,
            0x73,
            0x2E,
            0x63,
            0x6F,
            0x6D,
            0x2C,
            0x32,
            0x30,
            0x30,
            0x32,
            0x3A,
            0x69,
            0x6E,
            0x76,
            0x6F,
            0x69,
            0x63,
            0x65
        ]
    )

    testDecode(
        [
            0x21,
            0x3C,
            0x74,
            0x61,
            0x67,
            0x3A,
            0x63,
            0x6C,
            0x61,
            0x72,
            0x6B,
            0x65,
            0x76,
            0x61,
            0x6E,
            0x73,
            0x2E,
            0x63,
            0x6F,
            0x6D,
            0x2C,
            0x32,
            0x30,
            0x30,
            0x32,
            0x3A,
            0x69,
            0x6E,
            0x76,
            0x6F,
            0x69,
            0x63,
            0x65,
            0x3E,
            0x31
        ]
    )

    testDecode(
        [
            0x0A,
            0x74,
            0x69,
            0x74,
            0x6C,
            0x65,
            0x3A,
            0x20,
            0x3E,
            0x2D,
            0x0A,
            0xE2,
            0x80,
            0xA2,
            0xE2,
            0x80,
            0xA2,
            0x59,
            0x41,
            0x4D,
            0x4C,
            0x27,
            0x73,
            0x20,
            0x46,
            0x6F,
            0x6C,
            0x64,
            0x65,
            0x64,
            0x20,
            0x42,
            0x6C,
            0x6F,
            0x63,
            0x6B,
            0x20,
            0x53,
            0x63,
            0x61,
            0x6C,
            0x61,
            0x72,
            0x73,
            0x3A,
            0x0A,
            0xE2,
            0x80,
            0xA2,
            0xE2,
            0x80,
            0xA2,
            0x41,
            0x20,
            0x57,
            0x61,
            0x79,
            0x20,
            0x74,
            0x6F,
            0x20,
            0x41,
            0x76,
            0x6F,
            0x69,
            0x64,
            0x20,
            0x51,
            0x75,
            0x6F,
            0x74,
            0x69,
            0x6E,
            0x67,
            0x20,
            0x4D,
            0x6F,
            0x73,
            0x74,
            0x20,
            0x53,
            0x74,
            0x72,
            0x69,
            0x6E,
            0x67,
            0x73,
            0x0A,
            0xE2,
            0x80,
            0xA2,
            0xE2,
            0x80,
            0xA2,
            0x2D,
            0x30
        ]
    )

    testDecode("example: >-\n  -1".toArray())

    return 0
}

func testDecode(data: Array<UInt8>) {
    try {
        let res = decode(data)
        println(res)
    } catch (e: Exception) {
        // e.printStackTrace()
        // 忽略报错
    }
}
