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
 * OperateLogPO - operate_log表持久化对象
 * 
 * 对应数据库表: operate_log
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["operate_log"]
public class OperateLogPO {
        // 注意: 数据库列名 'id' 是关键字，已重命名为 'id'
    @ORMField[true 'id']
    private var id: String = ""

        // 注意: 数据库列名 'module' 是关键字，已重命名为 'module'
    @ORMField['module']
    private var module: String = ""

        // 注意: 数据库列名 'operate' 是关键字，已重命名为 'operate'
    @ORMField['operate']
    private var operate: String = ""

        // 注意: 数据库列名 'route' 是关键字，已重命名为 'route'
    @ORMField['route']
    private var route: String = ""

        // 注意: 数据库列名 'params' 是关键字，已重命名为 'params'
    @ORMField['params']
    private var params: String = ""

        // 注意: 数据库列名 'ip' 是关键字，已重命名为 'ip'
    @ORMField['ip']
    private var ip: String = ""

        // 注意: 数据库列名 'method' 是关键字，已重命名为 'method'
    @ORMField['method']
    private var method: String = ""

        // 注意: 数据库列名 'creator' 是关键字，已重命名为 'creator'
    @ORMField['creator']
    private var creator: ?String = None<String>

        // 注意: 数据库列名 'created_at' 是关键字，已重命名为 'createdAt'
    @ORMField['created_at']
    private var createdAt: DateTime = DateTime.now()

        // 注意: 数据库列名 'updated_at' 是关键字，已重命名为 'updatedAt'
    @ORMField['updated_at']
    private var updatedAt: DateTime = DateTime.now()

        // 注意: 数据库列名 'deleted_at' 是关键字，已重命名为 'deletedAt'
    @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    public init(
                id: String,
        module: String,
        operate: String,
        route: String,
        params: String,
        ip: String,
        method: String,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.module = module
        this.operate = operate
        this.route = route
        this.params = params
        this.ip = ip
        this.method = method
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"module\":\"${module}\",")
        sb.append("\"operate\":\"${operate}\",")
        sb.append("\"route\":\"${route}\",")
        sb.append("\"params\":\"${params}\",")
        sb.append("\"ip\":\"${ip}\",")
        sb.append("\"method\":\"${method}\",")
        if (let Some(v) <- creator) {
            sb.append("\"creator\":\"${v}\",")
        } else {
            sb.append("\"creator\":\"\",")
        }
        sb.append("\"created_at\":\"${createdAt}\",")
        sb.append("\"updated_at\":\"${updatedAt}\",")
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\"")
        } else {
            sb.append("\"deleted_at\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
