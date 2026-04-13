/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.mock

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import std.collection.{HashMap, Map, ArrayList}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.log.LogUtils

/**
 * MockController - Mock数据控制器
 *
 * 提供dashboard页面所需的mock数据接口
 * 对应原 NestJS 中的 mock/board.ts 接口
 */
public class MockController {
    
    /**
     * 获取用户数据选项
     * GET /api/user/getdata
     */
    public func getUserData(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let options = ArrayList<JsonValue>()
            
            let opt1 = JsonObject()
            opt1.put("value", JsonString("1"))
            opt1.put("label", JsonString("work.mock.employees"))
            options.add(opt1)
            
            let opt2 = JsonObject()
            opt2.put("value", JsonString("2"))
            opt2.put("label", JsonString("work.mock.onboard"))
            options.add(opt2)
            
            let opt3 = JsonObject()
            opt3.put("value", JsonString("3"))
            opt3.put("label", JsonString("work.mock.Test"))
            options.add(opt3)
            
            let result = JsonObject()
            result.put("options", JsonArray(options))
            
            res.status(200).json(result.toJsonString())
        } catch (e: Exception) {
            LogUtils.error("getUserData failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 获取实践数据
     * GET /api/user/getrpractic
     */
    public func getUserPractic(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let options = ArrayList<JsonValue>()
            
            let opt1 = JsonObject()
            opt1.put("value", JsonString("1"))
            opt1.put("label", JsonString("work.mock.week1"))
            options.add(opt1)
            
            let opt2 = JsonObject()
            opt2.put("value", JsonString("2"))
            opt2.put("label", JsonString("work.mock.week2"))
            options.add(opt2)
            
            let opt3 = JsonObject()
            opt3.put("value", JsonString("3"))
            opt3.put("label", JsonString("work.mock.week3"))
            options.add(opt3)
            
            let result = JsonObject()
            result.put("options", JsonArray(options))
            
            res.status(200).json(result.toJsonString())
        } catch (e: Exception) {
            LogUtils.error("getUserPractic failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 获取培训数据
     * GET /api/user/getrtrain
     */
    public func getUserTrain(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let options = ArrayList<JsonValue>()
            
            let opt1 = JsonObject()
            opt1.put("value", JsonString("work.mock.collectValue1"))
            opt1.put("description", JsonString("work.mock.collectDescription1"))
            opt1.put("label1", JsonString("work.mock.collectHotLabel1"))
            opt1.put("label2", JsonString("work.mock.collectLabel2"))
            options.add(opt1)
            
            let opt2 = JsonObject()
            opt2.put("value", JsonString("work.mock.collectValue2"))
            opt2.put("description", JsonString("work.mock.collectDescription2"))
            opt2.put("label1", JsonString("work.mock.collectHotLabel1"))
            opt2.put("label2", JsonString("work.mock.collectLabel3"))
            options.add(opt2)
            
            let opt3 = JsonObject()
            opt3.put("value", JsonString("work.mock.collectValue3"))
            opt3.put("description", JsonString("work.mock.collectDescription3"))
            opt3.put("label1", JsonString("work.mock.collectHotLabel1"))
            opt3.put("label2", JsonString("work.mock.collectLabel4"))
            options.add(opt3)
            
            let opt4 = JsonObject()
            opt4.put("value", JsonString("work.mock.collectValue4"))
            opt4.put("description", JsonString("work.mock.collectDescription4"))
            opt4.put("label1", JsonString("work.mock.collectHotLabel1"))
            opt4.put("label2", JsonString("work.mock.collectLabel5"))
            opt4.put("isNews", JsonBool(true))
            options.add(opt4)
            
            let result = JsonObject()
            result.put("options", JsonArray(options))
            
            res.status(200).json(result.toJsonString())
        } catch (e: Exception) {
            LogUtils.error("getUserTrain failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 切换数据源
     * POST /api/user/getselect
     */
    public func getUserChange(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            // 简化处理:直接解析body为整数
            let selectValue = Int64.parse(body)
            
            let result = ArrayList<JsonValue>()
            if (selectValue == 1) {
                result.add(JsonInt(101))
                result.add(JsonInt(212))
                result.add(JsonInt(122))
                result.add(JsonInt(232))
            } else if (selectValue == 2) {
                result.add(JsonInt(323))
                result.add(JsonInt(555))
                result.add(JsonInt(425))
                result.add(JsonInt(2221))
            } else {
                result.add(JsonInt(23234))
                result.add(JsonInt(234))
                result.add(JsonInt(989))
                result.add(JsonInt(122))
            }
            
            res.status(200).json(JsonArray(result).toJsonString())
        } catch (e: Exception) {
            LogUtils.error("getUserChange failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
}
