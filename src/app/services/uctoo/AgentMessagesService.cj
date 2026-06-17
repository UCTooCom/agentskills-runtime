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
import magic.app.models.uctoo.AgentMessagesPO
import magic.app.dao.uctoo.AgentMessagesDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * AgentMessagesService - agent_messages服务类
 *
 * 提供agent_messages相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class AgentMessagesService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建agent_messages
     * @param entity AgentMessagesPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: AgentMessagesPO, creatorId: String): APIResult<AgentMessagesPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // 只在 creator 为空且 creatorId 是有效 UUID 时才设置
            // 空字符串或非 UUID 格式的 creatorId 保持为 None（表示系统/匿名用户）
            if (entity.creator.isNone() && !creatorId.isEmpty() && isValidUUID(creatorId)) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertAgentMessages(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<AgentMessagesPO>(entity)
            } else {
                return APIResult<AgentMessagesPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentMessagesPO>(false, e.message)
        }
    }

    /**
     * 验证字符串是否为有效的 UUID 格式
     * UUID 格式：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
     */
    private func isValidUUID(str: String): Bool {
        // UUID 固定长度为 36
        if (str.size != 36) {
            return false
        }
        
        // 检查分隔符位置：第9、14、19、24个字符应该是 '-'
        // 使用 [start..end] 切片语法获取单字符字符串进行比较
        if (str[8..9] != "-" || str[13..14] != "-" || str[18..19] != "-" || str[23..24] != "-") {
            return false
        }
        
        // 检查是否只包含有效字符（0-9, a-f, A-F, -）
        let validChars = "0123456789abcdefABCDEF"
        let chars = str.toArray()
        for (c in chars) {
            let charStr = c.toString()
            if (!validChars.contains(charStr)) {
                return false
            }
        }
        
        return true
    }

    /**
     * 更新agent_messages（无权限检查）
     * @param entityId ID
     * @param entity AgentMessagesPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: AgentMessagesPO): APIResult<AgentMessagesPO> {
        try {
            let existing = getExecutor().findAgentMessagesById(entityId)
            
            if (existing.isNone()) {
                return APIResult<AgentMessagesPO>(false, "agent_messages不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.fromAgentId.isSome()) {
                existingEntity.fromAgentId = entity.fromAgentId
            }
            if (entity.toAgentId.isSome()) {
                existingEntity.toAgentId = entity.toAgentId
            }
            if (entity.taskId.isSome()) {
                existingEntity.taskId = entity.taskId
            }
            if (entity.messageType.size > 0) {
                existingEntity.messageType = entity.messageType
            }
            if (entity.content.isSome()) {
                existingEntity.content = entity.content
            }
            if (entity.status.isSome()) {
                existingEntity.status = entity.status
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
            
            let rows = getExecutor().updateAgentMessages(existingEntity)
            
            if (rows > 0) {
                return APIResult<AgentMessagesPO>(existingEntity)
            } else {
                return APIResult<AgentMessagesPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentMessagesPO>(false, e.message)
        }
    }

    /**
     * 批量更新agent_messages
     * @param entities agent_messages列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<AgentMessagesPO>): APIResult<ArrayList<AgentMessagesPO>> {
        try {
            let updatedEntities = ArrayList<AgentMessagesPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateAgentMessages(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<AgentMessagesPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<AgentMessagesPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<AgentMessagesPO>>(false, e.message)
        }
    }

    /**
     * 删除agent_messages（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findAgentMessagesById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "agent_messages不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteAgentMessagesById(entityId)
            } else {
                rows = getExecutor().softDeleteAgentMessagesById(entityId)
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
     * 批量删除agent_messages
     * @param ids agent_messagesID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteAgentMessages(ids)
            } else {
                rows = getExecutor().batchSoftDeleteAgentMessages(ids)
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
     * 恢复软删除的agent_messages
     * @param entityId agent_messagesID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<AgentMessagesPO> {
        try {
            let rows = getExecutor().restoreAgentMessagesById(entityId)

            if (rows > 0) {
                let result = getExecutor().findAgentMessagesById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<AgentMessagesPO>(entity)
                } else {
                    return APIResult<AgentMessagesPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<AgentMessagesPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentMessagesPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的agent_messages
     * @param ids agent_messagesID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreAgentMessagesById(id)
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
     * 根据ID获取agent_messages（无权限检查）
     * @param entityId ID
     * @return agent_messages对象
     */
    public func getById(entityId: String): APIResult<AgentMessagesPO> {
        try {
            let result = getExecutor().findAgentMessagesById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<AgentMessagesPO>(entity)
            } else {
                return APIResult<AgentMessagesPO>(false, "未找到该agent_messages")
            }
        } catch (e: Exception) {
            return APIResult<AgentMessagesPO>(false, e.message)
        }
    }

    /**
     * 获取agent_messages列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_messages列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<AgentMessagesPO>, Int64) {
        try {
            let pagination = getExecutor().findAllAgentMessagesPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentMessagesPO>(), 0)
        }
    }

    /**
     * 获取agent_messages列表（分页，支持排序和过滤，无权限过滤）
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
     * @return agent_messages列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentMessagesPO>, Int64) {
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
            let pagination = getExecutor().findAgentMessagesByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentMessagesPO>(), 0)
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
     * 获取agent_messages列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return agent_messages列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentMessagesPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_messages")

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
            let pagination = getExecutor().findAgentMessagesByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentMessagesPO>(), 0)
        }
    }

    /**
     * 获取agent_messages列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return agent_messages列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentMessagesPO>, Int64) {
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
            let pagination = getExecutor().findAgentMessagesByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentMessagesPO>(), 0)
        }
    }

    /**
     * 获取所有agent_messages列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_messages列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<AgentMessagesPO>, Int64) {
        let pagination = getExecutor().findAllAgentMessagesPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取agent_messages
     * @param ids ID列表
     * @return agent_messages列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<AgentMessagesPO> {
        getExecutor().findAgentMessagesByIds(ids)
    }

    /**
     * 统计用户的agent_messages数量
     * @param userId 用户ID
     * @return agent_messages数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countAgentMessagesByCreator(userId)
    }

    /**
     * 统计所有agent_messages数量
     * @return agent_messages数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllAgentMessages()
    }

    /**
     * 获取agent_messages列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return agent_messages列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<AgentMessagesPO>, Int64) {
        let pagination = getExecutor().findAgentMessagesByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_messages）
     * @return 删除结果
     */
    public func emptyRecycleBinAgentMessages(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinAgentMessages()

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

    public func createWithPermission(entity: AgentMessagesPO, creatorId: String): APIResult<AgentMessagesPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "agent_messages")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<AgentMessagesPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "agent_messages")
            if (!hasPermission) {
                return APIResult<AgentMessagesPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<AgentMessagesPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentMessagesPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_messages")

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

            let pagination = getExecutor().findAgentMessagesByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentMessagesPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: AgentMessagesPO, userId: String): APIResult<AgentMessagesPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_messages")
            if (!hasPermission) {
                return APIResult<AgentMessagesPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<AgentMessagesPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_messages")
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
}
