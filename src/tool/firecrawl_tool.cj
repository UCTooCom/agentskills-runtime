/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.utils.http.HttpUtils
import magic.utils.{getEnv}
import std.collection.HashMap
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}

public class FirecrawlTool <: AbsTool {
    public static let NAME = "firecrawl"
    
    public static let DESC = """
    Search and crawl the web using Firecrawl API.
    Supports web search, page scraping, site mapping, and crawling.
    Falls back to WebFetchTool if Firecrawl is not configured.
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
        get() { FirecrawlTool.NAME }
    }

    public prop description: String {
        get() { FirecrawlTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("action", "Action to perform: search, scrape, map, or crawl", TypeSchema.Str),
                ToolParameter("query", "Search query or URL", TypeSchema.Str),
                ToolParameter("apiKey", "Firecrawl API key (optional, uses FIRECRAWL_API_KEY env var if not provided)", TypeSchema.Str),
                ToolParameter("apiUrl", "Firecrawl API URL (optional, uses FIRECRAWL_API_URL env var or defaults to https://api.firecrawl.dev)", TypeSchema.Str)
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
                  "action": "search",
                  "query": "latest AI developments"
                }
                """,
                """
                {
                  "action": "scrape",
                  "query": "https://example.com"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let action = FirecrawlTool.extractString(args, "action").toAsciiLower()
        if (action.isEmpty()) {
            throw ToolException("Parameter 'action' is required")
        }

        let query = FirecrawlTool.extractString(args, "query")
        if (query.isEmpty()) {
            throw ToolException("Parameter 'query' is required")
        }

        let paramApiKey = FirecrawlTool.extractString(args, "apiKey")
        let paramApiUrl = FirecrawlTool.extractString(args, "apiUrl")

        let apiKey = FirecrawlTool.getApiKey(paramApiKey)
        if (apiKey.isEmpty()) {
            LogUtils.info("[FirecrawlTool] No API key configured, falling back to WebFetchTool")
            return FirecrawlTool.fallbackToWebFetch(query)
        }

        let apiUrl = FirecrawlTool.getApiUrl(paramApiUrl)

        LogUtils.info("[FirecrawlTool] Executing action '${action}' with query: ${query}")

        try {
            let result = match (action) {
                case "search" =>
                    FirecrawlTool.performSearch(apiKey, apiUrl, query)
                case "scrape" =>
                    FirecrawlTool.performScrape(apiKey, apiUrl, query)
                case "map" =>
                    FirecrawlTool.performMap(apiKey, apiUrl, query)
                case "crawl" =>
                    FirecrawlTool.performCrawl(apiKey, apiUrl, query)
                case _ =>
                    throw ToolException("Invalid action. Supported actions: search, scrape, map, crawl")
            }

            let response = JsonObject()
            response.put("success", JsonString("true"))
            response.put("action", JsonString(action))
            response.put("query", JsonString(query))
            response.put("result", JsonString(result))

            return ToolResponse(response.toJsonString())
        } catch (ex: Exception) {
            LogUtils.error("[FirecrawlTool] Failed to execute action: ${ex.message}")
            LogUtils.info("[FirecrawlTool] Falling back to WebFetchTool")
            return FirecrawlTool.fallbackToWebFetch(query)
        }
    }

    protected static func getApiKey(paramApiKey: String): String {
        if (!paramApiKey.isEmpty()) {
            return paramApiKey
        }

        let envApiKey = getEnv("FIRECRAWL_API_KEY")
        match (envApiKey) {
            case Some(key) =>
                if (key != "your_firecrawl_api_key_here") {
                    return key
                }
            case None =>
                return ""
        }
        return ""
    }

    protected static func getApiUrl(paramApiUrl: String): String {
        if (!paramApiUrl.isEmpty()) {
            return paramApiUrl
        }

        let envApiUrl = getEnv("FIRECRAWL_API_URL")
        match (envApiUrl) {
            case Some(url) =>
                if (!url.isEmpty()) {
                    return url
                }
            case None =>
                return "https://api.firecrawl.dev"
        }
        return "https://api.firecrawl.dev"
    }

    protected static func performSearch(apiKey: String, apiUrl: String, query: String): String {
        let endpoint = "/v2/search"
        let requestBody = JsonObject()
        requestBody.put("query", JsonString(query))

        let defaultLimit = FirecrawlTool.getDefaultLimit()
        requestBody.put("limit", JsonString(defaultLimit.toString()))

        let response = FirecrawlTool.makeRequest(apiKey, apiUrl, endpoint, requestBody)
        return response
    }

    protected static func performScrape(apiKey: String, apiUrl: String, url: String): String {
        let endpoint = "/v2/scrape"
        let requestBody = JsonObject()
        requestBody.put("url", JsonString(url))
        
        // v2 API requires formats parameter
        let formatsArray = JsonArray()
        formatsArray.add(JsonString("markdown"))
        requestBody.put("formats", formatsArray)

        let response = FirecrawlTool.makeRequest(apiKey, apiUrl, endpoint, requestBody)
        return response
    }

    protected static func performMap(apiKey: String, apiUrl: String, url: String): String {
        let endpoint = "/v2/map"
        let requestBody = JsonObject()
        requestBody.put("url", JsonString(url))

        let response = FirecrawlTool.makeRequest(apiKey, apiUrl, endpoint, requestBody)
        return response
    }

    protected static func performCrawl(apiKey: String, apiUrl: String, url: String): String {
        let endpoint = "/v2/crawl"
        let requestBody = JsonObject()
        requestBody.put("url", JsonString(url))

        let response = FirecrawlTool.makeRequest(apiKey, apiUrl, endpoint, requestBody)
        return response
    }

    protected static func getDefaultLimit(): Int64 {
        let envLimit = getEnv("FIRECRAWL_DEFAULT_LIMIT")
        match (envLimit) {
            case Some(limitStr) =>
                try {
                    return Int64.parse(limitStr)
                } catch (ex: Exception) {
                    return 10
                }
            case None =>
                return 10
        }
    }

    protected static func makeRequest(apiKey: String, apiUrl: String, endpoint: String, body: JsonObject): String {
        let headers = HashMap<String, String>()
        headers.add("Content-Type", "application/json")
        headers.add("Authorization", "Bearer ${apiKey}")
        headers.add("User-Agent", "AgentSkillsRuntime/1.0")

        let fullUrl = "${apiUrl}${endpoint}"
        LogUtils.info("[FirecrawlTool] Making request to: ${fullUrl}")

        let response = HttpUtils.post(fullUrl, headers, body)
        match (response) {
            case Some(content) =>
                return content
            case None =>
                throw ToolException("No response received from Firecrawl API")
        }
    }

    protected static func fallbackToWebFetch(url: String): ToolResponse {
        let webFetchTool = WebFetchTool()
        let args = HashMap<String, JsonValue>()
        args.add("url", JsonString(url))
        return webFetchTool.invoke(args)
    }

    public static func extractString(args: HashMap<String, JsonValue>, key: String): String {
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
