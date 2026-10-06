/*
 * L3 进程隔离轨插件 github 入口
 * 禁用 @Plugin 宏（cjpm 宏包 organization 跨模块缺陷）
 * 显式 API：PluginRuntime.run(...)
 */
package skill_github

import ystyle::cordis_plugin.{PluginRuntime, PluginContext}
import jsonvalue.*

//#region AutoCreateCode
main(): Int64 {
    // stdout 是 JSON-RPC 协议通道（NewlineFraming 逐行解析），诊断信息必须走 stderr
    eprintln("[skill_github] L3 process plugin starting")
    let inject = Array<String>(0, { _ => "" })
    let provide = Array<String>(0, { _ => "" })
    PluginRuntime.run(
        "github",
        inject,
        provide,
        { ctx =>
            GithubHandlers.register(ctx)
            GithubEffects.register(ctx)
        }
    )
    return 0
}
//#endregion AutoCreateCode

// ── 二次开发区 ────────────────────────────────────────────────
// 重新生成时以上 AutoCreateCode 区间会被覆盖，本区域的手写代码保留。
// 需要注册自定义 handler/effect 时：在此定义类，再把调用接进上面 main() 的 lambda 中。

