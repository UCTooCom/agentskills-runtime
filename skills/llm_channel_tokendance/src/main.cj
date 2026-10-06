/*
 * L3 进程隔离轨插件 llm_channel_tokendance 入口
 * 禁用 @Plugin 宏（cjpm 宏包 organization 跨模块缺陷）
 * 显式 API：PluginRuntime.run(...)
 *
 * 本插件是**大模型通道适配器**（模式B：protocol = plugin:llm_channel_tokendance），
 * 不提供 HTTP 路由，只向宿主暴露 adapter.* 四个契约方法。
 * 契约：docs/ref/llm-adapter-contract.md
 */
package skill_llm_channel_tokendance

import ystyle::cordis_plugin.{PluginRuntime, PluginContext}
import jsonvalue.*

main(): Int64 {
    // stdout 是 JSON-RPC 协议通道（NewlineFraming 逐行解析），诊断信息必须走 stderr
    eprintln("[skill_llm_channel_tokendance] L3 adapter plugin starting")
    // inject 留空：host.secret 由宿主 CordisHostServices 无条件注册
    // （cordis_host_services.cj:78），不作为握手依赖，避免无谓的 Pending 等待
    let inject = Array<String>(0, { _ => "" })
    let provide = Array<String>(0, { _ => "" })
    PluginRuntime.run(
        "llm_channel_tokendance",
        inject,
        provide,
        { ctx =>
            // 适配器契约实现（describe / chat / chatStream / probe）
            TokendanceAdapter.register(ctx)
            LlmChannelTokendanceHandlers.register(ctx)
            LlmChannelTokendanceEffects.register(ctx)
        }
    )
    return 0
}
