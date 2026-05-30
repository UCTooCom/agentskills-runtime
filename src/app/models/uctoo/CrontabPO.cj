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
 * CrontabPO - crontab表持久化对象
 * 
 * 对应数据库表: crontab
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["crontab"]
public class CrontabPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['name']
    public var name: String = ""

        @ORMField['group_name']
    public var groupName: String = "1"

        @ORMField['task']
    public var task: String = ""

        @ORMField['cron']
    public var cron: String = ""

        @ORMField['tactics']
    public var tactics: String = ""

        @ORMField['remark']
    public var remark: String = ""

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['status']
    public var status: Int32 = 0

        @ORMField['timeout']
    public var timeout: Option<Int32> = None<Int32>

        @ORMField['max_retries']
    public var maxRetries: Option<Int32> = None<Int32>

        @ORMField['retry_count']
    public var retryCount: Option<Int32> = None<Int32>

        @ORMField['concurrentable']
    public var concurrentable: Option<Bool> = None<Bool>

        @ORMField['once']
    public var once: Option<Bool> = None<Bool>

        @ORMField['priority']
    public var priority: Option<Int32> = None<Int32>

        @ORMField['parameters']
    public var parameters: Option<String> = None<String>

        @ORMField['misfire_threshold']
    public var misfireThreshold: Option<Int32> = None<Int32>

        @ORMField['last_executed_at']
    public var lastExecutedAt: Option<DateTime> = None<DateTime>

        @ORMField['next_executed_at']
    public var nextExecutedAt: Option<DateTime> = None<DateTime>

        @ORMField['exec_count']
    public var execCount: Option<Int32> = None<Int32>

    public init() {}

    public init(
                id: String,
                name: String,
                groupName: String,
                task: String,
                cron: String,
                tactics: String,
                remark: String,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                status: Int32,
                timeout: Option<Int32>,
                maxRetries: Option<Int32>,
                retryCount: Option<Int32>,
                concurrentable: Option<Bool>,
                once: Option<Bool>,
                priority: Option<Int32>,
                parameters: Option<String>,
                misfireThreshold: Option<Int32>,
                lastExecutedAt: Option<DateTime>,
                nextExecutedAt: Option<DateTime>,
                execCount: Option<Int32>
    ) {
                this.id = id
                this.name = name
                this.groupName = groupName
                this.task = task
                this.cron = cron
                this.tactics = tactics
                this.remark = remark
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.status = status
                this.timeout = timeout
                this.maxRetries = maxRetries
                this.retryCount = retryCount
                this.concurrentable = concurrentable
                this.once = once
                this.priority = priority
                this.parameters = parameters
                this.misfireThreshold = misfireThreshold
                this.lastExecutedAt = lastExecutedAt
                this.nextExecutedAt = nextExecutedAt
                this.execCount = execCount
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("name", this.name.toJsonValue())
        map.add("group_name", this.groupName.toJsonValue())
        map.add("task", this.task.toJsonValue())
        map.add("cron", this.cron.toJsonValue())
        map.add("tactics", this.tactics.toJsonValue())
        map.add("remark", this.remark.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("status", this.status.toJsonValue())
        map.add("timeout", optionToJsonValue(this.timeout))
        map.add("max_retries", optionToJsonValue(this.maxRetries))
        map.add("retry_count", optionToJsonValue(this.retryCount))
        map.add("concurrentable", optionToJsonValue(this.concurrentable))
        map.add("once", optionToJsonValue(this.once))
        map.add("priority", optionToJsonValue(this.priority))
        map.add("parameters", optionToJsonValue(this.parameters))
        map.add("misfire_threshold", optionToJsonValue(this.misfireThreshold))
        map.add("last_executed_at", optionToJsonValue(this.lastExecutedAt))
        map.add("next_executed_at", optionToJsonValue(this.nextExecutedAt))
        map.add("exec_count", optionToJsonValue(this.execCount))
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