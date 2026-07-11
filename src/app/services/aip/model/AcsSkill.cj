/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*
import stdx.encoding.json.*
import json4cj.JsonValueSerializable

public class AcsSkill {
    public var skillId: String = ""
    public var skillName: String = ""
    public var skillDescription: String = ""
    public var tags: Option<String> = None<String>
    public var inputTypes: Option<String> = None<String>
    public var outputTypes: Option<String> = None<String>

    public init() {}

    public init(skillId: String, skillName: String, skillDescription: String,
        tags: Option<String>, inputTypes: Option<String>, outputTypes: Option<String>) {
        this.skillId = skillId
        this.skillName = skillName
        this.skillDescription = skillDescription
        this.tags = tags
        this.inputTypes = inputTypes
        this.outputTypes = outputTypes
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("skill_id", this.skillId.toJsonValue())
        map.add("skill_name", this.skillName.toJsonValue())
        map.add("skill_description", this.skillDescription.toJsonValue())
        map.add("tags", optionToJsonValue(this.tags))
        map.add("input_types", optionToJsonValue(this.inputTypes))
        map.add("output_types", optionToJsonValue(this.outputTypes))
        return JsonObject(map)
    }

    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }
}