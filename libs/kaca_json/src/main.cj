package kaca_json

import std.collection.*

public class JSON {
    public static func parse(input: String): JsonValue {
        parseStrictJsonBytes(stringToBytes(input))
    }

    public static func parse(input: Array<Byte>): JsonValue {
        parseStrictJsonBytes(input)
    }

    public static func parseOrNull(input: String): ?JsonValue {
        try {
            Some(parseStrictJsonBytes(stringToBytes(input)))
        } catch (_: Exception) {
            None
        }
    }

    public static func parseOrNull(input: Array<Byte>): ?JsonValue {
        try {
            Some(parseStrictJsonBytes(input))
        } catch (_: Exception) {
            None
        }
    }

    public static func parseFast(input: String): FastValue {
        parseFastBytes(stringToBytes(input))
    }

    public static func parseFast(input: Array<Byte>): FastValue {
        parseFastBytes(input)
    }

    public static func parseFastOrNull(input: String): ?FastValue {
        try {
            Some(parseFastBytes(stringToBytes(input)))
        } catch (_: Exception) {
            None
        }
    }

    public static func parseFastOrNull(input: Array<Byte>): ?FastValue {
        try {
            Some(parseFastBytes(input))
        } catch (_: Exception) {
            None
        }
    }

    public static func parseJson5(input: String): JsonValue {
        Json5Parser(input).parse()
    }

    public static func parseJson5OrNull(input: String): ?JsonValue {
        try {
            Some(Json5Parser(input).parse())
        } catch (_: Exception) {
            None
        }
    }

    public static func stringify(value: JsonValue): String {
        let options = StringifyOptions()
        stringifyWithOptions(value, options)
    }

    public static func stringify(value: JsonValue, indent: Int64): String {
        let options = StringifyOptions()
        options.space = indent
        stringifyWithOptions(value, options)
    }

    public static func stringify(value: JsonValue, options: StringifyOptions): String {
        stringifyWithOptions(value, options)
    }

    public static func path(value: JsonValue, path: String): ArrayList<JsonValue> {
        jsonPath(value, path)
    }

    public static func pathFirst(value: JsonValue, path: String): ?JsonValue {
        jsonPathFirst(value, path)
    }
}

public class JsonPatch {
    public static func createList(): ArrayList<PatchOperation> {
        ArrayList<PatchOperation>()
    }

    public static func apply(value: JsonValue, operations: ArrayList<PatchOperation>): JsonValue {
        jsonPatch(value, operations)
    }

    public static func add(path: String, value: JsonValue): PatchOperation {
        PatchOperation.add(path, value)
    }

    public static func remove(path: String): PatchOperation {
        PatchOperation.remove(path)
    }

    public static func replace(path: String, value: JsonValue): PatchOperation {
        PatchOperation.replace(path, value)
    }

    public static func move(from: String, path: String): PatchOperation {
        PatchOperation.move(from, path)
    }

    public static func copy(from: String, path: String): PatchOperation {
        PatchOperation.copy(from, path)
    }

    public static func test(path: String, value: JsonValue): PatchOperation {
        PatchOperation.test(path, value)
    }
}

