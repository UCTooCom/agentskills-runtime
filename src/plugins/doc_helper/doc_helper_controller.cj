/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.doc_helper

import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt}
import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.log.LogUtils

/**
 * DocHelperController - 文档摘要 HTTP 控制器（插件轨路由示例）
 *
 * 由 PluginRouteScanner 按注解 controllerClass 反射无参构造，
 * 服务实例经静态接点 wiredService 获取（DocHelperPlugin.onLoad 注入，
 * 停用后清空 -> 路由降级 503，注册表中的路由不删除）
 *
 * 路由（DocHelperRoute 声明）：
 *   POST /api/v1/plugins/doc-helper/summary
 *   body: {"text": "待摘要文本", "maxSentences": 3}
 */
public class DocHelperController {
    /// 服务接线接点（插件激活注入，停用/卸载清空）
    public static var wiredService: Option<DocSummaryService> = None

    public init() {}

    /// 处理摘要请求（成功直接返回数据对象，错误返回 { errno, errmsg }）
    public func handleSummary(req: HttpRequest, res: HttpResponse): Unit {
        try {
            match (DocHelperController.wiredService) {
                case None =>
                    res.status(503).json("{\"errno\":503,\"errmsg\":\"doc-helper plugin is not active\"}")
                case Some(service) =>
                    let body = req.body
                    if (body.isEmpty()) {
                        res.status(400).json("{\"errno\":400,\"errmsg\":\"Request body is empty\"}")
                        return
                    }
                    let jsonObj = JsonValue.fromStr(body).asObject()
                    if (!jsonObj.containsKey("text")) {
                        res.status(400).json("{\"errno\":400,\"errmsg\":\"'text' field is required\"}")
                        return
                    }
                    let text = jsonObj["text"].asString().getValue()
                    let maxSentences = this.readMaxSentences(jsonObj)
                    let summary = service.summarize(text, maxSentences)

                    let resp = JsonObject()
                    resp.put("summary", JsonString(summary))
                    resp.put("maxSentences", JsonInt(Int64(maxSentences)))
                    res.status(200).json(resp.toJsonString())
            }
        } catch (e: Exception) {
            LogUtils.error("[DocHelperController] summary failed: ${e.message}")
            res.status(500).json("{\"errno\":500,\"errmsg\":\"Internal server error\"}")
        }
    }

    /// 读取可选参数 maxSentences（缺省 3；类型不符回退缺省值）
    private func readMaxSentences(jsonObj: JsonObject): Int32 {
        if (jsonObj.containsKey("maxSentences")) {
            let maxVal = jsonObj["maxSentences"]
            if (maxVal is JsonInt) {
                return Int32((maxVal as JsonInt).getOrThrow().getValue())
            }
        }
        return 3
    }
}
