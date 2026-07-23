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
import magic.app.models.uctoo.ConfigPO
import magic.app.dao.uctoo.ConfigDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * ConfigService - config服务类
 *
 * 提供config相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class ConfigService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建config
     * @param entity ConfigPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: ConfigPO, creatorId: String): APIResult<ConfigPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertConfig(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<ConfigPO>(entity)
            } else {
                return APIResult<ConfigPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<ConfigPO>(false, e.message)
        }
    }

    /**
     * 更新config（无权限检查）
     * @param entityId ID
     * @param entity ConfigPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: ConfigPO): APIResult<ConfigPO> {
        try {
            let existing = getExecutor().findConfigById(entityId)
            
            if (existing.isNone()) {
                return APIResult<ConfigPO>(false, "config不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.parentId.isSome()) {
                existingEntity.parentId = entity.parentId
            }
            if (entity.component.size > 0) {
                existingEntity.component = entity.component
            }
            if (entity.key.size > 0) {
                existingEntity.key = entity.key
            }
            if (entity.value.isSome()) {
                existingEntity.value = entity.value
            }
            existingEntity.status = entity.status
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.envKey.isSome()) {
                existingEntity.envKey = entity.envKey
            }
            if (entity.configGroup.isSome()) {
                existingEntity.configGroup = entity.configGroup
            }
            if (entity.configType.isSome()) {
                existingEntity.configType = entity.configType
            }
            if (entity.isSensitive.isSome()) {
                existingEntity.isSensitive = entity.isSensitive
            }
            if (entity.defaultValue.isSome()) {
                existingEntity.defaultValue = entity.defaultValue
            }
            if (entity.validationRule.isSome()) {
                existingEntity.validationRule = entity.validationRule
            }
            if (entity.description.isSome()) {
                existingEntity.description = entity.description
            }
            if (entity.displayOrder.isSome()) {
                existingEntity.displayOrder = entity.displayOrder
            }
            if (entity.editable.isSome()) {
                existingEntity.editable = entity.editable
            }
            if (entity.lastSyncedAt.isSome()) {
                existingEntity.lastSyncedAt = entity.lastSyncedAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateConfig(existingEntity)
            
            if (rows > 0) {
                return APIResult<ConfigPO>(existingEntity)
            } else {
                return APIResult<ConfigPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ConfigPO>(false, e.message)
        }
    }

    /**
     * 批量更新config
     * @param entities config列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<ConfigPO>): APIResult<ArrayList<ConfigPO>> {
        try {
            let updatedEntities = ArrayList<ConfigPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateConfig(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<ConfigPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<ConfigPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<ConfigPO>>(false, e.message)
        }
    }

    /**
     * 删除config（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findConfigById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "config不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteConfigById(entityId)
            } else {
                rows = getExecutor().softDeleteConfigById(entityId)
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
     * 批量删除config
     * @param ids configID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteConfig(ids)
            } else {
                rows = getExecutor().batchSoftDeleteConfig(ids)
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
     * 恢复软删除的config
     * @param entityId configID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<ConfigPO> {
        try {
            let rows = getExecutor().restoreConfigById(entityId)

            if (rows > 0) {
                let result = getExecutor().findConfigById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<ConfigPO>(entity)
                } else {
                    return APIResult<ConfigPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<ConfigPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<ConfigPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的config
     * @param ids configID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreConfigById(id)
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
     * 根据ID获取config（无权限检查）
     * @param entityId ID
     * @return config对象
     */
    public func getById(entityId: String): APIResult<ConfigPO> {
        try {
            let result = getExecutor().findConfigById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<ConfigPO>(entity)
            } else {
                return APIResult<ConfigPO>(false, "未找到该config")
            }
        } catch (e: Exception) {
            return APIResult<ConfigPO>(false, e.message)
        }
    }

    /**
     * 获取config列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return config列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<ConfigPO>, Int64) {
        try {
            let pagination = getExecutor().findAllConfigPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<ConfigPO>(), 0)
        }
    }

    /**
     * 获取config列表（分页，支持排序和过滤，无权限过滤）
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
     * @return config列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<ConfigPO>, Int64) {
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
            let pagination = getExecutor().findConfigByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<ConfigPO>(), 0)
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
     * 获取config列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return config列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<ConfigPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "config")

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
            let pagination = getExecutor().findConfigByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<ConfigPO>(), 0)
        }
    }

    /**
     * 获取config列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return config列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<ConfigPO>, Int64) {
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
            let pagination = getExecutor().findConfigByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<ConfigPO>(), 0)
        }
    }

    /**
     * 获取所有config列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return config列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<ConfigPO>, Int64) {
        let pagination = getExecutor().findAllConfigPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取config
     * @param ids ID列表
     * @return config列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<ConfigPO> {
        getExecutor().findConfigByIds(ids)
    }

    /**
     * 统计用户的config数量
     * @param userId 用户ID
     * @return config数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countConfigByCreator(userId)
    }

    /**
     * 统计所有config数量
     * @return config数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllConfig()
    }

    /**
     * 获取config列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return config列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<ConfigPO>, Int64) {
        let pagination = getExecutor().findConfigByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的config）
     * @return 删除结果
     */
    public func emptyRecycleBinConfig(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinConfig()

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

    public func createWithPermission(entity: ConfigPO, creatorId: String): APIResult<ConfigPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "config")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<ConfigPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "config")
            if (!hasPermission) {
                return APIResult<ConfigPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<ConfigPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<ConfigPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "config")

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

            let pagination = getExecutor().findConfigByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<ConfigPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: ConfigPO, userId: String): APIResult<ConfigPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "config")
            if (!hasPermission) {
                return APIResult<ConfigPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<ConfigPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "config")
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

    private let envFileService = EnvFileService()
    private let configValidator = ConfigValidator()


    public func getConfigByKey(envKey: String): APIResult<ConfigPO> {
        try {
            let result = getExecutor().findConfigByEnvKey(envKey)
            match (result) {
                case Some(entity) =>
                    if (match (entity.isSensitive) { case Some(v) => v; case None => false }) {
                        entity.value = Some(maskSensitiveValue(entity.value.getOrThrow()))
                    }
                    APIResult<ConfigPO>(entity)
                case None =>
                    APIResult<ConfigPO>(false, "Config not found for env_key: ${envKey}")
            }
        } catch (e: Exception) {
            APIResult<ConfigPO>(false, "Failed to get config by key: ${e.message}")
        }
    }

    public func getConfigsByGroup(group: String): APIResult<ArrayList<ConfigPO>> {
        try {
            let configs = getExecutor().findConfigsByGroup(group)
            for (config in configs) {
                if (match (config.isSensitive) { case Some(v) => v; case None => false }) {
                    config.value = Some(maskSensitiveValue(config.value.getOrThrow()))
                }
            }
            APIResult<ArrayList<ConfigPO>>(configs)
        } catch (e: Exception) {
            APIResult<ArrayList<ConfigPO>>(false, "Failed to get configs by group: ${e.message}")
        }
    }

    public func getAllConfigs(): APIResult<ArrayList<ConfigPO>> {
        try {
            let configs = getExecutor().findAllEnvConfigs()
            for (config in configs) {
                if (match (config.isSensitive) { case Some(v) => v; case None => false }) {
                    config.value = Some(maskSensitiveValue(config.value.getOrThrow()))
                }
            }
            APIResult<ArrayList<ConfigPO>>(configs)
        } catch (e: Exception) {
            APIResult<ArrayList<ConfigPO>>(false, "Failed to get all configs: ${e.message}")
        }
    }

    public func getConfigMetadata(): APIResult<ArrayList<ConfigMetadataVO>> {
        try {
            let configs = getExecutor().findAllEnvConfigs()
            let metadataList = ArrayList<ConfigMetadataVO>()
            for (config in configs) {
                let vo = ConfigMetadataVO()
                vo.envKey = config.envKey.getOrThrow()
                vo.name = config.name
                vo.configGroup = config.configGroup.getOrThrow()
                vo.configType = config.configType.getOrThrow()
                vo.isSensitive = match (config.isSensitive) { case Some(v) => v; case None => false }
                vo.defaultValue = config.defaultValue
                vo.validationRule = config.validationRule
                vo.description = config.description
                vo.displayOrder = match (config.displayOrder) { case Some(v) => v; case None => 0 }
                vo.editable = match (config.editable) { case Some(v) => v; case None => true }
                metadataList.add(vo)
            }
            APIResult<ArrayList<ConfigMetadataVO>>(metadataList)
        } catch (e: Exception) {
            APIResult<ArrayList<ConfigMetadataVO>>(false, "Failed to get config metadata: ${e.message}")
        }
    }

    public func updateConfigByKey(envKey: String, value: String, operatorId: String, channel: String): APIResult<ConfigPO> {
        try {
            let existing = getExecutor().findConfigByEnvKey(envKey)
            match (existing) {
                case Some(entity) =>
                    if (!match (entity.editable) { case Some(v) => v; case None => true }) {
                        return APIResult<ConfigPO>(false, "Config ${envKey} is not editable")
                    }
                    let configType = entity.configType.getOrThrow()
                    let validationRule = entity.validationRule
                    let vr = configValidator.validate(configType, validationRule, value)
                    if (!vr.isValid) {
                        return APIResult<ConfigPO>(false, "CONFIG_VALIDATION_FAILED: ${vr.errorMessage.getOrThrow()}")
                    }
                    let envPath = envFileService.getEnvFilePath()
                    if (!envFileService.envFileExists(envPath)) {
                        return APIResult<ConfigPO>(false, "CONFIG_ENV_FILE_NOT_FOUND: ${envPath}")
                    }
                    let backupPath = envFileService.backupEnvFile(envPath)
                    let writeOk = envFileService.writeEnvKeyValue(envPath, envKey, value)
                    if (!writeOk) {
                        if (let Some(bp) <- backupPath) {
                            envFileService.restoreBackup(bp, envPath)
                        }
                        return APIResult<ConfigPO>(false, "CONFIG_WRITE_FAILED: Failed to write .env file")
                    }
                    entity.value = Some(value)
                    entity.lastSyncedAt = Some(DateTime.now())
                    getExecutor().updateConfig(entity)
                    LogUtils.info("ConfigService", "Config ${envKey} updated by ${operatorId} via ${channel}")
                    APIResult<ConfigPO>(entity)
                case None =>
                    APIResult<ConfigPO>(false, "Config not found for env_key: ${envKey}")
            }
        } catch (e: Exception) {
            APIResult<ConfigPO>(false, "Failed to update config by key: ${e.message}")
        }
    }

    public func batchUpdateConfigs(items: ArrayList<ConfigUpdateItem>, operatorId: String, channel: String): APIResult<ArrayList<ConfigPO>> {
        try {
            let results = ArrayList<ConfigPO>()
            for (item in items) {
                let r = updateConfigByKey(item.envKey, item.value, operatorId, channel)
                if (r.success && r.data.isSome()) {
                    results.add(r.data.getOrThrow())
                }
            }
            APIResult<ArrayList<ConfigPO>>(results)
        } catch (e: Exception) {
            APIResult<ArrayList<ConfigPO>>(false, "Failed to batch update configs: ${e.message}")
        }
    }

    public func exportConfig(format: String): APIResult<String> {
        try {
            let configs = getExecutor().findAllEnvConfigs()
            if (format == "env") {
                let sb = StringBuilder()
                for (config in configs) {
                    let key = config.envKey.getOrThrow()
                    let value = config.value.getOrThrow()
                    sb.append(key + "=" + value + "\n")
                }
                APIResult<String>(sb.toString())
            } else {
                let sb = StringBuilder()
                sb.append("{")
                var first = true
                for (config in configs) {
                    if (!first) {
                        sb.append(",")
                    }
                    let key = config.envKey.getOrThrow()
                    let value = config.value.getOrThrow()
                    sb.append("\"" + key + "\":\"" + value + "\"")
                    first = false
                }
                sb.append("}")
                APIResult<String>(sb.toString())
            }
        } catch (e: Exception) {
            APIResult<String>(false, "Failed to export config: ${e.message}")
        }
    }

    public func importConfig(data: String, format: String, operatorId: String): APIResult<Bool> {
        try {
            if (format == "env") {
                let lines = envFileService.parseEnvFile(data)
                let items = ArrayList<ConfigUpdateItem>()
                for (line in lines) {
                    if (line.isKeyValue()) {
                        if (let Some(k) <- line.key) {
                            if (let Some(v) <- line.value) {
                                let item = ConfigUpdateItem()
                                item.envKey = k
                                item.value = v
                                items.add(item)
                            }
                        }
                    }
                }
                let r = batchUpdateConfigs(items, operatorId, "import")
                APIResult<Bool>(r.success)
            } else {
                APIResult<Bool>(false, "Import format not supported: ${format}")
            }
        } catch (e: Exception) {
            APIResult<Bool>(false, "Failed to import config: ${e.message}")
        }
    }

    public func maskSensitiveValue(value: String): String {
        if (value.size <= 8) {
            return "******"
        }
        value[0..4] + "****" + value[value.size - 4..value.size]
    }

    public func syncFromEnvFile(): APIResult<Bool> {
        try {
            let envPath = envFileService.getEnvFilePath()
            if (!envFileService.envFileExists(envPath)) {
                return APIResult<Bool>(false, "CONFIG_ENV_FILE_NOT_FOUND: ${envPath}")
            }
            let envValues = envFileService.readAllEnvValues(envPath)
            for ((key, value) in envValues) {
                let existing = getExecutor().findConfigByEnvKey(key)
                match (existing) {
                    case Some(entity) =>
                        entity.value = Some(value)
                        entity.lastSyncedAt = Some(DateTime.now())
                        getExecutor().updateConfig(entity)
                    case None =>
                        let newEntity = ConfigPO()
                        newEntity.name = key
                        newEntity.key = key
                        newEntity.envKey = Some(key)
                        newEntity.value = Some(value)
                        newEntity.configGroup = Some("other")
                        newEntity.configType = Some("string")
                        newEntity.isSensitive = Some(false)
                        newEntity.editable = Some(true)
                        newEntity.displayOrder = Some(Int32(0))
                        newEntity.status = 1
                        newEntity.lastSyncedAt = Some(DateTime.now())
                        getExecutor().insertConfig(newEntity)
                }
            }
            LogUtils.info("ConfigService", "Synced ${envValues.size} config items from .env file")
            APIResult<Bool>(true)
        } catch (e: Exception) {
            APIResult<Bool>(false, "Failed to sync from env file: ${e.message}")
        }
    }
}
