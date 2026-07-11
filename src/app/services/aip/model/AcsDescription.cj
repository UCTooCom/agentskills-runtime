/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*
import stdx.encoding.json.*
import json4cj.JsonValueSerializable

public class AcsDescription {
    public var name: String = ""
    public var version: String = "1.0.0"
    public var description: String = ""
    public var capabilities: Option<String> = None<String>
    public var defaultInputTypes: Option<String> = None<String>
    public var defaultOutputTypes: Option<String> = None<String>
    public var skills: ArrayList<AcsSkill> = ArrayList<AcsSkill>()
    public var discoverable: Bool = true

    public init() {}

    public init(name: String, version: String, description: String, capabilities: Option<String>,
        defaultInputTypes: Option<String>, defaultOutputTypes: Option<String>,
        skills: ArrayList<AcsSkill>, discoverable: Bool) {
        this.name = name
        this.version = version
        this.description = description
        this.capabilities = capabilities
        this.defaultInputTypes = defaultInputTypes
        this.defaultOutputTypes = defaultOutputTypes
        this.skills = skills
        this.discoverable = discoverable
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", this.name.toJsonValue())
        map.add("version", this.version.toJsonValue())
        map.add("description", this.description.toJsonValue())
        map.add("capabilities", optionToJsonValue(this.capabilities))
        map.add("default_input_types", optionToJsonValue(this.defaultInputTypes))
        map.add("default_output_types", optionToJsonValue(this.defaultOutputTypes))
        map.add("discoverable", this.discoverable.toJsonValue())
        var skillArr = JsonArray()
        for (skill in this.skills) {
            skillArr.add(skill.toJsonValue())
        }
        map.add("skills", skillArr)
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