package json4cj.test

internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
class ClassWithUInt {
    public var u8: UInt8 = 0u8
    public var u16: UInt16 = 0u16
    public var u32: UInt32 = 0u32
    public var u64: UInt64 = 0u64
}

@Test
public class TestUInt {
    private let UINT_JSON = """
    {
        "u8": 200,
        "u16": 5000,
        "u32": 100000,
        "u64": 999999
    }
    """

    @TestCase
    func testUIntFromJson(): Unit {
        let obj = ClassWithUInt.fromJson(UINT_JSON)
        @Assert(obj.u8, 200u8)
        @Assert(obj.u16, 5000u16)
        @Assert(obj.u32, 100000u32)
        @Assert(obj.u64, 999999u64)
    }

    @TestCase
    func testUIntToJson(): Unit {
        var obj = ClassWithUInt()
        obj.u8 = 255u8
        obj.u16 = 65535u16
        obj.u32 = 100000u32
        obj.u64 = 999999u64

        let json = obj.toJson()
        @Assert(json.contains("\"u8\":255"), true)
        @Assert(json.contains("\"u16\":65535"), true)
        @Assert(json.contains("\"u32\":100000"), true)
        @Assert(json.contains("\"u64\":999999"), true)
    }

    @TestCase
    func testUIntRoundTrip(): Unit {
        var obj = ClassWithUInt()
        obj.u8 = 128u8
        obj.u16 = 32000u16
        obj.u32 = 500000u32
        obj.u64 = 123456u64

        let json = obj.toJson()
        let restored = ClassWithUInt.fromJson(json)
        @Assert(restored.u8, 128u8)
        @Assert(restored.u16, 32000u16)
        @Assert(restored.u32, 500000u32)
        @Assert(restored.u64, 123456u64)
    }

    @TestCase
    func testUIntDefaultValue(): Unit {
        // JSON with missing uint fields -> should use default value 0
        let obj = ClassWithUInt.fromJson("{}")
        @Assert(obj.u8, 0u8)
        @Assert(obj.u16, 0u16)
        @Assert(obj.u32, 0u32)
        @Assert(obj.u64, 0u64)
    }
}
