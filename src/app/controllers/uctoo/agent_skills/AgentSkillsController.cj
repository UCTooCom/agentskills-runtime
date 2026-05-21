/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.agent_skills

//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.AgentSkillsPO
import magic.app.services.uctoo.AgentSkillsService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils

public class AgentSkillsController {
    private var service: AgentSkillsService

    public init(service: AgentSkillsService) {
        this.service = service
    }

    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let userIdStr = userId.getOrThrow() as String
            if (let Some(str) <- userIdStr) {
                if (str.isEmpty()) {
                    res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                    return
                }

                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let entity = mapToEntity(b)
                    let result = service.createWithPermission(entity, str)
                    if (result.success) {
                        if (result.data.isSome()) {
                            let data = result.data.getOrThrow()
                            res.status(200).json(data.toJson())
                        } else {
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建失败\"}")
                        }
                    } else {
                        let reason = result.reason ?? "创建失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let ids = b.get("ids")
                let id = b.get("id")

                let deletedAt = b.get("deleted_at")
                let isRestore = if (let Some(da) <- deletedAt) {
                    let daStr = da as String
                    if (let Some(s) <- daStr) {
                        s == "0"
                    } else {
                        false
                    }
                } else {
                    false
                }

                if (let Some(idsVal) <- ids) {
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        let idArray = parseIdsArray(idsStr)

                        if (isRestore) {
                            let result = service.restoreMultiple(idArray)
                            if (result.success) {
                                res.status(200).json("{\"desc\":\"恢复成功\"}")
                            } else {
                                let reason = result.reason ?? "批量恢复失败"
                                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                            }
                        } else {
                            let entities = ArrayList<AgentSkillsPO>()
                            for (idStr in idArray) {
                                let entity = mapToEntity(b)
                                entity.id = idStr
                                entities.add(entity)
                            }

                            let result = service.updateMultiple(entities)
                            if (result.success) {
                                if (let Some(data) <- result.data) {
                                    let sb = StringBuilder()
                                    sb.append("[")
                                    let size = data.size
                                    for (i in 0..size) {
                                        sb.append(data[i].toJson())
                                        if (i < size - 1) {
                                            sb.append(",")
                                        }
                                    }
                                    sb.append("]")
                                    res.status(200).json(sb.toString())
                                } else {
                                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"批量更新失败\"}")
                                }
                            } else {
                                let reason = result.reason ?? "批量更新失败"
                                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                            }
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"IDs参数格式错误\"}")
                    }
                } else {
                    if (let Some(idVal) <- id) {
                        let idStrOpt = idVal as String
                        if (let Some(idStr) <- idStrOpt) {
                            if (isRestore) {
                                let result = service.restore(idStr)
                                if (result.success) {
                                    if (let Some(data) <- result.data) {
                                        res.status(200).json(data.toJson())
                                    } else {
                                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"恢复失败\"}")
                                    }
                                } else {
                                    let reason = result.reason ?? "恢复失败"
                                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                                }
                            } else {
                                let entity = mapToEntity(b)
                                let editUserId = req.getLocals("userId")
                                var editUserIdStr = ""
                                if (let Some(u) <- editUserId) {
                                    let sOpt = u as String
                                    if (let Some(s) <- sOpt) { editUserIdStr = s }
                                }
                                let result = if (editUserIdStr.isEmpty()) {
                                    service.update(idStr, entity)
                                } else {
                                    service.updateWithPermission(idStr, entity, editUserIdStr)
                                }
                                if (result.success) {
                                    if (let Some(data) <- result.data) {
                                        res.status(200).json(data.toJson())
                                    } else {
                                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"更新失败\"}")
                                    }
                                } else {
                                    let reason = result.reason ?? "更新失败"
                                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                                }
                            }
                        } else {
                            res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"ID参数格式错误\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
                    }
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let id = b.get("id")
                let ids = b.get("ids")
                let forceOpt = b.get("force")
                let force = parseForce(forceOpt)

                if (let Some(idsVal) <- ids) {
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        let idArray = parseIdsArray(idsStr)
                        let result = service.deleteMultiple(idArray, force)
                        if (result.success) {
                            res.status(200).json("{\"desc\":\"删除成功\"}")
                        } else {
                            let reason = result.reason ?? "批量删除失败"
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"IDs参数格式错误\"}")
                    }
                } else if (let Some(idVal) <- id) {
                    let idStrOpt = idVal as String
                    if (let Some(idStr) <- idStrOpt) {
                        let delUserId = req.getLocals("userId")
                        var delUserIdStr = ""
                        if (let Some(u) <- delUserId) {
                            let sOpt = u as String
                            if (let Some(s) <- sOpt) { delUserIdStr = s }
                        }
                        let result = if (delUserIdStr.isEmpty()) {
                            service.delete(idStr, force)
                        } else {
                            service.deleteWithPermission(idStr, force, delUserIdStr)
                        }
                        if (result.success) {
                            res.status(200).json("{\"desc\":\"删除成功\"}")
                        } else {
                            let reason = result.reason ?? "删除失败"
                            res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"ID参数格式错误\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")

            if (let Some(idVal) <- id) {
                let userId = req.getLocals("userId")
                var userIdStr = ""
                if (let Some(u) <- userId) {
                    let sOpt = u as String
                    if (let Some(s) <- sOpt) { userIdStr = s }
                }
                let result = if (userIdStr.isEmpty()) {
                    service.getById(idVal)
                } else {
                    service.getByIdWithPermission(idVal, userIdStr)
                }

                if (result.success) {
                    if (let Some(data) <- result.data) {
                        res.status(200).json(data.toJson())
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该agent_skills\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该agent_skills\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let currentPageParam = req.queryParam("currentPage")
            let pageSizeParam = req.queryParam("pageSize")

            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")

            let pageSize = if (let Some(ps) <- pageSizeParam) {
                Int32.parse(ps)
            } else if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }

            let currentPage = if (let Some(cp) <- currentPageParam) {
                Int32.parse(cp)
            } else if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }

            if (pageSize > 1000) {
                res.status(400).json(APIError("40004", "请求数量不能超过1000条").toJson())
                return
            }

            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")

            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            var filterStr = ""
            if (let Some(f) <- filterParam) {
                let decodedFilter = f.replace("%7B", "{")
                    .replace("%7D", "}")
                    .replace("%22", "\"")
                    .replace("%3A", ":")
                    .replace("%2C", ",")
                    .replace("+", " ")
                filterStr = decodedFilter
            }

            let userId = req.getLocals("userId")
            var userIdStr = ""
            if (let Some(u) <- userId) {
                let sOpt = u as String
                if (let Some(s) <- sOpt) { userIdStr = s }
            }

            let (entities, total) = if (userIdStr.isEmpty()) {
                service.getListWithFilter(
                    currentPage,
                    pageSize,
                    sortStr,
                    filterStr
                )
            } else {
                service.getListWithPermission(
                    currentPage,
                    pageSize,
                    sortStr,
                    filterStr,
                    userIdStr
                )
            }

            let totalPage = if (pageSize > 0) {
                Int32((total + Int64(pageSize) - 1) / Int64(pageSize))
            } else {
                Int32(0)
            }

            var entitiesJson = ""
            for (e in entities) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"agent_skillss\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func getManyWithSkip(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")
            let skipParam = req.pathParam("skip")

            let limitNum = if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }

            let pageNum = if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }

            let skipNum = if (let Some(s) <- skipParam) {
                Int32.parse(s)
            } else {
                Int32(0)
            }

            if (limitNum > 1000) {
                res.status(400).json(APIError("40004", "请求数量不能超过1000条").toJson())
                return
            }

            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")

            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            let filterStr = if (let Some(f) <- filterParam) { f } else { "" }

            let userId = req.getLocals("userId")
            var userIdStr = ""
            if (let Some(u) <- userId) {
                let sOpt = u as String
                if (let Some(s) <- sOpt) { userIdStr = s }
            }

            let (entities, total) = if (userIdStr.isEmpty()) {
                service.getListWithSkip(pageNum - 1, limitNum, skipNum, sortStr, filterStr)
            } else {
                service.getListWithSkipWithPermission(pageNum - 1, limitNum, skipNum, sortStr, filterStr, userIdStr)
            }

            let totalPage = if (limitNum > 0) {
                Int32((total + Int64(limitNum) - 1) / Int64(limitNum))
            } else {
                Int32(0)
            }

            var entitiesJson = ""
            for (e in entities) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"agent_skillss\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinAgentSkills(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinAgentSkills()
            if (result.success) {
                res.status(200).json("{\"desc\":\"清空回收站成功\"}")
            } else {
                let reason = result.reason ?? "清空回收站失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func parseBody(req: HttpRequest): ?Map<String, Any> {
        try {
            let body = req.body

            if (body.isEmpty()) {
                return None<Map<String, Any>>
            }

            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                return None<Map<String, Any>>
            }

            let jsonObj = jsonValue.asObject()
            let map = HashMap<String, Any>()

            for ((key, value) in jsonObj.getFields()) {
                let anyValue = jsonValueToAny(value)
                map.add(key, anyValue)
            }

            return Some<Map<String, Any>>(map)
        } catch (e: Exception) {
            return None<Map<String, Any>>
        }
    }

    private func jsonValueToAny(value: JsonValue): Any {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue()
        } else if (value is JsonFloat) {
            return value.asFloat().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else {
            return ""
        }
    }

    private func mapToEntity(map: Map<String, Any>): AgentSkillsPO {
        let entity = AgentSkillsPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(name) <- map.get("name")) {
            let nameStr = name as String
            if (let Some(s) <- nameStr) {
                entity.name = s
            }
        }
        if (let Some(description) <- map.get("description")) {
            let descriptionStr = description as String
            if (let Some(s) <- descriptionStr) {
                entity.description = Some<String>(s)
            }
        }
        if (let Some(source) <- map.get("source")) {
            let sourceStr = source as String
            if (let Some(s) <- sourceStr) {
                entity.source = Some<String>(s)
            }
        }
        if (let Some(sourceUrl) <- map.get("source_url")) {
            let sourceUrlStr = sourceUrl as String
            if (let Some(s) <- sourceUrlStr) {
                entity.sourceUrl = Some<String>(s)
            }
        }
        if (let Some(sourceType) <- map.get("source_type")) {
            let sourceTypeStr = sourceType as String
            if (let Some(s) <- sourceTypeStr) {
                entity.sourceType = Some<String>(s)
            }
        }
        if (let Some(branch) <- map.get("branch")) {
            let branchStr = branch as String
            if (let Some(s) <- branchStr) {
                entity.branch = Some<String>(s)
            }
        }
        if (let Some(tag) <- map.get("tag")) {
            let tagStr = tag as String
            if (let Some(s) <- tagStr) {
                entity.tag = Some<String>(s)
            }
        }
        if (let Some(commit) <- map.get("commit")) {
            let commitStr = commit as String
            if (let Some(s) <- commitStr) {
                entity.commit = Some<String>(s)
            }
        }
        if (let Some(version) <- map.get("version")) {
            let versionStr = version as String
            if (let Some(s) <- versionStr) {
                entity.version = Some<String>(s)
            }
        }
        if (let Some(author) <- map.get("author")) {
            let authorStr = author as String
            if (let Some(s) <- authorStr) {
                entity.author = Some<String>(s)
            }
        }
        if (let Some(homepage) <- map.get("homepage")) {
            let homepageStr = homepage as String
            if (let Some(s) <- homepageStr) {
                entity.homepage = Some<String>(s)
            }
        }
        if (let Some(license) <- map.get("license")) {
            let licenseStr = license as String
            if (let Some(s) <- licenseStr) {
                entity.license = Some<String>(s)
            }
        }
        if (let Some(keywords) <- map.get("keywords")) {
            let keywordsStr = keywords as String
            if (let Some(s) <- keywordsStr) {
                entity.keywords = Some<String>(s)
            }
        }
        if (let Some(installPath) <- map.get("install_path")) {
            let installPathStr = installPath as String
            if (let Some(s) <- installPathStr) {
                entity.installPath = Some<String>(s)
            }
        }
        if (let Some(status) <- map.get("status")) {
            let statusInt = status as Int64
            if (let Some(v) <- statusInt) {
                entity.status = Int32(v)
            }
        }
        if (let Some(runtimeStatus) <- map.get("runtime_status")) {
            let runtimeStatusStr = runtimeStatus as String
            if (let Some(s) <- runtimeStatusStr) {
                entity.runtimeStatus = Some<String>(s)
            }
        }
        if (let Some(lastRunAt) <- map.get("last_run_at")) {
            // DateTime类型, 由数据库处理
        }
        if (let Some(runCount) <- map.get("run_count")) {
            let runCountInt = runCount as Int64
            if (let Some(v) <- runCountInt) {
                entity.runCount = Int32(v)
            }
        }
        if (let Some(config) <- map.get("config")) {
            let configStr = config as String
            if (let Some(s) <- configStr) {
                entity.config = Some<String>(s)
            }
        }
        if (let Some(creator) <- map.get("creator")) {
            let creatorStr = creator as String
            if (let Some(s) <- creatorStr) {
                entity.creator = Some<String>(s)
            }
        }
        if (let Some(createdAt) <- map.get("created_at")) {
        }
        if (let Some(updatedAt) <- map.get("updated_at")) {
        }
        if (let Some(deletedAt) <- map.get("deleted_at")) {
            // DateTime类型, 由数据库处理
        }
        if (let Some(allowedTools) <- map.get("allowed_tools")) {
            let allowedToolsStr = allowedTools as String
            if (let Some(s) <- allowedToolsStr) {
                entity.allowedTools = Some<String>(s)
            }
        }
        if (let Some(assetsDirExists) <- map.get("assets_dir_exists")) {
            let assetsDirExistsInt = assetsDirExists as Int64
            if (let Some(v) <- assetsDirExistsInt) {
                entity.assetsDirExists = Int32(v)
            }
        }
        if (let Some(avgExecutionTime) <- map.get("avg_execution_time")) {
            let avgExecutionTimeInt = avgExecutionTime as Int64
            if (let Some(v) <- avgExecutionTimeInt) {
                entity.avgExecutionTime = Int32(v)
            }
        }
        if (let Some(categories) <- map.get("categories")) {
            let categoriesStr = categories as String
            if (let Some(s) <- categoriesStr) {
                entity.categories = Some<String>(s)
            }
        }
        if (let Some(compatibility) <- map.get("compatibility")) {
            let compatibilityStr = compatibility as String
            if (let Some(s) <- compatibilityStr) {
                entity.compatibility = Some<String>(s)
            }
        }
        if (let Some(dependencies) <- map.get("dependencies")) {
            let dependenciesStr = dependencies as String
            if (let Some(s) <- dependenciesStr) {
                entity.dependencies = Some<String>(s)
            }
        }
        if (let Some(envVars) <- map.get("env_vars")) {
            let envVarsStr = envVars as String
            if (let Some(s) <- envVarsStr) {
                entity.envVars = Some<String>(s)
            }
        }
        if (let Some(errorCount) <- map.get("error_count")) {
            let errorCountInt = errorCount as Int64
            if (let Some(v) <- errorCountInt) {
                entity.errorCount = Int32(v)
            }
        }
        if (let Some(extraMetadata) <- map.get("extra_metadata")) {
            let extraMetadataStr = extraMetadata as String
            if (let Some(s) <- extraMetadataStr) {
                entity.extraMetadata = Some<String>(s)
            }
        }
        if (let Some(generationModel) <- map.get("generation_model")) {
            let generationModelStr = generationModel as String
            if (let Some(s) <- generationModelStr) {
                entity.generationModel = Some<String>(s)
            }
        }
        if (let Some(generationPrompt) <- map.get("generation_prompt")) {
            let generationPromptStr = generationPrompt as String
            if (let Some(s) <- generationPromptStr) {
                entity.generationPrompt = Some<String>(s)
            }
        }
        if (let Some(generationStatus) <- map.get("generation_status")) {
            let generationStatusStr = generationStatus as String
            if (let Some(s) <- generationStatusStr) {
                entity.generationStatus = Some<String>(s)
            }
        }
        if (let Some(instructions) <- map.get("instructions")) {
            let instructionsStr = instructions as String
            if (let Some(s) <- instructionsStr) {
                entity.instructions = Some<String>(s)
            }
        }
        if (let Some(lastError) <- map.get("last_error")) {
            let lastErrorStr = lastError as String
            if (let Some(s) <- lastErrorStr) {
                entity.lastError = Some<String>(s)
            }
        }
        if (let Some(lastValidatedAt) <- map.get("last_validated_at")) {
            // DateTime类型, 由数据库处理
        }
        if (let Some(parameters) <- map.get("parameters")) {
            let parametersStr = parameters as String
            if (let Some(s) <- parametersStr) {
                entity.parameters = Some<String>(s)
            }
        }
        if (let Some(parentSkillId) <- map.get("parent_skill_id")) {
            let parentSkillIdStr = parentSkillId as String
            if (let Some(s) <- parentSkillIdStr) {
                entity.parentSkillId = Some<String>(s)
            }
        }
        if (let Some(permissions) <- map.get("permissions")) {
            let permissionsStr = permissions as String
            if (let Some(s) <- permissionsStr) {
                entity.permissions = Some<String>(s)
            }
        }
        if (let Some(referencesDirExists) <- map.get("references_dir_exists")) {
            let referencesDirExistsInt = referencesDirExists as Int64
            if (let Some(v) <- referencesDirExistsInt) {
                entity.referencesDirExists = Int32(v)
            }
        }
        if (let Some(retryCount) <- map.get("retry_count")) {
            let retryCountInt = retryCount as Int64
            if (let Some(v) <- retryCountInt) {
                entity.retryCount = Int32(v)
            }
        }
        if (let Some(scriptsDirExists) <- map.get("scripts_dir_exists")) {
            let scriptsDirExistsInt = scriptsDirExists as Int64
            if (let Some(v) <- scriptsDirExistsInt) {
                entity.scriptsDirExists = Int32(v)
            }
        }
        if (let Some(successCount) <- map.get("success_count")) {
            let successCountInt = successCount as Int64
            if (let Some(v) <- successCountInt) {
                entity.successCount = Int32(v)
            }
        }
        if (let Some(tags) <- map.get("tags")) {
            let tagsStr = tags as String
            if (let Some(s) <- tagsStr) {
                entity.tags = Some<String>(s)
            }
        }
        if (let Some(timeout) <- map.get("timeout")) {
            let timeoutInt = timeout as Int64
            if (let Some(v) <- timeoutInt) {
                entity.timeout = Int32(v)
            }
        }
        if (let Some(validationErrors) <- map.get("validation_errors")) {
            let validationErrorsStr = validationErrors as String
            if (let Some(s) <- validationErrorsStr) {
                entity.validationErrors = Some<String>(s)
            }
        }
        if (let Some(validationStatus) <- map.get("validation_status")) {
            let validationStatusStr = validationStatus as String
            if (let Some(s) <- validationStatusStr) {
                entity.validationStatus = Some<String>(s)
            }
        }
        return entity
    }


    private func parseForce(forceOpt: ?Any): Bool {
        if (let Some(f) <- forceOpt) {
            let fInt64 = f as Int64
            if (let Some(v) <- fInt64) {
                v == 1
            } else {
                let fInt32 = f as Int32
                if (let Some(v) <- fInt32) {
                    v == 1
                } else {
                    let fStr = f as String
                    if (let Some(s) <- fStr) {
                        s == "true" || s == "1"
                    } else {
                        false
                    }
                }
            }
        } else {
            false
        }
    }

    private func parseIdsArray(idsStr: String): ArrayList<String> {
        let idArray = ArrayList<String>()
        try {
            let jsonValue = JsonValue.fromStr(idsStr)
            if (jsonValue is JsonArray) {
                let arr = jsonValue.asArray()
                for (item in arr.getItems()) {
                    if (item is JsonString) {
                        let jsonStr = item.asString()
                        idArray.add(jsonStr.getValue())
                    }
                }
            }
        } catch (e: Exception) {
            let parts = idsStr.split(",")
            for (part in parts) {
                let trimmed = part.trimAscii()
                if (!trimmed.isEmpty()) {
                    idArray.add(trimmed)
                }
            }
        }
        return idArray
    }

    private func parseLimit(limit: ?String): Int32 {
        if (let Some(l) <- limit) {
            Int32.parse(l)
        } else {
            10
        }
    }

    private func parsePage(page: ?String): Int32 {
        if (let Some(p) <- page) {
            Int32.parse(p)
        } else {
            1
        }
    }

    public func export(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取所有agent_skills数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,name,description,source,source_url,source_type,branch,tag,commit,version,author,homepage,license,keywords,install_path,status,runtime_status,last_run_at,run_count,config,creator,created_at,updated_at,deleted_at,allowed_tools,assets_dir_exists,avg_execution_time,categories,compatibility,dependencies,env_vars,error_count,extra_metadata,generation_model,generation_prompt,generation_status,instructions,last_error,last_validated_at,parameters,parent_skill_id,permissions,references_dir_exists,retry_count,scripts_dir_exists,success_count,tags,timeout,validation_errors,validation_status\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.name}" + ",")
                sb.append(if (let Some(v) <- entity.description) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.source) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.sourceUrl) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.sourceType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.branch) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.tag) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.commit) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.version) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.author) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.homepage) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.license) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.keywords) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.installPath) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.status}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.runtimeStatus) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.lastRunAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("${entity.runCount}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.config) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.allowedTools) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.assetsDirExists}")
                sb.append(",")
                sb.append("${entity.avgExecutionTime}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.categories) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.compatibility) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.dependencies) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.envVars) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.errorCount}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.extraMetadata) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.generationModel) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.generationPrompt) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.generationStatus) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.instructions) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.lastError) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.lastValidatedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.parameters) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.parentSkillId) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.permissions) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.referencesDirExists}")
                sb.append(",")
                sb.append("${entity.retryCount}")
                sb.append(",")
                sb.append("${entity.scriptsDirExists}")
                sb.append(",")
                sb.append("${entity.successCount}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.tags) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.timeout}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.validationErrors) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.validationStatus) { "\"" + v + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=agent_skills_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode
}
