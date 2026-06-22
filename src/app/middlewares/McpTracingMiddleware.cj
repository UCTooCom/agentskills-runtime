/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.middlewares

import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.core.middleware.Middleware
import magic.log.LogUtils
import f_util.UUID
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import std.time.DateTime

public class McpTracingMiddleware <: Middleware {
    public init() {}

    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        let path = req.uri.path
        if (path.startsWith("/api/v1/uctoo/webmcp") || path.startsWith("/api/v1/webmcp")) {
            let requestId = "mcp_${UUID.random().toString()}"
            res.header("X-MCP-Request-ID", requestId)

            if (req.method == HttpMethod.POST) {
                let body = req.body
                if (!body.isEmpty()) {
                    try {
                        let jsonValue = JsonValue.fromStr(body)
                        if (jsonValue is JsonObject) {
                            let method = jsonValue.asObject().get("method")
                            if (method.isSome() && method.getOrThrow() is JsonString) {
                                res.header("X-MCP-Method", method.getOrThrow().asString().getValue())
                            }
                        }
                    } catch (_: Exception) {}
                }
            }

            let now = DateTime.now()
            let epoch = DateTime.ofEpoch(second: 0, nanosecond: 0)
            let duration = now - epoch
            res.header("X-Processing-Start", duration.toMilliseconds().toString())
        }

        next()
    }
}
