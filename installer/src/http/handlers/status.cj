package uc_installer.http.handlers

import uc_installer.core.{AppContext, readRuntimePidFile}
import http_lib.router.Handler
import uc_installer.platform.{verifyProcessImage, queryProcess, findPidsByImage}
import uc_installer.util.{jstr, jint, jobj, jarr, jsonOk}
import std.collection.ArrayList
import std.convert.Parsable

/// `GET /setup/service-status` 处理器（T020 / design.md §4.2.3 #6）。
///
/// 返回 `{code:200, data:[{name,status,cpu,memory,uptime}]}`：
///   - runtime（来自 PID 文件 + 镜像名校验）记录运行状态、内存占用、启动时间；
///   - 三项依赖（node / postgresql / redis）按镜像名探测进程是否存在。
/// 内存/CPU 当前为最佳努力值（tasklist 仅稳定给出内存；CPU 采样留待后续 phase）。
public func serviceStatusHandler(ctx: AppContext): Handler {
    return { _ =>
        let data = jarr()

        // 1) runtime 自身
        let runtimeEntry = jobj()
        runtimeEntry.put("name", jstr("agentskills-runtime"))
        match (readRuntimePidFile(ctx.paths.installRoot)) {
            case Some(rec) =>
                if (verifyProcessImage(rec.pid, rec.image)) {
                    runtimeEntry.put("status", jstr("running"))
                    let mem = match (queryProcess(rec.pid)) {
                        case Some(e) => parseMemKb(e.memUsage)
                        case None => 0
                    }
                    runtimeEntry.put("memory", jint(mem))
                    runtimeEntry.put("uptime", jstr(rec.startedAt))
                } else {
                    runtimeEntry.put("status", jstr("stopped"))
                    runtimeEntry.put("memory", jint(0))
                    runtimeEntry.put("uptime", jstr(""))
                }
            case None =>
                runtimeEntry.put("status", jstr("stopped"))
                runtimeEntry.put("memory", jint(0))
                runtimeEntry.put("uptime", jstr(""))
        }
        runtimeEntry.put("cpu", jint(0))
        data.add(runtimeEntry)

        // 2) 三项依赖（仅判存活）
        let deps = ArrayList<(String, String)>()
        deps.add(("node", "node.exe"))
        deps.add(("postgresql", "postgres.exe"))
        deps.add(("redis", "redis-server.exe"))
        for ((name, image) in deps) {
            let e = jobj()
            e.put("name", jstr(name))
            let running = !findPidsByImage(image).isEmpty()
            var statusStr = "stopped"
            if (running) { statusStr = "running" }
            e.put("status", jstr(statusStr))
            e.put("cpu", jint(0))
            e.put("memory", jint(0))
            e.put("uptime", jstr(""))
            data.add(e)
        }

        jsonOk("服务状态", data)
    }
}

/// `GET /setup/logs` 处理器（T020 / design.md §4.2.3 #7）。
///
/// 当前返回默认空数组（R-10：未集成集中日志收集前不得编造条目）。
public func logsHandler(ctx: AppContext): Handler {
    return { _ => jsonOk("日志列表", jarr()) }
}

/// 把 tasklist 的 "20,240 K" 形式内存占用解析为 KB 整数（最佳努力，失败返回 0）。
private func parseMemKb(s: String): Int64 {
    let cleaned = s.replace(",", "").replace(" K", "").replace("K", "").trimAscii()
    if (cleaned.isEmpty()) {
        return 0
    }
    try {
        return Int64.parse(cleaned)
    } catch (_: Exception) {
        return 0
    }
}
