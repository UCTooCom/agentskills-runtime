/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolResponse, ToolParameter}
import magic.utils.http.HttpUtils
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import std.convert.*

/**
 * Built-in HTTP client tool for making HTTP requests
 * This tool is available to all skills and agents
 */
public class HttpTool <: AbsTool {
    public static let NAME = "http_request"
    
    public static let DESC = """
    A built-in HTTP client tool for making HTTP requests.
    Supports GET, POST, PUT, DELETE, PATCH methods with JSON body.
    Use this tool to send HTTP requests to external APIs.
    """

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { HttpTool.NAME }
    }

    public prop description: String {
        get() { HttpTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("method", "HTTP method (GET, POST, PUT, DELETE, PATCH)", TypeSchema.Str),
                ToolParameter("url", "The full URL to request", TypeSchema.Str),
                ToolParameter("headers", "Optional JSON object of request headers", TypeSchema.Str),
                ToolParameter("body", "Optional JSON object of request body", TypeSchema.Str),
                ToolParameter("timeout", "Optional timeout in milliseconds (default 30000)", TypeSchema.Int)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "method": "GET",
                  "url": "https://api.example.com/data"
                }
                """,
                """
                {
                  "method": "POST",
                  "url": "https://api.example.com/login",
                  "headers": "{\"Content-Type\": \"application/json\"}",
                  "body": "{\"username\": \"demo\", \"password\": \"123456\"}"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        try {
            LogUtils.info("[HttpTool] Executing HTTP request with ${args.size} arguments")
            
            var method = ""
            var url = ""
            if (let Some(methodValue) <- args.get("method")) {
                let strValue = methodValue.toString()
                method = if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                    strValue[1..(strValue.size - 1)]
                } else {
                    strValue
                }
            } else {
                throw ToolException("Parameter 'method' is required")
            }
            
            if (let Some(urlValue) <- args.get("url")) {
                let strValue = urlValue.toString()
                url = if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                    strValue[1..(strValue.size - 1)]
                } else {
                    strValue
                }
            } else {
                throw ToolException("Parameter 'url' is required")
            }
            
            let headers = HashMap<String, String>()
            if (let Some(headersValue) <- args.get("headers")) {
                var cleanHeadersValue = ""
                match (headersValue) {
                    case jStr: JsonString =>
                        cleanHeadersValue = jStr.getValue()
                    case _ =>
                        let strValue = headersValue.toString()
                        cleanHeadersValue = if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                            strValue[1..(strValue.size - 1)]
                        } else {
                            strValue
                        }
                }
                if (!cleanHeadersValue.isEmpty()) {
                    try {
                        let jsonHeaders = JsonValue.fromStr(cleanHeadersValue).asObject()
                        for ((key, value) in jsonHeaders.getFields()) {
                            let headerValue = match (value) {
                                case vStr: JsonString => vStr.getValue()
                                case _ => value.toString()
                            }
                            headers.add(key, headerValue)
                        }
                    } catch (ex: Exception) {
                        LogUtils.info("[HttpTool] Failed to parse headers: ${ex.message}")
                    }
                }
            }
            
            var hasContentType = false
            var hasAuthorization = false
            for ((k, v) in headers) {
                if (k == "Content-Type") {
                    hasContentType = true
                }
                if (k == "Authorization") {
                    hasAuthorization = true
                }
            }
            if (!hasContentType) {
                headers.add("Content-Type", "application/json")
            }
            
            let tokenManager = TokenManager.getInstance()
            let sessionContext = SessionContext.getInstance()
            
            if (!hasAuthorization && !tokenManager.isLoginEndpoint(url)) {
                let tokenOpt = sessionContext.getAccessToken()
                match (tokenOpt) {
                    case Some(token) =>
                        headers.add("Authorization", "Bearer ${token}")
                        LogUtils.info("[HttpTool] Auto-injected Authorization header from session token")
                    case None => ()
                }
            }
            
            var bodyOpt: Option<JsonObject> = None
            if (let Some(bodyValue) <- args.get("body")) {
                var cleanValue = ""
                match (bodyValue) {
                    case jStr: JsonString =>
                        cleanValue = jStr.getValue()
                    case _ =>
                        let strValue = bodyValue.toString()
                        cleanValue = if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                            strValue[1..(strValue.size - 1)]
                        } else {
                            strValue
                        }
                }
                LogUtils.info("[HttpTool] Body clean value: ${cleanValue}")
                if (!cleanValue.isEmpty()) {
                    try {
                        let jsonBody = JsonValue.fromStr(cleanValue).asObject()
                        LogUtils.info("[HttpTool] Parsed body: ${jsonBody.toJsonString()}")
                        bodyOpt = Some(jsonBody)
                    } catch (ex: Exception) {
                        LogUtils.error("[HttpTool] Failed to parse body: ${ex.message}")
                    }
                }
            } else {
                LogUtils.info("[HttpTool] No body parameter provided")
            }
            
            LogUtils.info("[HttpTool] Sending ${method} request to ${url}")
            LogUtils.info("[HttpTool] Headers: ${headers.toString()}")
            
            var resultOpt: Option<String> = None
            if (method.toAsciiUpper() == "GET") {
                resultOpt = HttpUtils.get(url, headers, bodyOpt, verify: false)
            } else if (method.toAsciiUpper() == "POST") {
                if (let Some(b) <- bodyOpt) {
                    resultOpt = HttpUtils.post(url, headers, b, verify: false)
                } else {
                    resultOpt = HttpUtils.get(url, headers, None, verify: false)
                }
            } else {
                LogUtils.error("[HttpTool] Unsupported HTTP method: ${method}")
            }
            
            if (let Some(result) <- resultOpt) {
                LogUtils.info("[HttpTool] Received response: ${if (result.size > 200) { result[0..200] + "..." } else { result }}")
                
                try {
                    let jsonResponse = JsonValue.fromStr(result)
                    
                    if (tokenManager.isLoginEndpoint(url)) {
                        match (jsonResponse) {
                            case respObj: JsonObject =>
                                let tokenInfoOpt = tokenManager.parseLoginResponse(respObj)
                                match (tokenInfoOpt) {
                                    case Some(tokenInfo) =>
                                        let sessionIdOpt = sessionContext.getCurrentSessionId()
                                        match (sessionIdOpt) {
                                            case Some(sessionId) =>
                                                tokenManager.setToken(sessionId, tokenInfo)
                                                LogUtils.info("[HttpTool] Auto-saved token for session: ${sessionId}")
                                            case None =>
                                                LogUtils.info("[HttpTool] No session context, cannot save token")
                                        }
                                    case None => ()
                                }
                            case _ => ()
                        }
                    }
                    
                    let wrapper = JsonObject()
                    wrapper.put("success", JsonString("true"))
                    wrapper.put("status", JsonString("200"))
                    wrapper.put("method", JsonString(method))
                    wrapper.put("url", JsonString(url))
                    wrapper.put("response", jsonResponse)
                    return ToolResponse(wrapper.toJsonString())
                } catch (ex: Exception) {
                    let wrapper = JsonObject()
                    wrapper.put("success", JsonString("true"))
                    wrapper.put("status", JsonString("200"))
                    wrapper.put("method", JsonString(method))
                    wrapper.put("url", JsonString(url))
                    wrapper.put("response", JsonString(result))
                    return ToolResponse(wrapper.toJsonString())
                }
            } else {
                let errorJson = JsonObject()
                errorJson.put("success", JsonString("false"))
                errorJson.put("error", JsonString("Request failed - no response received"))
                errorJson.put("method", JsonString(method))
                errorJson.put("url", JsonString(url))
                return ToolResponse(errorJson.toJsonString())
            }
        } catch (ex: Exception) {
            LogUtils.error("[HttpTool] Error executing HTTP request: ${ex.message}")
            let errorJson = JsonObject()
            errorJson.put("success", JsonString("false"))
            errorJson.put("error", JsonString(ex.message))
            return ToolResponse(errorJson.toJsonString())
        }
    }
}
