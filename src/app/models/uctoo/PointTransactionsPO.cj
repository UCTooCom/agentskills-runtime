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
 * PointTransactionsPO - point_transactions表持久化对象
 * 
 * 对应数据库表: point_transactions
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["point_transactions"]
public class PointTransactionsPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['account_type']
    public var accountType: String = ""

        @ORMField['account_id']
    public var accountId: String = ""

        @ORMField['transaction_type']
    public var transactionType: String = ""

        @ORMField['amount']
    public var amount: Int64 = 0

        @ORMField['balance_before']
    public var balanceBefore: Int64 = 0

        @ORMField['balance_after']
    public var balanceAfter: Int64 = 0

        @ORMField['task_id']
    public var taskId: Option<String> = None<String>

        @ORMField['counterparty_type']
    public var counterpartyType: Option<String> = None<String>

        @ORMField['counterparty_id']
    public var counterpartyId: Option<String> = None<String>

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['remark']
    public var remark: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public init(
                id: String,
                accountType: String,
                accountId: String,
                transactionType: String,
                amount: Int64,
                balanceBefore: Int64,
                balanceAfter: Int64,
                taskId: Option<String>,
                counterpartyType: Option<String>,
                counterpartyId: Option<String>,
                description: Option<String>,
                remark: Option<String>,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>
    ) {
                this.id = id
                this.accountType = accountType
                this.accountId = accountId
                this.transactionType = transactionType
                this.amount = amount
                this.balanceBefore = balanceBefore
                this.balanceAfter = balanceAfter
                this.taskId = taskId
                this.counterpartyType = counterpartyType
                this.counterpartyId = counterpartyId
                this.description = description
                this.remark = remark
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("account_type", this.accountType.toJsonValue())
        map.add("account_id", this.accountId.toJsonValue())
        map.add("transaction_type", this.transactionType.toJsonValue())
        map.add("amount", this.amount.toJsonValue())
        map.add("balance_before", this.balanceBefore.toJsonValue())
        map.add("balance_after", this.balanceAfter.toJsonValue())
        map.add("task_id", optionToJsonValue(this.taskId))
        map.add("counterparty_type", optionToJsonValue(this.counterpartyType))
        map.add("counterparty_id", optionToJsonValue(this.counterpartyId))
        map.add("description", optionToJsonValue(this.description))
        map.add("remark", optionToJsonValue(this.remark))
        map.add("creator", optionToJsonValue(this.creator))
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
