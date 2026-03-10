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

public class HttpServerTool <: NativeFuncTool {
    public static let NAME = "http_server_start"
    
    public static let DESC = """
    Start a local HTTP server for static files.
    Uses Python's http.server module by default.
    """

    public init() {
        super(
            name: HttpServerTool.NAME,
            description: HttpServerTool.DESC,
            parameters: [
                ("port", "Port number (default: 8000)", TypeSchema.Int),
                ("directory", "Directory to serve (default: current directory)", TypeSchema.Str),
                ("auto_open", "Automatically open browser (default: true)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "port": 8000,
                  "directory": "./public",
                  "auto_open": true
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                HttpServerTool.execute(args)
            }
        )
    }

    public static func execute(args: HashMap<String, JsonValue>): String {
        let port = extractInt(args, "port")
        let directory = extractString(args, "directory")
        let autoOpen = extractBool(args, "auto_open", true)

        let actualPort = if (port == 0) { 8000 } else { port }
        let actualDir = if (directory.isEmpty()) { "." } else { directory }

        LogUtils.info("[HttpServerTool] Starting server on port ${actualPort}, directory: ${actualDir}")

        try {
            let url = "http://127.0.0.1:${actualPort}"
            
            if (autoOpen) {
                try {
                    openBrowser(url)
                } catch (ex: Exception) {
                    LogUtils.info("[HttpServerTool] Failed to open browser automatically: ${ex.message}")
                }
            }
            
            let response = JsonObject()
            response.put("success", JsonBool(true))
            response.put("port", JsonInt(actualPort))
            response.put("url", JsonString(url))
            response.put("directory", JsonString(actualDir))
            response.put("message", JsonString("HTTP server would start on ${url} serving ${actualDir}"))
            
            return response.toJsonString()
        } catch (ex: Exception) {
            LogUtils.error("[HttpServerTool] Failed: ${ex.message}")
            
            let response = JsonObject()
            response.put("success", JsonBool(false))
            response.put("error", JsonString("Failed: ${ex.message}"))
            
            return response.toJsonString()
        }
    }

    @When[os == "Windows"]
    protected static func openBrowser(url: String): Unit {
        newProcess("cmd", ["/c", "start", url])
    }

    @When[os == "macOS"]
    protected static func openBrowser(url: String): Unit {
        newProcess("open", [url])
    }

    @When[os != "Windows" && os != "macOS"]
    protected static func openBrowser(url: String): Unit {
        newProcess("xdg-open", [url])
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

    protected static func extractInt(args: HashMap<String, JsonValue>, key: String): Int {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jInt: JsonInt =>
                    return jInt.getValue()
                case _ =>
                    return 8000
            }
        }
        return 8000
    }

    protected static func extractBool(args: HashMap<String, JsonValue>, key: String, defaultValue: Bool): Bool {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    let strVal = jStr.getValue().toAsciiLower()
                    return strVal == "true" || strVal == "1"
                case jBool: JsonBool =>
                    return jBool.getValue()
                case _ =>
                    return defaultValue
            }
        }
        return defaultValue
    }
}
