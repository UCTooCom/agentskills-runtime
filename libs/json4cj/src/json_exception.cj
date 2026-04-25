/*
 * Runtime exception classes for JSON deserialization errors.
 *
 * These exceptions carry field path context (dot notation) to help
 * locate the exact position of deserialization failures in nested JSON.
 *
 * Path format: $.user.address.city, $.items[0].name
 *
 * Exception hierarchy:
 *   JsonDeserializeException          — base for all deserialization errors
 *   JsonUnknownFieldsException        — unknown fields in strict mode
 */
package json4cj

import std.collection.ArrayList

public open class JsonDeserializeException <: Exception {
    public let path: String
    public let detail: String

    public init(path: String, detail: String) {
        super("JSON deserialization error at '" + path + "': " + detail)
        this.path = path
        this.detail = detail
    }
}

public class JsonUnknownFieldsException <: JsonDeserializeException {
    public let unknownFields: ArrayList<String>

    public init(path: String, unknownFields: ArrayList<String>) {
        super(path, "unknown fields " + unknownFields.toString())
        this.unknownFields = unknownFields
    }
}
