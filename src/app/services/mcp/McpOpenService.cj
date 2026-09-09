package magic.app.services.mcp

import magic.mcp.HttpMCPClient
import magic.app.services.uctoo.EnvFileService
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.JsonValue
import std.time.DateTime

public struct McpCallMeta {
    public let tool: String
    public let durationMs: Int64
    public let status: String
    public let errorMessage: String
    public init(tool: String, durationMs: Int64, status: String, errorMessage: String) {
        this.tool = tool
        this.durationMs = durationMs
        this.status = status
        this.errorMessage = errorMessage
    }
}

public struct McpCallResult {
    public let data: String
    public let isError: Bool
    public let meta: McpCallMeta
    public init(data: String, isError: Bool, meta: McpCallMeta) {
        this.data = data
        this.isError = isError
        this.meta = meta
    }
}

public struct McpAliasConfig {
    public let endpoint: String
    public let credentialKey: String
    public init(endpoint: String, credentialKey: String) {
        this.endpoint = endpoint
        this.credentialKey = credentialKey
    }
}

public class McpOpenService {
    private let aliasMap = HashMap<String, McpAliasConfig>()
    private let envService = EnvFileService()
    private let maxRetries: Int64 = 3

    public init() {
        this.registerDefaultAliases()
    }

    private func registerDefaultAliases(): Unit {
        this.aliasMap.add("tianyancha", McpAliasConfig(
            "https://mcp.tianyancha.com/mcp",
            "TIANYANCHA_MCP_TOKEN"
        ))
    }

    public func registerAlias(alias: String, config: McpAliasConfig): Unit {
        this.aliasMap.add(alias, config)
    }

    /// 以 JSON 字符串形式传入工具参数，内部解析为 Array<(String, JsonValue)> 后委托 call()。
    /// 供 host.mcp handler 调用——插件侧 params 为 jsonvalue.JsonValue，
    /// 经 stringify() 转为 JSON 字符串后传入本方法，避免跨包类型转换。
    public func callWithJsonString(mcpAlias: String, tool: String, argumentsJson: String): McpCallResult {
        let argArray = ArrayList<(String, JsonValue)>()
        if (!argumentsJson.isEmpty()) {
            try {
                let parsed = JsonValue.fromStr(argumentsJson)
                let obj = parsed.asObject()
                for ((k, v) in obj.getFields()) {
                    argArray.add((k, v))
                }
            } catch (e: Exception) {
                return McpCallResult(
                    "",
                    true,
                    McpCallMeta(tool, 0, "failed", "Failed to parse argumentsJson: ${e.toString()}")
                )
            }
        }
        return this.call(mcpAlias, tool, argArray.toArray())
    }

    public func call(mcpAlias: String, tool: String, arguments: Array<(String, JsonValue)>): McpCallResult {
        let startMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        let configOpt = this.aliasMap.get(mcpAlias)
        if (let Some(config) <- configOpt) {
            let tokenOpt = this.envService.readEnvValue(this.envService.getEnvFilePath(), config.credentialKey)
            let token = if (let Some(t) <- tokenOpt) { t } else { "" }
            var retryCount: Int64 = 0
            var delaySeconds: Int64 = 1
            while (retryCount <= this.maxRetries) {
                try {
                    let headers: Array<(String, String)> = [("Authorization", "Bearer ${token}")]
                    let client = HttpMCPClient(config.endpoint, headers: headers)
                    let response = client.callTool(tool, arguments)
                    client.close()
                    let endMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
                    let durationMs = endMs - startMs
                    if (response.isError) {
                        return McpCallResult(
                            response.content,
                            true,
                            McpCallMeta(tool, durationMs, "failed", "Tool returned error")
                        )
                    }
                    return McpCallResult(
                        response.content,
                        false,
                        McpCallMeta(tool, durationMs, "success", "")
                    )
                } catch (e: Exception) {
                    let endMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
                    let durationMs = endMs - startMs
                    let errMsg = e.toString()
                    if (retryCount >= this.maxRetries) {
                        return McpCallResult(
                            "",
                            true,
                            McpCallMeta(tool, durationMs, "failed", errMsg)
                        )
                    }
                    retryCount = retryCount + 1
                    sleep(Duration.second * delaySeconds)
                    delaySeconds = delaySeconds * 2
                }
            }
            return McpCallResult(
                "",
                true,
                McpCallMeta(tool, 0, "failed", "Max retries exceeded")
            )
        } else {
            return McpCallResult(
                "",
                true,
                McpCallMeta(tool, 0, "failed", "Unknown mcpAlias: ${mcpAlias}")
            )
        }
    }

    public func listTools(mcpAlias: String): Array<String> {
        let configOpt = this.aliasMap.get(mcpAlias)
        if (let Some(config) <- configOpt) {
            let tokenOpt = this.envService.readEnvValue(this.envService.getEnvFilePath(), config.credentialKey)
            let token = if (let Some(t) <- tokenOpt) { t } else { "" }
            try {
                let headers: Array<(String, String)> = [("Authorization", "Bearer ${token}")]
                let client = HttpMCPClient(config.endpoint, headers: headers)
                let tools = client.tools
                client.close()
                let names = Array<String>(tools.size, {_ => ""})
                var idx = 0
                while (idx < tools.size) {
                    names[idx] = tools[idx].name
                    idx = idx + 1
                }
                return names
            } catch (e: Exception) {
                return []
            }
        } else {
            return []
        }
    }
}