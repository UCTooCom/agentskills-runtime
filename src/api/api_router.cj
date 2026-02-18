/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.api

import std.collection.{HashMap, ArrayList}
import std.convert.*
import std.time.DateTime
import std.env.{getWorkingDirectory, getVariable}
import stdx.net.http.{Server, ServerBuilder, HttpContext, HttpRequest, HttpResponse, HttpResponseBuilder, FuncHandler, HttpRequestDistributor, HttpRequestHandler}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray, JsonFloat}
import magic.skill.application.SkillManagementService
import magic.skill.application.ProgressiveSkillLoader
import magic.skill.application.{DependencyResolver, GitManager, SkillPackageManager, GitException}
import magic.core.skill.{Skill, SkillManager}
import magic.skill.CompositeSkillToolManager
import magic.skill.domain.models.{SecurityPolicy, ResourceLimits}
import magic.skill.search.{PublicSkillSearchService, SkillSearchResponse}
import magic.log.LogUtils
import magic.config.Config

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
    private let _searchService: PublicSkillSearchService
    private let _gitManager: GitManager

    public init(port: Int32) {
        _port = port
        _distributor = Some(DefaultHttpRequestDistributor())
        _skillManagementService = SkillManagementService()
        
        // Initialize search service and Git manager
        _searchService = PublicSkillSearchService()
        _gitManager = GitManager()
        
        // Initialize ProgressiveSkillLoader with skills directories
        // Uses SKILL_INSTALL_PATH environment variable if set, otherwise defaults to ./skills
        let currentDir = getWorkingDirectory().toString()
        let skillInstallPath = if (let Some(configuredPath) <- getVariable("SKILL_INSTALL_PATH")) {
            if (!configuredPath.isEmpty()) {
                LogUtils.info("Using SKILL_INSTALL_PATH from environment: ${configuredPath}")
                configuredPath
            } else {
                "${currentDir}/skills"
            }
        } else {
            "${currentDir}/skills"
        }
        
        let skillDirs = [
            skillInstallPath,           // For installed skills (from SKILL_INSTALL_PATH)
            "${currentDir}/src/examples"  // For example skills (built-in)
        ]
        _progressiveSkillLoader = ProgressiveSkillLoader(
            skillBaseDirectories: skillDirs,
            defaultSecurityPolicy: SecurityPolicy.default(),
            defaultResourceLimits: ResourceLimits.default()
        )
        
        _skillManager = CompositeSkillToolManager()

        // Load skills from the configured directories into the skill manager
        try {
            let loadedSkills = _progressiveSkillLoader.loadSkillsToManager(_skillManager)
            LogUtils.info("✅ Successfully loaded ${loadedSkills.size} skills from directories")
            
            // Log all loaded skill IDs for debugging
            for (skill in loadedSkills) {
                LogUtils.info("Loaded skill ID: ${skill.name}")
            }
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
            
            // Find the index of "skills" and get the next part as the skill ID
            var skillId = ""
            var skillsIndex = -1
            
            for (i in 0..pathParts.size) {
                if (pathParts[i] == "skills") {
                    skillsIndex = i
                    break
                }
            }
            
            if (skillsIndex >= 0 && skillsIndex + 1 < pathParts.size) {
                skillId = pathParts[skillsIndex + 1]
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
                
                // Use actual skill properties if available, otherwise use placeholders
                let version = if (skill.metadata.get("version").isSome()) {
                    skill.metadata.get("version").getOrThrow()
                } else {
                    "1.0.0"  // Placeholder
                }
                responseObj.put("version", JsonString(version))

                let author = if (skill.metadata.get("author").isSome()) {
                    skill.metadata.get("author").getOrThrow()
                } else {
                    "Unknown"  // Placeholder
                }
                responseObj.put("author", JsonString(author))

                responseObj.put("license", JsonString(skill.license.getOrDefault({=>"MIT"})))

                let format = if (skill.metadata.get("format").isSome()) {
                    skill.metadata.get("format").getOrThrow()
                } else {
                    "skill_md"  // Placeholder
                }
                responseObj.put("format", JsonString(format))

                let createdAt = if (skill.metadata.get("created_at").isSome()) {
                    skill.metadata.get("created_at").getOrThrow()
                } else {
                    "2026-01-25T10:00:00Z"  // Placeholder
                }
                responseObj.put("created_at", JsonString(createdAt))

                let updatedAt = if (skill.metadata.get("updated_at").isSome()) {
                    skill.metadata.get("updated_at").getOrThrow()
                } else {
                    "2026-01-25T10:00:00Z"  // Placeholder
                }
                responseObj.put("updated_at", JsonString(updatedAt))

                responseObj.put("source_path", JsonString(skill.skillPath))
                responseObj.put("metadata", JsonObject())  // Placeholder - in a real implementation, this would be the actual metadata

                // Dependencies - in a real implementation, this would come from the skill manifest
                let dependenciesArray = JsonArray()
                responseObj.put("dependencies", dependenciesArray)

                // Tools - in a real implementation, this would come from the skill manifest
                let toolsArray = JsonArray()
                responseObj.put("tools", toolsArray)

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
     * Install a skill from a local path or Git repository URL
     */
    private func handleAddSkill(context: HttpContext): Unit {
        LogUtils.info("[handleAddSkill] === Starting handleAddSkill ===")
        try {
            let request = context.request
            LogUtils.info("[handleAddSkill] Got request object")
            
            // Parse request body
            let bodySizeOpt = request.bodySize
            LogUtils.info("[handleAddSkill] bodySize option: ${bodySizeOpt}")
            
            if (bodySizeOpt.isNone()) {
                LogUtils.error("[handleAddSkill] bodySize is None")
                createErrorResponse(context, 400, "invalid_request", "Request body size is missing")
                return
            }
            
            let bodySize = bodySizeOpt.getOrThrow()
            LogUtils.info("[handleAddSkill] bodySize: ${bodySize}")
            
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            LogUtils.info("[handleAddSkill] Request body: ${body}")
            
            let jsonObj = JsonValue.fromStr(body).asObject()

            if (!jsonObj.containsKey("source")) {
                createErrorResponse(context, 400, "missing_field", "Source field is required")
                return
            }

            let sourceStr = jsonObj["source"].asString().getValue()
            LogUtils.info("[handleAddSkill] Source: ${sourceStr}")
            
            let validate = if (jsonObj.containsKey("validate")) {
                jsonObj["validate"].asBool().getValue()
            } else {
                true
            }
            
            let creator = if (jsonObj.containsKey("creator")) {
                jsonObj["creator"].asString().getValue()
            } else {
                "unknown"
            }
            
            // Get optional install_path from request (Priority 1)
            let requestInstallPath: Option<String> = if (jsonObj.containsKey("install_path")) {
                Some(jsonObj["install_path"].asString().getValue())
            } else {
                None
            }
            
            // Get optional Git reference parameters
            let branch: Option<String> = if (jsonObj.containsKey("branch")) {
                Some(jsonObj["branch"].asString().getValue())
            } else {
                None
            }
            let tag: Option<String> = if (jsonObj.containsKey("tag")) {
                Some(jsonObj["tag"].asString().getValue())
            } else {
                None
            }
            let commit: Option<String> = if (jsonObj.containsKey("commit")) {
                Some(jsonObj["commit"].asString().getValue())
            } else {
                None
            }

            // Determine if source is a local path or Git URL
            let isGitSource = sourceStr.startsWith("http://") || sourceStr.startsWith("https://")
            LogUtils.info("[handleAddSkill] isGitSource: ${isGitSource}")
            
            // Check Git availability for Git sources
            if (isGitSource) {
                if (!_gitManager.isGitAvailable()) {
                    createErrorResponse(context, 50001, "git_not_available", "Git is not installed or not available in PATH. Please install Git to install skills from Git repositories.")
                    return
                }
            }

            // Create a skill package manager to handle the installation
            LogUtils.info("[handleAddSkill] Creating dependency resolver...")
            let dependencyResolver = DependencyResolver()
            LogUtils.info("[handleAddSkill] Getting skill registry...")
            let skillRegistry = _skillManagementService.getSkillRegistry()
            LogUtils.info("[handleAddSkill] Skill registry obtained")
            
            // Use the unified path determination logic from SkillPackageManager
            // Priority 1: install_path from request parameter
            // Priority 2: SKILL_INSTALL_PATH from .env file
            // Priority 3: Default to current_dir/skills
            LogUtils.info("[handleAddSkill] Determining installation path...")
            let skillInstallPath = SkillPackageManager.determineInstallationPath(
                requestInstallPath.getOrDefault({=>""})
            )
            LogUtils.info("[handleAddSkill] Installation path: ${skillInstallPath}")
            
            LogUtils.info("[handleAddSkill] Creating SkillPackageManager...")
            let skillPackageManager = SkillPackageManager(
                installationPath: skillInstallPath,
                dependencyResolver: dependencyResolver,
                skillRegistry: skillRegistry,
                gitManager: _gitManager
            )
            LogUtils.info("[handleAddSkill] SkillPackageManager created")

            // Determine if source is a local path or Git URL
            LogUtils.info("[handleAddSkill] Starting installation, isGitSource=${isGitSource}")
            let result = if (isGitSource) {
                // Git URL - install from Git with optional reference
                LogUtils.info("[handleAddSkill] Calling installFromGit...")
                skillPackageManager.installFromGit(sourceStr, branch, tag, commit)
            } else {
                // Local path - install from path
                skillPackageManager.installFromPath(sourceStr, validate)
            }

            if (result.success) {
                // Reload skills to include the newly added skill
                _progressiveSkillLoader.reloadSkills(_skillManager)

                let skillName = _extractSkillNameFromPath(sourceStr)
                let responseObj = JsonObject()
                responseObj.put("id", JsonString(skillName))
                responseObj.put("name", JsonString(skillName))
                responseObj.put("status", JsonString("installed"))
                
                if (isGitSource) {
                    responseObj.put("message", JsonString("Skill installed successfully from Git repository"))
                    responseObj.put("source_type", JsonString("git"))
                    responseObj.put("source_url", JsonString(sourceStr))
                } else {
                    responseObj.put("message", JsonString("Skill installed successfully from local path"))
                    responseObj.put("source_type", JsonString("local"))
                }
                
                responseObj.put("created_at", JsonString(DateTime.now().toString()))

                let responseHeaders = HashMap<String, String>()
                responseHeaders.add("Content-Type", "application/json")
                createSuccessResponse(context, responseObj.toString(), responseHeaders)
            } else {
                // Handle installation failure with specific error codes
                let errorMsg = result.error.getOrDefault({=>"Installation failed"})
                
                // Determine error code based on error message
                let errorCode = if (errorMsg.contains("SKILL.md not found")) {
                    "skill_md_not_found"
                } else if (errorMsg.contains("Invalid SKILL.md")) {
                    "invalid_skill_md"
                } else if (errorMsg.contains("clone")) {
                    "clone_failed"
                } else {
                    "installation_failed"
                }
                
                createErrorResponse(context, 500, errorCode, errorMsg)
            }
        } catch (ex: GitException) {
            LogUtils.error("Git error handling POST /skills/add: ${ex.message}")
            createErrorResponse(context, 50002, "git_error", "Git operation failed: ${ex.message}")
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/add: ${ex.message}")
            LogUtils.error("Exception type: ${ex}")
            createErrorResponse(context, 500, "internal_error", "Internal server error: ${ex.message}")
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

            let id = jsonObj["id"].asString().getValue()
            
            // Collect all fields to update (excluding 'id')
            let updates = HashMap<String, String>()
            if (jsonObj.containsKey("description")) {
                updates.add("description", jsonObj["description"].asString().getValue())
            }
            if (jsonObj.containsKey("creator")) {
                updates.add("creator", jsonObj["creator"].asString().getValue())
            }
            if (jsonObj.containsKey("name")) {
                updates.add("name", jsonObj["name"].asString().getValue())
            }
            if (jsonObj.containsKey("version")) {
                updates.add("version", jsonObj["version"].asString().getValue())
            }

            // Create a skill package manager to handle the edit
            let dependencyResolver = DependencyResolver()
            let skillRegistry = _skillManagementService.getSkillRegistry()
            let gitManager = GitManager()
            
            // Get optional install_path from request (Priority 1)
            let requestInstallPath: Option<String> = if (jsonObj.containsKey("install_path")) {
                Some(jsonObj["install_path"].asString().getValue())
            } else {
                None
            }

            // Use the unified path determination logic from SkillPackageManager
            let skillInstallPath = SkillPackageManager.determineInstallationPath(
                requestInstallPath.getOrDefault({=>""})
            )
            
            let skillPackageManager = SkillPackageManager(
                installationPath: skillInstallPath,
                dependencyResolver: dependencyResolver,
                skillRegistry: skillRegistry,
                gitManager: gitManager
            )

            // Edit the skill
            let success = skillPackageManager.editSkill(id, updates)

            if (success) {
                // Reload skills to reflect the changes
                _progressiveSkillLoader.reloadSkills(_skillManager)

                let responseObj = JsonObject()
                responseObj.put("id", JsonString(id))
                responseObj.put("status", JsonString("updated"))
                responseObj.put("message", JsonString("Skill updated successfully"))
                responseObj.put("updated_at", JsonString(DateTime.now().toString()))

                let responseHeaders = HashMap<String, String>()
                responseHeaders.add("Content-Type", "application/json")
                createSuccessResponse(context, responseObj.toString(), responseHeaders)
            } else {
                createErrorResponse(context, 500, "edit_failed", "Failed to edit skill: ${id}")
            }
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

            let id = jsonObj["id"].asString().getValue()

            // Create a skill package manager to handle the uninstallation
            let dependencyResolver = DependencyResolver()
            let skillRegistry = _skillManagementService.getSkillRegistry()
            let gitManager = GitManager()
            
            // Get optional install_path from request (Priority 1)
            let requestInstallPath: Option<String> = if (jsonObj.containsKey("install_path")) {
                Some(jsonObj["install_path"].asString().getValue())
            } else {
                None
            }

            // Use the unified path determination logic from SkillPackageManager
            let skillInstallPath = SkillPackageManager.determineInstallationPath(
                requestInstallPath.getOrDefault({=>""})
            )
            
            let skillPackageManager = SkillPackageManager(
                installationPath: skillInstallPath,
                dependencyResolver: dependencyResolver,
                skillRegistry: skillRegistry,
                gitManager: gitManager
            )

            // Uninstall the skill
            let success = skillPackageManager.uninstallSkill(id)

            if (success) {
                // Reload skills to exclude the deleted skill
                _progressiveSkillLoader.reloadSkills(_skillManager)

                let responseObj = JsonObject()
                responseObj.put("desc", JsonString("删除成功"))

                let responseHeaders = HashMap<String, String>()
                responseHeaders.add("Content-Type", "application/json")
                createSuccessResponse(context, responseObj.toString(), responseHeaders)
            } else {
                // Handle uninstallation failure
                createErrorResponse(context, 500, "uninstall_failed", "Failed to uninstall skill: ${id}")
            }
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
            let bodySize = request.bodySize.getOrThrow()
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            let jsonObj = JsonValue.fromStr(body).asObject()

            if (!jsonObj.containsKey("skill_id")) {
                createErrorResponse(context, 400, "missing_field", "skill_id field is required")
                return
            }

            let skillId = jsonObj["skill_id"].asString().getValue()
            
            let skillOpt = _skillManager.getSkill(skillId)
            if (skillOpt.isNone()) {
                createErrorResponse(context, 404, "not_found", "Skill not found: ${skillId}")
                return
            }
            
            let skill = skillOpt.getOrThrow()
            
            let args = HashMap<String, JsonValue>()
            if (jsonObj.containsKey("parameters")) {
                let paramsObj = jsonObj["parameters"].asObject()
                for ((key, value) in paramsObj.getFields()) {
                    args.add(key, value)
                }
            }
            
            let timeoutStr = if (jsonObj.containsKey("timeout")) {
                jsonObj["timeout"].asString().getValue()
            } else {
                "30s"
            }
            
            let timeoutMs = _parseTimeout(timeoutStr)
            
            let startTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            
            let output = skill.execute(args)
            
            let endTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
            let executionTime = endTime - startTime

            let responseObj = JsonObject()
            responseObj.put("id", JsonString("exec-${skillId}-${endTime}"))
            responseObj.put("success", JsonString("true"))
            responseObj.put("output", JsonString(output))
            responseObj.put("error", JsonString(""))
            responseObj.put("execution_time", JsonString("${executionTime}ms"))

            let resourcesUsedObj = JsonObject()
            resourcesUsedObj.put("cpu_time", JsonString("${executionTime}ms"))
            resourcesUsedObj.put("memory_peak", JsonInt(0))
            resourcesUsedObj.put("network_bytes_in", JsonInt(0))
            resourcesUsedObj.put("network_bytes_out", JsonInt(0))
            resourcesUsedObj.put("file_operations", JsonInt(0))
            responseObj.put("resources_used", resourcesUsedObj)

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, responseObj.toString(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/execute: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error: ${ex.message}")
        }
    }

    /**
     * Parse timeout string to milliseconds
     */
    private func _parseTimeout(timeoutStr: String): Int64 {
        try {
            if (timeoutStr.endsWith("ms")) {
                return Int64.parse(timeoutStr[0..timeoutStr.size - 2])
            } else if (timeoutStr.endsWith("s")) {
                let seconds = Int64.parse(timeoutStr[0..timeoutStr.size - 1])
                return seconds * 1000
            } else {
                return Int64.parse(timeoutStr)
            }
        } catch (ex: Exception) {
            return 30000
        }
    }

    /**
     * Handle POST /skills/search request
     * Search for skills from public open-source repositories (GitHub, AtomGit, Gitee)
     */
    private func handleSearchSkills(context: HttpContext): Unit {
        try {
            LogUtils.info("[APIRouter] handleSearchSkills called")
            let request = context.request
            
            // Parse request body
            let bodySizeOpt = request.bodySize
            if (bodySizeOpt.isNone()) {
                LogUtils.error("[APIRouter] bodySize is None")
                createErrorResponse(context, 400, "invalid_request", "No body size")
                return
            }
            
            let bodySize = bodySizeOpt.getOrThrow()
            LogUtils.info("[APIRouter] Body size: ${bodySize.toString()}")
            
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            request.body.read(buffer)
            let body = String.fromUtf8(buffer)
            LogUtils.info("[APIRouter] Request body: ${body}")
            
            let jsonObj = JsonValue.fromStr(body).asObject()
            LogUtils.info("[APIRouter] Parsed JSON object")

            // Validate required field
            if (!jsonObj.containsKey("query")) {
                createErrorResponse(context, 400, "missing_field", "query field is required")
                return
            }

            let query = jsonObj["query"].asString().getValue()
            
            // Parse optional parameters with defaults
            let source = if (jsonObj.containsKey("source")) {
                jsonObj["source"].asString().getValue()
            } else {
                "all"
            }
            
            let limit = if (jsonObj.containsKey("limit")) {
                let limitValue = Int32(jsonObj["limit"].asInt().getValue())
                if (limitValue > 50) { Int32(50) } else { limitValue }
            } else {
                Int32(10)
            }
            
            let sort = if (jsonObj.containsKey("sort")) {
                jsonObj["sort"].asString().getValue()
            } else {
                "stars"
            }

            LogUtils.info("[APIRouter] Searching for skills: query=${query}, source=${source}, limit=${limit}, sort=${sort}")

            // Use the public skill search service
            let searchResponse = _searchService.search(query, source, limit, sort)
            LogUtils.info("[APIRouter] Search completed, total_count: ${searchResponse.total_count.toString()}")

            let responseHeaders = HashMap<String, String>()
            responseHeaders.add("Content-Type", "application/json")
            createSuccessResponse(context, searchResponse.toJson(), responseHeaders)
        } catch (ex: Exception) {
            LogUtils.error("Error handling POST /skills/search: ${ex.message}")
            createErrorResponse(context, 500, "internal_error", "Internal server error: ${ex.message}")
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
    
    /**
     * Extract skill name from path
     */
    private func _extractSkillNameFromPath(path: String): String {
        // Extract skill name from the path (last part of the path)
        // Normalize path separators to forward slashes for consistent processing
        let normalizedPath = path.replace("\\", "/")
        let pathParts = normalizedPath.split("/")
        if (pathParts.size > 0) {
            return pathParts[pathParts.size - 1]
        } else {
            return "unknown-skill"
        }
    }
}

/**
 * Custom HTTP request distributor that registers and distributes requests to handlers
 */
private class DefaultHttpRequestDistributor <: HttpRequestDistributor {
    private let _routes: HashMap<String, HttpRequestHandler>
    private let _dynamicRoutes: ArrayList<(String, HttpRequestHandler)>  // Store dynamic routes like /skills/:id

    public init() {
        _routes = HashMap<String, HttpRequestHandler>()
        _dynamicRoutes = ArrayList<(String, HttpRequestHandler)>()
    }

    public func register(path: String, handler: HttpRequestHandler): Unit {
        if (path.contains(":")) {
            // This is a dynamic route (contains path parameters like :id)
            _dynamicRoutes.add((path, handler))
        } else {
            // This is a static route
            _routes.add(path, handler)
        }
    }

    public func distribute(path: String): HttpRequestHandler {
        // First, try to match static routes
        let handlerOption = _routes.get(path)
        if (handlerOption.isSome()) {
            return handlerOption.getOrThrow()
        }

        // If no static route matches, try dynamic routes
        for ((registeredPath, handler) in _dynamicRoutes) {
            if (this.matchesDynamicRoute(path, registeredPath)) {
                return handler
            }
        }

        // Return a default handler for 404
        return createNotFoundHandler()
    }

    /**
     * Check if the requested path matches a dynamic route pattern
     */
    private func matchesDynamicRoute(requestPath: String, routePattern: String): Bool {
        let requestParts = requestPath.split("/")
        let patternParts = routePattern.split("/")

        if (requestParts.size != patternParts.size) {
            return false
        }

        for (i in 0..requestParts.size) {
            let patternPart = patternParts[i]
            if (patternPart.startsWith(":")) {
                // This is a path parameter, it matches anything
                continue
            } else if (requestParts[i] != patternPart) {
                // Static parts must match exactly
                return false
            }
        }

        return true
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