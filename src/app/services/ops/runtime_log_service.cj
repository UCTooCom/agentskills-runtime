/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 *
 * RuntimeLogService —— T054（M2 冻结区豁免 1/2）：运行系统自身日志读取端点后端。
 *
 * 设计约束（tasks.md T054 / AC-267 / AC-270）：
 * - 只读、分页、限量；不得暴露日志目录外的任意文件（防目录穿越）。
 * - 严禁以业务数据表（crontab_log / llm_usage_logs）查询替代进程运行日志。
 * - 日志源：`logs/agentskills-runtime.log`（实际为带时间戳文件，见 log_utils_impl.cj）
 *        与 `logs/startup-trace.txt`（启动跟踪，main.cj:44）。
 */
package magic.app.services.ops

import std.fs.{File, OpenMode, exists, Directory, Path}
import std.io.{StringReader, InputStream}
import std.collection.HashMap
import std.env.{getVariable, getWorkingDirectory}
import std.convert.*
import magic.log.LogUtils
import magic.config.{Config as AppConfig}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonBool, JsonInt}

public class RuntimeLogService {
    /// 启动跟踪日志固定路径（相对 cwd）。
    private static let STARTUP_TRACE = "logs/startup-trace.txt"

    public init() {}

    /**
     * 读取运行日志。
     *
     * @param file      日志选择："startup" / "startup-trace" 读启动跟踪；其余一律读主运行日志。
     * @param tailLines 期望返回的最大行数（<=0 取默认 500，>5000 封顶 5000）。
     * @param offset    起始行下标；<0 表示取末尾 tailLines 行（默认行为）。
     * @return JsonObject：{ ok, path, totalLines, returnedLines, truncated, lines:[String] } 或 { ok:false, error }。
     */
    public func readLog(file: String, tailLines: Int64, offset: Int64): JsonObject {
        let path = this.resolvePath(file)
        let result = JsonObject()
        if (path.isEmpty()) {
            result.put("ok", JsonBool(false))
            result.put("error", JsonString("运行日志输出到控制台（logFile=${AppConfig.logFile}），无落盘文件可读"))
            result.put("lines", JsonArray())
            result.put("totalLines", JsonInt(Int64(0)))
            return result
        }
        if (!exists(path)) {
            result.put("ok", JsonBool(false))
            result.put("error", JsonString("日志文件不存在：${path}"))
            result.put("lines", JsonArray())
            result.put("totalLines", JsonInt(Int64(0)))
            return result
        }
        try {
            let f = File(path, OpenMode.Read)
            let reader = StringReader(f)
            let content = reader.readToEnd()
            reader.close()
            f.close()

            // 按行切分（\n 切分对中文 UTF-8 安全：中文字节留在同一行内）。
            let rawLines = content.split("\n")
            let total = rawLines.size

            // 限量：默认 500，封顶 5000。
            let maxLines = if (tailLines <= 0) {
                500
            } else if (tailLines > 5000) {
                5000
            } else {
                tailLines
            }

            // 起始下标：offset<0 取末尾 maxLines 行。
            var startIdx = if (offset < 0) {
                if (total > maxLines) { total - maxLines } else { 0 }
            } else {
                offset
            }
            if (startIdx < 0) { startIdx = 0 }
            if (startIdx > total) { startIdx = total }
            var endIdx = startIdx + maxLines
            if (endIdx > total) { endIdx = total }

            let arr = JsonArray()
            var i = startIdx
            while (i < endIdx) {
                arr.add(JsonString(rawLines[i]))
                i = i + 1
            }

            result.put("ok", JsonBool(true))
            result.put("path", JsonString(path))
            result.put("totalLines", JsonInt(Int64(total)))
            result.put("returnedLines", JsonInt(Int64(arr.getItems().size)))
            result.put("truncated", JsonBool(total > maxLines))
            result.put("lines", arr)
        } catch (e: Exception) {
            LogUtils.warn("RuntimeLogService", "读取日志失败：${path}, ${e.message}")
            result.put("ok", JsonBool(false))
            result.put("error", JsonString("读取日志失败：${e.message}"))
            result.put("lines", JsonArray())
            result.put("totalLines", JsonInt(Int64(0)))
        }
        return result
    }

    /// 把外部 file 参数映射到实际路径。无论参数如何，路径都由本方法固定给出，
    /// 绝不使用参数作为文件系统路径 → 目录穿越在结构上不可能。
    private func resolvePath(file: String): String {
        let cwd = getWorkingDirectory().toString()
        if (file == "startup" || file == "startup-trace") {
            return "${cwd}/${RuntimeLogService.STARTUP_TRACE}"
        }
        // 任何非白名单参数（含 "../../etc/passwd" 之类）一律忽略，回落到主运行日志，
        // 绝不把它当路径使用。
        return this.resolveRuntimeLogPath(cwd)
    }

    /**
     * 解析当前主运行日志路径（与 log_utils_impl.cj 同一口径）：
     * 1) 优先读日志框架维护的指针文件 `logs/current-log.txt`（含本次运行的带时间戳路径）；
     * 2) 否则扫描 logs 目录取最新的 `<stem>-<yyyyMMdd-HHmmss>[-n].log`；
     * 3) 否则用配置原路径。
     */
    private func resolveRuntimeLogPath(cwd: String): String {
        let configured = AppConfig.logFile
        if (configured == "stdout" || configured == "stderr") {
            return ""
        }
        let pointer = "${cwd}/logs/current-log.txt"
        if (exists(pointer)) {
            try {
                let f = File(pointer, OpenMode.Read)
                let r = StringReader(f)
                let content = r.readToEnd()
                r.close()
                f.close()
                let trimmed = content.trimAscii()
                if (!trimmed.isEmpty()) {
                    return trimmed
                }
            } catch (_: Exception) {}
        }
        let p = Path(configured)
        let dir = if (p.parent.toString().isEmpty()) { "${cwd}/logs" } else { p.parent.toString() }
        let stem = p.fileNameWithoutExtension
        if (exists(dir)) {
            var best = ""
            try {
                for (entry in Directory.readFrom(dir)) {
                    let name = entry.name
                    if (!name.startsWith("${stem}-") || !name.endsWith(".log")) {
                        continue
                    }
                    if (best == "" || name > best) {
                        best = name
                    }
                }
            } catch (_: Exception) {}
            if (best != "") {
                return "${dir}/${best}"
            }
        }
        return configured
    }
}
