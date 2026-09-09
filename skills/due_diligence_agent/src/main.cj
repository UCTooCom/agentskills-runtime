/*
 * L3 进程隔离轨插件 due_diligence_agent 入口
 * 禁用 @Plugin 宏（cjpm 宏包 organization 跨模块缺陷）
 * 显式 API：PluginRuntime.run(...)
 *
 * 承载 6 张表 CRUD + dd-fetch 采集聚合 + dd-save 幂等落库
 * 经 ctx.invoke("host.db", ...) 访问宿主数据库
 * 经 ctx.invoke("host.mcp", "call", ...) 调用宿主统一 MCP 开放服务
 */
package skill_due_diligence_agent

import ystyle::cordis_plugin.{PluginRuntime, PluginContext}
import jsonvalue.*

main(): Int64 {
    eprintln("[skill_due_diligence_agent] L3 process plugin starting")
    let inject = Array<String>(0, { _ => "" })
    let provide = Array<String>(0, { _ => "" })
    PluginRuntime.run(
        "due_diligence_agent",
        inject,
        provide,
        { ctx =>
            DdHandlers.register(ctx)
            DdEffects.register(ctx)
        }
    )
    return 0
}