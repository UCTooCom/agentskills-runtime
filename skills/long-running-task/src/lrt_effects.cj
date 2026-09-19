/*
 * ctx.effect 可逆效果注册框架（long-running-task）
 * 卸载时逆序执行已注册的清理效果
 *
 * 编码依据：skills/due_diligence_agent/src/dd_effects.cj
 */
package skill_long_running_task

import ystyle::cordis_plugin.PluginContext

public class LrtEffects {
    public static func register(ctx: PluginContext): Unit {
        ctx.effect({ =>
            eprintln("[skill_long_running_task] cleanup effect executed on unload")
        })
    }
}
