/*
 * ctx.effect 可逆效果注册框架（codelabs）
 * 卸载时逆序执行已注册的清理效果
 */
package skill_codelabs

import ystyle::cordis_plugin.PluginContext

public class CodelabsEffects {
    public static func register(ctx: PluginContext): Unit {
        // 注册可逆效果（卸载时逆序执行）
        ctx.effect({ =>
            // 逆向执行：清理资源（卸载时调用）
            // TODO: 注册资源清理逻辑
        })
    }
}
