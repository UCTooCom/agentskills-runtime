/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.AgentSkillsPO
import magic.app.dao.uctoo.AgentSkillsDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * AgentSkillsService - agent_skills服务类
 *
 * 提供agent_skills相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class AgentSkillsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建agent_skills
     * @param entity AgentSkillsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: AgentSkillsPO, creatorId: String): APIResult<AgentSkillsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertAgentSkills(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<AgentSkillsPO>(entity)
            } else {
                return APIResult<AgentSkillsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }

    /**
     * 更新agent_skills（无权限检查）
     * @param entityId ID
     * @param entity AgentSkillsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: AgentSkillsPO): APIResult<AgentSkillsPO> {
        try {
            let existing = getExecutor().findAgentSkillsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<AgentSkillsPO>(false, "agent_skills不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.description.isSome()) {
                existingEntity.description = entity.description
            }
            if (entity.source.isSome()) {
                existingEntity.source = entity.source
            }
            if (entity.sourceUrl.isSome()) {
                existingEntity.sourceUrl = entity.sourceUrl
            }
            if (entity.sourceType.isSome()) {
                existingEntity.sourceType = entity.sourceType
            }
            if (entity.branch.isSome()) {
                existingEntity.branch = entity.branch
            }
            if (entity.tag.isSome()) {
                existingEntity.tag = entity.tag
            }
            if (entity.commit.isSome()) {
                existingEntity.commit = entity.commit
            }
            if (entity.version.isSome()) {
                existingEntity.version = entity.version
            }
            if (entity.author.isSome()) {
                existingEntity.author = entity.author
            }
            if (entity.homepage.isSome()) {
                existingEntity.homepage = entity.homepage
            }
            if (entity.license.isSome()) {
                existingEntity.license = entity.license
            }
            if (entity.keywords.isSome()) {
                existingEntity.keywords = entity.keywords
            }
            if (entity.installPath.isSome()) {
                existingEntity.installPath = entity.installPath
            }
            existingEntity.status = entity.status
            if (entity.runtimeStatus.isSome()) {
                existingEntity.runtimeStatus = entity.runtimeStatus
            }
            if (entity.lastRunAt.isSome()) {
                existingEntity.lastRunAt = entity.lastRunAt
            }
            existingEntity.runCount = entity.runCount
            if (entity.config.isSome()) {
                existingEntity.config = entity.config
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.allowedTools.isSome()) {
                existingEntity.allowedTools = entity.allowedTools
            }
            existingEntity.assetsDirExists = entity.assetsDirExists
            existingEntity.avgExecutionTime = entity.avgExecutionTime
            if (entity.categories.isSome()) {
                existingEntity.categories = entity.categories
            }
            if (entity.compatibility.isSome()) {
                existingEntity.compatibility = entity.compatibility
            }
            if (entity.dependencies.isSome()) {
                existingEntity.dependencies = entity.dependencies
            }
            if (entity.envVars.isSome()) {
                existingEntity.envVars = entity.envVars
            }
            existingEntity.errorCount = entity.errorCount
            if (entity.extraMetadata.isSome()) {
                existingEntity.extraMetadata = entity.extraMetadata
            }
            if (entity.generationModel.isSome()) {
                existingEntity.generationModel = entity.generationModel
            }
            if (entity.generationPrompt.isSome()) {
                existingEntity.generationPrompt = entity.generationPrompt
            }
            if (entity.generationStatus.isSome()) {
                existingEntity.generationStatus = entity.generationStatus
            }
            if (entity.instructions.isSome()) {
                existingEntity.instructions = entity.instructions
            }
            if (entity.lastError.isSome()) {
                existingEntity.lastError = entity.lastError
            }
            if (entity.lastValidatedAt.isSome()) {
                existingEntity.lastValidatedAt = entity.lastValidatedAt
            }
            if (entity.parameters.isSome()) {
                existingEntity.parameters = entity.parameters
            }
            if (entity.parentSkillId.isSome()) {
                existingEntity.parentSkillId = entity.parentSkillId
            }
            if (entity.permissions.isSome()) {
                existingEntity.permissions = entity.permissions
            }
            existingEntity.referencesDirExists = entity.referencesDirExists
            existingEntity.retryCount = entity.retryCount
            existingEntity.scriptsDirExists = entity.scriptsDirExists
            existingEntity.successCount = entity.successCount
            if (entity.tags.isSome()) {
                existingEntity.tags = entity.tags
            }
            existingEntity.timeout = entity.timeout
            if (entity.validationErrors.isSome()) {
                existingEntity.validationErrors = entity.validationErrors
            }
            if (entity.validationStatus.isSome()) {
                existingEntity.validationStatus = entity.validationStatus
            }
            if (entity.sourcePath.isSome()) {
                existingEntity.sourcePath = entity.sourcePath
            }
            if (entity.syncStatus.isSome()) {
                existingEntity.syncStatus = entity.syncStatus
            }
            if (entity.lastSyncAt.isSome()) {
                existingEntity.lastSyncAt = entity.lastSyncAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateAgentSkills(existingEntity)
            
            if (rows > 0) {
                return APIResult<AgentSkillsPO>(existingEntity)
            } else {
                return APIResult<AgentSkillsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }

    /**
     * 批量更新agent_skills
     * @param entities agent_skills列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<AgentSkillsPO>): APIResult<ArrayList<AgentSkillsPO>> {
        try {
            let updatedEntities = ArrayList<AgentSkillsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateAgentSkills(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<AgentSkillsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<AgentSkillsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<AgentSkillsPO>>(false, e.message)
        }
    }

    /**
     * 删除agent_skills（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findAgentSkillsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "agent_skills不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteAgentSkillsById(entityId)
            } else {
                rows = getExecutor().softDeleteAgentSkillsById(entityId)
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    /**
     * 批量删除agent_skills
     * @param ids agent_skillsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteAgentSkills(ids)
            } else {
                rows = getExecutor().batchSoftDeleteAgentSkills(ids)
            }

            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "批量删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    /**
     * 恢复软删除的agent_skills
     * @param entityId agent_skillsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<AgentSkillsPO> {
        try {
            let rows = getExecutor().restoreAgentSkillsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findAgentSkillsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<AgentSkillsPO>(entity)
                } else {
                    return APIResult<AgentSkillsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<AgentSkillsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的agent_skills
     * @param ids agent_skillsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreAgentSkillsById(id)
            }

            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "批量恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    /**
     * 根据ID获取agent_skills（无权限检查）
     * @param entityId ID
     * @return agent_skills对象
     */
    public func getById(entityId: String): APIResult<AgentSkillsPO> {
        try {
            let result = getExecutor().findAgentSkillsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<AgentSkillsPO>(entity)
            } else {
                return APIResult<AgentSkillsPO>(false, "未找到该agent_skills")
            }
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }

    /**
     * 获取agent_skills列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_skills列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<AgentSkillsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllAgentSkillsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentSkillsPO>(), 0)
        }
    }

    /**
     * 获取agent_skills列表（分页，支持排序和过滤，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询：
     * - 排序：sort="-created_at,id"
     * - 过滤：filter={"name":{"contains":"test"},"status":{"equals":"active"}}
     * - 条件组合：filter={"AND":[{"name":{"contains":"test"}},{"status":{"equals":"active"}}]}
     *
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return agent_skills列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentSkillsPO>, Int64) {
        try {
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            // 2. 构建 WHERE 条件
            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            // 3. 构建 ORDER BY 子句
            let orderByClause = buildOrderByClause(parsedQuery.sort)

            // 4. 执行查询
            let pagination = getExecutor().findAgentSkillsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentSkillsPO>(), 0)
        }
    }

    /**
     * 构建WHERE子句字符串
     *
     * 将组合条件转换为SQL WHERE子句
     */
    private func buildWhereClause(composite: CompositeCondition): String {
        let sb = StringBuilder()

        // 处理字段条件
        let fieldConditions = composite.fieldConditions
        for (fieldCondition in fieldConditions) {
            if (sb.size > 0) {
                match (composite.logic) {
                    case LogicOperator.And => sb.append(" AND ")
                    case LogicOperator.Or => sb.append(" OR ")
                    case LogicOperator.Not => sb.append(" AND ")
                }
            }
            sb.append(buildFieldClause(fieldCondition))
        }

        // 处理嵌套组合条件
        let compositeConditions = composite.compositeConditions
        for (nestedComposite in compositeConditions) {
            if (sb.size > 0) {
                match (composite.logic) {
                    case LogicOperator.And => sb.append(" AND ")
                    case LogicOperator.Or => sb.append(" OR ")
                    case LogicOperator.Not => sb.append(" AND ")
                }
            }
            let nestedClause = buildWhereClause(nestedComposite)
            if (!nestedClause.isEmpty()) {
                sb.append("(${nestedClause})")
            }
        }

        // 处理 NOT 逻辑操作符
        match (composite.logic) {
            case LogicOperator.Not =>
                if (sb.size > 0) {
                    return "NOT(${sb.toString()})"
                } else {
                    return sb.toString()
                }
            case _ =>
                return sb.toString()
        }
    }

    /**
     * 构建单个字段条件的SQL子句
     */
    private func buildFieldClause(fieldCondition: FieldCondition): String {
        let field = fieldCondition.field
        let op = fieldCondition.op
        let value = fieldCondition.value

        match (op) {
            case QueryOperator.Equals => buildEqualsClause(field, value)
            case QueryOperator.Not => buildNotClause(field, value)
            case QueryOperator.Lt => buildLtClause(field, value)
            case QueryOperator.Lte => buildLteClause(field, value)
            case QueryOperator.Gt => buildGtClause(field, value)
            case QueryOperator.Gte => buildGteClause(field, value)
            case QueryOperator.Contains => buildContainsClause(field, value)
            case QueryOperator.StartsWith => buildStartsWithClause(field, value)
            case QueryOperator.EndsWith => buildEndsWithClause(field, value)
            case QueryOperator.In => buildInClauseWrapper(field, value, true)
            case QueryOperator.NotIn => buildInClauseWrapper(field, value, false)
            case QueryOperator.IsSet => buildIsSetClause(field, value)
            case QueryOperator.Between => buildBetweenClauseWrapper(field, value, true)
            case QueryOperator.NotBetween => buildBetweenClauseWrapper(field, value, false)
        }
    }

    private func buildEqualsClause(field: String, value: QueryValue): String {
        if (value.isNull()) {
            return "${field} IS NULL"
        }

        if (let Some(v) <- value.stringValue) {
            return "${field} = '${v}'"
        } else if (let Some(v) <- value.intValue) {
            return "${field} = ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} = ${v}"
        } else if (let Some(v) <- value.boolValue) {
            return "${field} = ${v}"
        }
        return ""
    }

    private func buildNotClause(field: String, value: QueryValue): String {
        if (value.isNull()) {
            return "${field} IS NOT NULL"
        }

        if (let Some(v) <- value.stringValue) {
            return "${field} != '${v}'"
        } else if (let Some(v) <- value.intValue) {
            return "${field} != ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} != ${v}"
        } else if (let Some(v) <- value.boolValue) {
            return "${field} != ${v}"
        }
        return ""
    }

    private func buildLtClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} < ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} < ${v}"
        }
        return ""
    }

    private func buildLteClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} <= ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} <= ${v}"
        }
        return ""
    }

    private func buildGtClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} > ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} > ${v}"
        }
        return ""
    }

    private func buildGteClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} >= ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} >= ${v}"
        }
        return ""
    }

    private func buildContainsClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.stringValue) {
            return "${field} LIKE '%${v}%'"
        }
        return ""
    }

    private func buildStartsWithClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.stringValue) {
            return "${field} LIKE '${v}%'"
        }
        return ""
    }

    private func buildEndsWithClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.stringValue) {
            return "${field} LIKE '%${v}'"
        }
        return ""
    }

    private func buildInClauseWrapper(field: String, value: QueryValue, isIn: Bool): String {
        if (let Some(arr) <- value.arrayValue) {
            return buildInClause(field, arr, isIn)
        }
        return ""
    }

    private func buildIsSetClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.boolValue) {
            if (v) {
                return "${field} IS NOT NULL"
            } else {
                return "${field} IS NULL"
            }
        }
        return ""
    }

    private func buildBetweenClauseWrapper(field: String, value: QueryValue, isBetween: Bool): String {
        if (let Some(arr) <- value.arrayValue) {
            if (arr.size >= 2) {
                return buildBetweenClause(field, arr[0], arr[1], isBetween)
            }
        }
        return ""
    }

    private func buildInClause(field: String, values: ArrayList<QueryValue>, isIn: Bool): String {
        let sb = StringBuilder()
        sb.append("${field} ")
        if (!isIn) {
            sb.append("NOT ")
        }
        sb.append("IN (")

        let size = values.size
        for (i in 0..size) {
            if (i > 0) {
                sb.append(", ")
            }
            let v = values[i]
            if (let Some(s) <- v.stringValue) {
                sb.append("'${s}'")
            } else if (let Some(n) <- v.intValue) {
                sb.append("${n}")
            } else if (let Some(f) <- v.floatValue) {
                sb.append("${f}")
            }
        }

        sb.append(")")
        return sb.toString()
    }


    /**
     * 构建BETWEEN子句
     */
    private func buildBetweenClause(field: String, v1: QueryValue, v2: QueryValue, isBetween: Bool): String {
        let sb = StringBuilder()
        sb.append("${field} ")

        if (!isBetween) {
            sb.append("NOT ")
        }
        sb.append("BETWEEN ")

        if (let Some(s) <- v1.stringValue) {
            sb.append("'${s}'")
        } else if (let Some(n) <- v1.intValue) {
            sb.append("${n}")
        } else if (let Some(f) <- v1.floatValue) {
            sb.append("${f}")
        }

        sb.append(" AND ")

        if (let Some(s) <- v2.stringValue) {
            sb.append("'${s}'")
        } else if (let Some(n) <- v2.intValue) {
            sb.append("${n}")
        } else if (let Some(f) <- v2.floatValue) {
            sb.append("${f}")
        }

        return sb.toString()
    }

    /**
     * 构建ORDER BY子句
     */
    private func buildOrderByClause(sort: ArrayList<SortCondition>): String {
        if (sort.isEmpty()) {
            return "created_at DESC"
        }

        let sb = StringBuilder()
        let size = sort.size

        for (i in 0..size) {
            let condition = sort[i]
            if (sb.size > 0) {
                sb.append(", ")
            }
            sb.append("${condition.field} ${if (condition.ascending) { "ASC" } else { "DESC" }}")
        }

        return sb.toString()
    }

    /**
     * 获取agent_skills列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return agent_skills列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentSkillsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_skills")

            if (permFilter == "1=1" || permFilter.isEmpty()) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            if (whereClause.isEmpty()) {
                whereClause = permFilter
            } else {
                whereClause = "(${whereClause}) AND ${permFilter}"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)

            let pageNum = if (pageSize > 0) { (skip / pageSize) + 1 } else { Int32(1) }
            let pagination = getExecutor().findAgentSkillsByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentSkillsPO>(), 0)
        }
    }

    /**
     * 获取agent_skills列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return agent_skills列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentSkillsPO>, Int64) {
        try {
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page + 1), Int64(pageSize))

            // 2. 构建 WHERE 条件
            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            // 3. 构建 ORDER BY 子句
            let orderByClause = buildOrderByClause(parsedQuery.sort)

            // 4. 执行查询（带跳过参数）
            let pagination = getExecutor().findAgentSkillsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentSkillsPO>(), 0)
        }
    }

    /**
     * 获取所有agent_skills列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_skills列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<AgentSkillsPO>, Int64) {
        let pagination = getExecutor().findAllAgentSkillsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取agent_skills
     * @param ids ID列表
     * @return agent_skills列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<AgentSkillsPO> {
        getExecutor().findAgentSkillsByIds(ids)
    }

    /**
     * 统计用户的agent_skills数量
     * @param userId 用户ID
     * @return agent_skills数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countAgentSkillsByCreator(userId)
    }

    /**
     * 统计所有agent_skills数量
     * @return agent_skills数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllAgentSkills()
    }

    /**
     * 获取agent_skills列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return agent_skills列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<AgentSkillsPO>, Int64) {
        let pagination = getExecutor().findAgentSkillsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_skills）
     * @return 删除结果
     */
    public func emptyRecycleBinAgentSkills(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinAgentSkills()

            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "回收站为空")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    // ==================== 行级权限集成方法（每个表都需要的标准化代码） ====================

    public func createWithPermission(entity: AgentSkillsPO, creatorId: String): APIResult<AgentSkillsPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "agent_skills")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<AgentSkillsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "agent_skills")
            if (!hasPermission) {
                return APIResult<AgentSkillsPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentSkillsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_skills")

            if (permFilter == "1=1" || permFilter.isEmpty()) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            if (whereClause.isEmpty()) {
                whereClause = permFilter
            } else {
                whereClause = "(${whereClause}) AND ${permFilter}"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)

            let pagination = getExecutor().findAgentSkillsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentSkillsPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: AgentSkillsPO, userId: String): APIResult<AgentSkillsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_skills")
            if (!hasPermission) {
                return APIResult<AgentSkillsPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_skills")
            if (!hasPermission) {
                return APIResult<Bool>(false, reason)
            }
            return delete(entityId, force)
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

//#endregion AutoCreateCode
}