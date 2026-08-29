package ystyle::cordis_plugin

import ystyle::cordis_core.{Methods, InvokeParams}
import ystyle::jsonrpc.JsonRpcServer
import jsonvalue.JsonValue
import stdx.encoding.json.stream.JsonDeserializable

/**
 * 服务代理（docs/design-impl.md §6 / @Inject 宏产物）
 *
 * 封装对远程服务（其他插件提供）的调用：所有调用经宿主 invoke 转发。
 * @Inject["key"] 宏生成的字段即为此类型：
 *
 * ```cangjie
 * @Plugin[]
 * public class MyPlugin {
 *     @Inject["db"]
 *     public var db: ServiceProxy   // 宏注入 ServiceProxy(ctx, "db")
 * }
 * ```
 */
public class ServiceProxy {
    private let server: JsonRpcServer
    private let serviceKey: String

    public init(server: JsonRpcServer, serviceKey: String) {
        this.server = server
        this.serviceKey = serviceKey
    }

    /**
     * 调用远程服务方法（泛型：返回自动反序列化为 R）
     * @param method 服务方法名
     * @param args 参数列表（JsonValue，自动序列化）
     * @return 服务返回值（自动反序列化为 R；R=JsonValue 时原样返回）
     * @throws Exception 宿主返回错误或调用超时
     */
    public func call<R>(method: String, args: Array<JsonValue>): R
        where R <: JsonDeserializable<R> {
        let result = this.server.request<InvokeParams, JsonValue>(
            Methods.INVOKE,
            params: InvokeParams(this.serviceKey, method, args))
        match (result) {
            case Ok(v) => JsonValue.toObject<R>(v)
            case Err(e) => throw Exception("invoke ${this.serviceKey}.${method} failed: ${e}")
        }
    }
}
