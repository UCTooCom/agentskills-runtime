/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */

/**
 * 长程任务 L3 插件调用客户端(Ch9)
 *
 * ## 为什么需要这个类
 *
 * 长程任务的业务实现(规划/执行/干预/验核/自演化)全部在**进程隔离插件**
 * `skills/long-running-task` 里,宿主侧只保留"入口 + 桥接"。
 * 宿主已有两条到达插件的路：
 *
 * 1. **HTTP 路**：`ExternalPluginRouteGateway` 把 plugin.yaml 的 routes 注册到
 *    宿主 Router,前端直接 `POST /api/v1/uctoo/long_running_task/lrt-plan` 即可。
 * 2. **内部路(本类)**：宿主进程内的其它组件(如 `WebMCPProtocol` 的意图路由、
 *    定时器、事件回调)需要在**不经过 HTTP 栈**的前提下调用同一个插件方法。
 *
 * 只有第 1 条路时,宿主内部想调插件就只能"自己给自己发 HTTP 请求",
 * 这在同进程里既是资源浪费(多一次序列化 + 走一遍中间件),
 * 也会因缺少认证上下文而失败。本类把第 2 条路补齐。
 *
 * ## 与 ExternalPluginRouteGateway 的关系
 *
 * **不重复实现 invoke 协议**。本类复用网关的同一套 JSON-RPC 约定：
 * `client.call<JsonValue, JsonValue>("invoke", params, timeout)`,
 * `params = { service: <pluginId>, method: <HTTP方法>, args: [ExternalRequest] }`。
 * 差异只在两点：
 * - **requestId** 本地生成(不经过 HTTP,没有网关的 requestId);
 * - **pathParams** 由调用方直接给出(不经过 Router,路由参数没有自动解析)。
 *
 * 这样插件侧看到的 `ExternalRequest` 结构与 HTTP 路**完全一致**,
 * 插件代码不需要为内部调用写第二套分支。
 *
 * ## 可用性约定
 *
 * 插件未启动(L3 轨未启用、插件加载失败、进程崩溃)时,本类一律返回
 * `Err(<原因>)`,**不抛异常**。调用方(如意图路由)据此决定"降级为普通
 * 对话"还是"回错误",而不是让一次插件不可用把宿主请求打挂。
 */

package magic.app.services.lrt

import std.collection.{ArrayList, HashMap}
import std.core.Duration
import std.time.DateTime
import jsonvalue.JsonValue
import magic.log.LogUtils
import magic.plugin.PluginAgentTools
import ystyle::cordis_core.InstanceStatus
import ystyle::cordis_host.PluginInstance
import f_base.Result

/// 长程任务插件标识（与 skills/long-running-task/plugin.yaml 的 name 一致）
public let LRT_PLUGIN_ID: String = "long-running-task"

/// 长程任务插件的路由前缀（plugin.yaml routes 的公共前缀）
public let LRT_ROUTE_PREFIX: String = "/api/v1/uctoo/long_running_task"

/// 插件调用超时。规划/执行类方法本身可能较慢，故给到 60s；
/// 对照 ExternalPluginRouteGateway 的 30s（那个是给普通 CRUD 用的）。
let LRT_INVOKE_TIMEOUT: Duration = 60 * Duration.second

/**
 * 长程任务插件调用客户端
 *
 * 全部方法都是 static：宿主里没有"长程任务客户端实例"这种有生命周期的对象,
 * 调用点散落在协议层、控制器、定时器,逐个注入引用会让装配链更脆。
 */
public class LrtPluginClient {
    /**
     * 调用插件的自定义方法(不经 HTTP)
     *
     * @param method HTTP 方法名(与 plugin.yaml routes 的 method 一致,插件按此 dispatch)
     * @param path 完整路径(含 LRT_ROUTE_PREFIX),用于插件侧二次路由
     * @param pathParams 路由参数(如 {"rootId": "xxx"});无则传空
     * @param queryParams 查询参数(如 {"page": "1"});无则传空
     * @param body 请求体;无则传 JsonValue.Null
     * @param userId 当前用户 ID(插件侧行级权限用;无则传空串)
     * @param permissions 权限列表(插件侧 RequirePermission 用)
     * @return Ok(插件返回的 JsonValue) / Err(原因字符串)
     */
    public static func invoke(
        method: String,
        path: String,
        pathParams: HashMap<String, String>,
        queryParams: HashMap<String, String>,
        body: JsonValue,
        userId: String,
        permissions: ArrayList<String>
    ): Result<JsonValue, String> {
        // 1. 拿插件宿主总控。未启用插件系统时直接返回错误，不必往下走。
        let hostManager = match (PluginAgentTools.pluginManager()) {
            case Some(m) => m
            case None =>
                LogUtils.warn("[LrtPluginClient] 插件系统未初始化，无法调用 ${LRT_PLUGIN_ID}")
                return Err("plugin system not initialized")
        }

        // 2. 拿 L3 进程轨总控。未启用时说明当前部署是内嵌/无进程插件模式。
        let cordisManager = match (hostManager.cordisHost()) {
            case Some(m) => m
            case None =>
                LogUtils.warn("[LrtPluginClient] L3 进程轨未启用，无法调用 ${LRT_PLUGIN_ID}")
                return Err("L3 process track not enabled")
        }

        // 3. 拿插件实例。None 表示插件未启动/已退出。
        let instance = match (cordisManager.getInstance(LRT_PLUGIN_ID)) {
            case Some(i) => i
            case None =>
                LogUtils.warn("[LrtPluginClient] 插件未运行: ${LRT_PLUGIN_ID}")
                return Err("plugin '${LRT_PLUGIN_ID}' not running")
        }

        // 4. 状态闸门：与 ExternalPluginRouteGateway 同一判断，
        //    保证"HTTP 路通、内部路不通"这种诡异情况不会出现。
        match (instance.status) {
            case InstanceStatus.Unreachable =>
                return Err("plugin '${LRT_PLUGIN_ID}' unreachable")
            case InstanceStatus.Failed =>
                return Err("plugin '${LRT_PLUGIN_ID}' failed")
            case _ => ()  // Starting/Pending/Active/Unloading 继续
        }

        // 5. 组装 ExternalRequest（与网关 serializeRequest 出的结构逐字段对齐）
        let requestId = LrtPluginClient.generateRequestId()
        let externalRequest = LrtPluginClient.buildExternalRequest(
            requestId, method, path, pathParams, queryParams, body, userId, permissions
        )

        // 6. JSON-RPC invoke
        let argsArray = ArrayList<JsonValue>(1, { _ => JsonValue.Null })
        argsArray[0] = externalRequest
        let invokeParams = HashMap<String, JsonValue>()
        invokeParams["service"] = JsonValue.String(LRT_PLUGIN_ID)
        invokeParams["method"] = JsonValue.String(method)
        invokeParams["args"] = JsonValue.Array(argsArray)

        try {
            let result = instance.client.call<JsonValue, JsonValue>(
                "invoke",
                params: Some(JsonValue.from(invokeParams)),
                timeout: LRT_INVOKE_TIMEOUT
            )
            match (result) {
                case Ok(v) => Ok(v)
                case Err(e) => Err(e)
            }
        } catch (e: Exception) {
            // client.call 理论上以 Result 表达失败，这里兜的是序列化/通道级异常。
            LogUtils.error("[LrtPluginClient] invoke 异常: ${e.message}")
            Err("invoke exception: ${e.message}")
        }
    }

    /**
     * 便捷方法：提交长程任务规划(`lrt-plan`)
     *
     * @param taskId 宿主侧已创建的 agent_tasks.id(插件据此回写规划结果)
     * @param goal 用户目标原文
     */
    public static func plan(taskId: String, goal: String, userId: String, permissions: ArrayList<String>): Result<JsonValue, String> {
        let body = HashMap<String, JsonValue>()
        body["task_id"] = JsonValue.String(taskId)
        body["goal"] = JsonValue.String(goal)
        return invoke(
            "POST",
            "${LRT_ROUTE_PREFIX}/lrt-plan",
            HashMap<String, String>(),
            HashMap<String, String>(),
            JsonValue.from(body),
            userId,
            permissions
        )
    }

    /**
     * 便捷方法：触发长程任务执行(`lrt-execute`)
     *
     * @param taskId 根任务 ID
     */
    public static func execute(taskId: String, userId: String, permissions: ArrayList<String>): Result<JsonValue, String> {
        let body = HashMap<String, JsonValue>()
        body["task_id"] = JsonValue.String(taskId)
        return invoke(
            "POST",
            "${LRT_ROUTE_PREFIX}/lrt-execute",
            HashMap<String, String>(),
            HashMap<String, String>(),
            JsonValue.from(body),
            userId,
            permissions
        )
    }

    /**
     * 便捷方法：干预(`lrt-intervene`)
     *
     * @param taskId 任务 ID
     * @param action 干预动作(pause/resume/cancel/redirect/modify)
     * @param content 干预内容(如 redirect 的新目标、modify 的新参数)
     */
    public static func intervene(
        taskId: String,
        action: String,
        content: String,
        userId: String,
        permissions: ArrayList<String>
    ): Result<JsonValue, String> {
        let body = HashMap<String, JsonValue>()
        body["task_id"] = JsonValue.String(taskId)
        body["action"] = JsonValue.String(action)
        body["content"] = JsonValue.String(content)
        return invoke(
            "POST",
            "${LRT_ROUTE_PREFIX}/lrt-intervene",
            HashMap<String, String>(),
            HashMap<String, String>(),
            JsonValue.from(body),
            userId,
            permissions
        )
    }

    /**
     * 便捷方法：验核(`lrt-verify`)
     */
    public static func verify(taskId: String, userId: String, permissions: ArrayList<String>): Result<JsonValue, String> {
        let body = HashMap<String, JsonValue>()
        body["task_id"] = JsonValue.String(taskId)
        return invoke(
            "POST",
            "${LRT_ROUTE_PREFIX}/lrt-verify",
            HashMap<String, String>(),
            HashMap<String, String>(),
            JsonValue.from(body),
            userId,
            permissions
        )
    }

    /**
     * 便捷方法：自演化(`lrt-evolve`)
     *
     * @param agentId 目标 Agent ID(自演化产物写回该 Agent 的技能/配置)
     */
    public static func evolve(agentId: String, userId: String, permissions: ArrayList<String>): Result<JsonValue, String> {
        let body = HashMap<String, JsonValue>()
        body["agent_id"] = JsonValue.String(agentId)
        return invoke(
            "POST",
            "${LRT_ROUTE_PREFIX}/lrt-evolve",
            HashMap<String, String>(),
            HashMap<String, String>(),
            JsonValue.from(body),
            userId,
            permissions
        )
    }

    /**
     * 便捷方法：交付确认(`lrt-deliver`，spec 5.6.1 规则 5 / Ch6.3)
     *
     * 用户在**确认交付后**才允许产物落地并置 `status=2`；执行器自身不得宣称完成。
     * 本方法是这条规则在宿主侧的唯一出口 —— 插件的 `lrt-deliver` 走 JSON-RPC over stdio，
     * 浏览器够不着，缺了这层转发，§6.3 的「用户确认」环节在宿主↔前端之间就是断的。
     *
     * @param taskId   任务 ID
     * @param action   确认动作：`confirm`(确认交付→status=2) / `abandon`(放弃→status=4)
     */
    public static func deliver(
        taskId: String,
        action: String,
        userId: String,
        permissions: ArrayList<String>
    ): Result<JsonValue, String> {
        let body = HashMap<String, JsonValue>()
        body["task_id"] = JsonValue.String(taskId)
        body["action"] = JsonValue.String(action)
        return invoke(
            "POST",
            "${LRT_ROUTE_PREFIX}/lrt-deliver",
            HashMap<String, String>(),
            HashMap<String, String>(),
            JsonValue.from(body),
            userId,
            permissions
        )
    }

    /**
     * 便捷方法：评审改进(`lrt-review`，spec 5.6.1 规则 4 / Ch6.3)
     *
     * 用户对验核结果不满意时给出反馈，由插件触发 `LrtPlanner.replan` 重规划并继续执行，
     * 形成「验核 → 评审 → 改进 → 再验核」的闭环。
     *
     * @param taskId   任务 ID
     * @param action   评审动作：`improve`(要求改进→触发 replan) / `abandon`(放弃→status=4)
     * @param feedback 用户的改进要求，作为 addedConstraints 传入 replan（可为空串）
     * @param goal     用户重述的目标（可为空串：为空表示沿用原目标，只追加反馈约束）
     */
    public static func review(
        taskId: String,
        action: String,
        feedback: String,
        goal: String,
        userId: String,
        permissions: ArrayList<String>
    ): Result<JsonValue, String> {
        let body = HashMap<String, JsonValue>()
        body["task_id"] = JsonValue.String(taskId)
        body["action"] = JsonValue.String(action)
        // 两个可空语义字段：空串时仍显式下发，让插件侧无需区分「键缺失」与「值为空」
        body["feedback"] = JsonValue.String(feedback)
        body["goal"] = JsonValue.String(goal)
        return invoke(
            "POST",
            "${LRT_ROUTE_PREFIX}/lrt-review",
            HashMap<String, String>(),
            HashMap<String, String>(),
            JsonValue.from(body),
            userId,
            permissions
        )
    }

    // ── 内部实现 ──────────────────────────────────────────────────

    /// 构造 ExternalRequest JSON（与 ExternalPluginRouteGateway.serializeRequest 逐字段对齐）
    private static func buildExternalRequest(
        requestId: String,
        method: String,
        path: String,
        pathParams: HashMap<String, String>,
        queryParams: HashMap<String, String>,
        body: JsonValue,
        userId: String,
        permissions: ArrayList<String>
    ): JsonValue {
        let params = HashMap<String, JsonValue>()
        params["requestId"] = JsonValue.String(requestId)
        params["pluginId"] = JsonValue.String(LRT_PLUGIN_ID)
        params["method"] = JsonValue.String(method)
        params["path"] = JsonValue.String(path)
        params["pathParams"] = JsonValue.from(LrtPluginClient.strMapToJson(pathParams))
        params["queryParams"] = JsonValue.from(LrtPluginClient.strMapToJson(queryParams))
        params["body"] = body
        // userId 为空时显式 null（与网关一致），插件侧据此区分"未认证"与"用户 0"
        if (userId.isEmpty()) {
            params["userId"] = JsonValue.Null
        } else {
            params["userId"] = JsonValue.String(userId)
        }
        let permArray = ArrayList<JsonValue>()
        for (perm in permissions) {
            permArray.add(JsonValue.String(perm))
        }
        params["permissions"] = JsonValue.Array(permArray)
        let headers = HashMap<String, JsonValue>()
        headers["Content-Type"] = JsonValue.String("application/json")
        headers["X-Lrt-Internal"] = JsonValue.String("1")  // 标记内部调用，便于插件侧日志区分
        params["headers"] = JsonValue.from(headers)
        JsonValue.from(params)
    }

    private static func strMapToJson(src: HashMap<String, String>): HashMap<String, JsonValue> {
        let out = HashMap<String, JsonValue>()
        for ((k, v) in src) {
            out[k] = JsonValue.String(v)
        }
        out
    }

    /// 本地 requestId：`lrt-req-<毫秒时间戳>-<自增序号>`
    /// 自增序号保证同一毫秒内的并发调用不撞 ID（网关用的是随机串，这里不必引入随机源）
    private static var _seq: Int64 = 0

    private static func generateRequestId(): String {
        _seq = _seq + 1
        "lrt-req-${(DateTime.now() - DateTime.UnixEpoch).toMilliseconds()}-${_seq}"
    }
}
