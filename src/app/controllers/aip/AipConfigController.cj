/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.aip

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.aip.AipConfigService
import magic.app.services.aip.model.AipMode
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject}

public class AipConfigController {
    private var configService: AipConfigService

    public init() {
        this.configService = AipConfigService()
    }

    public func getConfig(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = configService.getConfig()
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"获取配置失败\"}")
                }
            } else {
                let reason = result.reason ?? "获取配置失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipConfigController", "getConfig failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getMode(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = configService.getMode()
            if (result.success) {
                if (result.data.isSome()) {
                    let modeStr = match (result.data.getOrThrow()) {
                        case AipMode.Local => "local"
                        case AipMode.Interconnection => "interconnection"
                    }
                    res.status(200).json("{\"mode\":\"${modeStr}\"}")
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"获取模式失败\"}")
                }
            } else {
                let reason = result.reason ?? "获取模式失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipConfigController", "getMode failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func switchMode(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()

            let modeStr = getStringFromJson(obj, "mode")
            if (modeStr.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"mode参数不能为空\"}")
                return
            }

            if (modeStr != "local" && modeStr != "interconnection") {
                res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"无效的模式值，支持: local, interconnection\"}")
                return
            }

            let targetMode = match (modeStr) {
                case "local" => AipMode.Local
                case _ => AipMode.Interconnection
            }

            let result = configService.switchMode(targetMode)
            if (result.success) {
                res.status(200).json("{\"success\":true,\"mode\":\"${modeStr}\"}")
            } else {
                let reason = result.reason ?? "切换模式失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipConfigController", "switchMode failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func getStringFromJson(obj: JsonObject, key: String): String {
        let val = obj.get(key)
        if (val.isSome()) {
            let v = val.getOrThrow()
            let s = v as String
            if (let Some(str) <- s) { return str }
        }
        return ""
    }
}