/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.ArrayList
import std.core.StringBuilder

/**
 * DbTableInfo - 数据库表信息DTO
 *
 * 用于返回数据库表结构信息，不持久化到数据库
 */
public class DbTableInfo {
    public var tableCatalog: String = ""
    public var tableSchema: String = ""
    public var tableName: String = ""
    public var tableType: String = ""
    public var children: ArrayList<DbColumnInfo> = ArrayList<DbColumnInfo>()

    public init() {}

    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
        sb.append("\"table_catalog\":\"${tableCatalog}\",")
        sb.append("\"table_schema\":\"${tableSchema}\",")
        sb.append("\"table_name\":\"${tableName}\",")
        sb.append("\"table_type\":\"${tableType}\",")
        sb.append("\"children\":[")
        let childCount = children.size
        for (i in 0..childCount) {
            sb.append(children[i].toJson())
            if (i < childCount - 1) {
                sb.append(",")
            }
        }
        sb.append("]")
        sb.append("}")
        return sb.toString()
    }
}

/**
 * DbColumnInfo - 数据库列信息DTO
 *
 * 用于返回数据库列结构信息，不持久化到数据库
 */
public class DbColumnInfo {
    public var columnName: String = ""
    public var dataType: String = ""
    public var isNullable: String = ""
    public var columnDefault: String = ""
    public var ordinalPosition: Int32 = 0
    public var characterMaximumLength: Int32 = 0
    public var columnComment: String = ""

    public init() {}

    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
        sb.append("\"column_name\":\"${columnName}\",")
        sb.append("\"data_type\":\"${dataType}\",")
        sb.append("\"is_nullable\":\"${isNullable}\",")
        sb.append("\"column_default\":\"${columnDefault}\",")
        sb.append("\"ordinal_position\":${ordinalPosition},")
        sb.append("\"character_maximum_length\":${characterMaximumLength},")
        sb.append("\"column_comment\":\"${columnComment}\"")
        sb.append("}")
        return sb.toString()
    }
}