package ystyle::cordis_examples

import ystyle::cordis_plugin.*
import jsonvalue.*

/**
 * 外部插件示例（独立模块，不使用宏）
 *
 * 这是外部插件作者的标准写法：手写 main，调用 PluginRuntime.run
 * 显式注册服务处理器。不依赖 @Plugin/@Provide 宏，因此不受
 * 「cjpm 带 organization 宏包跨模块依赖缺陷」影响
 * （见 docs/macro-org-dependency-issue.md）。
 *
 * 提供两个服务：echo / add
 */
main(): Int64 {
    PluginRuntime.run("external-plugin", [], ["echo", "add"], { ctx =>
        // echo：原样返回第一个参数
        ctx.registerHandler("echo", { _, args =>
            if (args.size > 0) {
                args[0]
            } else {
                JsonValue.Null
            }
        })
        // add：两个数字相加
        ctx.registerHandler("add", { _, args =>
            let a = match (args[0]) { case JsonValue.Number(n) => n; case _ => 0.0 }
            let b = match (args[1]) { case JsonValue.Number(n) => n; case _ => 0.0 }
            JsonValue.Number(a + b)
        })
        ctx.log("info", "external plugin ready")
    })
    return 0
}
