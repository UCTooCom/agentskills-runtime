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
import magic.app.models.uctoo.UserHasTasksPO
import magic.app.dao.uctoo.UserHasTasksDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * UserHasTasksService - user_has_tasks服务类
 *
 * 提供user_has_tasks相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UserHasTasksService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建user_has_tasks
     * @param entity UserHasTasksPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: UserHasTasksPO, creatorId: String): APIResult<UserHasTasksPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertUserHasTasks(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UserHasTasksPO>(entity)
            } else {
                return APIResult<UserHasTasksPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasTasksPO>(false, e.message)
        }
    }

    /**
     * 更新user_has_tasks（无权限检查）
     * @param entityId ID
     * @param entity UserHasTasksPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: UserHasTasksPO): APIResult<UserHasTasksPO> {
        try {
            let existing = getExecutor().findUserHasTasksById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UserHasTasksPO>(false, "user_has_tasks不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.userId.size > 0) {
                existingEntity.userId = entity.userId
            }
            if (entity.taskId.size > 0) {
                existingEntity.taskId = entity.taskId
            }
            if (entity.relationType.size > 0) {
                existingEntity.relationType = entity.relationType
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.joinStatus.size > 0) {
                existingEntity.joinStatus = entity.joinStatus
            }
            if (entity.submissionContent.isSome()) {
                existingEntity.submissionContent = entity.submissionContent
            }
            if (entity.submissionAttachments.isSome()) {
                existingEntity.submissionAttachments = entity.submissionAttachments
            }
            if (entity.submittedAt.isSome()) {
                existingEntity.submittedAt = entity.submittedAt
            }
            if (entity.reviewStatus.size > 0) {
                existingEntity.reviewStatus = entity.reviewStatus
            }
            if (entity.reviewComment.isSome()) {
                existingEntity.reviewComment = entity.reviewComment
            }
            if (entity.reviewedAt.isSome()) {
                existingEntity.reviewedAt = entity.reviewedAt
            }
            if (entity.reviewerId.isSome()) {
                existingEntity.reviewerId = entity.reviewerId
            }
            existingEntity.allocationRatio = entity.allocationRatio
            existingEntity.pointsEarned = entity.pointsEarned
            if (entity.settledAt.isSome()) {
                existingEntity.settledAt = entity.settledAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateUserHasTasks(existingEntity)
            
            if (rows > 0) {
                return APIResult<UserHasTasksPO>(existingEntity)
            } else {
                return APIResult<UserHasTasksPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasTasksPO>(false, e.message)
        }
    }

    /**
     * 批量更新user_has_tasks
     * @param entities user_has_tasks列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UserHasTasksPO>): APIResult<ArrayList<UserHasTasksPO>> {
        try {
            let updatedEntities = ArrayList<UserHasTasksPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUserHasTasks(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UserHasTasksPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UserHasTasksPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UserHasTasksPO>>(false, e.message)
        }
    }

    /**
     * 删除user_has_tasks（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUserHasTasksById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "user_has_tasks不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUserHasTasksById(entityId)
            } else {
                rows = getExecutor().softDeleteUserHasTasksById(entityId)
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
     * 批量删除user_has_tasks
     * @param ids user_has_tasksID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteUserHasTasks(ids)
            } else {
                rows = getExecutor().batchSoftDeleteUserHasTasks(ids)
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
     * 恢复软删除的user_has_tasks
     * @param entityId user_has_tasksID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UserHasTasksPO> {
        try {
            let rows = getExecutor().restoreUserHasTasksById(entityId)

            if (rows > 0) {
                let result = getExecutor().findUserHasTasksById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UserHasTasksPO>(entity)
                } else {
                    return APIResult<UserHasTasksPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UserHasTasksPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasTasksPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的user_has_tasks
     * @param ids user_has_tasksID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUserHasTasksById(id)
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
     * 根据ID获取user_has_tasks（无权限检查）
     * @param entityId ID
     * @return user_has_tasks对象
     */
    public func getById(entityId: String): APIResult<UserHasTasksPO> {
        try {
            let result = getExecutor().findUserHasTasksById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<UserHasTasksPO>(entity)
            } else {
                return APIResult<UserHasTasksPO>(false, "未找到该user_has_tasks")
            }
        } catch (e: Exception) {
            return APIResult<UserHasTasksPO>(false, e.message)
        }
    }

    /**
     * 获取user_has_tasks列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return user_has_tasks列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<UserHasTasksPO>, Int64) {
        try {
            let pagination = getExecutor().findAllUserHasTasksPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UserHasTasksPO>(), 0)
        }
    }

    /**
     * 获取user_has_tasks列表（分页，支持排序和过滤，无权限过滤）
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
     * @return user_has_tasks列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserHasTasksPO>, Int64) {
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
            let pagination = getExecutor().findUserHasTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UserHasTasksPO>(), 0)
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
     * 获取user_has_tasks列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return user_has_tasks列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<UserHasTasksPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "user_has_tasks")

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
            let pagination = getExecutor().findUserHasTasksByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UserHasTasksPO>(), 0)
        }
    }

    /**
     * 获取user_has_tasks列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return user_has_tasks列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserHasTasksPO>, Int64) {
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
            let pagination = getExecutor().findUserHasTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UserHasTasksPO>(), 0)
        }
    }

    /**
     * 获取所有user_has_tasks列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return user_has_tasks列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UserHasTasksPO>, Int64) {
        let pagination = getExecutor().findAllUserHasTasksPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取user_has_tasks
     * @param ids ID列表
     * @return user_has_tasks列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UserHasTasksPO> {
        getExecutor().findUserHasTasksByIds(ids)
    }

    /**
     * 统计用户的user_has_tasks数量
     * @param userId 用户ID
     * @return user_has_tasks数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUserHasTasksByCreator(userId)
    }

    /**
     * 统计所有user_has_tasks数量
     * @return user_has_tasks数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUserHasTasks()
    }

    /**
     * 获取user_has_tasks列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return user_has_tasks列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<UserHasTasksPO>, Int64) {
        let pagination = getExecutor().findUserHasTasksByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_has_tasks）
     * @return 删除结果
     */
    public func emptyRecycleBinUserHasTasks(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinUserHasTasks()

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

    public func createWithPermission(entity: UserHasTasksPO, creatorId: String): APIResult<UserHasTasksPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "user_has_tasks")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<UserHasTasksPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "user_has_tasks")
            if (!hasPermission) {
                return APIResult<UserHasTasksPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<UserHasTasksPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<UserHasTasksPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "user_has_tasks")

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

            let pagination = getExecutor().findUserHasTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UserHasTasksPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: UserHasTasksPO, userId: String): APIResult<UserHasTasksPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "user_has_tasks")
            if (!hasPermission) {
                return APIResult<UserHasTasksPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<UserHasTasksPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "user_has_tasks")
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

    // ==================== 任务承接状态机方法 ====================

    /**
     * 查询用户承接的任务列表（按关系类型）
     * @param userId 用户ID
     * @param relationType 关系类型（participant/follower）
     * @return 任务关系列表
     */
    public func getUserTasksByRelation(userId: String, relationType: String): ArrayList<UserHasTasksPO> {
        let pagination = getExecutor().findTasksByUserIdAndRelation(userId, relationType, 1, 1000)
        pagination.list
    }

    /**
     * 查询任务的承接者列表
     */
    public func getTaskParticipants(taskId: String): ArrayList<UserHasTasksPO> {
        getExecutor().findParticipantsByTaskId(taskId)
    }

    /**
     * 查询任务的关注者列表
     */
    public func getTaskFollowers(taskId: String): ArrayList<UserHasTasksPO> {
        getExecutor().findFollowersByTaskId(taskId)
    }

    /**
     * 判断用户是否是任务承接者
     */
    public func isParticipant(userId: String, taskId: String): Bool {
        getExecutor().isParticipant(userId, taskId)
    }

    /**
     * 判断用户是否关注了任务
     */
    public func isFollowing(userId: String, taskId: String): Bool {
        getExecutor().isFollowing(userId, taskId)
    }

    /**
     * 查询承接关系详情
     */
    public func getRelation(userId: String, taskId: String, relationType: String): APIResult<UserHasTasksPO> {
        let result = getExecutor().findTaskRelation(userId, taskId, relationType)
        if (let Some(entity) <- result) {
            return APIResult<UserHasTasksPO>(entity)
        } else {
            return APIResult<UserHasTasksPO>(false, "未找到关系记录")
        }
    }

    /**
     * 设置多人任务的分配比例和积分
     * @param relationId 承接关系ID
     * @param allocationRatio 分配比例（0-100）
     * @param pointsEarned 获得积分
     */
    public func setAllocationAndPoints(relationId: String, allocationRatio: Int32, pointsEarned: Int64): APIResult<Bool> {
        try {
            if (allocationRatio < 0 || allocationRatio > 100) {
                return APIResult<Bool>(false, "分配比例必须在0-100之间")
            }
            let rows = getExecutor().updateAllocationAndPoints(relationId, allocationRatio, pointsEarned)
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "设置失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    /**
     * 标记单个承接者结算完成
     */
    public func markParticipantSettled(relationId: String, pointsEarned: Int64): APIResult<Bool> {
        try {
            let rows = getExecutor().settleSingleParticipant(relationId, pointsEarned)
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "标记结算失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
}
