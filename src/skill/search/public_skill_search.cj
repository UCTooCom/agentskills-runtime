/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.search

import std.collection.{ArrayList, HashMap}
import std.env.getVariable
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonNull}
import magic.log.LogUtils
import magic.utils.newProcess
import std.io.StringReader

/**
 * Public skill search service
 * Searches for skills from public open-source repositories (GitHub, AtomGit, Gitee)
 * 
 * Authentication strategy: Default no auth + optional user auth
 * - Default: Use public API without authentication (lower rate limits)
 * - Optional: Use user-provided tokens for higher rate limits
 */
public class PublicSkillSearchService {
    private let _githubSearcher: GitHubSkillSearcher
    private let _giteeSearcher: GiteeSkillSearcher
    private let _atomgitSearcher: AtomGitSkillSearcher
    
    public init() {
        _githubSearcher = GitHubSkillSearcher()
        _giteeSearcher = GiteeSkillSearcher()
        _atomgitSearcher = AtomGitSkillSearcher()
    }
    
    /**
     * Search for skills from public repositories
     * @param query Search keyword
     * @param source Search source: "github", "atomgit", "gitee", or "all"
     * @param limit Maximum number of results
     * @param sort Sort order: "stars", "updated", "best_match"
     * @return Search results
     */
    public func search(query: String, source: String, limit: Int32, sort: String): SkillSearchResponse {
        LogUtils.info("[PublicSkillSearchService] Searching for: ${query}, source: ${source}, limit: ${limit}")
        
        let allResults = ArrayList<SkillSearchResult>()
        
        if (source == "all" || source == "github") {
            let githubResults = _githubSearcher.search(query, limit, sort)
            LogUtils.info("[PublicSkillSearchService] GitHub returned ${githubResults.size.toString()} results")
            for (result in githubResults) {
                allResults.add(result)
            }
        }
        
        if (source == "all" || source == "gitee") {
            let giteeResults = _giteeSearcher.search(query, limit, sort)
            for (result in giteeResults) {
                allResults.add(result)
            }
        }
        
        if (source == "all" || source == "atomgit") {
            let atomgitResults = _atomgitSearcher.search(query, limit, sort)
            for (result in atomgitResults) {
                allResults.add(result)
            }
        }
        
        // Sort and limit results
        let sortedResults = _sortResults(allResults, sort, limit)
        
        return SkillSearchResponse(
            total_count: Int32(allResults.size),
            results: sortedResults
        )
    }
    
    /**
     * Sort results by specified order and limit to max count
     */
    private func _sortResults(results: ArrayList<SkillSearchResult>, sort: String, limit: Int32): Array<SkillSearchResult> {
        // For simplicity, we'll just take the first 'limit' results
        // In a real implementation, we would sort by stars/updated/best_match
        let limitedResults = ArrayList<SkillSearchResult>()
        var count: Int64 = 0
        let limit64 = Int64(limit)
        for (result in results) {
            if (count >= limit64) {
                break
            }
            limitedResults.add(result)
            count += 1
        }
        return limitedResults.toArray()
    }
}

/**
 * Search response
 */
public struct SkillSearchResponse {
    public let total_count: Int32
    public let results: Array<SkillSearchResult>
    
    public init(total_count!: Int32, results!: Array<SkillSearchResult>) {
        this.total_count = total_count
        this.results = results
    }
    
    public func toJson(): String {
        let json = JsonObject()
        json.put("total_count", JsonInt(Int64(total_count)))
        
        let resultsArray = JsonArray()
        for (result in results) {
            resultsArray.add(result.toJsonValue())
        }
        json.put("results", resultsArray)
        
        return json.toString()
    }
}

/**
 * Search result
 */
public struct SkillSearchResult {
    public let name: String
    public let full_name: String
    public let description: String
    public let url: String
    public let clone_url: String
    public let source: String
    public let stars: Int32
    public let forks: Int32
    public let updated_at: String
    public let topics: Array<String>
    public let license: String
    public let author: String
    
    public init(
        name!: String,
        full_name!: String,
        description!: String,
        url!: String,
        clone_url!: String,
        source!: String,
        stars!: Int32,
        forks!: Int32,
        updated_at!: String,
        topics!: Array<String>,
        license!: String,
        author!: String
    ) {
        this.name = name
        this.full_name = full_name
        this.description = description
        this.url = url
        this.clone_url = clone_url
        this.source = source
        this.stars = stars
        this.forks = forks
        this.updated_at = updated_at
        this.topics = topics
        this.license = license
        this.author = author
    }
    
    public func toJsonValue(): JsonValue {
        let json = JsonObject()
        json.put("name", JsonString(name))
        json.put("full_name", JsonString(full_name))
        json.put("description", JsonString(description))
        json.put("url", JsonString(url))
        json.put("clone_url", JsonString(clone_url))
        json.put("source", JsonString(source))
        json.put("stars", JsonInt(Int64(stars)))
        json.put("forks", JsonInt(Int64(forks)))
        json.put("updated_at", JsonString(updated_at))
        json.put("license", JsonString(license))
        json.put("author", JsonString(author))
        
        let topicsArray = JsonArray()
        for (topic in topics) {
            topicsArray.add(JsonString(topic))
        }
        json.put("topics", topicsArray)
        
        return json
    }
}

/**
 * GitHub skill searcher
 */
public class GitHubSkillSearcher {
    private let _apiUrl: String = "https://api.github.com/search/repositories"
    
    public func search(query: String, limit: Int32, sort: String): Array<SkillSearchResult> {
        LogUtils.info("[GitHubSkillSearcher] Searching for: ${query}")
        
        // Build search query with topic filter for agent-skill
        let encodedQuery = _encodeURIComponent(query)
        let searchQuery = "${encodedQuery}+topic:agent-skill"
        let sortParam = _convertSort(sort)
        let url = "${_apiUrl}?q=${searchQuery}&sort=${sortParam}&per_page=${limit}"
        
        // Get token from environment if available
        let token = getVariable("GITHUB_TOKEN")
        
        try {
            let response = _executeHttpRequest(url, token)
            return _parseGitHubResponse(response)
        } catch (ex: Exception) {
            LogUtils.error("[GitHubSkillSearcher] Search failed: ${ex.message}")
            return []
        }
    }
    
    private func _convertSort(sort: String): String {
        match (sort) {
            case "stars" => "stars"
            case "updated" => "updated"
            case _ => "best_match"
        }
    }
    
    private func _executeHttpRequest(url: String, token: Option<String>): String {
        var args = ArrayList<String>()
        args.add("-s")
        args.add("-H")
        args.add("Accept: application/vnd.github.v3+json")
        args.add("-H")
        args.add("User-Agent: AgentSkills-Runtime")
        
        if (token.isSome()) {
            args.add("-H")
            args.add("Authorization: token ${token.getOrThrow()}")
        }
        
        args.add(url)
        
        LogUtils.info("[GitHubSkillSearcher] Executing curl for GitHub API")
        
        try {
            let process = newProcess("curl", args.toArray(), redirectErr: true)
            let output = StringReader(process.stdOutPipe).readToEnd()
            let exitCode = process.wait()
            
            LogUtils.info("[GitHubSkillSearcher] Curl exit code: ${exitCode.toString()}, output length: ${output.size.toString()}")
            
            if (output.size == 0) {
                LogUtils.error("[GitHubSkillSearcher] Empty response from curl, URL: ${url}")
            }
            
            return output
        } catch (ex: Exception) {
            LogUtils.error("[GitHubSkillSearcher] Failed to execute curl: ${ex.message}")
            return ""
        }
    }
    
    private func _parseGitHubResponse(response: String): Array<SkillSearchResult> {
        let results = ArrayList<SkillSearchResult>()
        
        try {
            if (response.size == 0) {
                return []
            }
            
            let json = JsonValue.fromStr(response).asObject()
            
            if (!json.containsKey("items")) {
                return []
            }
            
            let items = json["items"].asArray()
            let itemsSize = items.size()
            
            for (i in 0..itemsSize) {
                let item = items[i]
                let itemObj = item.asObject()
                
                let name = if (itemObj.containsKey("name")) {
                    itemObj["name"].asString().getValue()
                } else {
                    ""
                }
                
                let fullName = if (itemObj.containsKey("full_name")) {
                    itemObj["full_name"].asString().getValue()
                } else {
                    name
                }
                
                let description = if (itemObj.containsKey("description")) {
                    let descValue = itemObj["description"]
                    match (descValue) {
                        case _: JsonNull => ""
                        case _ => descValue.asString().getValue()
                    }
                } else {
                    ""
                }
                
                let htmlUrl = if (itemObj.containsKey("html_url")) {
                    itemObj["html_url"].asString().getValue()
                } else {
                    ""
                }
                
                let cloneUrl = if (itemObj.containsKey("clone_url")) {
                    itemObj["clone_url"].asString().getValue()
                } else {
                    "${htmlUrl}.git"
                }
                
                let stars = if (itemObj.containsKey("stargazers_count")) {
                    Int32(itemObj["stargazers_count"].asInt().getValue())
                } else {
                    Int32(0)
                }
                
                let forks = if (itemObj.containsKey("forks_count")) {
                    Int32(itemObj["forks_count"].asInt().getValue())
                } else {
                    Int32(0)
                }
                
                let updatedAt = if (itemObj.containsKey("updated_at")) {
                    itemObj["updated_at"].asString().getValue()
                } else {
                    ""
                }
                
                let license = if (itemObj.containsKey("license")) {
                    let licenseValue = itemObj["license"]
                    match (licenseValue) {
                        case _: JsonNull => "Unknown"
                        case _ => _getLicenseSpdxId(licenseValue.asObject())
                    }
                } else {
                    "Unknown"
                }
                
                let owner = if (itemObj.containsKey("owner")) {
                    let ownerObj = itemObj["owner"].asObject()
                    if (ownerObj.containsKey("login")) {
                        ownerObj["login"].asString().getValue()
                    } else {
                        "unknown"
                    }
                } else {
                    "unknown"
                }
                
                // Parse topics
                let topicsList = ArrayList<String>()
                if (itemObj.containsKey("topics")) {
                    let topicsArray = itemObj["topics"].asArray()
                    let topicsSize = topicsArray.size()
                    for (j in 0..topicsSize) {
                        topicsList.add(topicsArray[j].asString().getValue())
                    }
                }
                
                results.add(SkillSearchResult(
                    name: name,
                    full_name: fullName,
                    description: description,
                    url: htmlUrl,
                    clone_url: cloneUrl,
                    source: "github",
                    stars: stars,
                    forks: forks,
                    updated_at: updatedAt,
                    topics: topicsList.toArray(),
                    license: license,
                    author: owner
                ))
            }
        } catch (ex: Exception) {
            LogUtils.error("[GitHubSkillSearcher] Failed to parse response: ${ex.message}")
        }
        
        return results.toArray()
    }
    
    private func _getLicenseSpdxId(licenseObj: JsonObject): String {
        if (licenseObj.containsKey("spdx_id")) {
            licenseObj["spdx_id"].asString().getValue()
        } else {
            "Unknown"
        }
    }
    
    private func _encodeURIComponent(str: String): String {
        str.replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
           .replace("<", "%3C").replace(">", "%3E").replace("\"", "%22").replace("'", "%27")
           .replace("/", "%2F").replace("?", "%3F").replace("=", "%3D").replace("@", "%40")
    }
}

/**
 * Gitee skill searcher
 * API Documentation: https://gitee.com/api/v5/swagger#/getV5SearchRepositories
 * Uses access_token parameter for authentication (not Authorization header)
 */
public class GiteeSkillSearcher {
    private let _apiUrl: String = "https://gitee.com/api/v5/search/repositories"
    
    public func search(query: String, limit: Int32, sort: String): Array<SkillSearchResult> {
        LogUtils.info("[GiteeSkillSearcher] Searching for: ${query}")
        
        let sortParam = _convertSort(sort)
        let token = getVariable("GITEE_TOKEN")
        let encodedQuery = _encodeURIComponent(query)
        
        var url = "${_apiUrl}?q=${encodedQuery}&sort=${sortParam}&per_page=${limit}"
        
        // Gitee uses access_token parameter for authentication
        if (token.isSome()) {
            url = "${url}&access_token=${token.getOrThrow()}"
        }
        
        try {
            let response = _executeHttpRequest(url)
            return _parseGiteeResponse(response)
        } catch (ex: Exception) {
            LogUtils.error("[GiteeSkillSearcher] Search failed: ${ex.message}")
            return []
        }
    }
    
    private func _convertSort(sort: String): String {
        match (sort) {
            case "stars" => "stars_count"
            case "updated" => "last_pushed"
            case _ => "best_match"
        }
    }
    
    private func _executeHttpRequest(url: String): String {
        var args = ArrayList<String>()
        args.add("-s")
        args.add("-H")
        args.add("User-Agent: AgentSkills-Runtime")
        args.add(url)
        
        let process = newProcess("curl", args.toArray(), redirectErr: true)
        let output = StringReader(process.stdOutPipe).readToEnd()
        let _ = process.wait()
        
        return output
    }
    
    private func _parseGiteeResponse(response: String): Array<SkillSearchResult> {
        let results = ArrayList<SkillSearchResult>()
        
        try {
            if (response.size == 0) {
                LogUtils.error("[GiteeSkillSearcher] Empty response")
                return []
            }
            
            LogUtils.info("[GiteeSkillSearcher] Response length: ${response.size.toString()}")
            
            let jsonValue = JsonValue.fromStr(response)
            
            // Gitee may return empty array [] or object with "data" key
            let items: JsonArray = if (jsonValue is JsonArray) {
                jsonValue.asArray()
            } else {
                let json = jsonValue.asObject()
                if (!json.containsKey("data")) {
                    return []
                }
                json["data"].asArray()
            }
            
            let itemsSize = items.size()
            
            for (i in 0..itemsSize) {
                let item = items[i]
                let itemObj = item.asObject()
                
                let name = if (itemObj.containsKey("name")) {
                    itemObj["name"].asString().getValue()
                } else {
                    ""
                }
                
                let fullName = if (itemObj.containsKey("full_name")) {
                    itemObj["full_name"].asString().getValue()
                } else {
                    if (itemObj.containsKey("path")) {
                        itemObj["path"].asString().getValue()
                    } else {
                        name
                    }
                }
                
                let description = if (itemObj.containsKey("description")) {
                    itemObj["description"].asString().getValue()
                } else {
                    ""
                }
                
                let htmlUrl = if (itemObj.containsKey("html_url")) {
                    itemObj["html_url"].asString().getValue()
                } else {
                    ""
                }
                
                let cloneUrl = if (itemObj.containsKey("clone_url")) {
                    itemObj["clone_url"].asString().getValue()
                } else {
                    "${htmlUrl}.git"
                }
                
                let stars = if (itemObj.containsKey("stargazers_count")) {
                    Int32(itemObj["stargazers_count"].asInt().getValue())
                } else {
                    Int32(0)
                }
                
                let forks = if (itemObj.containsKey("forks_count")) {
                    Int32(itemObj["forks_count"].asInt().getValue())
                } else {
                    Int32(0)
                }
                
                let updatedAt = if (itemObj.containsKey("updated_at")) {
                    itemObj["updated_at"].asString().getValue()
                } else {
                    ""
                }
                
                let license = if (itemObj.containsKey("license")) {
                    itemObj["license"].asString().getValue()
                } else {
                    "Unknown"
                }
                
                let owner = if (itemObj.containsKey("owner")) {
                    let ownerObj = itemObj["owner"].asObject()
                    if (ownerObj.containsKey("login")) {
                        ownerObj["login"].asString().getValue()
                    } else {
                        "unknown"
                    }
                } else {
                    "unknown"
                }
                
                results.add(SkillSearchResult(
                    name: name,
                    full_name: fullName,
                    description: description,
                    url: htmlUrl,
                    clone_url: cloneUrl,
                    source: "gitee",
                    stars: stars,
                    forks: forks,
                    updated_at: updatedAt,
                    topics: [],
                    license: license,
                    author: owner
                ))
            }
        } catch (ex: Exception) {
            LogUtils.error("[GiteeSkillSearcher] Failed to parse response: ${ex.message}")
        }
        
        return results.toArray()
    }
    
    private func _encodeURIComponent(str: String): String {
        str.replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
           .replace("<", "%3C").replace(">", "%3E").replace("\"", "%22").replace("'", "%27")
           .replace("/", "%2F").replace("?", "%3F").replace("=", "%3D").replace("@", "%40")
    }
}

/**
 * AtomGit skill searcher
 * API Documentation: https://docs.atomgit.com/docs/apis/get-api-v-5-search-repositories
 * Uses Gitee-compatible API (api/v5/search/repositories)
 */
public class AtomGitSkillSearcher {
    private let _apiUrl: String = "https://api.atomgit.com/api/v5/search/repositories"
    
    public func search(query: String, limit: Int32, sort: String): Array<SkillSearchResult> {
        LogUtils.info("[AtomGitSkillSearcher] Searching for: ${query}")
        
        let sortParam = _convertSort(sort)
        let token = getVariable("ATOMGIT_TOKEN")
        let encodedQuery = _encodeURIComponent(query)
        
        var url = "${_apiUrl}?q=${encodedQuery}&sort=${sortParam}&per_page=${limit}"
        
        if (token.isSome()) {
            url = "${url}&access_token=${token.getOrThrow()}"
        }
        
        try {
            let response = _executeHttpRequest(url)
            return _parseAtomGitResponse(response)
        } catch (ex: Exception) {
            LogUtils.error("[AtomGitSkillSearcher] Search failed: ${ex.message}")
            return []
        }
    }
    
    private func _convertSort(sort: String): String {
        match (sort) {
            case "stars" => "stars_count"
            case "updated" => "last_pushed"
            case _ => "best_match"
        }
    }
    
    private func _executeHttpRequest(url: String): String {
        var args = ArrayList<String>()
        args.add("-s")
        args.add("-H")
        args.add("Accept: application/json")
        args.add("-H")
        args.add("User-Agent: AgentSkills-Runtime")
        args.add(url)
        
        LogUtils.info("[AtomGitSkillSearcher] Executing curl with URL: ${url}")
        
        let process = newProcess("curl", args.toArray(), redirectErr: true)
        let output = StringReader(process.stdOutPipe).readToEnd()
        let exitCode = process.wait()
        
        LogUtils.info("[AtomGitSkillSearcher] Curl exit code: ${exitCode.toString()}, output length: ${output.size.toString()}")
        
        return output
    }
    
    private func _parseAtomGitResponse(response: String): Array<SkillSearchResult> {
        let results = ArrayList<SkillSearchResult>()
        
        try {
            if (response.size == 0) {
                LogUtils.error("[AtomGitSkillSearcher] Empty response")
                return []
            }
            
            let jsonValue = JsonValue.fromStr(response)
            
            // AtomGit returns a direct JSON array, not wrapped in an object
            if (jsonValue is JsonArray) {
                let items = jsonValue.asArray()
                let itemsSize = items.size()
                LogUtils.info("[AtomGitSkillSearcher] Found ${itemsSize.toString()} results")
                
                for (i in 0..itemsSize) {
                    let item = items[i]
                    let itemObj = item.asObject()
                    
                    let name = if (itemObj.containsKey("name")) {
                        itemObj["name"].asString().getValue()
                    } else {
                        ""
                    }
                    
                    let fullName = if (itemObj.containsKey("full_name")) {
                        itemObj["full_name"].asString().getValue()
                    } else {
                        if (itemObj.containsKey("path")) {
                            itemObj["path"].asString().getValue()
                        } else {
                            name
                        }
                    }
                    
                    let description = if (itemObj.containsKey("description")) {
                        itemObj["description"].asString().getValue()
                    } else {
                        ""
                    }
                    
                    let htmlUrl = if (itemObj.containsKey("html_url")) {
                        itemObj["html_url"].asString().getValue()
                    } else {
                        "https://atomgit.com/${fullName}"
                    }
                    
                    let cloneUrl = if (itemObj.containsKey("clone_url")) {
                        itemObj["clone_url"].asString().getValue()
                    } else {
                        "https://atomgit.com/${fullName}.git"
                    }
                    
                    let stars = if (itemObj.containsKey("stargazers_count")) {
                        Int32(itemObj["stargazers_count"].asInt().getValue())
                    } else {
                        Int32(0)
                    }
                    
                    let forks = if (itemObj.containsKey("forks_count")) {
                        Int32(itemObj["forks_count"].asInt().getValue())
                    } else {
                        Int32(0)
                    }
                    
                    let updatedAt = if (itemObj.containsKey("updated_at")) {
                        itemObj["updated_at"].asString().getValue()
                    } else {
                        ""
                    }
                    
                    let license = if (itemObj.containsKey("license")) {
                        itemObj["license"].asString().getValue()
                    } else {
                        "Unknown"
                    }
                    
                    let owner = if (itemObj.containsKey("owner")) {
                        let ownerObj = itemObj["owner"].asObject()
                        if (ownerObj.containsKey("login")) {
                            ownerObj["login"].asString().getValue()
                        } else {
                            "unknown"
                        }
                    } else {
                        "unknown"
                    }
                    
                    // Parse topics
                    let topicsList = ArrayList<String>()
                    if (itemObj.containsKey("topics")) {
                        let topicsArray = itemObj["topics"].asArray()
                        let topicsSize = topicsArray.size()
                        for (j in 0..topicsSize) {
                            topicsList.add(topicsArray[j].asString().getValue())
                        }
                    }
                    
                    results.add(SkillSearchResult(
                        name: name,
                        full_name: fullName,
                        description: description,
                        url: htmlUrl,
                        clone_url: cloneUrl,
                        source: "atomgit",
                        stars: stars,
                        forks: forks,
                        updated_at: updatedAt,
                        topics: topicsList.toArray(),
                        license: license,
                        author: owner
                    ))
                }
            } else if (jsonValue is JsonObject) {
                let json = jsonValue.asObject()
                if (json.containsKey("error_code")) {
                    let errorMsg = if (json.containsKey("error_message")) {
                        json["error_message"].asString().getValue()
                    } else {
                        "Unknown error"
                    }
                    LogUtils.error("[AtomGitSkillSearcher] API error: ${errorMsg}")
                    return []
                }
                
                // AtomGit uses Gitee-compatible API format with "data" array
                if (!json.containsKey("data")) {
                    LogUtils.error("[AtomGitSkillSearcher] No 'data' field in response")
                    return []
                }
                
                let items = json["data"].asArray()
                let itemsSize = items.size()
                
                for (i in 0..itemsSize) {
                    let item = items[i]
                    let itemObj = item.asObject()
                    
                    let name = if (itemObj.containsKey("name")) {
                        itemObj["name"].asString().getValue()
                    } else {
                        ""
                    }
                    
                    let fullName = if (itemObj.containsKey("full_name")) {
                        itemObj["full_name"].asString().getValue()
                    } else {
                        if (itemObj.containsKey("path")) {
                            itemObj["path"].asString().getValue()
                        } else {
                            name
                        }
                    }
                    
                    let description = if (itemObj.containsKey("description")) {
                        itemObj["description"].asString().getValue()
                    } else {
                        ""
                    }
                    
                    let htmlUrl = if (itemObj.containsKey("html_url")) {
                        itemObj["html_url"].asString().getValue()
                    } else {
                        "https://atomgit.com/${fullName}"
                    }
                    
                    let cloneUrl = if (itemObj.containsKey("clone_url")) {
                        itemObj["clone_url"].asString().getValue()
                    } else {
                        "https://atomgit.com/${fullName}.git"
                    }
                    
                    let stars = if (itemObj.containsKey("stargazers_count")) {
                        Int32(itemObj["stargazers_count"].asInt().getValue())
                    } else {
                        Int32(0)
                    }
                    
                    let forks = if (itemObj.containsKey("forks_count")) {
                        Int32(itemObj["forks_count"].asInt().getValue())
                    } else {
                        Int32(0)
                    }
                    
                    let updatedAt = if (itemObj.containsKey("updated_at")) {
                        itemObj["updated_at"].asString().getValue()
                    } else {
                        ""
                    }
                    
                    let license = if (itemObj.containsKey("license")) {
                        itemObj["license"].asString().getValue()
                    } else {
                        "Unknown"
                    }
                    
                    let owner = if (itemObj.containsKey("owner")) {
                        let ownerObj = itemObj["owner"].asObject()
                        if (ownerObj.containsKey("login")) {
                            ownerObj["login"].asString().getValue()
                        } else {
                            "unknown"
                        }
                    } else {
                        "unknown"
                    }
                    
                    // Parse topics
                    let topicsList = ArrayList<String>()
                    if (itemObj.containsKey("topics")) {
                        let topicsArray = itemObj["topics"].asArray()
                        let topicsSize = topicsArray.size()
                        for (j in 0..topicsSize) {
                            topicsList.add(topicsArray[j].asString().getValue())
                        }
                    }
                    
                    results.add(SkillSearchResult(
                        name: name,
                        full_name: fullName,
                        description: description,
                        url: htmlUrl,
                        clone_url: cloneUrl,
                        source: "atomgit",
                        stars: stars,
                        forks: forks,
                        updated_at: updatedAt,
                        topics: topicsList.toArray(),
                        license: license,
                        author: owner
                    ))
                }
            }
        } catch (ex: Exception) {
            LogUtils.error("[AtomGitSkillSearcher] Failed to parse response: ${ex.message}")
        }
        
        return results.toArray()
    }
    
    private func _encodeURIComponent(str: String): String {
        str.replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
           .replace("<", "%3C").replace(">", "%3E").replace("\"", "%22").replace("'", "%27")
           .replace("/", "%2F").replace("?", "%3F").replace("=", "%3D").replace("@", "%40")
    }
}
