package ystyle::cordis_plugin.examples.event_emit

import ystyle::cordis_plugin.*
import jsonvalue.*

/**
 * 端到端事件发布者插件：启动后发布 stats/report 事件
 *
 * 由宿主拉起；不感知订阅者（谁在听由宿主路由决定）。
 */
main(): Int64 {
    PluginRuntime.run("event-emit", [], [], { ctx =>
        // 发布两个事件（宿主扇出给订阅者）
        ctx.emit("stats/report", [JsonValue.Number(1.0)])
        ctx.emit("stats/report", [JsonValue.Number(2.0)])
        ctx.log("info", "event-emit published 2 events")
    })
    return 0
}
