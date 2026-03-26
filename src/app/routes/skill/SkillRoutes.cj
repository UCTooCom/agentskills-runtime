/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.skill

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.router.Router
import magic.core.skill.{Skill, SkillManager}
import magic.skill.application.SkillManagementService
import magic.skill.application.ProgressiveSkillLoader
import magic.skill.application.{DependencyResolver, GitManager, SkillPackageManager, GitException, AvailableSkillInfo}
import magic.skill.search.{PublicSkillSearchService, SkillSearchResponse}
import magic.log.LogUtils
import std.convert.*
import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import std.env.getVariable
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray, JsonBool}

/**
 * SkillRoutes - 技能管理API路由
 * 
 * 提供技能管理的HTTP接口，独立于agent_skills表的CRUD模块
 * 直接使用SkillManager，不通过AgentSkillsService
 * 
 * 路由设计:
 *   GET  /hello                    - 健康检查
 *   GET  /api/v1/uctoo/skills      - 获取技能列表
 *   GET  /api/v1/uctoo/skills/:id  - 获取技能详情
 *   POST /api/v1/uctoo/skills/add  - 安装技能
 *   POST /api/v1/uctoo/skills/edit - 更新技能
 *   POST /api/v1/uctoo/skills/del  - 卸载技能
 *   POST /api/v1/uctoo/skills/execute - 执行技能
 *   POST /api/v1/uctoo/skills/search - 搜索技能
 */
public class SkillRoutes {
    private let router: Router
    private let skillManager: SkillManager
    private let skillManagementService: SkillManagementService
    private let progressiveSkillLoader: ProgressiveSkillLoader
    private let searchService: PublicSkillSearchService
    private let gitManager: GitManager
    
    public init(
        router: Router,
        skillManager: SkillManager,
        skillManagementService: SkillManagementService,
        progressiveSkillLoader: ProgressiveSkillLoader
    ) {
        this.router = router
        this.skillManager = skillManager
        this.skillManagementService = skillManagementService
        this.progressiveSkillLoader = progressiveSkillLoader
        this.searchService = PublicSkillSearchService()
        this.gitManager = GitManager()
    }
    
    /**
     * 注册所有路由
     */
    public func register(): Unit {
        // GET /hello - 健康检查（保持原api模块的接口）
        router.get("/hello", { req, res =>
            handleHello(req, res)
        })
        
        // GET /api/v1/uctoo/skills - 获取技能列表
        router.get("/api/v1/uctoo/skills", { req, res =>
            handleGetSkills(req, res)
        })
        
        // GET /api/v1/uctoo/skills/:id - 获取技能详情
        router.get("/api/v1/uctoo/skills/:id", { req, res =>
            handleGetSkillById(req, res)
        })
        
        // POST /api/v1/uctoo/skills/add - 安装技能
        router.post("/api/v1/uctoo/skills/add", { req, res =>
            handleAddSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/edit - 更新技能
        router.post("/api/v1/uctoo/skills/edit", { req, res =>
            handleEditSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/del - 卸载技能
        router.post("/api/v1/uctoo/skills/del", { req, res =>
            handleDeleteSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/execute - 执行技能
        router.post("/api/v1/uctoo/skills/execute", { req, res =>
            handleExecuteSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/search - 搜索技能
        router.post("/api/v1/uctoo/skills/search", { req, res =>
            handleSearchSkills(req, res)
        })
        
        LogUtils.info("[SkillRoutes] All skill management routes registered")
    }
    
    /**
     * 处理健康检查
     */
    private func handleHello(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let responseObj = JsonObject()
            responseObj.put("message", JsonString("Hello World"))
            res.status(200).json(responseObj.toJsonString())
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling /hello: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 处理获取技能列表
     */
    private func handleGetSkills(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 解析分页参数
            let limit = getIntQueryParam(req, "limit", 10)
            let page = getIntQueryParam(req, "page", 0)
            
            // 验证参数
            if (limit > 100) {
                res.status(400).json("{\"error\":\"Limit cannot exceed 100\"}")
                return
            }
            
            // 获取技能列表
            let skills = skillManager.availableSkills.values().toArray()
            let totalSkills = skills.size
            let startIndex = page * limit
            let endIndex = min(startIndex + limit, Int32(totalSkills))
            
            // 应用分页
            let paginatedSkills = if (Int64(startIndex) < Int64(totalSkills)) {
                skills[Int64(startIndex)..Int64(endIndex)]
            } else {
                ArrayList<Skill>()
            }
            
            // 构建响应
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
                skillObj.put("version", JsonString("1.0.0"))
                skillObj.put("source_path", JsonString(skill.skillPath))
                skillsArray.add(skillObj)
            }
            responseObj.put("skills", skillsArray)
            
            res.status(200).json(responseObj.toJsonString())
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling GET /skills: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 处理获取技能详情
     */
    private func handleGetSkillById(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取技能ID
            let skillIdOption = req.pathParam("id")
            if (skillIdOption == None<String>) {
                res.status(400).json("{\"error\":\"Skill ID is required\"}")
                return
            }
            
            let skillId = skillIdOption.getOrThrow()
            
            // 获取技能
            if (let Some(skill) <- skillManager.getSkill(skillId)) {
                let responseObj = JsonObject()
                responseObj.put("id", JsonString(skill.name))
                responseObj.put("name", JsonString(skill.name))
                responseObj.put("description", JsonString(skill.description))
                responseObj.put("version", JsonString("1.0.0"))
                responseObj.put("source_path", JsonString(skill.skillPath))
                
                res.status(200).json(responseObj.toJsonString())
            } else {
                res.status(404).json("{\"error\":\"Skill not found\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling GET /skills/:id: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 处理安装技能
     */
    private func handleAddSkill(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 解析请求体
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"error\":\"Request body is empty\"}")
                return
            }
            
            let jsonObj = JsonValue.fromStr(body).asObject()
            
            if (!jsonObj.containsKey("source")) {
                res.status(400).json("{\"error\":\"Source field is required\"}")
                return
            }
            
            let sourceStr = jsonObj["source"].asString().getValue()
            let validate = if (jsonObj.containsKey("validate")) {
                jsonObj["validate"].asBool().getValue()
            } else {
                true
            }
            
            // 判断是否为Git源
            let isGitSource = sourceStr.startsWith("http://") || sourceStr.startsWith("https://")
            
            // 检查Git可用性
            if (isGitSource) {
                if (!gitManager.isGitAvailable()) {
                    res.status(500).json("{\"error\":\"Git is not installed or not available in PATH\"}")
                    return
                }
            }
            
            // 创建SkillPackageManager
            let dependencyResolver = DependencyResolver()
            let skillRegistry = skillManagementService.getSkillRegistry()
            let skillInstallPath = SkillPackageManager.determineInstallationPath("")
            
            let skillPackageManager = SkillPackageManager(
                installationPath: skillInstallPath,
                dependencyResolver: dependencyResolver,
                skillRegistry: skillRegistry,
                gitManager: gitManager
            )
            
            // 执行安装
            let result = if (isGitSource) {
                skillPackageManager.installFromGit(sourceStr, None<String>, None<String>, None<String>, None<String>)
            } else {
                skillPackageManager.installFromPath(sourceStr, validate)
            }
            
            // 处理结果
            if (result.success) {
                // 重新加载技能
                progressiveSkillLoader.reloadSkills(skillManager)
                
                let skillName = result.skillName.getOrDefault({=> _extractSkillNameFromPath(sourceStr) })
                let responseObj = JsonObject()
                responseObj.put("id", JsonString(skillName))
                responseObj.put("name", JsonString(skillName))
                responseObj.put("status", JsonString("installed"))
                responseObj.put("message", JsonString("Skill installed successfully"))
                
                res.status(200).json(responseObj.toJsonString())
            } else {
                let errorMsg = result.error.getOrDefault({=>"Installation failed"})
                res.status(500).json("{\"error\":\"${errorMsg}\"}")
            }
        } catch (ex: GitException) {
            LogUtils.error("[SkillRoutes] Git error: ${ex.message}")
            res.status(500).json("{\"error\":\"Git operation failed: ${ex.message}\"}")
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling POST /skills/add: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 处理更新技能
     */
    private func handleEditSkill(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"error\":\"Request body is empty\"}")
                return
            }
            
            let jsonObj = JsonValue.fromStr(body).asObject()
            
            if (!jsonObj.containsKey("id")) {
                res.status(400).json("{\"error\":\"ID field is required\"}")
                return
            }
            
            let id = jsonObj["id"].asString().getValue()
            
            // 收集更新字段
            let updates = HashMap<String, String>()
            if (jsonObj.containsKey("description")) {
                updates.add("description", jsonObj["description"].asString().getValue())
            }
            if (jsonObj.containsKey("name")) {
                updates.add("name", jsonObj["name"].asString().getValue())
            }
            
            // 创建SkillPackageManager
            let dependencyResolver = DependencyResolver()
            let skillRegistry = skillManagementService.getSkillRegistry()
            let skillInstallPath = SkillPackageManager.determineInstallationPath("")
            
            let skillPackageManager = SkillPackageManager(
                installationPath: skillInstallPath,
                dependencyResolver: dependencyResolver,
                skillRegistry: skillRegistry,
                gitManager: gitManager
            )
            
            // 执行更新
            let success = skillPackageManager.editSkill(id, updates)
            
            if (success) {
                // 重新加载技能
                progressiveSkillLoader.reloadSkills(skillManager)
                
                let responseObj = JsonObject()
                responseObj.put("id", JsonString(id))
                responseObj.put("status", JsonString("updated"))
                responseObj.put("message", JsonString("Skill updated successfully"))
                
                res.status(200).json(responseObj.toJsonString())
            } else {
                res.status(500).json("{\"error\":\"Failed to edit skill\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling POST /skills/edit: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 处理卸载技能
     */
    private func handleDeleteSkill(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"error\":\"Request body is empty\"}")
                return
            }
            
            let jsonObj = JsonValue.fromStr(body).asObject()
            
            if (!jsonObj.containsKey("id")) {
                res.status(400).json("{\"error\":\"ID field is required\"}")
                return
            }
            
            let id = jsonObj["id"].asString().getValue()
            
            // 创建SkillPackageManager
            let dependencyResolver = DependencyResolver()
            let skillRegistry = skillManagementService.getSkillRegistry()
            let skillInstallPath = SkillPackageManager.determineInstallationPath("")
            
            let skillPackageManager = SkillPackageManager(
                installationPath: skillInstallPath,
                dependencyResolver: dependencyResolver,
                skillRegistry: skillRegistry,
                gitManager: gitManager
            )
            
            // 执行卸载
            let success = skillPackageManager.uninstallSkill(id)
            
            if (success) {
                // 重新加载技能
                progressiveSkillLoader.reloadSkills(skillManager)
                
                let responseObj = JsonObject()
                responseObj.put("desc", JsonString("删除成功"))
                
                res.status(200).json(responseObj.toJsonString())
            } else {
                res.status(500).json("{\"error\":\"Failed to uninstall skill\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling POST /skills/del: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 处理执行技能
     */
    private func handleExecuteSkill(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"error\":\"Request body is empty\"}")
                return
            }
            
            let jsonObj = JsonValue.fromStr(body).asObject()
            
            if (!jsonObj.containsKey("skill_id")) {
                res.status(400).json("{\"error\":\"skill_id field is required\"}")
                return
            }
            
            let skillId = jsonObj["skill_id"].asString().getValue()
            
            // 获取技能
            if (let Some(skill) <- skillManager.getSkill(skillId)) {
                // 准备参数
                let args = HashMap<String, JsonValue>()
                if (jsonObj.containsKey("params")) {
                    let paramsObj = jsonObj["params"].asObject()
                    for ((key, value) in paramsObj.getFields()) {
                        args.add(key, value)
                    }
                }
                
                // 执行技能
                let startTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
                let output = skill.execute(args)
                let endTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
                let executionTime = endTime - startTime
                
                // 构建响应
                let responseObj = JsonObject()
                responseObj.put("id", JsonString("exec-${skillId}-${endTime}"))
                responseObj.put("success", JsonString("true"))
                responseObj.put("output", JsonString(output))
                responseObj.put("execution_time", JsonString("${executionTime}ms"))
                
                res.status(200).json(responseObj.toJsonString())
            } else {
                res.status(404).json("{\"error\":\"Skill not found\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling POST /skills/execute: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 处理搜索技能
     */
    private func handleSearchSkills(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"error\":\"Request body is empty\"}")
                return
            }
            
            let jsonObj = JsonValue.fromStr(body).asObject()
            
            if (!jsonObj.containsKey("query")) {
                res.status(400).json("{\"error\":\"query field is required\"}")
                return
            }
            
            let query = jsonObj["query"].asString().getValue()
            
            // 解析可选参数
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
            
            // 执行搜索
            let searchResponse = searchService.search(query, source, limit, sort)
            
            res.status(200).json(searchResponse.toJson())
        } catch (e: Exception) {
            LogUtils.error("[SkillRoutes] Error handling POST /skills/search: ${e.message}")
            res.status(500).json("{\"error\":\"Internal server error\"}")
        }
    }
    
    /**
     * 辅助函数：获取整数查询参数
     */
    private func getIntQueryParam(req: HttpRequest, paramName: String, defaultValue: Int32): Int32 {
        let paramOption = req.queryParam(paramName)
        if (let Some(value) <- paramOption) {
            try {
                return Int32.parse(value)
            } catch (e: Exception) {
                return defaultValue
            }
        }
        return defaultValue
    }
    
    /**
     * 辅助函数：提取技能名称
     */
    private func _extractSkillNameFromPath(path: String): String {
        let normalizedPath = path.replace("\\", "/")
        let pathParts = normalizedPath.split("/")
        if (pathParts.size > 0) {
            return pathParts[pathParts.size - 1]
        } else {
            return "unknown-skill"
        }
    }
    
    /**
     * 辅助函数：min操作
     */
    private func min(a: Int32, b: Int32): Int32 {
        return if (a < b) { a } else { b }
    }
}
