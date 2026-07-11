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
 * AttachmentsPO - attachments表持久化对象
 * 
 * 对应数据库表: attachments
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["attachments"]
public class AttachmentsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['path']
    public var path: String = ""

        @ORMField['url']
    public var url: String = ""

        @ORMField['mime_type']
    public var mimeType: String = ""

        @ORMField['file_ext']
    public var fileExt: String = ""

        @ORMField['filesize']
    public var filesize: Int32 = 0

        @ORMField['filename']
    public var filename: String = ""

        @ORMField['driver']
    public var driver: String = ""

        @ORMField['scene']
    public var scene: Option<String> = None<String>

        @ORMField['type']
    public var typeVal: Option<String> = None<String>

        @ORMField['sc_id']
    public var scId: Option<Int32> = None<Int32>

        @ORMField['ai_task_id']
    public var aiTaskId: Option<Int32> = None<Int32>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

    public init() {}

    public init(
                id: String,
                path: String,
                url: String,
                mimeType: String,
                fileExt: String,
                filesize: Int32,
                filename: String,
                driver: String,
                scene: Option<String>,
                typeVal: Option<String>,
                scId: Option<Int32>,
                aiTaskId: Option<Int32>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                creator: Option<String>
    ) {
                this.id = id
                this.path = path
                this.url = url
                this.mimeType = mimeType
                this.fileExt = fileExt
                this.filesize = filesize
                this.filename = filename
                this.driver = driver
                this.scene = scene
                this.typeVal = typeVal
                this.scId = scId
                this.aiTaskId = aiTaskId
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.creator = creator
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("path", this.path.toJsonValue())
        map.add("url", this.url.toJsonValue())
        map.add("mime_type", this.mimeType.toJsonValue())
        map.add("file_ext", this.fileExt.toJsonValue())
        map.add("filesize", this.filesize.toJsonValue())
        map.add("filename", this.filename.toJsonValue())
        map.add("driver", this.driver.toJsonValue())
        map.add("scene", optionToJsonValue(this.scene))
        map.add("type", optionToJsonValue(this.typeVal))
        map.add("sc_id", optionToJsonValue(this.scId))
        map.add("ai_task_id", optionToJsonValue(this.aiTaskId))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("creator", optionToJsonValue(this.creator))
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
