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

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


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
    public var id: ?String = None<String>

        @ORMField['table_catalog']
    public var tableCatalog: String = ""

        @ORMField['table_schema']
    public var tableSchema: ?String = None<String>

        // 注意: 数据库列名 'table_name' 是关键字，已重命名为 'dbTableName'
    @ORMField['table_name']
    public var dbTableName: String = ""

        @ORMField['column_name']
    public var columnName: String = ""

        @ORMField['column_default']
    public var columnDefault: ?String = None<String>

        @ORMField['is_nullable']
    public var isNullable: String = ""

        @ORMField['data_type']
    public var dataType: ?String = None<String>

        @ORMField['vue_component_type']
    public var vueComponentType: ?String = None<String>

        @ORMField['react_component_type']
    public var reactComponentType: ?String = None<String>

        @ORMField['arkui_component_type']
    public var arkuiComponentType: ?String = None<String>

        @ORMField['uniapp_component_type']
    public var uniappComponentType: ?String = None<String>

        @ORMField['rules']
    public var rules: ?String = None<String>

        @ORMField['pattern']
    public var pattern: ?String = None<String>

        @ORMField['weight']
    public var weight: ?Int32 = None<Int32>

        @ORMField['creator']
    public var creator: ?String = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: ?DateTime = None<DateTime>

        @ORMField['placeholder']
    public var placeholder: ?String = None<String>

        @ORMField['is_column_hidden']
    public var isColumnHidden: String = ""

        @ORMField['is_table_hidden']
    public var isTableHidden: String = ""

        @ORMField['column_comment']
    public var columnComment: ?String = None<String>

        @ORMField['ordinal_position']
    public var ordinalPosition: ?Int32 = None<Int32>

        @ORMField['migration_id']
    public var migrationId: ?String = None<String>

        @ORMField['character_maximum_length']
    public var characterMaximumLength: ?Int32 = None<Int32>
    
    public init() {}
    
    public init(
                id: String,
        tableCatalog: String,
        tableSchema: ?String,
        dbTableName: String,
        columnName: String,
        columnDefault: ?String,
        isNullable: String,
        dataType: ?String,
        vueComponentType: ?String,
        reactComponentType: ?String,
        arkuiComponentType: ?String,
        uniappComponentType: ?String,
        rules: ?String,
        pattern: ?String,
        weight: ?Int32,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime,
        placeholder: ?String,
        isColumnHidden: String,
        isTableHidden: String,
        columnComment: ?String,
        ordinalPosition: ?Int32,
        migrationId: ?String,
        characterMaximumLength: ?Int32
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
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"table_catalog\":\"${tableCatalog}\",")
        if (let Some(v) <- tableSchema) {
            sb.append("\"table_schema\":\"${v}\",")
        } else {
            sb.append("\"table_schema\":\"\",")
        }
        sb.append("\"table_name\":\"${dbTableName}\",")
        sb.append("\"column_name\":\"${columnName}\",")
        if (let Some(v) <- columnDefault) {
            sb.append("\"column_default\":\"${v}\",")
        } else {
            sb.append("\"column_default\":\"\",")
        }
        sb.append("\"is_nullable\":\"${isNullable}\",")
        if (let Some(v) <- dataType) {
            sb.append("\"data_type\":\"${v}\",")
        } else {
            sb.append("\"data_type\":\"\",")
        }
        if (let Some(v) <- vueComponentType) {
            sb.append("\"vue_component_type\":\"${v}\",")
        } else {
            sb.append("\"vue_component_type\":\"\",")
        }
        if (let Some(v) <- reactComponentType) {
            sb.append("\"react_component_type\":\"${v}\",")
        } else {
            sb.append("\"react_component_type\":\"\",")
        }
        if (let Some(v) <- arkuiComponentType) {
            sb.append("\"arkui_component_type\":\"${v}\",")
        } else {
            sb.append("\"arkui_component_type\":\"\",")
        }
        if (let Some(v) <- uniappComponentType) {
            sb.append("\"uniapp_component_type\":\"${v}\",")
        } else {
            sb.append("\"uniapp_component_type\":\"\",")
        }
        if (let Some(v) <- rules) {
            sb.append("\"rules\":\"${v}\",")
        } else {
            sb.append("\"rules\":\"\",")
        }
        if (let Some(v) <- pattern) {
            sb.append("\"pattern\":\"${v}\",")
        } else {
            sb.append("\"pattern\":\"\",")
        }
        if (let Some(v) <- weight) {
            sb.append("\"weight\":${v},")
        } else {
            sb.append("\"weight\":null,")
        }
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        sb.append("\"created_at\":\"${createdAt}\",")
        sb.append("\"updated_at\":\"${updatedAt}\",")
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\",")
        } else {
            sb.append("\"deleted_at\":\"\",")
        }
        if (let Some(v) <- placeholder) {
            sb.append("\"placeholder\":\"${v}\",")
        } else {
            sb.append("\"placeholder\":\"\",")
        }
        sb.append("\"is_column_hidden\":\"${isColumnHidden}\",")
        sb.append("\"is_table_hidden\":\"${isTableHidden}\",")
        if (let Some(v) <- columnComment) {
            sb.append("\"column_comment\":\"${v}\",")
        } else {
            sb.append("\"column_comment\":\"\",")
        }
        if (let Some(v) <- ordinalPosition) {
            sb.append("\"ordinal_position\":${v},")
        } else {
            sb.append("\"ordinal_position\":null,")
        }
        if (let Some(v) <- migrationId) {
            sb.append("\"migration_id\":\"${v}\",")
        } else {
            sb.append("\"migration_id\":\"\",")
        }
        if (let Some(v) <- characterMaximumLength) {
            sb.append("\"character_maximum_length\":${v}")
        } else {
            sb.append("\"character_maximum_length\":null")
        }
        sb.append("}")
        return sb.toString()
    }

//#endregion AutoCreateCode
}
