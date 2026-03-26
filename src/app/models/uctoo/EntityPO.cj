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
 * EntityPO - entity表持久化对象
 * 
 * 对应数据库表: entity
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["entity"]
public class EntityPO {
        @ORMField[true 'id']
    private var id: String = ""

        @ORMField['link']
    private var link: String = ""

        @ORMField['privacy_level']
    private var privacyLevel: ?Int32 = None<Int32>

        @ORMField['stars']
    private var stars: ?Float64 = None<Float64>

        @ORMField['description']
    private var description: ?String = None<String>

        @ORMField['group_id']
    private var groupId: ?String = None<String>

        @ORMField['picture']
    private var picture: ?String = None<String>

        @ORMField['images']
    private var images: ?String = None<String>

        @ORMField['content']
    private var content: ?String = None<String>

        @ORMField['json']
    private var json: ?String = None<String>

        @ORMField['city']
    private var city: ?String = None<String>

        @ORMField['price']
    private var price: ?Float64 = None<Float64>

        @ORMField['birthday']
    private var birthday: ?DateTime = None<DateTime>

        @ORMField['owner']
    private var owner: ?String = None<String>

        @ORMField['creator']
    private var creator: String = ""

        @ORMField['created_at']
    private var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    private var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    private var deletedAt: ?DateTime = None<DateTime>

        @ORMField['end_time']
    private var endTime: ?DateTime = None<DateTime>

        @ORMField['start_time']
    private var startTime: ?DateTime = None<DateTime>

        @ORMField['status']
    private var status: ?String = None<String>
    
    public init() {}
    
    public init(
                id: String,
        link: String,
        privacyLevel: ?Int32,
        stars: ?Float64,
        description: ?String,
        groupId: ?String,
        picture: ?String,
        images: ?String,
        content: ?String,
        json: ?String,
        city: ?String,
        price: ?Float64,
        birthday: ?DateTime,
        owner: ?String,
        creator: String,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: ?DateTime,
        endTime: ?DateTime,
        startTime: ?DateTime,
        status: ?String
    ) {
                this.id = id
        this.link = link
        this.privacyLevel = privacyLevel
        this.stars = stars
        this.description = description
        this.groupId = groupId
        this.picture = picture
        this.images = images
        this.content = content
        this.json = json
        this.city = city
        this.price = price
        this.birthday = birthday
        this.owner = owner
        this.creator = creator
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.deletedAt = deletedAt
        this.endTime = endTime
        this.startTime = startTime
        this.status = status
    }
    
    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{")
                sb.append("\"id\":\"${id}\",")
        sb.append("\"link\":\"${link}\",")
        if (let Some(v) <- privacyLevel) {
            sb.append("\"privacy_level\":${v},")
        } else {
            sb.append("\"privacy_level\":null,")
        }
        if (let Some(v) <- stars) {
            sb.append("\"stars\":${v},")
        } else {
            sb.append("\"stars\":null,")
        }
        if (let Some(v) <- description) {
            sb.append("\"description\":\"${v}\",")
        } else {
            sb.append("\"description\":\"\",")
        }
        if (let Some(v) <- groupId) {
            sb.append("\"group_id\":\"${v}\",")
        } else {
            sb.append("\"group_id\":\"\",")
        }
        if (let Some(v) <- picture) {
            sb.append("\"picture\":\"${v}\",")
        } else {
            sb.append("\"picture\":\"\",")
        }
        if (let Some(v) <- images) {
            sb.append("\"images\":\"${v}\",")
        } else {
            sb.append("\"images\":\"\",")
        }
        if (let Some(v) <- content) {
            sb.append("\"content\":\"${v}\",")
        } else {
            sb.append("\"content\":\"\",")
        }
        if (let Some(v) <- json) {
            sb.append("\"json\":\"${v}\",")
        } else {
            sb.append("\"json\":\"\",")
        }
        if (let Some(v) <- city) {
            sb.append("\"city\":\"${v}\",")
        } else {
            sb.append("\"city\":\"\",")
        }
        if (let Some(v) <- price) {
            sb.append("\"price\":\"${v}\",")
        } else {
            sb.append("\"price\":\"\",")
        }
        if (let Some(v) <- birthday) {
            sb.append("\"birthday\":\"${v}\",")
        } else {
            sb.append("\"birthday\":\"\",")
        }
        if (let Some(v) <- owner) {
            sb.append("\"owner\":\"${v}\",")
        } else {
            sb.append("\"owner\":\"\",")
        }
        sb.append("\"creator\":\"${creator}\",")
        sb.append("\"created_at\":\"${createdAt}\",")
        sb.append("\"updated_at\":\"${updatedAt}\",")
        if (let Some(v) <- deletedAt) {
            sb.append("\"deleted_at\":\"${v}\",")
        } else {
            sb.append("\"deleted_at\":\"\",")
        }
        if (let Some(v) <- endTime) {
            sb.append("\"end_time\":\"${v}\",")
        } else {
            sb.append("\"end_time\":\"\",")
        }
        if (let Some(v) <- startTime) {
            sb.append("\"start_time\":\"${v}\",")
        } else {
            sb.append("\"start_time\":\"\",")
        }
        if (let Some(v) <- status) {
            sb.append("\"status\":\"${v}\"")
        } else {
            sb.append("\"status\":\"\"")
        }
        sb.append("}")
        return sb.toString()
    }
}
