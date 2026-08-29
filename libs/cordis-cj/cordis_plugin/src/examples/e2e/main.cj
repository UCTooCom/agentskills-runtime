package ystyle::cordis_plugin.examples.e2e

import ystyle::cordis_plugin.*
import jsonvalue.*
import stdx.serialization.serialization.*

/**
 * 端到端测试插件：提供两个服务（echo/add），供宿主拉起验证全流程
 *
 * 运行方式：作为独立可执行文件被宿主 PluginManager.launch 拉起。
 * 支持两种传输模式（宿主配置决定）：
 * - stdio（默认）：通过 stdin/stdout 换行帧与宿主 JSON-RPC 通信
 * - uds：宿主传入 --uds <path> 参数，插件连接 Unix Domain Socket
 *   与宿主通信（Content-Length 帧）
 *
 * 支持插件私有配置（宿主 entry.config 下发）：
 * ```toml
 * [plugins.config]
 * offset = 100   # add 结果加偏移（配置热更新验证用）
 * ```
 */
main(): Int64 {
    let handler = { ctx: PluginContext =>
        // 读取插件私有配置（宿主 initialize 响应下发），解析为不可变值供 lambda 捕获
        let offset = match (ctx.config) {
            case s: DataModelStruct =>
                match (s.get("offset")) {
                    case i: DataModelInt => i.getValue()
                    case f: DataModelFloat => Int64(f.getValue())
                    case _ => 0
                }
            case _ => 0
        }
        // 注册 echo 服务实现：原样返回第一个参数
        ctx.registerHandler("echo", { _, args =>
            if (args.size > 0) {
                args[0]
            } else {
                JsonValue.Null
            }
        })
        // 注册 add 服务实现：两个数字相加 + 配置偏移
        ctx.registerHandler("add", { _, args =>
            let a = match (args[0]) { case JsonValue.Number(n) => n; case _ => 0.0 }
            let b = match (args[1]) { case JsonValue.Number(n) => n; case _ => 0.0 }
            JsonValue.Number(a + b + Float64(offset))
        })
        ctx.log("info", "e2e plugin ready (offset=${offset})")
    }

    // run 自动检测传输模式：宿主 uds 模式传 --uds <path>（getCommandLine 获取），
    // 否则 stdio——插件 main 无需感知
    PluginRuntime.run("e2e-plugin", [], ["echo", "add"], handler)
    return 0
}
