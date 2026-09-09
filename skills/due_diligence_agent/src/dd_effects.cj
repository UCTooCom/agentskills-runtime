/*
 * ctx.effect 可逆效果注册框架（due_diligence_agent）
 * 卸载时逆序执行已注册的清理效果
 */
package skill_due_diligence_agent

import ystyle::cordis_plugin.PluginContext

public class DdEffects {
    public static func register(ctx: PluginContext): Unit {
        ctx.effect({ =>
            eprintln("[skill_due_diligence_agent] cleanup effect executed on unload")
        })
    }
}