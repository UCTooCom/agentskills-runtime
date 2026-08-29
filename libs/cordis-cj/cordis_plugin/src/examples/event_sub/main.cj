package ystyle::cordis_plugin.examples.event_sub

import ystyle::cordis_plugin.*
import jsonvalue.*

/**
 * 端到端事件订阅者插件：订阅 stats/report 事件，收到后 log 通知宿主
 *
 * 由宿主拉起，与事件发布者（其他插件）解耦——不感知谁在发布。
 */
main(): Int64 {
    PluginRuntime.run("event-sub", [], [], { ctx =>
        ctx.on("stats/report", { args =>
            let count = match (args[0]) { case JsonValue.Number(n) => n; case _ => -1.0 }
            ctx.log("info", "received stats/report count=${count}")
        })
        ctx.log("info", "event-sub ready")
    })
    return 0
}
