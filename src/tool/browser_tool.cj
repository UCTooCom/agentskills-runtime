/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolParameter}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.utils.newProcess
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt}

public class BrowserTool <: NativeFuncTool {
    public static let NAME = "browser_open"
    
    public static let DESC = """
    Open URL or local file in default browser.
    Supports cross-platform browser opening.
    
    Usage: Provide a URL or local file path.
    """

    public init() {
        super(
            name: BrowserTool.NAME,
            description: BrowserTool.DESC,
            parameters: [
                ("url", "URL or file path to open (e.g., 'http://localhost:8080' or 'file:///path/to/file.html')", TypeSchema.Str),
                ("browser", "Specific browser to use (optional, e.g., 'chrome', 'firefox', 'edge')", TypeSchema.Str)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "url": "http://localhost:8080"
                }
                """,
                """
                {
                  "url": "file:///C:/path/to/report.html",
                  "browser": "chrome"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                BrowserTool.execute(args)
            }
        )
    }

    public static func execute(args: HashMap<String, JsonValue>): String {
        let url = extractString(args, "url")
        if (url.isEmpty()) {
            throw ToolException("Parameter 'url' is required")
        }

        // 同源应用地址护栏：browser_open 通过操作系统默认浏览器打开一个「独立」浏览器实例，
        // 该实例不共享用户在 Web 管理后台已登录的标签页会话，会被服务端重定向到登录页，
        // 导致 agent 无法在用户当前 tab 内继续操作。运营 uctoo 管理后台（localhost:3031 /
        // javatoarktsapi.uctoo.com）必须使用页面级 WebMCP 工具 navigate_url（在用户当前
        // 标签页内 router.push），而不是 browser_open。命中同源地址时直接拒绝并提示。
        if (isSameOriginAppUrl(url)) {
            LogUtils.warn("[BrowserTool] Refused same-origin app URL (would lose login session): ${url}")
            let response = JsonObject()
            response.put("success", JsonBool(false))
            response.put("url", JsonString(url))
            response.put("error", JsonString(
                "拒绝在独立浏览器中打开同源管理后台地址（会丢失用户登录态、被重定向到登录页）。" +
                "请改用页面级 WebMCP 工具 navigate_url 在用户当前已登录的标签页内导航，" +
                "例如：{ \"name\": \"navigate_url\", \"arguments\": { \"url\": \"${url}\" } }。"))
            return response.toJsonString()
        }

        let browser = extractString(args, "browser")

        LogUtils.info("[BrowserTool] Opening URL: ${url}")

        try {
            let result = openBrowser(url, browser)
            
            let response = JsonObject()
            response.put("success", JsonBool(result.success))
            response.put("url", JsonString(url))
            if (!result.command.isEmpty()) {
                response.put("command", JsonString(result.command))
            }
            if (!result.error.isEmpty()) {
                response.put("error", JsonString(result.error))
            }
            
            return response.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[BrowserTool] Failed to open browser: ${ex.message}")
            
            let response = JsonObject()
            response.put("success", JsonBool(false))
            response.put("url", JsonString(url))
            response.put("error", JsonString("Failed to open browser: ${ex.message}"))
            
            return response.toJsonString()
        }
    }

    @When[os == "Windows"]
    protected static func openBrowser(url: String, browser: String): OpenResult {
        var command: String
        var args: Array<String>
        
        if (!browser.isEmpty()) {
            command = browser
            args = [url]
        } else {
            command = "cmd"
            args = ["/c", "start", url]
        }

        LogUtils.info("[BrowserTool] Executing: ${command}")

        let subProcess = newProcess(command, args)
        let exitCode = subProcess.wait()

        if (exitCode == 0) {
            return OpenResult(true, command, "")
        } else {
            return OpenResult(false, command, "Command exited with code ${exitCode}")
        }
    }

    @When[os == "macOS"]
    protected static func openBrowser(url: String, browser: String): OpenResult {
        var command: String
        var args: Array<String>
        
        if (!browser.isEmpty()) {
            command = browser
            args = [url]
        } else {
            command = "open"
            args = [url]
        }

        LogUtils.info("[BrowserTool] Executing: ${command}")

        let subProcess = newProcess(command, args)
        let exitCode = subProcess.wait()

        if (exitCode == 0) {
            return OpenResult(true, command, "")
        } else {
            return OpenResult(false, command, "Command exited with code ${exitCode}")
        }
    }

    @When[os != "Windows" && os != "macOS"]
    protected static func openBrowser(url: String, browser: String): OpenResult {
        var command: String
        var args: Array<String>
        
        if (!browser.isEmpty()) {
            command = browser
            args = [url]
        } else {
            command = "xdg-open"
            args = [url]
        }

        LogUtils.info("[BrowserTool] Executing: ${command}")

        let subProcess = newProcess(command, args)
        let exitCode = subProcess.wait()

        if (exitCode == 0) {
            return OpenResult(true, command, "")
        } else {
            return OpenResult(false, command, "Command exited with code ${exitCode}")
        }
    }

    protected static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }

    // 判断是否为「同源管理后台」地址。命中即用 browser_open 打开独立浏览器会丢失登录态，
    // 必须在用户当前已登录标签页内用 navigate_url 操作。覆盖开发(localhost:3031)与生产(javatoarktsapi.uctoo.com)。
    protected static func isSameOriginAppUrl(url: String): Bool {
        let markers = ["localhost:3031", "127.0.0.1:3031", "javatoarktsapi.uctoo.com"]
        for (marker in markers) {
            if (url.contains(marker)) {
                return true
            }
        }
        return false
    }
}

protected struct OpenResult {
    public let success: Bool
    public let command: String
    public let error: String

    public init(success: Bool, command: String, error: String) {
        this.success = success
        this.command = command
        this.error = error
    }
}
