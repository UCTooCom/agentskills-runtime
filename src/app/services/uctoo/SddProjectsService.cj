/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.SddProjectsPO
import magic.app.dao.uctoo.SddProjectsDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * SddProjectsService - sdd_projects服务类
 *
 * 提供sdd_projects相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class SddProjectsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建sdd_projects
     * @param entity SddProjectsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: SddProjectsPO, creatorId: String): APIResult<SddProjectsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertSddProjects(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<SddProjectsPO>(entity)
            } else {
                return APIResult<SddProjectsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    /**
     * 更新sdd_projects（无权限检查）
     * @param entityId ID
     * @param entity SddProjectsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: SddProjectsPO): APIResult<SddProjectsPO> {
        try {
            let existing = getExecutor().findSddProjectsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<SddProjectsPO>(false, "sdd_projects不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.featureName.size > 0) {
                existingEntity.featureName = entity.featureName
            }
            if (entity.title.isSome()) {
                existingEntity.title = entity.title
            }
            if (entity.taskId.isSome()) {
                existingEntity.taskId = entity.taskId
            }
            if (entity.currentStage.size > 0) {
                existingEntity.currentStage = entity.currentStage
            }
            if (entity.status.size > 0) {
                existingEntity.status = entity.status
            }
            existingEntity.enableResearch = entity.enableResearch
            existingEntity.round = entity.round
            if (entity.payload.size > 0) {
                existingEntity.payload = entity.payload
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.ownerUserId.isSome()) {
                existingEntity.ownerUserId = entity.ownerUserId
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateSddProjects(existingEntity)
            
            if (rows > 0) {
                return APIResult<SddProjectsPO>(existingEntity)
            } else {
                return APIResult<SddProjectsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    /**
     * 批量更新sdd_projects
     * @param entities sdd_projects列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<SddProjectsPO>): APIResult<ArrayList<SddProjectsPO>> {
        try {
            let updatedEntities = ArrayList<SddProjectsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateSddProjects(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<SddProjectsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<SddProjectsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<SddProjectsPO>>(false, e.message)
        }
    }

    /**
     * 删除sdd_projects（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findSddProjectsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "sdd_projects不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteSddProjectsById(entityId)
            } else {
                rows = getExecutor().softDeleteSddProjectsById(entityId)
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
     * 批量删除sdd_projects
     * @param ids sdd_projectsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteSddProjects(ids)
            } else {
                rows = getExecutor().batchSoftDeleteSddProjects(ids)
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
     * 恢复软删除的sdd_projects
     * @param entityId sdd_projectsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<SddProjectsPO> {
        try {
            let rows = getExecutor().restoreSddProjectsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findSddProjectsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<SddProjectsPO>(entity)
                } else {
                    return APIResult<SddProjectsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<SddProjectsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的sdd_projects
     * @param ids sdd_projectsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreSddProjectsById(id)
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
     * 根据ID获取sdd_projects（无权限检查）
     * @param entityId ID
     * @return sdd_projects对象
     */
    public func getById(entityId: String): APIResult<SddProjectsPO> {
        try {
            let result = getExecutor().findSddProjectsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<SddProjectsPO>(entity)
            } else {
                return APIResult<SddProjectsPO>(false, "未找到该sdd_projects")
            }
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    /**
     * 获取sdd_projects列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return sdd_projects列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<SddProjectsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllSddProjectsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SddProjectsPO>(), 0)
        }
    }

    /**
     * 获取sdd_projects列表（分页，支持排序和过滤，无权限过滤）
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
     * @return sdd_projects列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<SddProjectsPO>, Int64) {
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
            let pagination = getExecutor().findSddProjectsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SddProjectsPO>(), 0)
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
     * 获取sdd_projects列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return sdd_projects列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<SddProjectsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "sdd_projects")

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
            let pagination = getExecutor().findSddProjectsByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SddProjectsPO>(), 0)
        }
    }

    /**
     * 获取sdd_projects列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return sdd_projects列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<SddProjectsPO>, Int64) {
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
            let pagination = getExecutor().findSddProjectsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SddProjectsPO>(), 0)
        }
    }

    /**
     * 获取所有sdd_projects列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return sdd_projects列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<SddProjectsPO>, Int64) {
        let pagination = getExecutor().findAllSddProjectsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取sdd_projects
     * @param ids ID列表
     * @return sdd_projects列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<SddProjectsPO> {
        getExecutor().findSddProjectsByIds(ids)
    }

    /**
     * 统计用户的sdd_projects数量
     * @param userId 用户ID
     * @return sdd_projects数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countSddProjectsByCreator(userId)
    }

    /**
     * 统计所有sdd_projects数量
     * @return sdd_projects数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllSddProjects()
    }

    /**
     * 获取sdd_projects列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return sdd_projects列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<SddProjectsPO>, Int64) {
        let pagination = getExecutor().findSddProjectsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的sdd_projects）
     * @return 删除结果
     */
    public func emptyRecycleBinSddProjects(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinSddProjects()

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

    public func createWithPermission(entity: SddProjectsPO, creatorId: String): APIResult<SddProjectsPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "sdd_projects")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<SddProjectsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "sdd_projects")
            if (!hasPermission) {
                return APIResult<SddProjectsPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<SddProjectsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "sdd_projects")

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

            let pagination = getExecutor().findSddProjectsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SddProjectsPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: SddProjectsPO, userId: String): APIResult<SddProjectsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "sdd_projects")
            if (!hasPermission) {
                return APIResult<SddProjectsPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "sdd_projects")
            if (!hasPermission) {
                return APIResult<Bool>(false, reason)
            }
            return delete(entityId, force)
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    // ── SDD 工程语义化写入口（ADR-001 v2 §6：业务禁直调通用 create/update）────────
    // sdd_projects 是 agent_tasks 状态机的投影（feature_name 唯一、round 递增），
    // 写入责任方是宿主侧编排服务，故只暴露 upsertProject / advanceStage 两个语义入口。

    /**
     * 按 feature_name 幂等取/建 SDD 工程（upsert）。
     *
     * @param featureName 工程唯一键（对应 specs/{feature_name} 目录名）
     * @param title       工程标题（可空）
     * @param taskId      根任务 ID（可空）
     * @param enableResearch 研究步是否执行（COMPOSITION condition 信号）
     * @param payloadJson 工程上下文 JSON 字符串
     * @param creatorId   创建者
     */
    public func upsertProject(
        featureName: String,
        title: String,
        taskId: String,
        enableResearch: Bool,
        payloadJson: String,
        creatorId: String
    ): APIResult<SddProjectsPO> {
        try {
            match (this.findByFeatureName(featureName)) {
                case Some(po) => return APIResult<SddProjectsPO>(po)
                case None =>
                    let po = SddProjectsPO()
                    po.featureName = featureName
                    po.title = if (title.isEmpty()) { None<String> } else { Some(title) }
                    po.taskId = if (taskId.isEmpty()) { None<String> } else { Some(taskId) }
                    po.currentStage = "init"
                    po.status = "running"
                    po.enableResearch = enableResearch
                    po.round = 0
                    po.payload = payloadJson
                    return this.create(po, creatorId)
            }
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    /**
     * 推进 SDD 工程阶段（只改 current_stage / status，**不触碰 round**）。
     *
     * 刻意不动 round：阶段推进发生在同一轮次内，若在此重置 round 会把 revise
     * 递增上来的轮次打回 0（revise 重做靠 round + 新 task_id 隔离上下文）。
     * 轮次递增走 bumpRound。
     *
     * @param stage 目标阶段（research/spec/design/task/code/test/done）
     */
    public func advanceStage(
        featureName: String,
        stage: String,
        status: String,
        creatorId: String
    ): APIResult<SddProjectsPO> {
        try {
            match (this.findByFeatureName(featureName)) {
                case Some(po) =>
                    po.currentStage = stage
                    po.status = status
                    return this.update(po.id, po)
                case None =>
                    return APIResult<SddProjectsPO>(false, "sdd_projects 不存在: feature_name='${featureName}'")
            }
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    /**
     * 轮次 +1（gate revise 时调用）。
     *
     * revise 语义：回退上一步重做，**不丢已确认产物**，上下文按新 task_id 重开
     * （agent_contexts 按 task_id 隔离，避免同一子 agent 多次调用串上下文）。
     */
    public func bumpRound(featureName: String, creatorId: String): APIResult<SddProjectsPO> {
        try {
            match (this.findByFeatureName(featureName)) {
                case Some(po) =>
                    po.round = po.round + 1
                    return this.update(po.id, po)
                case None =>
                    return APIResult<SddProjectsPO>(false, "sdd_projects 不存在: feature_name='${featureName}'")
            }
        } catch (e: Exception) {
            return APIResult<SddProjectsPO>(false, e.message)
        }
    }

    /**
     * 按 feature_name 只读查询工程（对外查询口）。
     *
     * ADR-001 约束的是**写**（通用 add/edit/del 不暴露），读不走状态机，
     * 故显式开放这一只读访问器，供编排薄路由回显工程进度（T-09 / T-23）。
     */
    public func getByFeatureName(featureName: String): ?SddProjectsPO {
        this.findByFeatureName(featureName)
    }

    /// 按 feature_name 查工程（取首条）
    private func findByFeatureName(featureName: String): ?SddProjectsPO {
        let filter = "{\"feature_name\":{\"equals\":\"${featureName}\"}}"
        let (list, _) = this.getListWithFilter(1, 10, "", filter)
        if (list.size > 0) {
            return Some(list[0])
        }
        return None<SddProjectsPO>
    }
}
