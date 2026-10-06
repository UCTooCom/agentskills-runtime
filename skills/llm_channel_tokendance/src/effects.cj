/*
 * ctx.effect 可逆效果注册框架（llm_channel_tokendance）
 * 卸载时逆序执行已注册的清理效果
 */
package skill_llm_channel_tokendance

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*

public class LlmChannelTokendanceEffects {
    public static func register(ctx: PluginContext): Unit {
        // effect(disposer, label): 插件卸载时逆序执行 disposer 清理资源（plugin_runtime.cj:82）
        ctx.effect({ =>
            // 逆向执行：清理资源（卸载时调用）
            // TODO: 注册资源清理逻辑
        })
    }
}
