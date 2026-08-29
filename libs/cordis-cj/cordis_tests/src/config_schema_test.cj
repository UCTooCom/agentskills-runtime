package ystyle::cordis_tests

import ystyle::cordis_core.*
import ystyle::cordis_host.*
import stdx.serialization.serialization.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

/**
 * Config schema 校验测试（docs/cordis-comparison.md §4）
 *
 * 覆盖：字段类型校验、必填检查、未知字段（严格模式）、路径化错误、
 * 宿主集成（registerSchema → launchPlugin 拒绝非法配置）。
 */
@Test
class ConfigSchemaTest {

    private static func sampleSchema(): ConfigSchema {
        let fields = ArrayList<ConfigFieldSpec>()
        fields.add(ConfigFieldSpec("host", "string", required: true))
        fields.add(ConfigFieldSpec("port", "int"))
        fields.add(ConfigFieldSpec("debug", "bool"))
        fields.add(ConfigFieldSpec("tags", "array"))
        ConfigSchema(fields)
    }

    @TestCase
    func testValidConfigPasses(): Unit {
        let tags = ArrayList<DataModel>()
        tags.add(DataModelString("a"))
        let dm = DataModelStruct()
            .add(field<String>("host", "127.0.0.1"))
            .add(field<Int64>("port", 5432))
            .add(field<Bool>("debug", true))
            .add(Field("tags", DataModelSeq(tags)))
        let schema = sampleSchema()
        @Expect(schema.validate(dm, "plugins[0].config").isNone())
        @Expect(schema.validateStrict(dm, "plugins[0].config").isNone())
    }

    @TestCase
    func testMissingRequiredField(): Unit {
        // 缺 host（required）
        let dm = DataModelStruct().add(field<Int64>("port", 5432))
        let schema = sampleSchema()
        let err = schema.validate(dm, "plugins[0].config")
        @Expect(err.isSome())
        match (err) {
            case Some(e) => @Expect(e, "plugins[0].config.host: missing required field")
            case None => @Fail("expected error")
        }
    }

    @TestCase
    func testTypeMismatch(): Unit {
        // port 应为 int，给了 string
        let dm = DataModelStruct()
            .add(field<String>("host", "x"))
            .add(field<String>("port", "5432"))
        let schema = sampleSchema()
        let err = schema.validate(dm, "plugins[0].config")
        @Expect(err.isSome())
        match (err) {
            case Some(e) => @Expect(e, "plugins[0].config.port: expected int, got string")
            case None => @Fail("expected error")
        }
    }

    @TestCase
    func testUnknownFieldStrict(): Unit {
        // 严格模式：未知字段报错
        let dm = DataModelStruct()
            .add(field<String>("host", "x"))
            .add(field<String>("mystery", "y"))
        let schema = sampleSchema()
        @Expect(schema.validate(dm, "p.c").isNone())          // 宽松模式通过
        let err = schema.validateStrict(dm, "p.c")
        @Expect(err.isSome())
        match (err) {
            case Some(e) => @Expect(e, "p.c.mystery: unknown field")
            case None => @Fail("expected error")
        }
    }

    @TestCase
    func testNullConfigWithoutRequiredFields(): Unit {
        // 无配置 + 无必填 → 通过
        let fields = ArrayList<ConfigFieldSpec>()
        fields.add(ConfigFieldSpec("port", "int"))
        let schema = ConfigSchema(fields)
        @Expect(schema.validate(DataModelNull(), "p.c").isNone())
    }

    @TestCase
    func testIntAcceptsWholeFloat(): Unit {
        // int 字段接受整数值 float（jsonvalue 往返产生 DataModelFloat）
        let dm = DataModelStruct()
            .add(field<String>("host", "x"))
            .add(Field("port", DataModelFloat(5432.0)))
        let schema = sampleSchema()
        @Expect(schema.validate(dm, "p.c").isNone())
    }

    @TestCase
    func testHostRejectsInvalidConfig(): Unit {
        // 宿主集成：registerSchema 后 launchPlugin 拒绝非法配置（路径化异常）
        // 用 /bin/true 作为插件（schema 校验在 launch 前，不会真拉起）
        let manager = PluginManager()
        let host = PluginHost(manager)
        host.registerSchema("bad-plugin", sampleSchema())

        let entry = PluginEntry("bad-plugin", "/bin/true",
            config: DataModelStruct().add(field<String>("host", "x")).add(field<String>("port", "abc")))
        var threw = false
        try {
            host.launchPlugin(entry)
        } catch (e: Exception) {
            threw = true
            @Expect(e.message.contains("config validation failed"))
            @Expect(e.message.contains("bad-plugin"))
            @Expect(e.message.contains("expected int, got string"))
        }
        @Expect(threw)
    }
}
