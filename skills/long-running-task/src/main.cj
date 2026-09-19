/*
 * L3 进程隔离轨插件 long-running-task 入口
 * 禁用 @Plugin 宏（cjpm 宏包 organization 跨模块缺陷）
 * 显式 API：PluginRuntime.run(...)
 *
 * 承载 2 张新增表 CRUD + 5 个自定义路由（lrt-plan/lrt-execute/lrt-intervene/lrt-verify/lrt-evolve）
 * 经 ctx.invoke("host.db", ...) 访问宿主数据库
 * 经 ctx.invoke("host.mcp", "call", ...) 调用宿主统一 MCP 开放服务
 *
 * 编码依据：skills/due_diligence_agent/src/main.cj（JSON-RPC over stdio 通信模式）
 */
package skill_long_running_task

import ystyle::cordis_plugin.{PluginRuntime, PluginContext}
import jsonvalue.*

main(): Int64 {
    eprintln("[skill_long_running_task] L3 process plugin starting")
    let inject = Array<String>(0, { _ => "" })
    let provide = Array<String>(0, { _ => "" })
    PluginRuntime.run(
        "long-running-task",
        inject,
        provide,
        { ctx =>
            LrtHandlers.register(ctx)
            LrtEffects.register(ctx)
        }
    )
    return 0
}
