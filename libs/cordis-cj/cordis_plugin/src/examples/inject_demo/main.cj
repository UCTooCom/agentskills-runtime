package ystyle::cordis_plugin.examples.inject_demo

import ystyle::cordis_plugin.*
import ystyle::cordis_plugin.macros.*
import jsonvalue.*

/**
 * @Inject 宏示例插件：注入 e2e 插件提供的 add 服务，通过代理调用
 *
 * 由宿主拉起；注入依赖 "add"（由其他插件提供）。
 * 宏生成：init(ctx) 构造函数注入 ServiceProxy + inject 依赖列表 ["add"]。
 */
@Plugin[]
public class InjectDemo {
    @Inject["add"]
    public var add: ServiceProxy

    @Provide["calc"]
    public func calc(args: Array<JsonValue>): JsonValue {
        // 通过代理调用远程 add 服务（宿主 invoke 转发）；args 透传，缺省 5+6
        let a = if (args.size > 0) {
            match (args[0]) { case JsonValue.Number(n) => n; case _ => 5.0 }
        } else {
            5.0
        }
        let b = if (args.size > 1) {
            match (args[1]) { case JsonValue.Number(n) => n; case _ => 6.0 }
        } else {
            6.0
        }
        let result = this.add.call<JsonValue>("add", [JsonValue.Number(a), JsonValue.Number(b)])
        match (result) {
            case JsonValue.Number(n) => JsonValue.Number(n)
            case _ => JsonValue.Null
        }
    }
}
