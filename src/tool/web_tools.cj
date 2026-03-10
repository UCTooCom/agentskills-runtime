/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.utils.http.HttpUtils
import std.collection.HashMap
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

public class WebFetchTool <: AbsTool {
    public static let NAME = "web_fetch"
    
    public static let DESC = """
    Fetch content from a URL and convert HTML to markdown.
    Useful for retrieving web page content for analysis.
    Returns the page content as markdown text.
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
        get() { WebFetchTool.NAME }
    }

    public prop description: String {
        get() { WebFetchTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("url", "The URL to fetch", TypeSchema.Str),
                ToolParameter("timeout", "Timeout in milliseconds (default 30000)", TypeSchema.Int),
                ToolParameter("maxContentLength", "Maximum content length in bytes (default 1048576)", TypeSchema.Int)
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
                  "url": "https://example.com/page"
                }
                """,
                """
                {
                  "url": "https://example.com/article",
                  "maxContentLength": 2097152
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let url = WebFetchTool.extractString(args, "url")
        if (url.isEmpty()) {
            throw ToolException("Parameter 'url' is required")
        }

        let maxContentLength = WebFetchTool.extractInt(args, "maxContentLength", 1048576)

        LogUtils.info("[WebFetchTool] Fetching URL: ${url}")

        try {
            let headers = HashMap<String, String>()
            headers.add("User-Agent", "Mozilla/5.0 (compatible; AgentSkillsRuntime/1.0)")
            headers.add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

            let result = HttpUtils.get(url, headers, None<JsonObject>)

            match (result) {
                case Some(content) =>
                    if (content.size > maxContentLength) {
                        throw ToolException("Content exceeds maximum length of ${maxContentLength.toString()} bytes")
                    }

                    let markdown = WebFetchTool.htmlToMarkdown(content)

                    let response = JsonObject()
                    response.put("success", JsonString("true"))
                    response.put("url", JsonString(url))
                    response.put("content", JsonString(markdown))
                    response.put("contentLength", JsonString(markdown.size.toString()))

                    return ToolResponse(response.toJsonString())
                case None =>
                    throw ToolException("Failed to fetch URL: no response received")
            }
        } catch (ex: Exception) {
            LogUtils.error("[WebFetchTool] Failed to fetch URL: ${ex.message}")
            throw ToolException("Failed to fetch URL: ${ex.message}")
        }
    }

    public static func htmlToMarkdown(html: String): String {
        var result = html
        
        result = WebFetchTool.removeScriptAndStyle(result)
        result = WebFetchTool.convertHeadings(result)
        result = WebFetchTool.convertLinks(result)
        result = WebFetchTool.convertImages(result)
        result = WebFetchTool.convertLists(result)
        result = WebFetchTool.convertParagraphs(result)
        result = WebFetchTool.convertLineBreaks(result)
        result = WebFetchTool.removeTags(result)
        result = WebFetchTool.cleanWhitespace(result)
        
        return result
    }

    protected static func removeScriptAndStyle(html: String): String {
        var result = html
        result = WebFetchTool.removeTagContent(result, "script")
        result = WebFetchTool.removeTagContent(result, "style")
        result = WebFetchTool.removeTagContent(result, "nav")
        result = WebFetchTool.removeTagContent(result, "footer")
        return result
    }

    protected static func removeTagContent(html: String, tagName: String): String {
        var result = html
        let openTag = "<${tagName}"
        let closeTag = "</${tagName}>"
        
        let startIdxOpt = result.indexOf(openTag)
        if (let Some(startIdx) <- startIdxOpt) {
            let endIdxOpt = result.indexOf(closeTag, startIdx)
            if (let Some(endIdx) <- endIdxOpt) {
                if (endIdx > startIdx) {
                    result = result[0..startIdx] + result[(endIdx + closeTag.size)..result.size]
                    return WebFetchTool.removeTagContent(result, tagName)
                }
            }
        }
        return result
    }

    protected static func convertHeadings(html: String): String {
        var result = html
        
        for (level in 1..=6) {
            let openTag = "<h${level.toString()}"
            let closeTag = "</h${level.toString()}>"
            
            let idxOpt = result.indexOf(openTag)
            if (let Some(idx) <- idxOpt) {
                let gtIdxOpt = result.indexOf(">", idx)
                if (let Some(gtIdx) <- gtIdxOpt) {
                    if (gtIdx > idx) {
                        var prefix = ""
                        for (_ in 0..level) {
                            prefix = prefix + "#"
                        }
                        result = result[0..gtIdx] + "\n${prefix} " + result[(gtIdx + 1)..result.size]
                    }
                }
            }
            
            result = result.replace(closeTag, "\n")
        }
        
        return result
    }

    protected static func convertLinks(html: String): String {
        var result = html
        let linkPattern = "<a "
        let idxOpt = result.indexOf(linkPattern)
        
        if (let Some(idx) <- idxOpt) {
            let endTagOpt = result.indexOf(">", idx)
            if (let Some(endTag) <- endTagOpt) {
                if (endTag > idx) {
                    let closeTagOpt = result.indexOf("</a>", endTag)
                    if (let Some(closeTag) <- closeTagOpt) {
                        if (closeTag > endTag) {
                            let tagContent = result[idx..endTag]
                            let href = WebFetchTool.extractAttribute(tagContent, "href")
                            let linkText = result[(endTag + 1)..closeTag]
                            let replacement = "[${linkText}](${href})"
                            result = result[0..idx] + replacement + result[(closeTag + 4)..result.size]
                            return WebFetchTool.convertLinks(result)
                        }
                    }
                }
            }
        }
        
        return result
    }

    protected static func convertImages(html: String): String {
        var result = html
        let imgPattern = "<img "
        let idxOpt = result.indexOf(imgPattern)
        
        if (let Some(idx) <- idxOpt) {
            let endTagOpt = result.indexOf("/>", idx)
            let endTag = if (let Some(et) <- endTagOpt) {
                et
            } else {
                let gtOpt = result.indexOf(">", idx)
                if (let Some(gt) <- gtOpt) { gt } else { idx }
            }
            
            if (endTag > idx) {
                let tagContent = result[idx..endTag]
                let altText = WebFetchTool.extractAttribute(tagContent, "alt")
                let srcUrl = WebFetchTool.extractAttribute(tagContent, "src")
                
                if (!srcUrl.isEmpty()) {
                    let replacement = "![${altText}](${srcUrl})"
                    let endOffset = if (result[endTag..(endTag+2)] == "/>") { 2 } else { 1 }
                    result = result[0..idx] + replacement + result[(endTag + endOffset)..result.size]
                    return WebFetchTool.convertImages(result)
                }
            }
        }
        
        return result
    }

    protected static func extractAttribute(tagContent: String, attrName: String): String {
        let attrPattern = "${attrName}=\""
        let idxOpt = tagContent.indexOf(attrPattern)
        if (let Some(idx) <- idxOpt) {
            let start = idx + attrPattern.size
            let endOpt = tagContent.indexOf("\"", start)
            if (let Some(end) <- endOpt) {
                if (end > start) {
                    return tagContent[start..end]
                }
            }
        }
        return ""
    }

    protected static func convertLists(html: String): String {
        var result = html
        
        result = result.replace("<ul>", "\n")
        result = result.replace("</ul>", "\n")
        result = result.replace("<ol>", "\n")
        result = result.replace("</ol>", "\n")
        result = result.replace("<li>", "- ")
        result = result.replace("</li>", "\n")
        
        return result
    }

    protected static func convertParagraphs(html: String): String {
        var result = html
        
        result = result.replace("<p>", "\n")
        result = result.replace("</p>", "\n\n")
        result = result.replace("<div>", "\n")
        result = result.replace("</div>", "\n")
        result = result.replace("<br>", "\n")
        result = result.replace("<br/>", "\n")
        result = result.replace("<br />", "\n")
        
        return result
    }

    protected static func convertLineBreaks(html: String): String {
        var result = html
        
        result = result.replace("&nbsp;", " ")
        result = result.replace("&amp;", "&")
        result = result.replace("&lt;", "<")
        result = result.replace("&gt;", ">")
        result = result.replace("&quot;", "\"")
        result = result.replace("&#39;", "'")
        
        return result
    }

    protected static func removeTags(html: String): String {
        var result = html
        var inTag = false
        var cleaned = StringBuilder()
        
        for (i in 0..result.size) {
            let char = result[i..(i+1)]
            if (char == "<") {
                inTag = true
            } else if (char == ">") {
                inTag = false
            } else if (!inTag) {
                cleaned.append(char)
            }
        }
        
        return cleaned.toString()
    }

    protected static func cleanWhitespace(text: String): String {
        var result = text
        
        while (result.contains("  ")) {
            result = result.replace("  ", " ")
        }
        
        while (result.contains("\n\n\n")) {
            result = result.replace("\n\n\n", "\n\n")
        }
        
        while (result.startsWith("\n")) {
            result = result[1..result.size]
        }
        
        while (result.endsWith("\n")) {
            result = result[0..(result.size - 1)]
        }
        
        return result
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

    public static func extractBool(args: HashMap<String, JsonValue>, key: String, defaultValue: Bool): Bool {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    let strVal = jStr.getValue().toAsciiLower()
                    return strVal == "true" || strVal == "1"
                case _ =>
                    return value.toString().toAsciiLower() == "true"
            }
        }
        return defaultValue
    }

    public static func extractInt(args: HashMap<String, JsonValue>, key: String, defaultValue: Int64): Int64 {
        if (let Some(value) <- args.get(key)) {
            try {
                match (value) {
                    case jStr: JsonString =>
                        return Int64.parse(jStr.getValue())
                    case _ =>
                        return Int64.parse(value.toString())
                }
            } catch (ex: Exception) {
                return defaultValue
            }
        }
        return defaultValue
    }
}
