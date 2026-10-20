package uc_installer.http.handlers

import uc_installer.core.AppContext
import http_lib.router.Handler
import uc_installer.util.{jstr, jbool, jobj, jarr, jsonOkCode}
import uc_installer.services.checkEnvironment

/// `GET /setup/check-environment` 处理器（T018 / design.md §4.2.3 #2）。
///
/// **本文件只是 HTTP 封装**：探测逻辑在 `services/envcheck.cj`，与
/// `ucInstaller.exe check-environment` 命令行共用同一实现（同一份依赖清单、
/// 同一套三级降级口径），杜绝「命令行一项、网页另一项」的分裂。
///
/// 对外契约保持原样：组装 `{code:200, data:[3 项], message:"环境检测完成"}`；
/// 单项探测异常仍计入结果（不抛 500）。
public func checkEnvironmentHandler(ctx: AppContext): Handler {
    return { _ =>
        let res = checkEnvironment()
        let data = jarr()
        for (it in res.items) {
            let o = jobj()
            o.put("name", jstr(it.name))
            o.put("reachable", jbool(it.reachable))
            o.put("method", jstr(it.method))
            o.put("version", jstr(it.version))
            o.put("detail", jstr(it.detail))
            data.add(o)
        }
        jsonOkCode(200, "环境检测完成", data)
    }
}
