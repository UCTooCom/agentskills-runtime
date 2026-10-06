/*
 * 运维自检 handler（llm_channel_tokendance）
 *
 * 生成器默认产出的是 V4 CRUD 骨架（add/edit/del/get/list），本插件用不到——
 * 适配器不提供 HTTP 路由，宿主只经 stdio JSON-RPC 调 adapter.* 四个方法
 * （实现在 src/adapter.cj）。这里保留一个**只读自检**方法，
 * 供排障时确认「插件活着 / host.secret 通 / 网关可达」。
 *
 * 为什么值得留：插件进程崩溃时宿主侧只看到「通道不可用」，
 * 有一个不依赖密钥的自检端点能立刻区分「进程没起来」与「密钥/网络有问题」。
 */
package skill_llm_channel_tokendance

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*
import std.collection.HashMap

public class LlmChannelTokendanceHandlers {
    public static func register(ctx: PluginContext): Unit {
        // 注册 API 见 plugin_runtime.cj:52 registerHandler(key, (String, Array<JsonValue>) -> JsonValue)
        // 独立 service key（不用插件名）：避免与 adapter.* 的分发入口混淆——
        // PluginAdapterBridge 用插件名当 service 调 adapter.*，这里另起一个 key 供
        // ExternalPluginRouteGateway 之类的显式调用方使用。
        ctx.registerHandler(
            "llm_channel_tokendance/selftest",
            { method, args => LlmChannelTokendanceHandlers.handleSelfTest() }
        )
    }

    /**
     * 自检：只报事实，不修改任何状态。
     *
     * 检查项：
     * 1. 插件进程存活（能走到这里就说明 cordis 握手已完成、receiveLoop 已启动）
     * 2. host.secret 通道是否可用（只问"配没配"，**不取明文**——自检不该产生明文外流）
     * 3. 声明能力位（静态声明，不代表实测可用；实测看 adapter.probe）
     */
    private static func handleSelfTest(): JsonValue {
        let (hasSecret, secretDetail) = TokendanceAdapter.probeSecretPresence()
        let m = HashMap<String, JsonValue>()
        m["ok"] = JsonValue.Boolean(true)
        m["plugin"] = JsonValue.String("llm_channel_tokendance")
        m["pid_alive"] = JsonValue.Boolean(true)
        m["protocol_version"] = JsonValue.String(TokendanceAdapter.PROTOCOL_VERSION)
        m["secret_ref"] = JsonValue.String(TokendanceAdapter.SECRET_REF)
        m["secret_configured"] = JsonValue.Boolean(hasSecret)
        m["secret_detail"] = JsonValue.String(secretDetail)
        m["default_base_url"] = JsonValue.String(TokendanceAdapter.DEFAULT_BASE_URL)
        m["models"] = JsonValue.String(TokendanceAdapter.modelListText())
        m["hint"] = JsonValue.String(
            "secret_configured 只表示宿主侧有该引用，不表示网关可用；" +
            "实际可用性请用界面「大模型通道 → 探测」或 adapter.probe"
        )
        JsonValue.Map(m)
    }
}
