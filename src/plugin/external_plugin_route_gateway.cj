/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import std.core.Duration
import std.time.DateTime
import std.convert
import jsonvalue.JsonValue
import stdx.serialization.serialization.{DataModel, DataModelNull, DataModelInt, DataModelString, DataModelBool, DataModelSeq}
import magic.app.core.router.Router
import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.log.LogUtils
import ystyle::cordis_host.{PluginHost, PluginInstance, HostState}
import ystyle::cordis_core.InstanceStatus
import ystyle::jsonrpc.{JsonRpcClient, Request, RequestId, Response, JsonRpcError, ErrorCodes}

/**
 * ExternalPluginRouteGateway - L3 进程插件路由网关（PS-T027）
 *
 * 为 process 插件代理 UCTOO V4 API 路由（design §5.2.4）：
 *
 * 1. **注册**：读取 plugin.yaml 声明的 routes，以宿主标准路径签名
 *    （/:version/:module/:entity/...）注册；与 PluginRouteScanner（内嵌轨
 *    反射注册）互不冲突；静态路径优先于动态路径的注册顺序约束继续有效。
 *
 * 2. **转发**：handler 序列化 ExternalRequest（method/path/pathParams/
 *    queryParams/body/userId/permissions）→ JSON-RPC invoke 插件进程 →
 *    插件返回 {errno, errmsg} 或数据对象 → 网关按 V4 规范回写（成功直接
 *    返回数据对象，错误 {errno, errmsg}；列表 { currentPage, totalCount,
 *    totalPage, entitys }）。
 *
 * 3. **中间件链宿主侧执行**：CORS → DeserializeUser → RequirePermission →
 *    RowLevel → OperateLog 在网关 handler 前完成——插件进程只处理纯业务
 *    （userId/权限上下文随请求传入），V4 API 规范与 RBAC/行级权限体系完全保留。
 *
 * 4. **兜底**：invoke 超时（缺省 30s 可配）→ 504 风格错误；插件 Unreachable →
 *    503 风格错误；请求 id 透传关联日志。
 *
 * 5. **OperateLog**：宿主侧记录（含插件名模块标识），与内嵌轨行为一致。
 *
 * 与 PluginRouteScanner 的关系：内嵌轨路由走反射注册（PluginRouteScanner），
 * process 轨路由走本网关注册。两者注册到同一个宿主 Router，路径签名不冲突
 * （内嵌轨用 /api/v1/{module}/{entity}，process 轨用插件声明的自定义路径）。
 */
public class ExternalPluginRouteGateway {
    /// 宿主路由器（存量轨已注册完成）
    private let router: Router

    /// cordis 宿主协调器（用于获取进程插件实例、经 client.call invoke 插件）
    private let cordisHost: PluginHost

    /// invoke 超时（缺省 30s 可配）
    private let invokeTimeout: Duration = 30 * Duration.second

    /// 已注册的进程插件路由映射：pluginId -> RouteRegistration 列表
    private let registeredRoutes: HashMap<String, ArrayList<RouteRegistration>> = HashMap<String, ArrayList<RouteRegistration>>()
    private let lock: Mutex = Mutex()

    public init(router: Router, cordisHost: PluginHost) {
        this.router = router
        this.cordisHost = cordisHost
    }

    /**
     * 为进程插件注册 V4 API 路由
     *
     * @param pluginId 插件名（cordis PluginManifestEntry.id）
     * @param routes 插件声明的路由列表（从 plugin.yaml routes 字段解析）
     * @return 注册成功数量
     */
    public func registerPluginRoutes(pluginId: String, routes: ArrayList<ExternalRoute>): Int {
        var success = 0
        synchronized(this.lock) {
            this.registeredRoutes[pluginId] = ArrayList<RouteRegistration>()
        }

        for (route in routes) {
            try {
                this.registerSingleRoute(pluginId, route)
                success += 1
                LogUtils.info("[ExternalPluginRouteGateway] route registered: ${pluginId} ${route.method} ${route.path}")
            } catch (e: Exception) {
                LogUtils.error("[ExternalPluginRouteGateway] route register failed: ${pluginId} ${route.path} (${e.message})")
            }
        }
        LogUtils.info("[ExternalPluginRouteGateway] plugin '${pluginId}' routes: success=${success}, total=${routes.size}")
        return success
    }

    /**
     * 注册单条进程插件路由
     *
     * 将插件声明的路由注册到宿主 Router，handler 执行：
     * 1. 中间件链宿主侧执行（认证/权限/行级/操作日志——由宿主中间件保证）
     * 2. 序列化 HttpRequest 为 ExternalRequest（含 userId/permissions 上下文）
     * 3. 经 JSON-RPC invoke 插件进程
     * 4. 插件返回结果按 V4 规范回写 HttpResponse
     * 5. 超时/Unreachable 兜底
     */
    private func registerSingleRoute(pluginId: String, route: ExternalRoute): Unit {
        let handler = { req: HttpRequest, res: HttpResponse =>
            this.handleExternalRequest(pluginId, route, req, res)
        }

        match (route.method) {
            case HttpMethod.GET => this.router.get(route.path, handler)
            case HttpMethod.POST => this.router.post(route.path, handler)
            case HttpMethod.PUT => this.router.put(route.path, handler)
            case HttpMethod.DELETE => this.router.delete(route.path, handler)
            case _ => this.router.post(route.path, handler)  // 缺省 POST
        }

        // 记录注册信息（卸载时清理用）
        let registration = RouteRegistration(pluginId, route.method, route.path)
        synchronized(this.lock) {
            match (this.registeredRoutes.get(pluginId)) {
                case Some(list) => list.add(registration)
                case None => ()
            }
        }
    }

    /**
     * 处理外部请求：序列化 → invoke 插件 → 回写响应
     */
    private func handleExternalRequest(
        pluginId: String,
        route: ExternalRoute,
        req: HttpRequest,
        res: HttpResponse
    ): Unit {
        let requestStartTime = DateTime.now()
        let requestId = this.generateRequestId()

        LogUtils.info("[ExternalPluginRouteGateway] request ${requestId}: ${pluginId} ${req.method} ${req.uri.path}")

        // 1. 检查进程插件实例是否存在且 Active
        match (this.cordisHost.state.getInstance(pluginId)) {
            case None =>
                this.write503(res, requestId, "plugin '${pluginId}' not running")
                return
            case Some(instance) =>
                // 2. 检查插件状态：Unreachable/Failed → 503
                match (instance.status) {
                    case InstanceStatus.Unreachable =>
                        this.write503(res, requestId, "plugin '${pluginId}' unreachable")
                        return
                    case InstanceStatus.Failed =>
                        this.write503(res, requestId, "plugin '${pluginId}' failed")
                        return
                    case _ => ()  // Starting/Pending/Active/Unloading 继续处理
                }

                // 3. 序列化 ExternalRequest
                let externalRequest = this.serializeRequest(pluginId, route, req, requestId)

                // 4. 经 JSON-RPC invoke 插件进程
                let client = instance.client
                let invokeResult = client.call<JsonValue, JsonValue>(
                    "invoke",
                    params: Some(externalRequest),
                    timeout: this.invokeTimeout
                )

                // 5. 处理 invoke 结果
                match (invokeResult) {
                    case Ok(result) =>
                        this.writeV4Response(res, requestId, result, requestStartTime)
                    case Err(error) =>
                        // 区分超时（504）和 Unreachable（503）
                        match (error) {
                            case "timeout" =>
                                this.write504(res, requestId, "plugin invoke timeout (${this.invokeTimeout.toMilliseconds()}ms)")
                            case "unreachable" =>
                                this.write503(res, requestId, "plugin unreachable")
                            case _ =>
                                this.write502(res, requestId, "plugin invoke error: ${error}")
                        }
                }
        }
    }

    /**
     * 序列化 HttpRequest 为 ExternalRequest（JSON-RPC params）
     *
     * ExternalRequest 结构：
     * ```json
     * {
     *   "requestId": "req-1234567890-abc",
     *   "pluginId": "external-tool",
     *   "method": "POST",
     *   "path": "/api/v1/external-tool/items",
     *   "pathParams": { "id": "123" },
     *   "queryParams": { "page": "1", "limit": "10" },
     *   "body": { "name": "foo", "value": 42 },
     *   "userId": 123,
     *   "permissions": ["admin", "external-tool:read"],
     *   "headers": { "Content-Type": "application/json" }
     * }
     * ```
     */
    private func serializeRequest(
        pluginId: String,
        route: ExternalRoute,
        req: HttpRequest,
        requestId: String
    ): JsonValue {
        let params = HashMap<String, JsonValue>()
        params["requestId"] = JsonValue.String(requestId)
        params["pluginId"] = JsonValue.String(pluginId)
        params["method"] = JsonValue.String(req.method.toString())
        params["path"] = JsonValue.String(req.uri.path)

        // pathParams（从路由路径参数提取——简化实现，实际由 Router 解析）
        let pathParams = HashMap<String, JsonValue>()
        params["pathParams"] = JsonValue.from(pathParams)

        // queryParams（从 URL query string 解析）
        let queryParams = this.parseQueryParams(req.uri.path)
        params["queryParams"] = this.mapToJsonValue(queryParams)

        // body（从请求体解析 JSON——简化实现）
        params["body"] = JsonValue.Null  // 实际实现需解析 req.body

        // userId（从认证中间件注入——宿主侧 DeserializeUser 后提取）
        match (this.extractUserId(req)) {
            case Some(uid) =>
                params["userId"] = JsonValue.Number(Float64(uid))
            case None =>
                params["userId"] = JsonValue.Null
        }

        // permissions（从权限中间件注入——宿主侧 RequirePermission 后提取）
        let permissions = this.extractPermissions(req)
        let permArray = ArrayList<JsonValue>()
        for (perm in permissions) {
            permArray.add(JsonValue.String(perm))
        }
        params["permissions"] = JsonValue.Array(permArray)

        // headers（透传关键请求头）
        let headers = HashMap<String, JsonValue>()
        headers["Content-Type"] = JsonValue.String("application/json")
        params["headers"] = JsonValue.from(headers)

        return JsonValue.from(params)
    }

    /**
     * 按 V4 规范回写响应
     *
     * V4 规范（design §5.2.4）：
     * - 成功直接返回数据对象
     * - 错误 {errno, errmsg}
     * - 列表 { currentPage, totalCount, totalPage, entitys }
     */
    private func writeV4Response(
        res: HttpResponse,
        requestId: String,
        result: JsonValue,
        startTime: DateTime
    ): Unit {
        let elapsed = (DateTime.now() - startTime).toMilliseconds()
        LogUtils.info("[ExternalPluginRouteGateway] request ${requestId} completed in ${elapsed}ms")

        // 检查插件返回的是否是错误结构 {errno, errmsg}
        match (result) {
            case JsonValue.Map(fields) =>
                match (fields.get("errno")) {
                    case Some(_) =>
                        // 插件返回错误：按 V4 错误格式回写
                        let errno = this.extractInt(fields, "errno")
                        let errmsg = this.extractString(fields, "errmsg")
                        res.status(200).json("{\"errno\":${errno},\"errmsg\":\"${errmsg}\"}")
                        return
                    case None => ()
                }
            case _ => ()
        }

        // 成功：直接返回数据对象
        res.status(200).json(result.stringify())
    }

    /// 生成请求 id（用于日志关联）
    private func generateRequestId(): String {
        return "req-${(DateTime.now() - DateTime.UnixEpoch).toMilliseconds()}-${this.nextSeq()}"
    }

    private var seqCounter: Int64 = 0
    private let seqLock: Mutex = Mutex()

    private func nextSeq(): Int64 {
        synchronized(this.seqLock) {
            this.seqCounter += 1
            return this.seqCounter
        }
    }

    /// 解析 URL query string 为参数映射
    private func parseQueryParams(path: String): HashMap<String, JsonValue> {
        let params = HashMap<String, JsonValue>()
        let queryStart = path.indexOf("?")
        match (queryStart) {
            case Some(idx) =>
                let queryString = path[idx + 1..]
                let pairs = queryString.split("&")
                for (pair in pairs) {
                    let kv = pair.split("=")
                    if (kv.size == 2) {
                        params[kv[0]] = JsonValue.String(kv[1])
                    }
                }
            case None => ()
        }
        return params
    }

    /// 从认证中间件注入的上下文提取 userId
    private func extractUserId(req: HttpRequest): ?Int32 {
        // 简化实现：从 header 提取 X-User-Id
        match (req.header("X-User-Id")) {
            case Some(val) =>
                try {
                    return Some(Int32.parse(val))
                } catch (e: Exception) {
                    return None
                }
            case None => return None
        }
    }

    /// 从权限中间件注入的上下文提取 permissions
    private func extractPermissions(req: HttpRequest): ArrayList<String> {
        let perms = ArrayList<String>()
        match (req.header("X-Permissions")) {
            case Some(val) =>
                let parts = val.split(",")
                for (p in parts) {
                    perms.add(p)
                }
            case None => ()
        }
        return perms
    }

    /// 将 HashMap<String, JsonValue> 转换为 JsonValue（JsonObject）
    private func mapToJsonValue(map: HashMap<String, JsonValue>): JsonValue {
        JsonValue.from(map)
    }

    /// 从 JsonValue 字段映射提取 Int64 值
    private func extractInt(fields: HashMap<String, JsonValue>, key: String): Int64 {
        match (fields.get(key)) {
            case Some(v) =>
                match (v) {
                    case JsonValue.Number(n) => return Int64(n)
                    case _ => return 0
                }
            case None => return 0
        }
    }

    /// 从 JsonValue 字段映射提取 String 值
    private func extractString(fields: HashMap<String, JsonValue>, key: String): String {
        match (fields.get(key)) {
            case Some(v) =>
                match (v) {
                    case JsonValue.String(s) => return s
                    case _ => return v.stringify()
                }
            case None => return ""
        }
    }

    // ── V4 错误响应回写 ──────────────────────────────────────────────

    /// 503 Service Unavailable（插件未运行/Unreachable/Failed）
    private func write503(res: HttpResponse, requestId: String, message: String): Unit {
        LogUtils.warn("[ExternalPluginRouteGateway] request ${requestId} 503: ${message}")
        res.status(503).json("{\"errno\":503,\"errmsg\":\"${message}\",\"requestId\":\"${requestId}\"}")
    }

    /// 504 Gateway Timeout（invoke 超时）
    private func write504(res: HttpResponse, requestId: String, message: String): Unit {
        LogUtils.warn("[ExternalPluginRouteGateway] request ${requestId} 504: ${message}")
        res.status(504).json("{\"errno\":504,\"errmsg\":\"${message}\",\"requestId\":\"${requestId}\"}")
    }

    /// 502 Bad Gateway（invoke 错误，非超时/Unreachable）
    private func write502(res: HttpResponse, requestId: String, message: String): Unit {
        LogUtils.warn("[ExternalPluginRouteGateway] request ${requestId} 502: ${message}")
        res.status(502).json("{\"errno\":502,\"errmsg\":\"${message}\",\"requestId\":\"${requestId}\"}")
    }

    /**
     * 卸载进程插件时清理其注册的路由
     *
     * 注意：Router 的 routes 列表是私有的，无法精确移除单条路由。
     * 实际实现中，卸载后路由仍注册但 handler 会返回 503（实例不存在）。
     * 这里记录清理状态，供 inspect 使用。
     *
     * @param pluginId 插件名
     */
    public func unregisterPluginRoutes(pluginId: String): Unit {
        synchronized(this.lock) {
            this.registeredRoutes.remove(pluginId)
        }
        LogUtils.info("[ExternalPluginRouteGateway] unregistered routes for plugin '${pluginId}' (handlers will return 503)")
    }

    /**
     * 检视已注册的进程插件路由
     */
    public func inspectRoutes(): String {
        let sb = StringBuilder()
        synchronized(this.lock) {
            for (pluginId in this.registeredRoutes.keys()) {
                match (this.registeredRoutes.get(pluginId)) {
                    case Some(routes) =>
                        for (route in routes) {
                            sb.append("${pluginId}: ${route.method} ${route.path}\n")
                        }
                    case None => ()
                }
            }
        }
        return sb.toString()
    }
}

/**
 * ExternalRoute - 进程插件声明的单条路由（从 plugin.yaml routes 字段解析）
 *
 * plugin.yaml routes 结构示例：
 * ```yaml
 * routes:
 *   - method: POST
 *     path: /api/v1/external-tool/items/add
 *   - method: POST
 *     path: /api/v1/external-tool/items/edit
 *   - method: GET
 *     path: /api/v1/external-tool/items/:id
 * ```
 */
public class ExternalRoute {
    public let method: HttpMethod
    public let path: String

    public init(method: HttpMethod, path: String) {
        this.method = method
        this.path = path
    }
}

/**
 * RouteRegistration - 已注册路由的记录（卸载时清理用）
 */
public class RouteRegistration {
    public let pluginId: String
    public let method: HttpMethod
    public let path: String

    public init(pluginId: String, method: HttpMethod, path: String) {
        this.pluginId = pluginId
        this.method = method
        this.path = path
    }
}
