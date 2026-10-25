/*
 * effects.cj — ctx.effect 可逆效果注册（yuanbao-policy）
 * 卸载时逆序执行已注册的清理效果
 */
package skill_yuanbao_policy

import ystyle::cordis_plugin.PluginContext

public class YbEffects {
    public static func register(ctx: PluginContext): Unit {
        ctx.effect({ =>
            eprintln("[yuanbao-policy] 插件卸载，清理完成")
        })
    }
}
