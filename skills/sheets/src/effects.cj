/*
 * ctx.effect 可逆效果注册框架（sheets）
 * 卸载时逆序执行已注册的清理效果
 */
package skill_sheets

import ystyle::cordis_plugin.PluginContext

//#region AutoCreateCode
public class SheetsEffects {
    public static func register(ctx: PluginContext): Unit {
        // 注册可逆效果（卸载时逆序执行）
        ctx.effect({ =>
            // 逆向执行：清理资源（卸载时调用）
            // TODO: 注册资源清理逻辑
        })
    }
}
//#endregion AutoCreateCode

// ── 二次开发区 ────────────────────────────────────────────────
// 重新生成时以上 AutoCreateCode 区间会被覆盖，本区域的手写代码保留。
// 自定义可逆效果写在此处（另起 class，用 ctx.effect 注册），再接进 main.cj 的注册链。
