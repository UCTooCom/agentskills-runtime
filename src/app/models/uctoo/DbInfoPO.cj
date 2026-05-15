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
 * DbInfoPO - db_info表持久化对象
 * 
 * 对应数据库表: db_info
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["db_info"]
public class DbInfoPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['table_catalog']
    public var tableCatalog: String = ""

        @ORMField['table_schema']
    public var tableSchema: Option<String> = None<String>

        // 注意: 数据库列名 'table_name' 是关键字，已重命名为 'dbTableName'
        @ORMField['table_name']
    public var dbTableName: String = ""

        @ORMField['column_name']
    public var columnName: String = ""

        @ORMField['column_default']
    public var columnDefault: Option<String> = None<String>

        @ORMField['is_nullable']
    public var isNullable: String = ""

        @ORMField['data_type']
    public var dataType: Option<String> = None<String>

        @ORMField['vue_component_type']
    public var vueComponentType: Option<String> = None<String>

        @ORMField['react_component_type']
    public var reactComponentType: Option<String> = None<String>

        @ORMField['arkui_component_type']
    public var arkuiComponentType: Option<String> = None<String>

        @ORMField['uniapp_component_type']
    public var uniappComponentType: Option<String> = None<String>

        @ORMField['rules']
    public var rules: Option<String> = None<String>

        @ORMField['pattern']
    public var pattern: Option<String> = None<String>

        @ORMField['weight']
    public var weight: Int32 = 0

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['placeholder']
    public var placeholder: Option<String> = None<String>

        @ORMField['is_column_hidden']
    public var isColumnHidden: String = ""

        @ORMField['is_table_hidden']
    public var isTableHidden: String = ""

        @ORMField['column_comment']
    public var columnComment: Option<String> = None<String>

        @ORMField['ordinal_position']
    public var ordinalPosition: Int32 = 0

        @ORMField['migration_id']
    public var migrationId: Option<String> = None<String>

        @ORMField['character_maximum_length']
    public var characterMaximumLength: Option<Int64> = None<Int64>

    public init() {}

    public init(
                id: String,
                tableCatalog: String,
                tableSchema: Option<String>,
                dbTableName: String,
                columnName: String,
                columnDefault: Option<String>,
                isNullable: String,
                dataType: Option<String>,
                vueComponentType: Option<String>,
                reactComponentType: Option<String>,
                arkuiComponentType: Option<String>,
                uniappComponentType: Option<String>,
                rules: Option<String>,
                pattern: Option<String>,
                weight: Int32,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                placeholder: Option<String>,
                isColumnHidden: String,
                isTableHidden: String,
                columnComment: Option<String>,
                ordinalPosition: Int32,
                migrationId: Option<String>,
                characterMaximumLength: Option<Int64>
    ) {
                this.id = id
                this.tableCatalog = tableCatalog
                this.tableSchema = tableSchema
                this.dbTableName = dbTableName
                this.columnName = columnName
                this.columnDefault = columnDefault
                this.isNullable = isNullable
                this.dataType = dataType
                this.vueComponentType = vueComponentType
                this.reactComponentType = reactComponentType
                this.arkuiComponentType = arkuiComponentType
                this.uniappComponentType = uniappComponentType
                this.rules = rules
                this.pattern = pattern
                this.weight = weight
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.placeholder = placeholder
                this.isColumnHidden = isColumnHidden
                this.isTableHidden = isTableHidden
                this.columnComment = columnComment
                this.ordinalPosition = ordinalPosition
                this.migrationId = migrationId
                this.characterMaximumLength = characterMaximumLength
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("table_catalog", this.tableCatalog.toJsonValue())
        map.add("table_schema", optionToJsonValue(this.tableSchema))
        map.add("table_name", this.dbTableName.toJsonValue())
        map.add("column_name", this.columnName.toJsonValue())
        map.add("column_default", optionToJsonValue(this.columnDefault))
        map.add("is_nullable", this.isNullable.toJsonValue())
        map.add("data_type", optionToJsonValue(this.dataType))
        map.add("vue_component_type", optionToJsonValue(this.vueComponentType))
        map.add("react_component_type", optionToJsonValue(this.reactComponentType))
        map.add("arkui_component_type", optionToJsonValue(this.arkuiComponentType))
        map.add("uniapp_component_type", optionToJsonValue(this.uniappComponentType))
        map.add("rules", optionToJsonValue(this.rules))
        map.add("pattern", optionToJsonValue(this.pattern))
        map.add("weight", this.weight.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("placeholder", optionToJsonValue(this.placeholder))
        map.add("is_column_hidden", this.isColumnHidden.toJsonValue())
        map.add("is_table_hidden", this.isTableHidden.toJsonValue())
        map.add("column_comment", optionToJsonValue(this.columnComment))
        map.add("ordinal_position", this.ordinalPosition.toJsonValue())
        map.add("migration_id", optionToJsonValue(this.migrationId))
        map.add("character_maximum_length", optionToJsonValue(this.characterMaximumLength))
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
