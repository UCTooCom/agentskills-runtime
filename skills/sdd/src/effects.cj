/*
 * ctx.effect 可逆效果注册框架（sdd）
 * 卸载时逆序执行已注册的清理效果
 */
package skill_sdd

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*

public class SddEffects {
    public static func register(ctx: PluginContext): Unit {
        // effect(disposer, label): 插件卸载时逆序执行 disposer 清理资源（plugin_runtime.cj:82）
        // ⚠️ label 是「位置参数」（签名 label: String，无 !），不能带名调用；
        //    只有 effectAsync 的 label 带 ! 才是命名参数（service_registry.cj:143 / 158）。
        // ⚠️ lambda 的 => 不可省略（仓颉规范：=> 分隔参数与函数体），空体用 Unit 唯一值 () 占位。
        ctx.effect({ =>
            // 逆向执行：清理资源（卸载时调用）
            // TODO: 注册资源清理逻辑
            ()
        }, "sdd/cleanup")
    }
}
