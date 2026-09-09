/*
 * L3 进程隔离轨插件 codelabs 入口
 * 禁用 @Plugin 宏（cjpm 宏包 organization 跨模块缺陷）
 * 显式 API：PluginRuntime.run(...)
 */
package skill_codelabs

import ystyle::cordis_plugin.{PluginRuntime, PluginContext}
import jsonvalue.*

main(): Int64 {
    // stdout 是 JSON-RPC 协议通道（NewlineFraming 逐行解析），诊断信息必须走 stderr
    eprintln("[skill_codelabs] L3 process plugin starting")
    let inject = Array<String>(0, { _ => "" })
    let provide = Array<String>(0, { _ => "" })
    PluginRuntime.run(
        "codelabs",
        inject,
        provide,
        { ctx =>
            CodelabsHandlers.register(ctx)
            CodelabsEffects.register(ctx)
        }
    )
    return 0
}
