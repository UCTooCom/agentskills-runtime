/*
 * L3 进程隔离轨插件 sdd 入口
 * 禁用 @Plugin 宏（cjpm 宏包 organization 跨模块缺陷）
 * 显式 API：PluginRuntime.run(...)
 *
 * 编码依据：skills/long-running-task/src/main.cj（同为 L3 process 轨，已通过编译）
 *
 * 红线修正（相对 plugingen 生成的骨架）：
 *   1. 骨架用了 `console.log` 打 stdout —— L3 进程 stdout 是 stdio RPC 协议通道
 *      （NewlineFraming 逐行解析），混入非协议帧会导致宿主解析错乱，故改 `eprintln` 走 stderr。
 *   2. 骨架注册 `SddHandlers`（CRUD add/edit/del/get/list 框架）——SDD 是编排型插件，
 *      不需要通用 CRUD，handlers.cj 已按 T-01 删除，此处同步去掉注册（否则编译报未定义符号）。
 *   3. `PluginRuntime.run` 采用 long-running-task 的位置参数调用形式（已通过该插件编译验证），
 *      不使用骨架模板的 `name:` / `provide!:` 命名参数形式。
 */
package skill_sdd

import ystyle::cordis_plugin.{PluginRuntime, PluginContext}
import jsonvalue.*

main(): Int64 {
    eprintln("[skill_sdd] L3 process plugin starting")
    let inject = Array<String>(0, { _ => "" })
    let provide = Array<String>(0, { _ => "" })
    PluginRuntime.run(
        "sdd",
        inject,
        provide,
        { ctx =>
            // T-09 将在此补齐三个注册：
            //   SddHandlers.register(ctx)          —— 六步编排入口（gen-* / review / projects）
            //   SddSubAgentDispatch.register(ctx)  —— 子 agent 派单八步时序
            //   SddEventRelay.register(ctx)        —— 经 host.event 上报 sdd_* 进度事件
            SddEffects.register(ctx)
        }
    )
    return 0
}
