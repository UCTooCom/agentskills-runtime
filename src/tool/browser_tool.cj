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
