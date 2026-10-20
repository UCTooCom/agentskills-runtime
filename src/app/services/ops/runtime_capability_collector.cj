/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 *
 * RuntimeCapabilityCollector —— T055（M2 冻结区豁免 2/2）：系统及环境能力采集器 + 运维端点后端。
 *
 * 设计依据（tasks.md T055 / R-42 / R-40，复用 .codeartsdoer/specs/system-env-capability/spec.md）：
 * - 实现「唯一采集器」：大模型与主 Agent 消费能力清单，运维面板复用同一结果，不维护两份探测清单。
 * - 复用 Config.modelCapabilities / Config.modelSupportsVision()，不另立模型能力真相。
 * - 严禁把 Node.js 列为必需项（仓颉 runtime 不依赖 node）；shell 探测只报版本、不把 node 缺失当失败。
 * - 部分探测失败返回「部分能力未知」并继续（spec §5 降级要求），绝不因采集失败阻断启动。
 * - 启动即采集，落盘 ./runtime/capabilities.json 并缓存。
 */
package magic.app.services.ops

import std.fs.{File, OpenMode, exists, Directory, Path}
import std.io.StringReader
import std.collection.{ArrayList, HashMap, Set}
import std.process.{executeWithOutput, ProcessRedirect}
import std.env.{getVariable, getVariables, getWorkingDirectory}
import std.convert.*
import std.time.DateTime
import magic.log.LogUtils
import magic.config.{Config as AppConfig}
import magic.model.channel.ChannelRegistry
import f_orm.ORM
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonBool, JsonInt}

public class RuntimeCapabilityCollector {
    private static var cached: Option<JsonObject> = None

    public init() {}

    /// 启动即采集并落盘；失败仅记录，绝不阻断启动（spec §5）。
    public func collectAndPersist(): JsonObject {
        let manifest = this.collect()
        try {
            let dir = "${getWorkingDirectory().toString()}/runtime"
            if (!exists(dir)) {
                Directory.create(dir, recursive: true)
            }
            let json = manifest.toJsonString()
            File.writeTo("${dir}/capabilities.json", json.toArray())
            LogUtils.info("RuntimeCapabilityCollector",
                "capabilities collected: vision=${this.visionOf(manifest)}, browser=${this.browserAvailable(manifest)} -> ${dir}/capabilities.json")
        } catch (e: Exception) {
            LogUtils.warn("RuntimeCapabilityCollector", "落盘 capabilities.json 失败（不阻断）: ${e.message}")
        }
        cached = Some(manifest)
        return manifest
    }

    /// 返回缓存清单（无则现采）。运维端点用此，避免每次请求都跑探测。
    public func getManifest(): JsonObject {
        match (cached) {
            case Some(m) => m
            case None => this.collect()
        }
    }

    /// 运维实时块：数据库连通性 + 磁盘水位（与 log_utils_impl.checkDiskWatermark 同口径）。
    public func opsBlock(): JsonObject {
        let ops = JsonObject()
        let (dbOk, dbDetail) = this.checkDatabase()
        let db = JsonObject()
        db.put("connected", JsonBool(dbOk))
        db.put("detail", JsonString(dbDetail))
        ops.put("database", db)
        ops.put("disk", this.checkDisk())
        return ops
    }

    /// 组合「缓存清单 + 实时运维块」为完整 JSON 字符串，供端点直接返回。
    /// 清单与运维共用同一份采集结果（R-42：不维护两份探测清单）。
    public func buildOpsResponse(): String {
        let manifest = this.getManifest()
        let ops = this.opsBlock()
        let out = JsonObject()
        out.put("os", manifest.get("os").getOrDefault({ => JsonObject() }))
        out.put("shell", manifest.get("shell").getOrDefault({ => JsonObject() }))
        out.put("browser", manifest.get("browser").getOrDefault({ => JsonObject() }))
        out.put("llm", manifest.get("llm").getOrDefault({ => JsonObject() }))
        out.put("env", manifest.get("env").getOrDefault({ => JsonObject() }))
        out.put("skills", manifest.get("skills").getOrDefault({ => JsonObject() }))
        out.put("extension", manifest.get("extension").getOrDefault({ => JsonObject() }))
        out.put("collectedAt", manifest.get("collectedAt").getOrDefault({ => JsonString("") }))
        out.put("partial", manifest.get("partial").getOrDefault({ => JsonBool(false) }))
        out.put("ops", ops)
        return out.toJsonString()
    }

    // ==================== 采集项（spec §3） ====================

    public func collect(): JsonObject {
        let m = JsonObject()
        m.put("os", this.detectOs())
        m.put("shell", this.detectShell())
        m.put("browser", this.detectBrowser())
        m.put("llm", this.detectLlm())
        m.put("env", this.detectEnv())
        m.put("skills", this.detectSkills())
        m.put("extension", this.extensionInfo())
        m.put("collectedAt", JsonString(DateTime.now().toString()))
        m.put("partial", JsonBool(false))
        return m
    }

    private func detectOs(): JsonObject {
        let obj = JsonObject()
        var platform = "unknown"
        var version = ""
        var arch = "unknown"
        let osEnv = getVariable("OS").getOrDefault({ => "" })
        if (osEnv.contains("Windows")) {
            platform = "windows"
            version = osEnv
            arch = getVariable("PROCESSOR_ARCHITECTURE").getOrDefault({ => "" })
        } else {
            let unameS = this.runCommand("uname", ["-s"])
            if (!unameS.isEmpty()) {
                if (unameS.contains("Darwin")) { platform = "macos" } else { platform = "linux" }
                version = this.runCommand("uname", ["-v"]).trimAscii()
                arch = this.runCommand("uname", ["-m"]).trimAscii()
            }
        }
        if (arch == "unknown" || arch == "") {
            let a = getVariable("PROCESSOR_ARCHITECTURE").getOrDefault({ => "" })
            if (!a.isEmpty()) { arch = a }
        }
        obj.put("platform", JsonString(platform))
        obj.put("version", JsonString(version))
        obj.put("arch", JsonString(arch))
        return obj
    }

    private func detectShell(): JsonObject {
        let obj = JsonObject()
        let bash = this.versionOf("bash", ["--version"])
        let pwsh = this.versionOf("pwsh", ["--version"])
        let python = this.versionOf("python", ["--version"])
        let git = this.versionOf("git", ["--version"])
        obj.put("bash", JsonString(bash))
        obj.put("pwsh", JsonString(pwsh))
        obj.put("python", JsonString(python))
        obj.put("git", JsonString(git))
        // 可用判据：至少 bash / pwsh 之一存在。
        obj.put("available", JsonBool(!bash.isEmpty() || !pwsh.isEmpty()))
        // R-40：Node.js 非本运行时依赖，不探测、不列为必需、不报告缺失。
        return obj
    }

    private func detectBrowser(): JsonObject {
        let obj = JsonObject()
        let playwright = this.runCommand("npx", ["playwright", "--version"])
        let chrome = this.runCommand("google-chrome", ["--version"])
        let chromium = this.runCommand("chromium", ["--version"])
        let available = !playwright.isEmpty() || !chrome.isEmpty() || !chromium.isEmpty()
        obj.put("available", JsonBool(available))
        if (available) {
            let provider = if (!playwright.isEmpty()) {
                "playwright"
            } else if (!chrome.isEmpty()) {
                "chrome"
            } else {
                "chromium"
            }
            obj.put("provider", JsonString(provider))
        } else {
            obj.put("reason", JsonString("未检测到可自动化浏览器（Playwright/Chrome/Chromium）"))
        }
        return obj
    }

    private func detectLlm(): JsonObject {
        let obj = JsonObject()
        // 真相源已统一为 llm_channel 表（默认通道）；无默认通道时回退 AppConfig（默认值）。
        let defOpt = ChannelRegistry.shared().getDefault()
        let provider = if (let Some(s) <- defOpt) { s.code } else { AppConfig.MODEL_PROVIDER }
        let model = if (let Some(s) <- defOpt) { s.defaultModel } else { AppConfig.MODEL_NAME }
        obj.put("provider", JsonString(provider))
        obj.put("model", JsonString(model))
        // 复用 Config 单一真相，不得另立模型能力。
        let capsArr = JsonArray()
        for (c in AppConfig.modelCapabilities) {
            capsArr.add(JsonString(c))
        }
        obj.put("capabilities", capsArr)
        let supportsVision = if (let Some(s) <- defOpt) { s.capabilities.contains("vision") } else { AppConfig.modelSupportsVision() }
        obj.put("supports_vision", JsonBool(supportsVision))
        var apiKeyConfigured = false
        if (let Some(s) <- defOpt) {
            apiKeyConfigured = !ChannelRegistry.shared().resolveSecret(s.code).isEmpty()
        } else {
            apiKeyConfigured = !AppConfig.getModelApiKey().isEmpty()
        }
        obj.put("api_key_configured", JsonBool(apiKeyConfigured))
        obj.put("source", JsonString(if (defOpt.isSome()) { "llm_channel" } else { "app_config" }))
        return obj
    }

    private func detectEnv(): JsonObject {
        let obj = JsonObject()
        // 大模型通道已统一由 llm_channel 表承载，.env 不再存 MODEL_* / *_API_KEY；
        // "必需配置"改为「存在一个默认通道且其 api_key 可解析」。
        let required = ArrayList<String>()
        required.add("llm_channel.default(api_key)")
        let missing = ArrayList<String>()
        let defCode = ChannelRegistry.shared().getDefaultCode()
        if (defCode == "") {
            missing.add("llm_channel.default(api_key)")
        } else {
            let secret = ChannelRegistry.shared().resolveSecret(defCode)
            if (secret.isEmpty()) {
                missing.add("llm_channel.default(api_key)")
            }
        }
        let reqArr = JsonArray()
        for (r in required) { reqArr.add(JsonString(r)) }
        let missArr = JsonArray()
        for (m in missing) { missArr.add(JsonString(m)) }
        obj.put("required", reqArr)
        obj.put("missing", missArr)
        return obj
    }

    private func detectSkills(): JsonObject {
        let obj = JsonObject()
        let list = ArrayList<String>()
        let cwd = getWorkingDirectory().toString()
        let skillsDir = "${cwd}/skills"
        if (exists(skillsDir)) {
            try {
                for (entry in Directory.readFrom(skillsDir)) {
                    // 仅认含 SKILL.md 的目录，避免把无关子目录当技能扫进去。
                    if (exists("${skillsDir}/${entry.name}/SKILL.md")) {
                        list.add(entry.name)
                    }
                }
            } catch (_: Exception) {}
        }
        let arr = JsonArray()
        for (s in list) { arr.add(JsonString(s)) }
        obj.put("count", JsonInt(Int64(list.size)))
        obj.put("items", arr)
        return obj
    }

    private func extensionInfo(): JsonObject {
        let obj = JsonObject()
        obj.put("how_to_add_tool", JsonString("通过 MCP 连接器 / 插件市场安装；详见 README"))
        obj.put("how_to_add_skill", JsonString("WorkBuddy 技能市场或 skill-creator 生成"))
        return obj
    }

    // ==================== 运维实时探测 ====================

    private func checkDatabase(): (Bool, String) {
        try {
            let conn = ORM.connection()
            let closed = conn.isClosed()
            conn.close()
            if (closed) {
                return (false, "数据库连接已建立但处于关闭状态")
            }
            return (true, "数据库连接正常")
        } catch (e: Exception) {
            return (false, "数据库连接失败：${e.message}")
        }
    }

    /// 磁盘水位（复用日志目录占用 vs LRT_LOG_WATERMARK_BYTES 阈值，与 log_utils_impl 同口径）。
    private func checkDisk(): JsonObject {
        let obj = JsonObject()
        try {
            let p = Path(AppConfig.logFile)
            let dir = p.parent.toString()
            if (dir.isEmpty() || !exists(dir)) {
                obj.put("ok", JsonBool(false))
                obj.put("detail", JsonString("日志目录不存在: ${dir}"))
                obj.put("usedBytes", JsonInt(Int64(0)))
                obj.put("watermarkBytes", JsonInt(Int64(0)))
                return obj
            }
            let prefix = "${p.fileNameWithoutExtension}-"
            var total: Int64 = 0
            for (entry in Directory.readFrom(dir)) {
                let name = entry.name
                if (!name.startsWith(prefix) || !name.endsWith(".log")) {
                    continue
                }
                total += entry.size
            }
            let limit = this.watermarkBytes()
            obj.put("usedBytes", JsonInt(total))
            obj.put("watermarkBytes", JsonInt(limit))
            obj.put("ok", JsonBool(limit <= 0 || total <= limit))
            if (limit > 0) {
                obj.put("detail", JsonString("日志目录占用 ${total} 字节 / 水位阈值 ${limit} 字节"))
            } else {
                obj.put("detail", JsonString("日志目录占用 ${total} 字节（水位告警关闭）"))
            }
        } catch (e: Exception) {
            obj.put("ok", JsonBool(false))
            obj.put("detail", JsonString("磁盘探测失败：${e.message}"))
            obj.put("usedBytes", JsonInt(Int64(0)))
            obj.put("watermarkBytes", JsonInt(Int64(0)))
        }
        return obj
    }

    private func watermarkBytes(): Int64 {
        let def = Int64(1024) * 1024 * 1024 // 1GiB
        match (getVariable("LRT_LOG_WATERMARK_BYTES")) {
            case Some(s) =>
                if (s.isEmpty()) { return def }
                match (Int64.tryParse(s)) {
                    case Some(v) => return v
                    case None => return def
                }
            case None => return def
        }
    }

    // ==================== 命令执行与原值提取辅助 ====================

    /// 运行命令取 stdout 首行（trim）。失败/超时返回空串。复用 ScriptExecutor 的 executeWithOutput 范式：
    /// environment 为整体替换，须以 HashMap(getVariables()) 为基，否则丢 PATH。
    private func runCommand(command: String, args: Array<String>): String {
        try {
            let (exitCode, stdout, _) = executeWithOutput(
                command,
                args,
                environment: HashMap(getVariables()),
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )
            if (exitCode == 0) {
                return String.fromUtf8(stdout).trimAscii()
            }
            return ""
        } catch (_: Exception) {
            return ""
        }
    }

    /// 取命令版本首行；部分工具把版本打在 stderr（如 python --version），用 sh -c "... 2>&1" 兜底再探一次。
    private func versionOf(command: String, args: Array<String>): String {
        let out = this.runCommand(command, args)
        if (!out.isEmpty()) {
            return out.split("\n")[0]
        }
        if (args.size > 0) {
            let shellOut = this.runCommand("sh", ["-c", "${command} ${args[0]} 2>&1"])
            if (!shellOut.isEmpty()) {
                return shellOut.split("\n")[0]
            }
        }
        return ""
    }

    // ==================== 清单内字段提取（日志用） ====================

    private func visionOf(manifest: JsonObject): String {
        match (manifest.get("llm")) {
            case Some(v) =>
                if (v is JsonObject) {
                    match (v.asObject().get("supports_vision")) {
                        case Some(b) => return if (b is JsonBool) { if (b.asBool().getValue()) { "true" } else { "false" } } else { "unknown" }
                        case None => return "unknown"
                    }
                }
            case None => ()
        }
        return "unknown"
    }

    private func browserAvailable(manifest: JsonObject): String {
        match (manifest.get("browser")) {
            case Some(v) =>
                if (v is JsonObject) {
                    match (v.asObject().get("available")) {
                        case Some(b) => return if (b is JsonBool) { if (b.asBool().getValue()) { "true" } else { "false" } } else { "unknown" }
                        case None => return "unknown"
                    }
                }
            case None => ()
        }
        return "unknown"
    }
}
