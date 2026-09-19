/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.cli

import std.env.getStdOut
import std.collection.HashMap
import magic.app.services.mcp.McpOpenService
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt, JsonArray}

/**
 * MCP 开放服务 CLI（T2.4）
 *
 * 用法：uctoo mcp-call --alias <mcpAlias> --tool <tool> --args '<json>'
 *   --alias  MCP 别名（如 tianyancha），必填
 *   --tool   工具名称（如 registration-info），必填
 *   --args   工具参数 JSON 字符串（如 '{"name":"腾讯科技"}'），可选，缺省 {}
 *   --list-tools  列出指定 alias 的可用工具
 *
 * stdout 输出 {data, meta} JSON；错误输出 {error} JSON 并以非零退出码结束。
 *
 * 可被脚本经 cli_execute 调用：
 *   cli_execute(command="uctoo", args=["mcp-call","--alias","tianyancha","--tool","registration-info","--args","{\"name\":\"腾讯科技\"}"])
 */
public class McpCallCLI {
    private let mcpOpenService = McpOpenService()

    public init() {}

    public func execute(args: Array<String>): Unit {
        if (args.size == 0) {
            printUsage()
            return
        }

        var mcpAlias = ""
        var tool = ""
        var argumentsJson = "{}"
        var listToolsMode = false

        var i = 0
        while (i < args.size) {
            let arg = args[i]
            if (arg == "--alias" && i + 1 < args.size) {
                mcpAlias = args[i + 1]
                i += 2
            } else if (arg == "--tool" && i + 1 < args.size) {
                tool = args[i + 1]
                i += 2
            } else if (arg == "--args" && i + 1 < args.size) {
                argumentsJson = args[i + 1]
                i += 2
            } else if (arg == "--list-tools") {
                listToolsMode = true
                i += 1
            } else if (arg == "--help" || arg == "-h") {
                printUsage()
                return
            } else {
                i += 1
            }
        }

        if (mcpAlias.isEmpty()) {
            getStdOut().writeln("{\"error\":\"--alias is required\"}")
            return
        }

        if (listToolsMode) {
            executeListTools(mcpAlias)
            return
        }

        if (tool.isEmpty()) {
            getStdOut().writeln("{\"error\":\"--tool is required (or use --list-tools)\"}")
            return
        }

        executeCall(mcpAlias, tool, argumentsJson)
    }

    private func executeCall(mcpAlias: String, tool: String, argumentsJson: String): Unit {
        LogUtils.info("[McpCallCLI] calling mcpAlias='${mcpAlias}', tool='${tool}'")
        // source 标记 CLI 入口，便于在审计表里区分调用形态（spec 5.13.1 规则 3）
        let result = mcpOpenService.callWithJsonString(mcpAlias, tool, argumentsJson, source: "mcp_cli")

        // 构建 JSON 输出：{"data":"...","isError":false,"meta":{"tool":"...","durationMs":0,"status":"success","errorMessage":""}}
        let resultObj = HashMap<String, JsonValue>()
        resultObj["data"] = JsonString(result.data)
        resultObj["isError"] = JsonBool(result.isError)

        let metaObj = HashMap<String, JsonValue>()
        metaObj["tool"] = JsonString(result.meta.tool)
        metaObj["durationMs"] = JsonInt(result.meta.durationMs)
        metaObj["status"] = JsonString(result.meta.status)
        metaObj["errorMessage"] = JsonString(result.meta.errorMessage)
        resultObj["meta"] = JsonObject(metaObj)

        let output = JsonObject(resultObj)
        getStdOut().writeln(output.toString())
    }

    private func executeListTools(mcpAlias: String): Unit {
        LogUtils.info("[McpCallCLI] listing tools for mcpAlias='${mcpAlias}'")
        let tools = mcpOpenService.listTools(mcpAlias)

        // 构建 JSON 输出：{"tools":["tool1","tool2"]}
        let resultObj = HashMap<String, JsonValue>()
        let toolsArray = Array<JsonValue>(tools.size, {_ => JsonString("")})
        var idx = 0
        while (idx < tools.size) {
            toolsArray[idx] = JsonString(tools[idx])
            idx += 1
        }
        resultObj["tools"] = JsonArray(toolsArray)

        let output = JsonObject(resultObj)
        getStdOut().writeln(output.toString())
    }

    private func printUsage(): Unit {
        getStdOut().writeln("Usage: uctoo mcp-call --alias <mcpAlias> --tool <tool> --args '<json>'")
        getStdOut().writeln("       uctoo mcp-call --alias <mcpAlias> --list-tools")
        getStdOut().writeln("")
        getStdOut().writeln("Options:")
        getStdOut().writeln("  --alias       MCP alias (e.g., tianyancha), required")
        getStdOut().writeln("  --tool        Tool name (e.g., registration-info), required for call")
        getStdOut().writeln("  --args        Tool arguments JSON string (default: {})")
        getStdOut().writeln("  --list-tools  List available tools for the alias")
        getStdOut().writeln("  --help, -h    Show this help message")
        getStdOut().writeln("")
        getStdOut().writeln("Output: {\"data\":\"...\",\"meta\":{\"tool\",\"durationMs\",\"status\",\"errorMessage\"}}")
    }
}