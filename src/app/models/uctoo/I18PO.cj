/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * I18PO - i18表持久化对象
 * 
 * 对应数据库表: i18
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["i18"]
public class I18PO {
        @ORMField[true 'id']
    public var id: String = ""

        @ORMField['key']
    public var key: String = ""

        @ORMField['content']
    public var content: String = ""

        @ORMField['lang_id']
    public var langId: ?String = None<String>

        @ORMField['creator']
    public var creator: ?String = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        key: String,
        content: String,
        langId: ?String,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.key = key
        this.content = content
        this.langId = langId
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    private func escapeJsonString(s: String): String {
        let sb = StringBuilder()
        for (char in s.runes()) {
            if (char == r'"') {
                sb.append("\\\"")
            } else if (char == r'\\') {
                sb.append("\\\\")
            } else if (char == r'\n') {
                sb.append("\\n")
            } else if (char == r'\r') {
                sb.append("\\r")
            } else if (char == r'\t') {
                sb.append("\\t")
            } else {
                sb.append(char)
            }
        }
        return sb.toString()
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"")
        sb.append(escapeJsonString(id))
        sb.append("\",")
        sb.append("\"key\":\"")
        sb.append(escapeJsonString(key))
        sb.append("\",")
        sb.append("\"content\":\"")
        sb.append(escapeJsonString(content))
        sb.append("\",")
        if (let Some(v) <- langId) {
            sb.append("\"lang_id\":\"")
            sb.append(escapeJsonString(v))
            sb.append("\",")
        } else {
            sb.append("\"lang_id\":\"\",")
        }
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"")
            sb.append(escapeJsonString(v))
            sb.append("\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        sb.append("\"created_at\":\"")
        sb.append(escapeJsonString(createdAt.toString()))
        sb.append("\",")
        sb.append("\"updated_at\":\"")
        sb.append(escapeJsonString(updatedAt.toString()))
        sb.append("\",")
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"")
            sb.append(escapeJsonString(v.toString()))
            sb.append("\"")
        } else {
            sb.append("\"deleted_at\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
