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
import magic.log.LogUtils

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
     * 更新operate_log
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
     * 删除operate_log
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
     * 根据ID获取operate_log
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
            LogUtils.error("OperateLogService", "getList error: ${e.message}")
            return (ArrayList<OperateLogPO>(), 0)
        }
    }

    /**
     * 获取operate_log列表（分页，支持排序和过滤）
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
            LogUtils.error("OperateLogService", "Failed to get list: ${e.message}")
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
     * 获取operate_log列表（带跳过参数）
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

//#endregion AutoCreateCode
}