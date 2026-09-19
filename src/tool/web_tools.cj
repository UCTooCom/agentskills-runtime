/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.utils.http.HttpUtils
import std.collection.HashMap
import std.core.StringBuilder
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

// ---------------------------------------------------------------------------
// 重建说明（2026-09-17）
//
// 本文件在 2026-09-17 00:31 因写盘中断被零填充损坏（14000 字节全 0，且 git 未跟踪，
// 无历史副本可还原），现按工程同类工具（http_tool / firecrawl_tool / vision_tools）
// 的既有写法重建，并顺带修掉 222604 日志暴露的几个实网抓取故障：
//
//   1) 自报家门型 UA（AgentSkillsRuntime/1.0）被搜索引擎静默拦截
//      -> HTTP 200 但正文只有 21 字节。改用常规浏览器 UA + Accept/Accept-Language。
//   2) 搜索结果页整页 HTML 原样回灌模型（数十万字符），白白吃掉上下文
//      -> 默认做 HTML 去标签提炼正文（mode=auto），保留 mode=raw 逃生开关。
//   3) 抓取失败只回一句话，agent 无法判断该换引擎还是换手段
//      -> 拦截/失败都结构化给出 reason + suggestion。
//
// 注意：传输层的两个坑不在这里修——
//   - chunked 响应 "incomplete chunk data" 已在 libs/http_lib/src/client/client.cj
//     改为增量流式解码（对齐 transport.cj）；
//   - Windows 缺 CA 信任锚已在 libs/http_lib/src/connection/tls_connection.cj 修。
// ---------------------------------------------------------------------------

public class WebFetchTool <: AbsTool {
    public static let NAME = "web_fetch"

    public static let DESC = """
    Fetch the content of a web page / URL and return its readable text.
    Accepts the full URL including query string (search engines included).
    By default HTML is converted to plain text so the result stays small;
    set mode="raw" to get the untouched response body (HTML / JSON / plain).
    If a search engine returns an anti-bot page instead of results, this tool
    reports 'blocked' with a reason - switch to another engine instead of
    retrying the same one with slightly different parameters.
    """

    // 常规桌面版 Chrome UA。此前自报家门的 "compatible; AgentSkillsRuntime/1.0"
    // 会被百度/必应等按 bot 处理：返回 200 但正文是十几字节的空壳。
    public static let DEFAULT_UA =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

    public static let DEFAULT_ACCEPT =
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

    public static let DEFAULT_LANGUAGE = "zh-CN,zh;q=0.9,en;q=0.8"

    // 正文提炼后超过该字符数即截断，避免整页 HTML 灌爆上下文
    public static let MAX_CONTENT_CHARS: Int64 = 60000

    // 提炼后正文短于此值时，说明大概率拿到了空白页/拦截页/纯跳转页
    public static let MIN_USEFUL_CHARS: Int64 = 128

    // 常见验证页 / 反爬页特征（小写比对）
    public static let BLOCK_MARKERS: Array<String> = [
        "verify.baidu.com",
        "百度安全验证",
        "请输入验证码",
        "cf-browser-verification",
        "just a moment",
        "unusual traffic",
        "antispider",
        "访问异常",
        "请求过于频繁",
        "sec.baidu.com"
    ]

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { WebFetchTool.NAME }
    }

    public prop description: String {
        get() { WebFetchTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("url", "The full URL to fetch (http or https), including query string. Required.", TypeSchema.Str),
                ToolParameter("mode", "auto (default): convert HTML to readable text; text: force conversion; raw: return the untouched response body.", TypeSchema.Str)
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
                  "url": "https://www.bing.com/search?q=2025%E5%B9%B4%E9%AB%98%E8%80%83%E6%95%B0%E5%AD%A6%E5%8E%8B%E8%BD%B4%E9%A2%98"
                }
                """,
                """
                {
                  "url": "https://zh.wikipedia.org/wiki/%E9%AB%98%E8%80%83",
                  "mode": "text"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let url = WebFetchTool.extractString(args, "url")
        if (url.isEmpty()) {
            throw ToolException("Parameter 'url' is required for web_fetch")
        }
        let mode = WebFetchTool.extractString(args, "mode").toAsciiLower()
        let rawMode = mode == "raw"

        let headers = HashMap<String, String>()
        headers.add("User-Agent", WebFetchTool.DEFAULT_UA)
        headers.add("Accept", WebFetchTool.DEFAULT_ACCEPT)
        headers.add("Accept-Language", WebFetchTool.DEFAULT_LANGUAGE)
        headers.add("Cache-Control", "no-cache")

        LogUtils.info("[WebFetchTool] Fetching URL: ${url}")

        // 抓取：先用 verify=false；失败（多为 TLS 握手被服务端主动断开，
        // 或 CA 校验不过）再用系统 CA（verify=true）重试一次 ——
        // .env 里的 SSL_CERT_FILE 已指向本地 CA 包，这一步才有意义。
        var fetched: Option<String> = None<String>
        var lastError = ""
        for (verifyMode in [false, true]) {
            try {
                fetched = HttpUtils.get(url, headers, None<JsonObject>, verify: verifyMode)
            } catch (ex: Exception) {
                lastError = ex.message
                LogUtils.info("[WebFetchTool] verify=${verifyMode} 尝试失败: ${ex.message}")
            }
            if (fetched.isSome()) {
                break
            }
        }

        try {
            if (let Some(body) <- fetched) {
                let trimmedHead = body.trimAscii()
                if (trimmedHead.isEmpty()) {
                    LogUtils.error("[WebFetchTool] Empty body from: ${url}")
                    let errObj = JsonObject()
                    errObj.put("success", JsonString("false"))
                    errObj.put("status", JsonString("empty"))
                    errObj.put("url", JsonString(url))
                    errObj.put("error", JsonString("响应体为空（0 字节）"))
                    errObj.put("suggestion", JsonString(WebFetchTool.blockedSuggestion("empty_body")))
                    return ToolResponse(errObj.toJsonString(), isError: true)
                }

                let blockReason = WebFetchTool.detectBlockReason(body)
                let isBlocked = !blockReason.isEmpty()

                // 内容整形：默认把 HTML 提炼成可读文本；mode=raw 时原样返回
                var content = body
                var contentType = "raw"
                if (!rawMode && WebFetchTool.looksLikeHtml(body)) {
                    content = WebFetchTool.htmlToText(body)
                    contentType = "text"
                }

                let originalLength = body.size
                var truncated = false
                if (content.size > WebFetchTool.MAX_CONTENT_CHARS) {
                    content = content[0..WebFetchTool.MAX_CONTENT_CHARS]
                    truncated = true
                }

                let tooShort = content.trimAscii().size < WebFetchTool.MIN_USEFUL_CHARS

                let okObj = JsonObject()
                okObj.put("success", JsonString(if (isBlocked) { "false" } else { "true" }))
                okObj.put("status", JsonString(if (isBlocked) { "blocked" } else { "ok" }))
                okObj.put("url", JsonString(url))
                okObj.put("content_type", JsonString(contentType))
                okObj.put("original_length", JsonString("${originalLength}"))
                okObj.put("length", JsonString("${content.size}"))
                okObj.put("truncated", JsonString(if (truncated) { "true" } else { "false" }))
                okObj.put("content", JsonString(content))
                if (isBlocked) {
                    okObj.put("error", JsonString("疑似被目标站点反爬拦截：${blockReason}"))
                    okObj.put("suggestion", JsonString(WebFetchTool.blockedSuggestion(blockReason)))
                } else if (tooShort) {
                    okObj.put("warning", JsonString("正文过短，可能命中拦截页或 JS 渲染页，建议换引擎或用 python_execute 抓。"))
                }
                if (!isBlocked && tooShort) {
                    LogUtils.info("[WebFetchTool] Suspiciously short body (${content.size} chars) from: ${url}")
                }
                return ToolResponse(okObj.toJsonString(), isError: isBlocked)
            }

            let detail = if (lastError.isEmpty()) { "请求未完成，未拿到任何响应体" } else { lastError }
            LogUtils.error("[WebFetchTool] No response body from: ${url} (${detail})")
            let errObj = JsonObject()
            errObj.put("success", JsonString("false"))
            errObj.put("status", JsonString("no_response"))
            errObj.put("url", JsonString(url))
            errObj.put("error", JsonString(detail))
            errObj.put("suggestion", JsonString(WebFetchTool.failureSuggestion(detail)))
            return ToolResponse(errObj.toJsonString(), isError: true)
        } catch (ex: Exception) {
            LogUtils.error("[WebFetchTool] Failed to fetch URL: ${ex.message}")
            let failObj = JsonObject()
            failObj.put("success", JsonString("false"))
            failObj.put("status", JsonString("error"))
            failObj.put("url", JsonString(url))
            failObj.put("error", JsonString(ex.message))
            failObj.put("suggestion", JsonString(WebFetchTool.failureSuggestion(ex.message)))
            return ToolResponse(failObj.toJsonString(), isError: true)
        }
    }

    /// 判定响应体是否疑似反爬/验证页。返回命中的原因，正常内容返回空串。
    public static func detectBlockReason(body: String): String {
        let lowered = body.toAsciiLower()
        let probe = if (lowered.size > 8192) { lowered[0..8192] } else { lowered }
        for (marker in WebFetchTool.BLOCK_MARKERS) {
            if (probe.contains(marker.toAsciiLower())) {
                return marker
            }
        }
        let plain = body.trimAscii()
        if (plain.size < 64) {
            if (!plain.contains("<") && !plain.contains("{")) {
                return "empty_shell_${plain.size}bytes"
            }
        }
        return ""
    }

    /// 只在确实像 HTML 时才做正文提炼，避免把 JSON / 纯文本接口结果弄坏。
    public static func looksLikeHtml(body: String): Bool {
        let lowered = body.toAsciiLower()
        if (lowered.contains("<html")) {
            return true
        }
        if (lowered.contains("<!doctype")) {
            return true
        }
        if (lowered.contains("<div")) {
            return true
        }
        if (lowered.contains("<script")) {
            return true
        }
        if (lowered.contains("<meta")) {
            return true
        }
        return false
    }

    /// HTML → 可读文本：去 script/style/注释/标签 → 反转义常用实体 → 折叠空白。
    public static func htmlToText(html: String): String {
        var text = html
        text = WebFetchTool.removeBetween(text, "<script", "</script>")
        text = WebFetchTool.removeBetween(text, "<style", "</style>")
        text = WebFetchTool.removeBetween(text, "<noscript", "</noscript>")
        text = WebFetchTool.removeBetween(text, "<!--", "-->")
        text = WebFetchTool.removeTags(text)
        text = text.replace("&nbsp;", " ")
        text = text.replace("&amp;", "&")
        text = text.replace("&lt;", "<")
        text = text.replace("&gt;", ">")
        text = text.replace("&quot;", "\"")
        text = text.replace("&#39;", "'")
        text = text.replace("&mdash;", "—")
        text = text.replace("&ldquo;", "“")
        text = text.replace("&rdquo;", "”")
        text = text.replace("\r\n", "\n")
        text = text.replace("\r", "\n")
        text = text.replace("\t", " ")
        // 折叠连续空白与空行（只用工程里已验证过的 replace/contains 组合，不引正则）
        while (text.contains("\n \n")) {
            text = text.replace("\n \n", "\n\n")
        }
        while (text.contains("\n\n\n")) {
            text = text.replace("\n\n\n", "\n\n")
        }
        while (text.contains("  ")) {
            text = text.replace("  ", " ")
        }
        return text.trimAscii()
    }

    /// 删除 openMarker 与 closeMarker 之间的全部内容（连同标记本身）。
    private static func removeBetween(src: String, openMarker: String, closeMarker: String): String {
        let sb = StringBuilder()
        var pos: Int64 = 0
        while (pos < src.size) {
            if (let Some(openAt) <- src.indexOf(openMarker, pos)) {
                sb.append(src[pos..openAt])
                if (let Some(closeAt) <- src.indexOf(closeMarker, openAt + openMarker.size)) {
                    pos = closeAt + closeMarker.size
                } else {
                    pos = src.size
                }
            } else {
                sb.append(src[pos..src.size])
                pos = src.size
            }
        }
        return sb.toString()
    }

    /// 删除所有标签（尖括号对），保留标签之间的文本。
    private static func removeTags(src: String): String {
        let sb = StringBuilder()
        var pos: Int64 = 0
        while (pos < src.size) {
            if (let Some(lt) <- src.indexOf("<", pos)) {
                sb.append(src[pos..lt])
                if (let Some(gt) <- src.indexOf(">", lt + 1)) {
                    pos = gt + 1
                } else {
                    pos = src.size
                }
            } else {
                sb.append(src[pos..src.size])
                pos = src.size
            }
        }
        return sb.toString()
    }

    /// 命中验证/拦截页时给 agent 的可执行建议。
    public static func blockedSuggestion(reason: String): String {
        return "目标站点返回了验证/拦截页（${reason}）：请勿对同一引擎反复重试相同参数，换用另一个搜索引擎或数据源；若都不通，用 python_execute 执行技能目录下的抓取脚本（requests + 自定义 headers/cookies）。"
    }

    /// 传输层失败时，按错误类型给出对应的下一步动作。
    public static func failureSuggestion(message: String): String {
        let lowered = message.toAsciiLower()
        if (lowered.contains("enotfound") || lowered.contains("getaddrinfo")) {
            return "域名解析失败：该域名在本机网络不可达（可能被墙或无 DNS），请直接换用国内可访问的引擎。"
        }
        if (lowered.contains("10060") || lowered.contains("timed out") || lowered.contains("timeout")) {
            return "连接超时：该站点在本机网络不可达，请换用国内可访问的引擎，不要继续空等重试。"
        }
        if (lowered.contains("10054") || lowered.contains("tls") || lowered.contains("handshake")) {
            return "TLS 握手被服务端断开：多为对客户端指纹的限制，请换一个数据源，或用 python_execute 走系统 requests/curl。"
        }
        if (lowered.contains("chunk")) {
            return "响应为分块传输且格式特殊：http 客户端层已改为流式解码，若仍失败请用 python_execute 抓。"
        }
        return "抓取失败：请换一个数据源，或改用 python_execute + requests 脚本。"
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
