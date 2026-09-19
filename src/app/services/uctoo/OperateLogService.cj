/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.OperateLogPO
import magic.app.dao.uctoo.OperateLogDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils

/**
 * OperateLogService - operate_log服务类
 *
 * 提供operate_log相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class OperateLogService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建operate_log
     * @param entity OperateLogPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: OperateLogPO, creatorId: String): APIResult<OperateLogPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertOperateLog(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<OperateLogPO>(entity)
            } else {
                return APIResult<OperateLogPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }

    /**
     * 更新operate_log（无权限检查）
     * @param entityId ID
     * @param entity OperateLogPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: OperateLogPO): APIResult<OperateLogPO> {
        try {
            let existing = getExecutor().findOperateLogById(entityId)
            
            if (existing.isNone()) {
                return APIResult<OperateLogPO>(false, "operate_log不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.module.size > 0) {
                existingEntity.module = entity.module
            }
            if (entity.operate.size > 0) {
                existingEntity.operate = entity.operate
            }
            if (entity.route.size > 0) {
                existingEntity.route = entity.route
            }
            if (entity.params.size > 0) {
                existingEntity.params = entity.params
            }
            if (entity.ip.size > 0) {
                existingEntity.ip = entity.ip
            }
            if (entity.method.size > 0) {
                existingEntity.method = entity.method
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateOperateLog(existingEntity)
            
            if (rows > 0) {
                return APIResult<OperateLogPO>(existingEntity)
            } else {
                return APIResult<OperateLogPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }

    /**
     * 批量更新operate_log
     * @param entities operate_log列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<OperateLogPO>): APIResult<ArrayList<OperateLogPO>> {
        try {
            let updatedEntities = ArrayList<OperateLogPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateOperateLog(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<OperateLogPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<OperateLogPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<OperateLogPO>>(false, e.message)
        }
    }

    /**
     * 删除operate_log（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findOperateLogById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "operate_log不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteOperateLogById(entityId)
            } else {
                rows = getExecutor().softDeleteOperateLogById(entityId)
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
     * 批量删除operate_log
     * @param ids operate_logID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteOperateLog(ids)
            } else {
                rows = getExecutor().batchSoftDeleteOperateLog(ids)
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
     * 恢复软删除的operate_log
     * @param entityId operate_logID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<OperateLogPO> {
        try {
            let rows = getExecutor().restoreOperateLogById(entityId)

            if (rows > 0) {
                let result = getExecutor().findOperateLogById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<OperateLogPO>(entity)
                } else {
                    return APIResult<OperateLogPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<OperateLogPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的operate_log
     * @param ids operate_logID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreOperateLogById(id)
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
     * 根据ID获取operate_log（无权限检查）
     * @param entityId ID
     * @return operate_log对象
     */
    public func getById(entityId: String): APIResult<OperateLogPO> {
        try {
            let result = getExecutor().findOperateLogById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<OperateLogPO>(entity)
            } else {
                return APIResult<OperateLogPO>(false, "未找到该operate_log")
            }
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }

    /**
     * 获取operate_log列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return operate_log列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<OperateLogPO>, Int64) {
        try {
            let pagination = getExecutor().findAllOperateLogPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<OperateLogPO>(), 0)
        }
    }

    /**
     * 获取operate_log列表（分页，支持排序和过滤，无权限过滤）
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
     * @return operate_log列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<OperateLogPO>, Int64) {
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
            let pagination = getExecutor().findOperateLogByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<OperateLogPO>(), 0)
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
     * 获取operate_log列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return operate_log列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<OperateLogPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "operate_log")

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
            let pagination = getExecutor().findOperateLogByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<OperateLogPO>(), 0)
        }
    }

    /**
     * 获取operate_log列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return operate_log列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<OperateLogPO>, Int64) {
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
            let pagination = getExecutor().findOperateLogByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<OperateLogPO>(), 0)
        }
    }

    /**
     * 获取所有operate_log列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return operate_log列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<OperateLogPO>, Int64) {
        let pagination = getExecutor().findAllOperateLogPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取operate_log
     * @param ids ID列表
     * @return operate_log列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<OperateLogPO> {
        getExecutor().findOperateLogByIds(ids)
    }

    /**
     * 统计用户的operate_log数量
     * @param userId 用户ID
     * @return operate_log数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countOperateLogByCreator(userId)
    }

    /**
     * 统计所有operate_log数量
     * @return operate_log数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllOperateLog()
    }

    /**
     * 获取operate_log列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return operate_log列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<OperateLogPO>, Int64) {
        let pagination = getExecutor().findOperateLogByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的operate_log）
     * @return 删除结果
     */
    public func emptyRecycleBinOperateLog(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinOperateLog()

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

    public func createWithPermission(entity: OperateLogPO, creatorId: String): APIResult<OperateLogPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "operate_log")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<OperateLogPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "operate_log")
            if (!hasPermission) {
                return APIResult<OperateLogPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<OperateLogPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "operate_log")

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

            let pagination = getExecutor().findOperateLogByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<OperateLogPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: OperateLogPO, userId: String): APIResult<OperateLogPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "operate_log")
            if (!hasPermission) {
                return APIResult<OperateLogPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "operate_log")
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

    /**
     * 记录操作日志（静态方法，用于工具类调用）
     * 
     * @param module 模块名称 (如: api, tool, cli)
     * @param operate 操作名称 (如: create, read, update, delete)
     * @param route 路由路径
     * @param params 参数(JSON格式字符串)
     * @param ip IP地址
     * @param method 请求方法 (如: GET, POST, PUT, DELETE)
     * @param creator 创建人ID
     */
    public static func recordLog(
        module: String,
        operate: String,
        route: String,
        params: String,
        ip: String,
        method: String,
        creator: ?String
    ): Unit {
        try {
            let operateLog = OperateLogPO()
            operateLog.module = module
            operateLog.operate = operate
            operateLog.route = route
            operateLog.params = params
            operateLog.ip = ip
            operateLog.method = method
            operateLog.creator = creator
            operateLog.createdAt = DateTime.now()
            operateLog.updatedAt = DateTime.now()
            
            // 直接走 DAO，不经 create()：create() 在 creator 为 None 时会用传入的
            // creatorId 覆盖（传空串即 Some("")），而 creator 是 uuid 列 —— 空串会让
            // PostgreSQL 报 invalid input syntax for type uuid，异常在 create() 与本方法
            // 的 catch 里被依次吞掉，表现为「日志静默丢失」。保持 None 写 NULL，
            // 这样插件链路（无用户上下文）也能正常留痕。
            let _ = ORM.executor().insertOperateLog(operateLog)
        } catch (e: Exception) {
            // 日志记录失败不影响主流程
        }
    }
    
    /**
     * 记录API操作日志
     */
    public static func recordApiLog(
        operate: String,
        route: String,
        params: String,
        ip: String,
        method: String,
        creator: ?String
    ): Unit {
        recordLog("api", operate, route, params, ip, method, creator)
    }
    
    /**
     * 记录工具调用日志
     */
    public static func recordToolLog(
        operate: String,
        route: String,
        params: String,
        ip: String,
        creator: ?String
    ): Unit {
        recordLog("tool", operate, route, params, ip, "tool", creator)
    }
    
    /**
     * 记录CLI操作日志
     */
    public static func recordCliLog(
        operate: String,
        route: String,
        params: String,
        creator: ?String
    ): Unit {
        recordLog("cli", operate, route, params, "127.0.0.1", "cli", creator)
    }

    // ════════════════════════════════════════════════════════════════════
    // 审计留痕出口（spec/long-running-task 5.12.1 规则 5 / 5.13.1 规则 3）
    //
    // 为什么接在 operate_log、而不是另建 agent_audit_log 表：
    //   ① operate_log 的表注释就是「操作记录」，既有 api/tool/cli 三类；插件写库与
    //      MCP 调用是第四、五类操作，同属操作记录，不构成新领域。
    //   ② 数据库规范要求所有表含 created_at/updated_at/deleted_at/creator 四列，
    //      operate_log 已齐备，且五层模块 + 中间件 + 回收站 + CSV 导出 + Web 管理页
    //      全部在位；另建表要把这一整套重建一遍。
    //   ③ backend(TS) / agentskills-runtime(仓颉) / web-admin 三端已同构，
    //      另建表要在三端各建一套，与「多端一致的 UMI 规范」相悖。
    //   评估与字段映射见
    //   .codeartsdoer/specs/long-running-task/audit-module-evaluation-20260915.md
    //
    // 两个出口（都选在宿主侧唯一通道上，插件与脚本不必各自实现）：
    //   recordPluginLog  ← CordisHostServices.executeExecute()（成功路径）
    //                      与其外层 catch（失败路径）
    //   recordMcpCallLog ← McpOpenService.call()（REST / 插件 host.mcp / CLI 三入口汇聚点）
    // ════════════════════════════════════════════════════════════════════

    /// 入参摘要最大长度（字节）
    public static let AUDIT_MAX_SUMMARY: Int64 = 2000
    /// 错误信息最大长度（字节）
    public static let AUDIT_MAX_ERROR: Int64 = 1000

    /// 插件写库审计（spec 5.12.1 规则 5）：`module='plugin'`
    ///
    /// @param pluginId 来源 L3 插件标识
    /// @param table 被写入的表名
    /// @param operation insert / update / delete
    /// @param dataJson 写入内容摘要（JSON 对象文本；内部脱敏 + 截断）
    /// @param affected 影响记录数（失败时传 0）
    /// @param userId 操作人 userId；插件链路无用户上下文时留空，creator 写 NULL
    public static func recordPluginLog(
        pluginId: String,
        table: String,
        operation: String,
        dataJson: String,
        affected: Int64,
        userId!: String = "",
        status!: String = "ok",
        errorMessage!: String = "",
        traceId!: String = ""
    ): Unit {
        let params = buildAuditParams(
            dataJson,
            if (status == "ok") { true } else { false },
            affected,
            0,
            errorMessage: errorMessage,
            pluginId: pluginId,
            source: "host.db",
            actorType: resolveAuditActorType(userId, pluginId),
            traceId: traceId
        )
        recordLog(
            "plugin",
            if (operation.isEmpty()) { "execute" } else { operation },
            table,
            params,
            "127.0.0.1",
            "plugin",
            if (userId.isEmpty()) { None<String> } else { Some(userId) }
        )
    }

    /// MCP 调用审计（spec 5.13.1 规则 3）：`module='tool'`
    ///
    /// 与既有 174 条 `module='tool'` 记录同构 —— `operate` 为工具名，`params` 为
    /// `args/result/error` JSON。`source` 区分入口（mcp_open_rest / host.mcp / mcp_cli）。
    public static func recordMcpCallLog(
        mcpAlias: String,
        tool: String,
        argumentsJson: String,
        durationMs: Int64,
        userId!: String = "",
        pluginId!: String = "",
        source!: String = "mcp_open",
        status!: String = "ok",
        errorMessage!: String = ""
    ): Unit {
        let params = buildAuditParams(
            argumentsJson,
            if (status == "ok") { true } else { false },
            0,
            durationMs,
            errorMessage: errorMessage,
            pluginId: pluginId,
            mcpAlias: mcpAlias,
            source: source,
            actorType: resolveAuditActorType(userId, pluginId)
        )
        recordLog(
            "tool",
            tool,
            "/api/v1/uctoo/mcp/open/call",
            params,
            "127.0.0.1",
            "tool",
            if (userId.isEmpty()) { None<String> } else { Some(userId) }
        )
    }

    /// 构造审计 `params` JSON —— 与既有数据格式对齐：
    /// `{"args":{…},"result":{"success":…,"affected":…,"durationMs":…},"error":"…",…}`
    ///
    /// 空值字段一律省略，避免 JSON 塞满空串噪声。
    public static func buildAuditParams(
        argsJson: String,
        success: Bool,
        affected: Int64,
        durationMs: Int64,
        errorMessage!: String = "",
        pluginId!: String = "",
        mcpAlias!: String = "",
        source!: String = "",
        actorType!: String = "",
        traceId!: String = ""
    ): String {
        let sb = StringBuilder()
        sb.append("{\"args\":")
        sb.append(normalizeAuditArgs(argsJson))
        sb.append(",\"result\":{\"success\":")
        sb.append(if (success) { "true" } else { "false" })
        sb.append(",\"affected\":")
        sb.append(affected.toString())
        sb.append(",\"durationMs\":")
        sb.append(durationMs.toString())
        sb.append("}")
        if (!errorMessage.isEmpty()) {
            sb.append(",\"error\":\"" + jsonEscape(truncateAuditText(errorMessage, AUDIT_MAX_ERROR)) + "\"")
        }
        if (!pluginId.isEmpty()) {
            sb.append(",\"pluginId\":\"" + jsonEscape(pluginId) + "\"")
        }
        if (!mcpAlias.isEmpty()) {
            sb.append(",\"mcpAlias\":\"" + jsonEscape(mcpAlias) + "\"")
        }
        if (!source.isEmpty()) {
            sb.append(",\"source\":\"" + jsonEscape(source) + "\"")
        }
        if (!actorType.isEmpty()) {
            sb.append(",\"actorType\":\"" + jsonEscape(actorType) + "\"")
        }
        if (!traceId.isEmpty()) {
            sb.append(",\"traceId\":\"" + jsonEscape(traceId) + "\"")
        }
        sb.append("}")
        sb.toString()
    }

    /// 敏感字段脱敏：把 `<"key":"值">` 形式的值替换为 `***`。
    ///
    /// 与 `SchedulerEngine.sanitizeParameters` 同思路（纯字符串扫描，不用正则）；
    /// 那个服务定时任务参数日志，本方法服务审计表。
    public static func sanitizeAuditText(text: String): String {
        var result = text
        for (key in auditSensitiveKeys()) {
            let patterns = ArrayList<String>()
            patterns.add("\"${key}\":\"")
            patterns.add("\"${key}\": \"")
            for (p in patterns) {
                // 同一 key 可能出现多次；每次替换后原值即消失，循环必然收敛，
                // attempts 仅作为极端输入下的保险丝。
                var attempts = 0
                while (result.contains(p) && attempts < 16) {
                    attempts = attempts + 1
                    let lower = result.toAsciiLower()
                    match (lower.indexOf(p.toAsciiLower())) {
                        case Some(idx) =>
                            let valueStart = idx + p.size
                            let tail = result[valueStart..]
                            match (tail.indexOf("\"")) {
                                case Some(relEnd) =>
                                    result = result[0..valueStart] + "***" + result[valueStart + relEnd..]
                                case None =>
                                    result = result[0..valueStart] + "***"
                            }
                        case None => ()
                    }
                }
            }
        }
        result
    }

    // ── 审计内部实现 ─────────────────────────────────────────────────

    private static func resolveAuditActorType(userId: String, pluginId: String): String {
        if (!userId.isEmpty()) {
            return "user"
        }
        if (!pluginId.isEmpty()) {
            return "plugin"
        }
        "system"
    }

    /// 入参文本规整为可直接嵌入 `params` 的 JSON 片段
    private static func normalizeAuditArgs(text: String): String {
        if (text.isEmpty()) {
            return "{}"
        }
        let sanitized = truncateAuditText(sanitizeAuditText(text.trimAscii()), AUDIT_MAX_SUMMARY)
        if (sanitized.startsWith("{") && sanitized.endsWith("}")) {
            return sanitized
        }
        // 非对象文本（数组 / 裸字符串）退化为 JSON 字符串，避免拼出非法 JSON
        "\"" + jsonEscape(sanitized) + "\""
    }

    /// 截断（超出部分丢弃）
    public static func truncateAuditText(value: String, maxLength: Int64): String {
        if (value.size > maxLength) {
            value[0..maxLength]
        } else {
            value
        }
    }

    /// JSON 字符串值转义（键名固定，值需转义）
    private static func jsonEscape(value: String): String {
        value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
    }

    private static func auditSensitiveKeys(): ArrayList<String> {
        let keys = ArrayList<String>()
        keys.add("password")
        keys.add("passwd")
        keys.add("token")
        keys.add("secret")
        keys.add("api_key")
        keys.add("apikey")
        keys.add("accesskey")
        keys.add("authorization")
        keys.add("credential")
        return keys
    }
}