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
import magic.app.models.uctoo.UctooUserPO
import magic.app.dao.uctoo.UctooUserDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * UctooUserService - uctoo_user服务类
 *
 * 提供uctoo_user相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UctooUserService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建uctoo_user
     * @param entity UctooUserPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: UctooUserPO, creatorId: String): APIResult<UctooUserPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertUctooUser(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UctooUserPO>(entity)
            } else {
                return APIResult<UctooUserPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }

    /**
     * 更新uctoo_user（无权限检查）
     * @param entityId ID
     * @param entity UctooUserPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: UctooUserPO): APIResult<UctooUserPO> {
        try {
            let existing = getExecutor().findUctooUserById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UctooUserPO>(false, "uctoo_user不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.username.size > 0) {
                existingEntity.username = entity.username
            }
            if (entity.email.size > 0) {
                existingEntity.email = entity.email
            }
            if (entity.password.size > 0) {
                existingEntity.password = entity.password
            }
            if (entity.avatar.isSome()) {
                existingEntity.avatar = entity.avatar
            }
            existingEntity.lastLogin = entity.lastLogin
            existingEntity.authProvider = entity.authProvider
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.lastLoginIp.isSome()) {
                existingEntity.lastLoginIp = entity.lastLoginIp
            }
            existingEntity.lastLoginTime = entity.lastLoginTime
            if (entity.rememberToken.isSome()) {
                existingEntity.rememberToken = entity.rememberToken
            }
            existingEntity.status = entity.status
            if (entity.accessToken.isSome()) {
                existingEntity.accessToken = entity.accessToken
            }
            if (entity.refreshToken.isSome()) {
                existingEntity.refreshToken = entity.refreshToken
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateUctooUser(existingEntity)
            
            if (rows > 0) {
                return APIResult<UctooUserPO>(existingEntity)
            } else {
                return APIResult<UctooUserPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }

    /**
     * 批量更新uctoo_user
     * @param entities uctoo_user列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UctooUserPO>): APIResult<ArrayList<UctooUserPO>> {
        try {
            let updatedEntities = ArrayList<UctooUserPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooUser(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UctooUserPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UctooUserPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UctooUserPO>>(false, e.message)
        }
    }

    /**
     * 删除uctoo_user（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUctooUserById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "uctoo_user不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUctooUserById(entityId)
            } else {
                rows = getExecutor().softDeleteUctooUserById(entityId)
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
     * 批量删除uctoo_user
     * @param ids uctoo_userID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteUctooUser(ids)
            } else {
                rows = getExecutor().batchSoftDeleteUctooUser(ids)
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
     * 恢复软删除的uctoo_user
     * @param entityId uctoo_userID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UctooUserPO> {
        try {
            let rows = getExecutor().restoreUctooUserById(entityId)

            if (rows > 0) {
                let result = getExecutor().findUctooUserById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UctooUserPO>(entity)
                } else {
                    return APIResult<UctooUserPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UctooUserPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的uctoo_user
     * @param ids uctoo_userID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUctooUserById(id)
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
     * 根据ID获取uctoo_user（无权限检查）
     * @param entityId ID
     * @return uctoo_user对象
     */
    public func getById(entityId: String): APIResult<UctooUserPO> {
        try {
            let result = getExecutor().findUctooUserById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<UctooUserPO>(entity)
            } else {
                return APIResult<UctooUserPO>(false, "未找到该uctoo_user")
            }
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }

    /**
     * 获取uctoo_user列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return uctoo_user列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<UctooUserPO>, Int64) {
        try {
            let pagination = getExecutor().findAllUctooUserPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UctooUserPO>(), 0)
        }
    }

    /**
     * 获取uctoo_user列表（分页，支持排序和过滤，无权限过滤）
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
     * @return uctoo_user列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooUserPO>, Int64) {
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
            let pagination = getExecutor().findUctooUserByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UctooUserPO>(), 0)
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
     * 获取uctoo_user列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return uctoo_user列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<UctooUserPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "uctoo_user")

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
            let pagination = getExecutor().findUctooUserByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UctooUserPO>(), 0)
        }
    }

    /**
     * 获取uctoo_user列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return uctoo_user列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooUserPO>, Int64) {
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
            let pagination = getExecutor().findUctooUserByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UctooUserPO>(), 0)
        }
    }

    /**
     * 获取所有uctoo_user列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return uctoo_user列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UctooUserPO>, Int64) {
        let pagination = getExecutor().findAllUctooUserPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取uctoo_user
     * @param ids ID列表
     * @return uctoo_user列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UctooUserPO> {
        getExecutor().findUctooUserByIds(ids)
    }

    /**
     * 统计用户的uctoo_user数量
     * @param userId 用户ID
     * @return uctoo_user数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUctooUserByCreator(userId)
    }

    /**
     * 统计所有uctoo_user数量
     * @return uctoo_user数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUctooUser()
    }

    /**
     * 获取uctoo_user列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return uctoo_user列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<UctooUserPO>, Int64) {
        let pagination = getExecutor().findUctooUserByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的uctoo_user）
     * @return 删除结果
     */
    public func emptyRecycleBinUctooUser(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinUctooUser()

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

    public func createWithPermission(entity: UctooUserPO, creatorId: String): APIResult<UctooUserPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "uctoo_user")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<UctooUserPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "uctoo_user")
            if (!hasPermission) {
                return APIResult<UctooUserPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<UctooUserPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "uctoo_user")

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

            let pagination = getExecutor().findUctooUserByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<UctooUserPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: UctooUserPO, userId: String): APIResult<UctooUserPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "uctoo_user")
            if (!hasPermission) {
                return APIResult<UctooUserPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "uctoo_user")
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
     * 根据用户名查找用户
     * @param username 用户名
     * @return 用户对象
     */
    public func findByUsername(username: String): ?UctooUserPO {
        try {
            getExecutor().findUctooUserByUsername(username)
        } catch (e: Exception) {
            LogUtils.error("findByUsername failed: ${e.message}")
            None<UctooUserPO>
        }
    }
    
    /**
     * 根据邮箱查找用户
     * @param email 邮箱
     * @return 用户对象
     */
    public func findByEmail(email: String): ?UctooUserPO {
        try {
            getExecutor().findUctooUserByEmail(email)
        } catch (e: Exception) {
            LogUtils.error("findByEmail failed: ${e.message}")
            None<UctooUserPO>
        }
    }
    
    /**
     * 更新用户的access_token和refresh_token
     * @param userId 用户ID
     * @param accessToken access_token
     * @param refreshToken refresh_token
     * @return 更新是否成功
     */
    public func updateTokens(userId: String, accessToken: String, refreshToken: String): Bool {
        try {
            let existing = getExecutor().findUctooUserById(userId)
            if (let Some(user) <- existing) {
                user.accessToken = Some<String>(accessToken)
                user.refreshToken = Some<String>(refreshToken)
                user.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooUser(user)
                return rows > 0
            }
            false
        } catch (e: Exception) {
            LogUtils.error("updateTokens failed: ${e.message}")
            false
        }
    }
    
    /**
     * 更新用户access_token
     * @param userId 用户ID
     * @param accessToken access_token
     * @return 更新是否成功
     */
    public func updateAccessToken(userId: String, accessToken: String): Bool {
        try {
            let existing = getExecutor().findUctooUserById(userId)
            if (let Some(user) <- existing) {
                user.accessToken = Some<String>(accessToken)
                user.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooUser(user)
                return rows > 0
            }
            false
        } catch (e: Exception) {
            LogUtils.error("updateAccessToken failed: ${e.message}")
            false
        }
    }
}
