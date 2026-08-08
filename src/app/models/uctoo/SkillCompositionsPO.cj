/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * SkillCompositionsPO - skill_compositions表持久化对象
 * 
 * 对应数据库表: skill_compositions
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["skill_compositions"]
public class SkillCompositionsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['definition']
    public var definition: String = ""

        @ORMField['source_path']
    public var sourcePath: Option<String> = None<String>

        @ORMField['template_ref']
    public var templateRef: Option<String> = None<String>

        @ORMField['is_template']
    public var isTemplate: Bool = false

        @ORMField['sync_status']
    public var syncStatus: String = ""

        @ORMField['creator']
    public var creator: String = ""

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                name: String,
                description: Option<String>,
                definition: String,
                sourcePath: Option<String>,
                templateRef: Option<String>,
                isTemplate: Bool,
                syncStatus: String,
                creator: String,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.name = name
                this.description = description
                this.definition = definition
                this.sourcePath = sourcePath
                this.templateRef = templateRef
                this.isTemplate = isTemplate
                this.syncStatus = syncStatus
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("description", optionToJsonValue(this.description))
        map.add("definition", this.definition.toJsonValue())
        map.add("source_path", optionToJsonValue(this.sourcePath))
        map.add("template_ref", optionToJsonValue(this.templateRef))
        map.add("is_template", this.isTemplate.toJsonValue())
        map.add("sync_status", this.syncStatus.toJsonValue())
        map.add("creator", this.creator.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        return JsonObject(map)
    }

    /// 辅助方法：将 Option<T> 转换为 JsonValue
    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }

    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return this.toJsonValue().toString()
    }

//#endregion AutoCreateCode
}
