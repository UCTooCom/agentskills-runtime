/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.{DATABASE_NAME}

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * {TABLE_NAME_PASCAL}PO - {TABLE_NAME}表持久化对象
 * 
 * 对应数据库表: {TABLE_NAME}
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["{TABLE_NAME}"]
public class {TABLE_NAME_PASCAL}PO {
    {FIELDS_SECTION}
    
    public init() {}
    
    public init(
        {CONSTRUCTOR_PARAMS}
    ) {
        {CONSTRUCTOR_ASSIGNMENTS}
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
        {TO_JSON_FIELDS}
        sb.append("}")
        return sb.toString()
    }
}
