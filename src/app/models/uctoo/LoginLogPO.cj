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
 * LoginLogPO - login_log表持久化对象
 * 
 * 对应数据库表: login_log
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["login_log"]
public class LoginLogPO {
        // 注意: 数据库列名 'id' 是关键字，已重命名为 'id'
    @ORMField[true 'id']
    private var id: String = ""

        // 注意: 数据库列名 'login_name' 是关键字，已重命名为 'loginName'
    @ORMField['login_name']
    private var loginName: String = ""

        // 注意: 数据库列名 'login_ip' 是关键字，已重命名为 'loginIp'
    @ORMField['login_ip']
    private var loginIp: String = ""

        // 注意: 数据库列名 'browser' 是关键字，已重命名为 'browser'
    @ORMField['browser']
    private var browser: String = ""

        // 注意: 数据库列名 'os' 是关键字，已重命名为 'os'
    @ORMField['os']
    private var os: String = ""

        // 注意: 数据库列名 'login_at' 是关键字，已重命名为 'loginAt'
    @ORMField['login_at']
    private var loginAt: DateTime = DateTime.now()

        // 注意: 数据库列名 'status' 是关键字，已重命名为 'status'
    @ORMField['status']
    private var status: ?Int32 = None<Int32>

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
        loginName: String,
        loginIp: String,
        browser: String,
        os: String,
        loginAt: DateTime,
        status: ?Int32,
        creator: ?String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime
    ) {
                this.id = id
        this.loginName = loginName
        this.loginIp = loginIp
        this.browser = browser
        this.os = os
        this.loginAt = loginAt
        this.status = status
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"login_name\":\"${loginName}\",")
        sb.append("\"login_ip\":\"${loginIp}\",")
        sb.append("\"browser\":\"${browser}\",")
        sb.append("\"os\":\"${os}\",")
        sb.append("\"login_at\":\"${loginAt}\",")
        sb.append("\"status\":${status},")
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
