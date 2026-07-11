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
import magic.app.models.uctoo.MessagesPO
import magic.app.dao.uctoo.MessagesDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * MessagesService - messages服务类
 *
 * 提供messages相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class MessagesService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建messages
     * @param entity MessagesPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: MessagesPO, creatorId: String): APIResult<MessagesPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertMessages(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<MessagesPO>(entity)
            } else {
                return APIResult<MessagesPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<MessagesPO>(false, e.message)
        }
    }

    /**
     * 更新messages（无权限检查）
     * @param entityId ID
     * @param entity MessagesPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: MessagesPO): APIResult<MessagesPO> {
        try {
            let existing = getExecutor().findMessagesById(entityId)
            
            if (existing.isNone()) {
                return APIResult<MessagesPO>(false, "messages不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.userId.size > 0) {
                existingEntity.userId = entity.userId
            }
            if (entity.senderId.isSome()) {
                existingEntity.senderId = entity.senderId
            }
            if (entity.messageType.size > 0) {
                existingEntity.messageType = entity.messageType
            }
            if (entity.title.size > 0) {
                existingEntity.title = entity.title
            }
            if (entity.content.size > 0) {
                existingEntity.content = entity.content
            }
            if (entity.msgRelatedType.isSome()) {
                existingEntity.msgRelatedType = entity.msgRelatedType
            }
            if (entity.relatedId.isSome()) {
                existingEntity.relatedId = entity.relatedId
            }
            existingEntity.isRead = entity.isRead
            if (entity.readAt.isSome()) {
                existingEntity.readAt = entity.readAt
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
            
            let rows = getExecutor().updateMessages(existingEntity)
            
            if (rows > 0) {
                return APIResult<MessagesPO>(existingEntity)
            } else {
                return APIResult<MessagesPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<MessagesPO>(false, e.message)
        }
    }

    /**
     * 批量更新messages
     * @param entities messages列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<MessagesPO>): APIResult<ArrayList<MessagesPO>> {
        try {
            let updatedEntities = ArrayList<MessagesPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateMessages(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<MessagesPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<MessagesPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<MessagesPO>>(false, e.message)
        }
    }

    /**
     * 删除messages（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findMessagesById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "messages不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteMessagesById(entityId)
            } else {
                rows = getExecutor().softDeleteMessagesById(entityId)
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
     * 批量删除messages
     * @param ids messagesID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteMessages(ids)
            } else {
                rows = getExecutor().batchSoftDeleteMessages(ids)
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
     * 恢复软删除的messages
     * @param entityId messagesID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<MessagesPO> {
        try {
            let rows = getExecutor().restoreMessagesById(entityId)

            if (rows > 0) {
                let result = getExecutor().findMessagesById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<MessagesPO>(entity)
                } else {
                    return APIResult<MessagesPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<MessagesPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<MessagesPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的messages
     * @param ids messagesID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreMessagesById(id)
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
     * 根据ID获取messages（无权限检查）
     * @param entityId ID
     * @return messages对象
     */
    public func getById(entityId: String): APIResult<MessagesPO> {
        try {
            let result = getExecutor().findMessagesById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<MessagesPO>(entity)
            } else {
                return APIResult<MessagesPO>(false, "未找到该messages")
            }
        } catch (e: Exception) {
            return APIResult<MessagesPO>(false, e.message)
        }
    }

    /**
     * 获取messages列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return messages列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<MessagesPO>, Int64) {
        try {
            let pagination = getExecutor().findAllMessagesPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<MessagesPO>(), 0)
        }
    }

    /**
     * 获取messages列表（分页，支持排序和过滤，无权限过滤）
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
     * @return messages列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<MessagesPO>, Int64) {
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
            let pagination = getExecutor().findMessagesByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<MessagesPO>(), 0)
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
     * 获取messages列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return messages列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<MessagesPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "messages")

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
            let pagination = getExecutor().findMessagesByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<MessagesPO>(), 0)
        }
    }

    /**
     * 获取messages列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return messages列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<MessagesPO>, Int64) {
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
            let pagination = getExecutor().findMessagesByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<MessagesPO>(), 0)
        }
    }

    /**
     * 获取所有messages列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return messages列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<MessagesPO>, Int64) {
        let pagination = getExecutor().findAllMessagesPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取messages
     * @param ids ID列表
     * @return messages列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<MessagesPO> {
        getExecutor().findMessagesByIds(ids)
    }

    /**
     * 统计用户的messages数量
     * @param userId 用户ID
     * @return messages数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countMessagesByCreator(userId)
    }

    /**
     * 统计所有messages数量
     * @return messages数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllMessages()
    }

    /**
     * 获取messages列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return messages列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<MessagesPO>, Int64) {
        let pagination = getExecutor().findMessagesByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的messages）
     * @return 删除结果
     */
    public func emptyRecycleBinMessages(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinMessages()

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

    public func createWithPermission(entity: MessagesPO, creatorId: String): APIResult<MessagesPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "messages")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<MessagesPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "messages")
            if (!hasPermission) {
                return APIResult<MessagesPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<MessagesPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<MessagesPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "messages")

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

            let pagination = getExecutor().findMessagesByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<MessagesPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: MessagesPO, userId: String): APIResult<MessagesPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "messages")
            if (!hasPermission) {
                return APIResult<MessagesPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<MessagesPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "messages")
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

    // ==================== 消息通知与已读管理方法 ====================

    /**
     * 发送一条消息通知
     * @param userId 接收者ID
     * @param senderId 发送者ID（系统消息传 None）
     * @param messageType 消息类型（system/task/company/settlement 等）
     * @param title 标题
     * @param content 内容
     * @param relatedType 关联类型（task/company/settlement 等）
     * @param relatedId 关联ID
     * @return 创建结果
     */
    public func sendNotification(
        userId: String,
        senderId: Option<String>,
        messageType: String,
        title: String,
        content: String,
        relatedType: Option<String>,
        relatedId: Option<String>
    ): APIResult<MessagesPO> {
        try {
            let entity = MessagesPO()
            entity.userId = userId
            entity.senderId = senderId
            entity.messageType = messageType
            entity.title = title
            entity.content = content
            entity.msgRelatedType = relatedType
            entity.relatedId = relatedId
            entity.isRead = false
            entity.readAt = None<DateTime>
            entity.creator = senderId
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()

            let executor = getExecutor()
            let id = executor.insertMessages(entity)
            if (id.isEmpty()) {
                return APIResult<MessagesPO>(false, "消息写入失败")
            }
            entity.id = id
            return APIResult<MessagesPO>(entity)
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "发送消息通知失败: ${e.message}")
            return APIResult<MessagesPO>(false, e.message)
        }
    }

    /**
     * 查询用户消息列表（分页）
     * @param userId 用户ID
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param messageType 消息类型筛选（空字符串表示不筛选）
     * @return 消息列表和总数
     */
    public func getUserMessages(userId: String, page: Int64, pageSize: Int64, messageType: String): (ArrayList<MessagesPO>, Int64) {
        try {
            let executor = getExecutor()
            let pagination = executor.queryMessagesByUserId(userId, page, pageSize, messageType)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "查询用户消息失败: ${e.message}")
            return (ArrayList<MessagesPO>(), 0)
        }
    }

    /**
     * 我的消息列表（Prisma风格）
     * @param userId 用户ID
     * @param page 页码
     * @param pageSize 每页数量
     * @param sort 排序字段
     * @param filter 过滤条件
     * @return 消息列表和总数
     */
    public func getMyMessagesWithFilter(
        userId: String,
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<MessagesPO>, Int64) {
        try {
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            var myWhere = "user_id = '${userId}' and deleted_at is null"
            if (!whereClause.isEmpty()) {
                myWhere = myWhere + " and (" + whereClause + ")"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)
            var finalOrderBy = orderByClause
            if (finalOrderBy.isEmpty()) {
                finalOrderBy = "order by created_at desc"
            }

            let pagination = getExecutor().findMessagesByCondition(
                myWhere,
                finalOrderBy,
                Int64(page),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "getMyMessagesWithFilter error: ${e.message}")
            return (ArrayList<MessagesPO>(), 0)
        }
    }

    /**
     * 获取用户未读消息数
     * @param userId 用户ID
     * @return 未读消息数
     */
    public func getUnreadCount(userId: String): Int64 {
        try {
            return getExecutor().countUnread(userId)
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "获取未读消息数失败: ${e.message}")
            return 0
        }
    }

    /**
     * 将单条消息标记为已读
     * @param msgId 消息ID
     * @param userId 用户ID（用于权限校验）
     * @return 影响行数
     */
    public func markAsRead(msgId: String, userId: String): Int64 {
        try {
            return getExecutor().markAsRead(msgId, userId)
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "标记消息已读失败: ${e.message}")
            return 0
        }
    }

    /**
     * 将用户所有未读消息标记为已读
     * @param userId 用户ID
     * @return 影响行数
     */
    public func markAllAsRead(userId: String): Int64 {
        try {
            return getExecutor().markAllAsRead(userId)
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "标记所有消息已读失败: ${e.message}")
            return 0
        }
    }

    /**
     * 批量通知任务关注者
     * @param taskId 任务ID
     * @param title 标题
     * @param content 内容
     * @param senderId 发送者ID（可None）
     * @return 发送成功的数量
     */
    public func notifyTaskFollowers(taskId: String, title: String, content: String, senderId: Option<String>): Int64 {
        try {
            let executor = getExecutor()
            let followerIds = executor.findFollowerIdsByTaskId(taskId)
            var sentCount: Int64 = 0
            for (uid in followerIds) {
                let result = sendNotification(
                    uid,
                    senderId,
                    "task",
                    title,
                    content,
                    Some<String>("task"),
                    Some<String>(taskId)
                )
                if (result.success) {
                    sentCount = sentCount + 1
                }
            }
            return sentCount
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "通知任务关注者失败: ${e.message}")
            return 0
        }
    }

    /**
     * 批量通知组织成员
     * @param companyId 组织ID
     * @param title 标题
     * @param content 内容
     * @param senderId 发送者ID（可None）
     * @return 发送成功的数量
     */
    public func notifyCompanyMembers(companyId: String, title: String, content: String, senderId: Option<String>): Int64 {
        try {
            let executor = getExecutor()
            let memberIds = executor.findMemberIdsByCompanyId(companyId)
            var sentCount: Int64 = 0
            for (uid in memberIds) {
                let result = sendNotification(
                    uid,
                    senderId,
                    "company",
                    title,
                    content,
                    Some<String>("company"),
                    Some<String>(companyId)
                )
                if (result.success) {
                    sentCount = sentCount + 1
                }
            }
            return sentCount
        } catch (e: Exception) {
            LogUtils.error("MessagesService", "通知组织成员失败: ${e.message}")
            return 0
        }
    }
}
