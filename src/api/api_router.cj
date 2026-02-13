/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.api

import std.collection.{HashMap, ArrayList}
import std.convert.*
import stdx.net.http.{Server, ServerBuilder, HttpContext, HttpRequest, HttpResponse, HttpResponseBuilder, FuncHandler, HttpRequestDistributor, HttpRequestHandler}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray, JsonFloat}
import magic.skill.application.SkillManagementService
import magic.skill.application.ProgressiveSkillLoader
import magic.core.skill.{Skill, SkillManager}
import magic.skill.CompositeSkillToolManager
import magic.skill.domain.models.{SecurityPolicy, ResourceLimits}
import magic.log.LogUtils

/**
 * API Router for the Agent Skills Runtime
 * Implements the standard API interface layer following contracts/api-contract.yaml
 */
public class APIRouter {
    private let _server: Any
    private var _distributor: ?HttpRequestDistributor = None
    private let _skillManagementService: SkillManagementService
    private let _progressiveSkillLoader: ProgressiveSkillLoader
    private let _skillManager: SkillManager
    private let _port: Int32

    public init(port: Int32) {
        _port = port
        _distributor = Some(DefaultHttpRequestDistributor())
        _skillManagementService = SkillManagementService()
        
        // Initialize ProgressiveSkillLoader with skills directories - using hardcoded paths for now
        _progressiveSkillLoader = ProgressiveSkillLoader(
            skillBaseDirectories: ["./skills", "./src/examples"],  // Hardcoded paths
            defaultSecurityPolicy: SecurityPolicy.default(),
            defaultResourceLimits: ResourceLimits.default()
        )
        
        _skillManager = CompositeSkillToolManager()
        
        // Load skills from the configured directories into the skill manager
        try {
            let loadedSkills = _progressiveSkillLoader.loadSkillsToManager(_skillManager)
            LogUtils.info("✅ Successfully loaded ${loadedSkills.size} skills from './skills' and './src/examples' directories")
        } catch (ex: Exception) {
            LogUtils.error("❌ Failed to load skills: ${ex.message}")
        }

        let builder = ServerBuilder()
        builder.addr("127.0.0.1")
        builder.port(UInt16(port))
        // Set the distributor with our routes
        builder.distributor(_distributor.getOrThrow())
        _server = builder.build()
        // Set up routes after server is built
        setupRoutes()
    }

    public init() {
        this(8080)  // Default port 8080
    }

    /**
     * Helper function to get environment variable or return default value
     */
    private func getEnvOrDefault(envVar: String, defaultValue: String): String {
        // For now, returning default value since environment variable access might not be available
        // In a real implementation, this would properly check the environment
        return defaultValue
    }

    /**
     * Set up all API routes
     */
    private func setupRoutes(): Unit {
        // Register route handlers with the distributor
        let distributor = _distributor.getOrThrow()

        // Add hello endpoint for health check - GET method
        distributor.register("/hello", FuncHandler({ context => this.handleHello(context) }))

        // Register other existing routes with appropriate HTTP methods
        distributor.register("/skills", FuncHandler({ context => this.handleGetSkills(context) }))
        distributor.register("/skills/:id", FuncHandler({ context => this.handleGetSkillById(context) }))
        distributor.register("/skills/add", FuncHandler({ context => this.handleAddSkill(context) }))
        distributor.register("/skills/edit", FuncHandler({ context => this.handleEditSkill(context) }))
        distributor.register("/skills/del", FuncHandler({ context => this.handleDeleteSkill(context) }))
        distributor.register("/skills/execute", FuncHandler({ context => this.handleExecuteSkill(context) }))
        distributor.register("/skills/search", FuncHandler({ context => this.handleSearchSkills(context) }))
        distributor.register("/mcp/stream", FuncHandler({ context => this.handleMCPStream(context) }))
    }

    /**
     * Start the API server
     */
    public func start(): Unit {
        LogUtils.info("🚀 Starting Agent Skills Runtime API server on port ${_port}...")
        LogUtils.info("📁 Loading skills from directory: ./skills and ./src/examples")
        LogUtils.info("⚡ Loaded ${_skillManager.availableSkills.values().toArray().size} skills")

        match (_server as Server) {
            case Some(server) => this.startWithServer(server)
            case None => this.handleErrorInStart()
        }
    }

    /**
     * Start the API server
     */
    private func startWithServer(server: Server): Unit {
        try {
            LogUtils.info("✅ API server started successfully on http://127.0.0.1:${_port}")
            LogUtils.info("💡 Available endpoints:")
            LogUtils.info("   GET  /hello           - Health check")
            LogUtils.info("   GET  /skills          - List all skills")
            LogUtils.info("   GET  /skills/:id      - Get skill details")
            LogUtils.info("   POST /skills/add      - Install a skill")
            LogUtils.info("   POST /skills/edit     - Update a skill")
            LogUtils.info("   POST /skills/del      - Uninstall a skill")
            LogUtils.info("   POST /skills/execute  - Execute a skill")
            LogUtils.info("   POST /skills/search   - Search skills")
            LogUtils.info("   GET  /mcp/stream      - MCP server with streaming")
            
            // Note: server.serve() is a blocking call, so in a real implementation
            // you would want to run this in a background thread or async context
            // For now, we'll just call it directly
            server.serve()
        } catch (ex: Exception) {
            LogUtils.error("❌ Failed to start API server: ${ex.message}")
            throw ex
        }
    }

    private func handleErrorInStart(): Unit {
        LogUtils.error("Failed to cast _server to Server type in start()")
        throw Exception("Failed to start API server: server type cast failed")
    }

    /**
     * Stop the API server
     */
    public func stop(): Unit {
        LogUtils.info("🛑 Stopping Agent Skills Runtime API server...")

        match (_server as Server) {
            case Some(server) => this.stopWithServer(server)
            case None => this.handleErrorInStop()
        }
    }

    private func handleErrorInStop(): Unit {
        LogUtils.error("Failed to cast _server to Server type in stop()")
        throw Exception("Failed to stop API server: server type cast failed")
    }

    private func stopWithServer(server: Server): Unit {
        try {
            server.close()
            LogUtils.info("✅ API server stopped successfully")
        } catch (ex: Exception) {
            LogUtils.error("❌ Failed to stop API server: ${ex.message}")
            throw ex
        }
    }

    /**
     * Handle GET /skills request
     */
    private func handleGetSkills(context: HttpContext): Unit {
        try {
            let request = context.request
            // Parse query parameters for pagination
            let limit = getIntQueryParam(request, "limit", 10)
            let page = getIntQueryParam(request, "page", 0)
            let skip = getIntQueryParam(request, "skip", 0)

            // Validate parameters
            if (limit > 100) {
                createErrorResponse(context, 400, "limit", "Limit cannot exceed 100")
                return
            }

            // Fetch skills from the skill manager
            let skills = _skillManager.availableSkills.values().toArray()

            // Apply pagination
            let totalSkills = skills.size
            let startIndex = (page * limit) + skip
            let endIndex = min(startIndex + limit, Int32(totalSkills))

            let paginatedSkills = if (Int64(startIndex) < Int64(totalSkills)) {
                skills[Int64(startIndex)..Int64(endIndex)]
            } else {
                ArrayList<Skill>()
            }

            // Create response object
            let responseObj = JsonObject()
            responseObj.put("current_page", JsonInt(Int64(page)))
            responseObj.put("total_count", JsonInt(totalSkills))
            responseObj.put("total_page", JsonInt(Int64((Int64(totalSkills) + Int64(limit) - 1) / Int64(limit))))

            let skillsArray = JsonArray()
            for (skill in paginatedSkills) {
                let skillObj = JsonObject()
                skillObj.put("id", JsonString(skill.name))
                skillObj.put("name", JsonString(skill.name))
                skillObj.put("description", JsonString(skill.description))
                
                // Use actual skill properties if available, otherwise use placeholders
                let version = if (skill.metadata.get("version").isSome()) {
                    skill.metadata.get("version").getOrThrow()
                } else {
                    "1.0.0"  // Placeholder
                }
                skillObj.put("version", JsonString(version))
                
                let author = if (skill.metadata.get("author").isSome()) {
                    skill.metadata.get("author").getOrThrow()
                } else {
                    "Unknown"  // Placeholder
                }
                skillObj.put("author", JsonString(author))
                
                skillObj.put("license", JsonString(skill.license.getOrDefault({=>"MIT"})))
                
                let format = if (skill.metadata.get("format").isSome()) {
                    skill.metadata.get("format").getOrThrow()
                } else {
                    "skill_md"  // Placeholder
                }
                skillObj.put("format", JsonString(format))
                
                let createdAt = if (skill.metadata.get("created_at").isSome()) {
                    skill.metadata.get("created_at").getOrThrow()
                } else {
                    "2026-01-25T10:00:00Z"  // Placeholder
                }
                skillObj.put("created_at", JsonString(createdAt))
                
                let updatedAt = if (skill.metadata.get("updated_at").isSome()) {
                    skill.metadata.get("updated_at").getOrThrow()
                } else {
                    "2026-01-25T10:00:00Z"  // Placeholder
                }
                skillObj.put("updated_at", JsonString(updatedAt))
                
                skillObj.put("source_path", JsonString(skill.skillPath))
                skillObj.put("metadata", JsonObject())  // Placeholder - in a real implementation, this would be the actual metadata
                
                // Dependencies - in a real implementation, this would come from the skill manifest
                let dependenciesArray = JsonArray()
                skillObj.put("dependencies", dependenciesArray)
                
                skillsArray.add(skillObj)
            }
            responseObj.put("skills", skillsArray)

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling GET /skills: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle GET /skills/:id request
     */
    private func handleGetSkillById(context: HttpContext): Unit {
        try {
            let request = context.request
            // Extract skillId from the URL path
            let urlPath = request.url.path
            let pathParts = urlPath.split("/")
            var skillId = ""
            for (i in 0..pathParts.size) {
                if (i > 0 && pathParts[i-1] == "skills" && i < pathParts.size) {
                    skillId = pathParts[i]
                    break
                }
            }
            if (skillId.isEmpty()) {
                createErrorResponse(context, 400, "invalid_param", "Skill ID is required")
                return
            }

            // In a real implementation, this would fetch the specific skill
            if (_skillManager.getSkill(skillId).isSome()) {
                let skill = _skillManager.getSkill(skillId).getOrThrow()
                let responseObj = JsonObject()
                responseObj.put("id", JsonString(skill.name))
                responseObj.put("name", JsonString(skill.name))
                responseObj.put("description", JsonString(skill.description))
                responseObj.put("version", JsonString("1.0.0"))  // Placeholder
                responseObj.put("author", JsonString("Unknown"))  // Placeholder
                responseObj.put("license", JsonString(skill.license.getOrDefault({=>"MIT"})))
                responseObj.put("format", JsonString("skill_md"))  // Placeholder
                responseObj.put("created_at", JsonString("2026-01-25T10:00:00Z"))  // Placeholder
                responseObj.put("updated_at", JsonString("2026-01-25T10:00:00Z"))  // Placeholder
                responseObj.put("source_path", JsonString(skill.skillPath))
                responseObj.put("metadata", JsonObject())  // Placeholder
                responseObj.put("dependencies", JsonArray())  // Placeholder
                responseObj.put("tools", JsonArray())  // Placeholder

                let responseHeaders = HashMap<String, String>()
                responseHeaders.add("Content-Type", "application/json")
                createSuccessResponse(context, responseObj.toString(), responseHeaders)
            } else {
                createErrorResponse(context, 404, "not_found", "Skill not found")
            }
        } catch (ex: Exception) {
            LogUtils.error("Error handling GET /skills/:id: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle POST /skills/add request
     */
    private func handleAddSkill(context: HttpContext): Unit {
        try {
            let request = context.request
            // Parse request body
            let bodySize = request.bodySize.getOrThrow()
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            let jsonObj = JsonValue.fromStr(body).asObject()

            if (!jsonObj.containsKey("source")) {
                createErrorResponse(context, 400, "missing_field", "Source field is required")
                return
            }

            let source = jsonObj["source"].asString()
            let validate = if (jsonObj.containsKey("validate")) {
                jsonObj["validate"].asBool()
            } else {
                true
            }
            let creator = if (jsonObj.containsKey("creator")) {
                jsonObj["creator"].asString()
            } else {
                "unknown"
            }

            // In a real implementation, this would install the skill from the source
            // For now, we'll simulate the installation

            let responseObj = JsonObject()
            responseObj.put("id", JsonString("test-skill-id"))
            responseObj.put("name", JsonString("test-skill"))
            responseObj.put("status", JsonString("installed"))
            responseObj.put("message", JsonString("Skill installed successfully"))
            responseObj.put("created_at", JsonString("2026-01-25T10:00:00Z"))

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/add: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle POST /skills/edit request
     */
    private func handleEditSkill(context: HttpContext): Unit {
        try {
            let request = context.request
            // Parse request body
            let bodySize = request.bodySize.getOrThrow()
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            let jsonObj = JsonValue.fromStr(body).asObject()

            if (!jsonObj.containsKey("id")) {
                createErrorResponse(context, 400, "missing_field", "ID field is required")
                return
            }

            let id = jsonObj["id"].asString()
            let description = if (jsonObj.containsKey("description")) {
                jsonObj["description"].asString()
            } else {
                ""
            }
            let creator = if (jsonObj.containsKey("creator")) {
                jsonObj["creator"].asString()
            } else {
                "unknown"
            }

            // In a real implementation, this would update the skill
            // For now, we'll simulate the update

            let responseObj = JsonObject()
            responseObj.put("id", JsonString(id.toString()))
            responseObj.put("name", JsonString("test-skill"))
            responseObj.put("description", JsonString(description.toString()))
            responseObj.put("updated_at", JsonString("2026-01-25T10:00:00Z"))

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/edit: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle POST /skills/del request
     */
    private func handleDeleteSkill(context: HttpContext): Unit {
        try {
            let request = context.request
            // Parse request body
            let bodySize = request.bodySize.getOrThrow()
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            let jsonObj = JsonValue.fromStr(body).asObject()

            if (!jsonObj.containsKey("id")) {
                createErrorResponse(context, 400, "missing_field", "ID field is required")
                return
            }

            let id = jsonObj["id"].asString()

            // In a real implementation, this would uninstall the skill
            // For now, we'll simulate the uninstallation

            let responseObj = JsonObject()
            responseObj.put("desc", JsonString("删除成功"))  // "Deletion successful" in Chinese

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/del: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle POST /skills/execute request
     */
    private func handleExecuteSkill(context: HttpContext): Unit {
        try {
            let request = context.request
            // Parse request body
            let bodySize = request.bodySize.getOrThrow()
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            let jsonObj = JsonValue.fromStr(body).asObject()

            if (!jsonObj.containsKey("skill_id")) {
                createErrorResponse(context, 400, "missing_field", "skill_id field is required")
                return
            }

            let skillId = jsonObj["skill_id"].asString()
            let parameters = if (jsonObj.containsKey("parameters")) {
                jsonObj["parameters"].asObject()
            } else {
                JsonObject()
            }
            let capabilities = if (jsonObj.containsKey("capabilities")) {
                jsonObj["capabilities"].asArray()
            } else {
                JsonArray()
            }
            let timeout = if (jsonObj.containsKey("timeout")) {
                jsonObj["timeout"].asString()
            } else {
                "30s"
            }

            // In a real implementation, this would execute the skill
            // For now, we'll simulate the execution

            let responseObj = JsonObject()
            responseObj.put("id", JsonString("exec-test-123"))
            responseObj.put("success", JsonString("true"))
            responseObj.put("output", JsonString("Skill executed successfully"))
            responseObj.put("error", JsonString(""))
            responseObj.put("execution_time", JsonString("123ms"))

            let resourcesUsedObj = JsonObject()
            resourcesUsedObj.put("cpu_time", JsonString("50ms"))
            resourcesUsedObj.put("memory_peak", JsonInt(1048576))
            resourcesUsedObj.put("network_bytes_in", JsonInt(0))
            resourcesUsedObj.put("network_bytes_out", JsonInt(0))
            resourcesUsedObj.put("file_operations", JsonInt(0))
            responseObj.put("resources_used", resourcesUsedObj)

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/execute: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle POST /skills/search request
     */
    private func handleSearchSkills(context: HttpContext): Unit {
        try {
            let request = context.request
            // Parse request body
            let bodySize = request.bodySize.getOrThrow()
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            let jsonObj = JsonValue.fromStr(body).asObject()

            let query = if (jsonObj.containsKey("query")) {
                jsonObj["query"].asString()
            } else {
                ""
            }
            let topK = if (jsonObj.containsKey("top_k")) {
                Int32(jsonObj["top_k"].asInt().getValue())
            } else {
                Int32(5)
            }
            let includeUsageExamples = if (jsonObj.containsKey("include_usage_examples")) {
                jsonObj["include_usage_examples"].asBool().getValue()
            } else {
                true
            }
            let rerank = if (jsonObj.containsKey("rerank")) {
                jsonObj["rerank"].asBool()
            } else {
                true
            }
            let queryUnderstanding = if (jsonObj.containsKey("query_understanding")) {
                jsonObj["query_understanding"].asBool()
            } else {
                true
            }

            // In a real implementation, this would perform semantic search
            // For now, we'll simulate the search results

            let responseObj = JsonObject()
            let resultsArray = JsonArray()

            // Add sample results
            let result1 = JsonObject()
            result1.put("id", JsonString("kubernetes-456"))
            result1.put("name", JsonString("kubernetes"))
            result1.put("description", JsonString("Kubernetes cluster management with kubectl"))
            result1.put("score", JsonFloat(0.95))

            if (includeUsageExamples) {
                let examplesArray = JsonArray()
                let example1 = JsonObject()
                example1.put("tool", JsonString("kubectl-get"))
                let exampleData = JsonObject()
                exampleData.put("resource", JsonString("pods"))
                exampleData.put("namespace", JsonString("default"))
                example1.put("example", exampleData)
                examplesArray.add(example1)
                result1.put("usage_examples", examplesArray)
            }

            resultsArray.add(result1)
            responseObj.put("results", resultsArray)

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/search: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle GET /mcp/stream request
     */
    private func handleMCPStream(context: HttpContext): Unit {
        try {
            // In a real implementation, this would start the MCP server with HTTP streaming
            // For now, we'll return a placeholder response

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "text/html")

            let htmlContent = """
<!DOCTYPE html>
<html>
<head>
    <title>MCP Server Stream</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>MCP Server with HTTP Streaming</h1>
    <p>This is a placeholder for the MCP server streaming interface.</p>
    <p>In a real implementation, this would provide an embedded web UI for MCP server management and skill execution.</p>
</body>
</html>
"""

            createSuccessResponse(context, htmlContent, responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling GET /mcp/stream: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Handle GET /hello request for health check
     */
    private func handleHello(context: HttpContext): Unit {
        try {
            let responseObj = JsonObject()
            responseObj.put("message", JsonString("Hello World"))

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling GET /hello: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error")
        }
    }

    /**
     * Helper function to get integer query parameter with default value
     */
    private func getIntQueryParam(request: HttpRequest, paramName: String, defaultValue: Int32): Int32 {
        let queryParams = request.url.queryForm
        match (queryParams.get(paramName)) {
            case Some(value) => this.parseInt32(value.toString(), defaultValue)
            case None => defaultValue
        }
    }

    /**
     * Helper function to create success response
     */
    private func createSuccessResponse(context: HttpContext, body: String, headers: HashMap<String, String>): Unit {
        let responseBuilder = HttpResponseBuilder()
        responseBuilder.status(200)
        for ((key, value) in headers) {
            responseBuilder.header(key, value)
        }
        responseBuilder.body(body)
        let response = responseBuilder.build()
        
        // Copy response to context
        context.responseBuilder.status(200)
        for ((key, value) in headers) {
            context.responseBuilder.header(key, value)
        }
        context.responseBuilder.body(body)
    }

    /**
     * Helper function to create error response
     */
    private func createErrorResponse(context: HttpContext, statusCode: Int32, errorCode: String, errorMessage: String): Unit {
        let responseBuilder = HttpResponseBuilder()
        responseBuilder.status(UInt16(statusCode))
        responseBuilder.header("Content-Type", "application/json")

        let errorObj = JsonObject()
        errorObj.put("error_code", JsonString(errorCode))
        errorObj.put("error_message", JsonString(errorMessage))

        responseBuilder.body(errorObj.toString())
        let response = responseBuilder.build()
        
        // Copy response to context
        context.responseBuilder.status(UInt16(statusCode))
        context.responseBuilder.header("Content-Type", "application/json")
        context.responseBuilder.body(errorObj.toString())
    }

    /**
     * Helper function to parse Int32 with default value
     */
    private func parseInt32(str: String, defaultValue: Int32): Int32 {
        try {
            return Int32.parse(str)
        } catch (ex: Exception) {
            return defaultValue
        }
    }

    /**
     * Helper function for min operation
     */
    private func min(a: Int32, b: Int32): Int32 {
        return if (a < b) { a } else { b }
    }
}

/**
 * Custom HTTP request distributor that registers and distributes requests to handlers
 */
private class DefaultHttpRequestDistributor <: HttpRequestDistributor {
    private let _routes: HashMap<String, HttpRequestHandler>

    public init() {
        _routes = HashMap<String, HttpRequestHandler>()
    }

    public func register(path: String, handler: HttpRequestHandler): Unit {
        _routes.add(path, handler)
    }

    public func distribute(path: String): HttpRequestHandler {
        // Look for the handler based on the path
        let handlerOption = _routes.get(path)
        if (handlerOption.isSome()) {
            return handlerOption.getOrThrow()
        }

        // Return a default handler for 404
        return createNotFoundHandler()
    }

    /**
     * Helper function to create a not found handler
     */
    private func createNotFoundHandler(): HttpRequestHandler {
        return FuncHandler({ context =>
            let responseBuilder = HttpResponseBuilder()
            responseBuilder.status(404)
            responseBuilder.header("Content-Type", "application/json")
            let responseObj = JsonObject()
            responseObj.put("error", JsonString("Not Found"))
            responseObj.put("path", JsonString(context.request.url.path))
            responseBuilder.body(responseObj.toString())
            
            // Copy response to context
            context.responseBuilder.status(404)
            context.responseBuilder.header("Content-Type", "application/json")
            context.responseBuilder.body(responseObj.toString())
        })
    }
}