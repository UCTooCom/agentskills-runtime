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
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

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
        @ORMField['id']
    public var id: String = ""

        @ORMField['link']
    public var link: String = ""

        @ORMField['privacy_level']
    public var privacyLevel: Option<Int32> = None<Int32>

        @ORMField['stars']
    public var stars: Option<Float64> = None<Float64>

        @ORMField['description']
    public var description: Option<String> = None<String>

        @ORMField['group_id']
    public var groupId: Option<String> = None<String>

        @ORMField['picture']
    public var picture: Option<String> = None<String>

        @ORMField['images']
    public var images: Option<String> = None<String>

        @ORMField['content']
    public var content: Option<String> = None<String>

        @ORMField['json']
    public var json: Option<String> = None<String>

        @ORMField['city']
    public var city: Option<String> = None<String>

        @ORMField['price']
    public var price: Option<Float64> = None<Float64>

        @ORMField['birthday']
    public var birthday: Option<DateTime> = None<DateTime>

        @ORMField['owner']
    public var owner: Option<String> = None<String>

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['end_time']
    public var endTime: Option<DateTime> = None<DateTime>

        @ORMField['start_time']
    public var startTime: Option<DateTime> = None<DateTime>

        @ORMField['status']
    public var status: Option<String> = None<String>
    
    public init() {}
    
    public init(
                id: String,
        link: String,
        privacyLevel: Option<Int32>,
        stars: Option<Float64>,
        description: Option<String>,
        groupId: Option<String>,
        picture: Option<String>,
        images: Option<String>,
        content: Option<String>,
        json: Option<String>,
        city: Option<String>,
        price: Option<Float64>,
        birthday: Option<DateTime>,
        owner: Option<String>,
        creator: Option<String>,
        createdAt: DateTime,
        updatedAt: DateTime,
        deletedAt: Option<DateTime>,
        endTime: Option<DateTime>,
        startTime: Option<DateTime>,
        status: Option<String>
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
    
    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("link", this.link.toJsonValue())
        map.add("privacy_level", optionToJsonValue(this.privacyLevel))
        map.add("stars", optionToJsonValue(this.stars))
        map.add("description", optionToJsonValue(this.description))
        map.add("group_id", optionToJsonValue(this.groupId))
        map.add("picture", optionToJsonValue(this.picture))
        map.add("images", optionToJsonValue(this.images))
        map.add("content", optionToJsonValue(this.content))
        map.add("json", optionToJsonValue(this.json))
        map.add("city", optionToJsonValue(this.city))
        map.add("price", optionToJsonValue(this.price))
        map.add("birthday", optionToJsonValue(this.birthday))
        map.add("owner", optionToJsonValue(this.owner))
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("end_time", optionToJsonValue(this.endTime))
        map.add("start_time", optionToJsonValue(this.startTime))
        map.add("status", optionToJsonValue(this.status))
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
    
    /// 从 JSON 字符串反序列化
    public static func fromJson(json: String): EntityPO {
        return EntityPO.fromJsonValue(JsonValue.fromStr(json))
    }
    
    /// 从 JsonValue 反序列化
    public static func fromJsonValue(value: JsonValue): EntityPO {
        return fromJsonValue(value, "$")
    }
    
    /// 从 JsonValue 反序列化（带路径的错误追踪）
    public static func fromJsonValue(value: JsonValue, path: String): EntityPO {
        var ret = EntityPO()
        let obj = value.asObject()
        
        // 解析 id 字段
        if (obj.getFields().contains("id")) {
            try {
                ret.id = String.fromJsonValue(obj.get("id").getOrThrow(), path + ".id")
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.id': ${e.message}")
            }
        }
        
        // 解析 link 字段
        if (obj.getFields().contains("link")) {
            try {
                ret.link = String.fromJsonValue(obj.get("link").getOrThrow(), path + ".link")
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.link': ${e.message}")
            }
        }
        
        // 解析 privacy_level 字段
        if (obj.getFields().contains("privacy_level")) {
            try {
                let fieldValue = obj.get("privacy_level").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.privacyLevel = None
                } else {
                    ret.privacyLevel = Some(Int32.fromJsonValue(fieldValue, path + ".privacy_level"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.privacy_level': ${e.message}")
            }
        }
        
        // 解析 stars 字段
        if (obj.getFields().contains("stars")) {
            try {
                let fieldValue = obj.get("stars").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.stars = None
                } else {
                    ret.stars = Some(Float64.fromJsonValue(fieldValue, path + ".stars"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.stars': ${e.message}")
            }
        }
        
        // 解析 description 字段
        if (obj.getFields().contains("description")) {
            try {
                let fieldValue = obj.get("description").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.description = None
                } else {
                    ret.description = Some(String.fromJsonValue(fieldValue, path + ".description"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.description': ${e.message}")
            }
        }
        
        // 解析 group_id 字段
        if (obj.getFields().contains("group_id")) {
            try {
                let fieldValue = obj.get("group_id").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.groupId = None
                } else {
                    ret.groupId = Some(String.fromJsonValue(fieldValue, path + ".group_id"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.group_id': ${e.message}")
            }
        }
        
        // 解析 picture 字段
        if (obj.getFields().contains("picture")) {
            try {
                let fieldValue = obj.get("picture").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.picture = None
                } else {
                    ret.picture = Some(String.fromJsonValue(fieldValue, path + ".picture"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.picture': ${e.message}")
            }
        }
        
        // 解析 images 字段
        if (obj.getFields().contains("images")) {
            try {
                let fieldValue = obj.get("images").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.images = None
                } else {
                    ret.images = Some(String.fromJsonValue(fieldValue, path + ".images"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.images': ${e.message}")
            }
        }
        
        // 解析 content 字段
        if (obj.getFields().contains("content")) {
            try {
                let fieldValue = obj.get("content").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.content = None
                } else {
                    ret.content = Some(String.fromJsonValue(fieldValue, path + ".content"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.content': ${e.message}")
            }
        }
        
        // 解析 json 字段
        if (obj.getFields().contains("json")) {
            try {
                let fieldValue = obj.get("json").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.json = None
                } else {
                    ret.json = Some(String.fromJsonValue(fieldValue, path + ".json"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.json': ${e.message}")
            }
        }
        
        // 解析 city 字段
        if (obj.getFields().contains("city")) {
            try {
                let fieldValue = obj.get("city").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.city = None
                } else {
                    ret.city = Some(String.fromJsonValue(fieldValue, path + ".city"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.city': ${e.message}")
            }
        }
        
        // 解析 price 字段
        if (obj.getFields().contains("price")) {
            try {
                let fieldValue = obj.get("price").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.price = None
                } else {
                    ret.price = Some(Float64.fromJsonValue(fieldValue, path + ".price"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.price': ${e.message}")
            }
        }
        
        // 解析 birthday 字段
        if (obj.getFields().contains("birthday")) {
            try {
                let fieldValue = obj.get("birthday").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.birthday = None
                } else {
                    ret.birthday = Some(DateTime.fromJsonValue(fieldValue, path + ".birthday"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.birthday': ${e.message}")
            }
        }
        
        // 解析 owner 字段
        if (obj.getFields().contains("owner")) {
            try {
                let fieldValue = obj.get("owner").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.owner = None
                } else {
                    ret.owner = Some(String.fromJsonValue(fieldValue, path + ".owner"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.owner': ${e.message}")
            }
        }
        
        // 解析 creator 字段
        if (obj.getFields().contains("creator")) {
            try {
                let fieldValue = obj.get("creator").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.creator = None
                } else {
                    ret.creator = Some(String.fromJsonValue(fieldValue, path + ".creator"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.creator': ${e.message}")
            }
        }
        
        // 解析 created_at 字段
        if (obj.getFields().contains("created_at")) {
            try {
                ret.createdAt = DateTime.fromJsonValue(obj.get("created_at").getOrThrow(), path + ".created_at")
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.created_at': ${e.message}")
            }
        }
        
        // 解析 updated_at 字段
        if (obj.getFields().contains("updated_at")) {
            try {
                ret.updatedAt = DateTime.fromJsonValue(obj.get("updated_at").getOrThrow(), path + ".updated_at")
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.updated_at': ${e.message}")
            }
        }
        
        // 解析 deleted_at 字段
        if (obj.getFields().contains("deleted_at")) {
            try {
                let fieldValue = obj.get("deleted_at").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.deletedAt = None
                } else {
                    ret.deletedAt = Some(DateTime.fromJsonValue(fieldValue, path + ".deleted_at"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.deleted_at': ${e.message}")
            }
        }
        
        // 解析 end_time 字段
        if (obj.getFields().contains("end_time")) {
            try {
                let fieldValue = obj.get("end_time").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.endTime = None
                } else {
                    ret.endTime = Some(DateTime.fromJsonValue(fieldValue, path + ".end_time"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.end_time': ${e.message}")
            }
        }
        
        // 解析 start_time 字段
        if (obj.getFields().contains("start_time")) {
            try {
                let fieldValue = obj.get("start_time").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.startTime = None
                } else {
                    ret.startTime = Some(DateTime.fromJsonValue(fieldValue, path + ".start_time"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.start_time': ${e.message}")
            }
        }
        
        // 解析 status 字段
        if (obj.getFields().contains("status")) {
            try {
                let fieldValue = obj.get("status").getOrThrow()
                if (fieldValue is JsonNull) {
                    ret.status = None
                } else {
                    ret.status = Some(String.fromJsonValue(fieldValue, path + ".status"))
                }
            } catch (e: Exception) {
                if (e.message.startsWith("JSON deserialization error at '")) {
                    throw e
                }
                throw Exception("JSON deserialization error at '${path}.status': ${e.message}")
            }
        }
        
        return ret
    }
}
