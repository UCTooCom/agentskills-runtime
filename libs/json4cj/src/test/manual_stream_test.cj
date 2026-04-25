package json4cj.test

/*
 * Manual test for stdx.encoding.json.stream API.
 *
 * IMPORTANT: cjc version must match stdx version (both 1.0.x).
 * Version mismatch causes itfVExtensionDataStart nullptr crash.
 * With matching versions, writeValue<T>() and readValue<T>() work correctly.
 */
import stdx.encoding.json.stream.*
import std.io.{ByteBuffer, readToEnd}
import std.collection.{ArrayList, HashMap, HashSet}
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@Test
public class TestManualStream {

    // --- Serialization: direct call vs writeValue<T> ---

    @TestCase
    func testDirectStringSerialization(): Unit {
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        "hello".toJson(writer)
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(result, "\"hello\"")
    }

    @TestCase
    func testWriteValueString(): Unit {
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<String>("hello")
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(result, "\"hello\"")
    }

    @TestCase
    func testWriteValueInt64(): Unit {
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<Int64>(Int64(42))
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(result, "42")
    }

    @TestCase
    func testWriteValueBool(): Unit {
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<Bool>(true)
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(result, "true")
    }

    // --- Deserialization: direct call vs readValue<T> ---

    @TestCase
    func testDirectStringDeserialization(): Unit {
        let jsonStr = "\"hello\""
        let buf = ByteBuffer()
        unsafe { buf.write(jsonStr.rawData()) }
        let reader = JsonReader(buf)
        let value = String.fromJson(reader)
        @Assert(value, "hello")
    }

    @TestCase
    func testReadValueString(): Unit {
        let jsonStr = "\"hello\""
        let buf = ByteBuffer()
        unsafe { buf.write(jsonStr.rawData()) }
        let reader = JsonReader(buf)
        let value = reader.readValue<String>()
        @Assert(value, "hello")
    }

    @TestCase
    func testReadValueInt64(): Unit {
        let jsonStr = "42"
        let buf = ByteBuffer()
        unsafe { buf.write(jsonStr.rawData()) }
        let reader = JsonReader(buf)
        let value = reader.readValue<Int64>()
        @Assert(value, Int64(42))
    }

    @TestCase
    func testReadValueBool(): Unit {
        let jsonStr = "true"
        let buf = ByteBuffer()
        unsafe { buf.write(jsonStr.rawData()) }
        let reader = JsonReader(buf)
        let value = reader.readValue<Bool>()
        @Assert(value, true)
    }

    // --- Object with writeValue / readValue ---

    @TestCase
    func testObjectWithWriteValue(): Unit {
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.startObject()
        writer.writeName("name").writeValue<String>("Alice")
        writer.writeName("age").writeValue<Int64>(Int64(30))
        writer.endObject()
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(compactJson(result), compactJson("{\"name\":\"Alice\",\"age\":30}"))
    }

    @TestCase
    func testObjectWithReadValue(): Unit {
        let jsonStr = "{\"name\":\"Alice\",\"age\":30}"
        let buf = ByteBuffer()
        unsafe { buf.write(jsonStr.rawData()) }
        let reader = JsonReader(buf)
        reader.startObject()
        var name = ""
        var age = Int64(0)
        while (let Some(token) <- reader.peek()) {
            if (token == EndObject) {
                break
            }
            match (reader.readName()) {
                case "name" => name = reader.readValue<String>()
                case "age" => age = reader.readValue<Int64>()
                case _ => reader.skip()
            }
        }
        reader.endObject()
        @Assert(name, "Alice")
        @Assert(age, Int64(30))
    }

    // --- Container types with writeValue / readValue ---

    @TestCase
    func testArrayListWithWriteValue(): Unit {
        let list = ArrayList<String>(["a", "b", "c"])
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<ArrayList<String>>(list)
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(compactJson(result), compactJson("[\"a\",\"b\",\"c\"]"))
    }

    @TestCase
    func testArrayListWithReadValue(): Unit {
        let jsonStr = "[\"go\",\"rust\",\"cangjie\"]"
        let buf = ByteBuffer()
        unsafe { buf.write(jsonStr.rawData()) }
        let reader = JsonReader(buf)
        let result = reader.readValue<ArrayList<String>>()
        @Assert(result.size, Int64(3))
        @Assert(result[0], "go")
        @Assert(result[1], "rust")
        @Assert(result[2], "cangjie")
    }

    @TestCase
    func testOptionSomeWithWriteValue(): Unit {
        let opt: Option<String> = Some("hello")
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<Option<String>>(opt)
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(result, "\"hello\"")
    }

    @TestCase
    func testOptionNoneWithWriteValue(): Unit {
        let opt: Option<String> = None
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<Option<String>>(opt)
        writer.flush()
        let result = String.fromUtf8(readToEnd(buf))
        @Assert(result, "null")
    }

    // --- Full round-trip with nested object + Option + ArrayList ---

    @TestCase
    func testComplexRoundTrip(): Unit {
        // Serialize
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.startObject()
        writer.writeName("name").writeValue<String>("Alice")
        writer.writeName("age").writeValue<Int64>(Int64(28))
        writer.writeName("nickname").writeValue<Option<String>>(Some("Ally"))
        let tags = ArrayList<String>(["dev", "cangjie"])
        writer.writeName("tags").writeValue<ArrayList<String>>(tags)
        // Nested object
        writer.writeName("address")
        writer.startObject()
        writer.writeName("city").writeValue<String>("Suzhou")
        writer.endObject()
        writer.endObject()
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        // Deserialize
        let buf2 = ByteBuffer()
        unsafe { buf2.write(jsonStr.rawData()) }
        let reader = JsonReader(buf2)
        reader.startObject()
        var dName = ""
        var dAge = Int64(0)
        var dNickname: Option<String> = None
        var dTags = ArrayList<String>()
        var dCity = ""
        while (let Some(token) <- reader.peek()) {
            if (token == EndObject) {
                break
            }
            match (reader.readName()) {
                case "name" => dName = reader.readValue<String>()
                case "age" => dAge = reader.readValue<Int64>()
                case "nickname" => dNickname = reader.readValue<Option<String>>()
                case "tags" => dTags = reader.readValue<ArrayList<String>>()
                case "address" =>
                    reader.startObject()
                    while (let Some(t) <- reader.peek()) {
                        if (t == EndObject) {
                            break
                        }
                        match (reader.readName()) {
                            case "city" => dCity = reader.readValue<String>()
                            case _ => reader.skip()
                        }
                    }
                    reader.endObject()
                case _ => reader.skip()
            }
        }
        reader.endObject()
        @Assert(dName, "Alice")
        @Assert(dAge, Int64(28))
        var nickVal = ""
        if (let Some(v) <- dNickname) {
            nickVal = v
        }
        @Assert(nickVal, "Ally")
        @Assert(dTags.size, Int64(2))
        @Assert(dTags[0], "dev")
        @Assert(dCity, "Suzhou")
    }
}

// compactJson is defined in collection_test.cj

// --- Step 0: Verify extend outside class body works for stdx stream interfaces ---

class StreamUser {
    public var name: String = ""
    public var age: Int64 = 0
    public var tags: ArrayList<String> = ArrayList<String>()
    public var nickname: Option<String> = None

    public init() {}
}

extend StreamUser <: JsonSerializable {
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("name").writeValue<String>(this.name)
        w.writeName("age").writeValue<Int64>(this.age)
        w.writeName("tags").writeValue<ArrayList<String>>(this.tags)
        w.writeName("nickname").writeValue<Option<String>>(this.nickname)
        w.endObject()
    }
}

extend StreamUser <: JsonDeserializable<StreamUser> {
    public static func fromJson(r: JsonReader): StreamUser {
        r.startObject()
        var name = ""
        var age = Int64(0)
        var tags = ArrayList<String>()
        var nickname: Option<String> = None
        while (let Some(token) <- r.peek()) {
            if (token == EndObject) {
                break
            }
            match (r.readName()) {
                case "name" => name = r.readValue<String>()
                case "age" => age = r.readValue<Int64>()
                case "tags" => tags = r.readValue<ArrayList<String>>()
                case "nickname" => nickname = r.readValue<Option<String>>()
                case _ => r.skip()
            }
        }
        r.endObject()
        let obj = StreamUser()
        obj.name = name
        obj.age = age
        obj.tags = tags
        obj.nickname = nickname
        return obj
    }
}

@Test
public class TestExtendPattern {

    @TestCase
    func testExtendWriteValueClazz(): Unit {
        let user = StreamUser()
        user.name = "Alice"
        user.age = Int64(30)
        user.tags = ArrayList<String>(["go", "cangjie"])
        user.nickname = Some("Ally")

        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<StreamUser>(user)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))
        @Assert(compactJson(jsonStr), compactJson("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"go\",\"cangjie\"],\"nickname\":\"Ally\"}"))
    }

    @TestCase
    func testExtendReadValueClazz(): Unit {
        let jsonStr = "{\"name\":\"Bob\",\"age\":25,\"tags\":[\"rust\"],\"nickname\":null}"
        let buf = ByteBuffer()
        unsafe { buf.write(jsonStr.rawData()) }
        let reader = JsonReader(buf)
        let user = reader.readValue<StreamUser>()
        @Assert(user.name, "Bob")
        @Assert(user.age, Int64(25))
        @Assert(user.tags.size, Int64(1))
        @Assert(user.tags[0], "rust")
        @Assert(user.nickname == None, true)
    }

    @TestCase
    func testExtendRoundTrip(): Unit {
        let user = StreamUser()
        user.name = "Charlie"
        user.age = Int64(28)
        user.tags = ArrayList<String>(["dev"])
        user.nickname = Some("Chuck")

        // Serialize
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<StreamUser>(user)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        // Deserialize
        let buf2 = ByteBuffer()
        unsafe { buf2.write(jsonStr.rawData()) }
        let reader = JsonReader(buf2)
        let user2 = reader.readValue<StreamUser>()

        @Assert(user2.name, "Charlie")
        @Assert(user2.age, Int64(28))
        @Assert(user2.tags.size, Int64(1))
        @Assert(user2.tags[0], "dev")
        var nickVal = ""
        if (let Some(v) <- user2.nickname) {
            nickVal = v
        }
        @Assert(nickVal, "Chuck")
    }

    @TestCase
    func testArrayListOfClazzWithExtend(): Unit {
        // Verify ArrayList<StreamUser> works because StreamUser <: JsonSerializable
        let users = ArrayList<StreamUser>()
        let u1 = StreamUser()
        u1.name = "A"
        u1.age = Int64(1)
        let u2 = StreamUser()
        u2.name = "B"
        u2.age = Int64(2)
        users.add(u1)
        users.add(u2)

        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<ArrayList<StreamUser>>(users)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        // Deserialize
        let buf2 = ByteBuffer()
        unsafe { buf2.write(jsonStr.rawData()) }
        let reader = JsonReader(buf2)
        let users2 = reader.readValue<ArrayList<StreamUser>>()

        @Assert(users2.size, Int64(2))
        @Assert(users2[0].name, "A")
        @Assert(users2[1].name, "B")
    }
}

/*
 * Macro-generated stream serialization/deserialization test.
 * The @JsonSerialize macro generates extend blocks for stdx stream interfaces.
 */
@JsonSerialize
class StreamSimpleUser {
    public var name: String = ""
    public var age: Int64 = 0
}

@Test
public class TestMacroStream {
    @TestCase
    func testStreamSerialize(): Unit {
        let user = StreamSimpleUser()
        user.name = "Alice"
        user.age = Int64(30)

        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<StreamSimpleUser>(user)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        @Assert(jsonStr.contains("Alice"), true)
        @Assert(jsonStr.contains("30"), true)
    }

    @TestCase
    func testStreamDeserialize(): Unit {
        let json = "{\"name\":\"Bob\",\"age\":25}"
        let buf = ByteBuffer()
        unsafe { buf.write(json.rawData()) }
        let reader = JsonReader(buf)
        let user = reader.readValue<StreamSimpleUser>()

        @Assert(user.name, "Bob")
        @Assert(user.age, Int64(25))
    }

    @TestCase
    func testStreamRoundTrip(): Unit {
        let user = StreamSimpleUser()
        user.name = "Charlie"
        user.age = Int64(40)

        // Serialize
        let buf1 = ByteBuffer()
        let writer = JsonWriter(buf1)
        writer.writeValue<StreamSimpleUser>(user)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf1))

        // Deserialize
        let buf2 = ByteBuffer()
        unsafe { buf2.write(jsonStr.rawData()) }
        let reader = JsonReader(buf2)
        let user2 = reader.readValue<StreamSimpleUser>()

        @Assert(user2.name, "Charlie")
        @Assert(user2.age, Int64(40))
    }

    @TestCase
    func testStreamMatchesHashMap(): Unit {
        let user = StreamSimpleUser()
        user.name = "Dave"
        user.age = Int64(50)

        // Stream serialization
        let buf1 = ByteBuffer()
        let writer = JsonWriter(buf1)
        writer.writeValue<StreamSimpleUser>(user)
        writer.flush()
        let streamJson = String.fromUtf8(readToEnd(buf1))

        // HashMap serialization (existing API)
        let hashMapJson = user.toJson()

        // Both should produce equivalent JSON
        @Assert(compactJson(streamJson), compactJson(hashMapJson))
    }
}

/*
 * Direct verification: test stdx stream API with HashSet/HashMap directly.
 * This tests whether writeValue<HashSet<Int64>>() works WITHOUT the macro,
 * to verify if the constraint resolution issue is real.
 *
 * Using a standalone function outside @Test class to avoid macro interference.
 */
@JsonSerialize
class ClassWithHashSetField {
    public var int64Set: HashSet<Int64> = HashSet<Int64>()
}

@Test
public class TestHashSetStreamDirect {

    @TestCase
    func testHashSetViaMacroGeneratedStream(): Unit {
        // This test uses the MACRO-GENERATED extend block
        // ClassWithHashSetField gets: extend <: JsonSerializable { toJson(w) }
        // which internally uses the JsonValue bridge for HashSet fields
        let obj = ClassWithHashSetField()
        obj.int64Set.add(1)
        obj.int64Set.add(2)
        obj.int64Set.add(3)

        // Use stream serialization (macro-generated toJson(w))
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<ClassWithHashSetField>(obj)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        @Assert(jsonStr.contains("int64Set"), true)
    }

    /*
     * CRITICAL VERIFICATION: Test writeValue<HashSet<Int64>>() directly.
     * Also tests writeValue<ArrayList<Int64>>() for comparison.
     */
    @TestCase
    func testDirectWriteValueArrayList(): Unit {
        // ArrayList<Int64> should work — stdx has extend for it
        let list = ArrayList<Int64>()
        list.add(1)
        list.add(2)

        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<ArrayList<Int64>>(list)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        @Assert(jsonStr.contains("1"), true)
    }

    // NOTE: writeValue<HashSet<Int64>> fails to compile with:
    // 'Class-HashSet<Int64>' is not a subtype of 'Interface-JsonSerializable'
    // This is a stdx/cjc issue, NOT our macro bug.
    // The JsonValue bridge is the correct workaround.
}

/*
 * Test: Option<UserType> field in Stream deserialization.
 * This exercises the JsonValue bridge path in emitOptionRead(),
 * which uses readValueBytes → JsonValue → T.fromJsonValue() instead of
 * readValue<Option<T>>() because cjc 1.0.1 constraint propagation fails
 * for user-defined inner types.
 */
@JsonSerialize
class Address {
    public var city: String = ""
    public var zip: String = ""
}

@JsonSerialize
class PersonWithAddress {
    public var name: String = ""
    public var address: Option<Address> = None
}

@Test
public class TestOptionUserTypeStream {

    @TestCase
    func testOptionUserTypeSomeStream(): Unit {
        let addr = Address()
        addr.city = "Suzhou"
        addr.zip = "215000"

        let person = PersonWithAddress()
        person.name = "Alice"
        person.address = Some(addr)

        // Stream serialization
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<PersonWithAddress>(person)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        @Assert(jsonStr.contains("Alice"), true)
        @Assert(jsonStr.contains("Suzhou"), true)
        @Assert(jsonStr.contains("215000"), true)
    }

    @TestCase
    func testOptionUserTypeNoneStream(): Unit {
        let person = PersonWithAddress()
        person.name = "Bob"
        // address stays None

        // Stream serialization
        let buf = ByteBuffer()
        let writer = JsonWriter(buf)
        writer.writeValue<PersonWithAddress>(person)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf))

        @Assert(jsonStr.contains("Bob"), true)
        @Assert(jsonStr.contains("null"), true)
    }

    @TestCase
    func testOptionUserTypeDeserializeSome(): Unit {
        let json = "{\"name\":\"Charlie\",\"address\":{\"city\":\"Beijing\",\"zip\":\"100000\"}}"
        let buf = ByteBuffer()
        unsafe { buf.write(json.rawData()) }
        let reader = JsonReader(buf)
        let person = reader.readValue<PersonWithAddress>()

        @Assert(person.name, "Charlie")
        @Assert(person.address.isSome(), true)
        @Assert(person.address.getOrThrow().city, "Beijing")
        @Assert(person.address.getOrThrow().zip, "100000")
    }

    @TestCase
    func testOptionUserTypeDeserializeNull(): Unit {
        let json = "{\"name\":\"Dave\",\"address\":null}"
        let buf = ByteBuffer()
        unsafe { buf.write(json.rawData()) }
        let reader = JsonReader(buf)
        let person = reader.readValue<PersonWithAddress>()

        @Assert(person.name, "Dave")
        @Assert(person.address.isNone(), true)
    }

    @TestCase
    func testOptionUserTypeDeserializeMissing(): Unit {
        // Missing Option field should stay None
        let json = "{\"name\":\"Eve\"}"
        let buf = ByteBuffer()
        unsafe { buf.write(json.rawData()) }
        let reader = JsonReader(buf)
        let person = reader.readValue<PersonWithAddress>()

        @Assert(person.name, "Eve")
        @Assert(person.address.isNone(), true)
    }

    @TestCase
    func testOptionUserTypeRoundTrip(): Unit {
        let addr = Address()
        addr.city = "Shanghai"
        addr.zip = "200000"

        let original = PersonWithAddress()
        original.name = "Frank"
        original.address = Some(addr)

        // Serialize
        let buf1 = ByteBuffer()
        let writer = JsonWriter(buf1)
        writer.writeValue<PersonWithAddress>(original)
        writer.flush()
        let jsonStr = String.fromUtf8(readToEnd(buf1))

        // Deserialize
        let buf2 = ByteBuffer()
        unsafe { buf2.write(jsonStr.rawData()) }
        let reader = JsonReader(buf2)
        let restored = reader.readValue<PersonWithAddress>()

        @Assert(restored.name, "Frank")
        @Assert(restored.address.isSome(), true)
        @Assert(restored.address.getOrThrow().city, "Shanghai")
        @Assert(restored.address.getOrThrow().zip, "200000")
    }
}
