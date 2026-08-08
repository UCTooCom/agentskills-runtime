/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public let NULL_NODE: JsonValue = JsonNull()
public let MISSING_CLAIM = JsonNodeClaim()

func createClaim(data: JsonValue): Claim {
    JsonNodeClaim(data)
}

/*
 * 使用std.json实现的claim
 */
public class JsonNodeClaim <: Claim {
    private let data: JsonValue
    private var missing = false

    protected init() {
        this.data = NULL_NODE
        this.missing = true
    }

    public init(data: JsonValue) {
        this.data = data
    }

    public func isNull(): Bool {
        !isMissing() && data.kind() == JsonKind.JsNull
    }

    public func isMissing(): Bool {
        missing
    }

    public func asBool(): Bool {
        data.asBool().getValue()
    }

    public func asInt(): Int64 {
        data.asInt().getValue()
    }

    public func asFloat(): Float64 {
        data.asFloat().getValue()
    }

    public func asString(): String {
        data.asString().getValue()
    }

    public func asTime(): DateTime {
        DateTime.ofEpoch(second: data.asInt().getValue(), nanosecond: 0)
    }

    public func asArray(): Array<JsonValue> {
        asList().toArray()
    }

    public func asList(): ArrayList<JsonValue> {
        data.asArray().getItems()
    }

    public func asMap(): Map<String, JsonValue> {
        data.asObject().getFields()
    }

    public func getValue(): JsonValue {
        return data
    }

    public func toString(): String {
        if (missing) {
            throw MissingClaimException()
        } else {
            data.toStr()
        }
    }
}
