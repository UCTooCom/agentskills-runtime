/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// Ch13.4：web_request_approval 通道的审批结果快照（tool 层产出、此处消费）
// 依赖方向 app.services.uctoo → tool.webmcp 与仓库既有写法一致（app 下多处已 import magic.tool.webmcp），
// 且 tool.webmcp 无任何 `import magic.app.*`，不构成循环依赖。
import magic.tool.webmcp.ApprovalDecisionRecord

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.AgentApprovalsPO
import magic.app.dao.uctoo.AgentApprovalsDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * AgentApprovalsService - agent_approvals服务类
 *
 * 提供agent_approvals相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class AgentApprovalsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建agent_approvals
     * @param entity AgentApprovalsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: AgentApprovalsPO, creatorId: String): APIResult<AgentApprovalsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertAgentApprovals(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<AgentApprovalsPO>(entity)
            } else {
                return APIResult<AgentApprovalsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentApprovalsPO>(false, e.message)
        }
    }

    /**
     * 更新agent_approvals（无权限检查）
     * @param entityId ID
     * @param entity AgentApprovalsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: AgentApprovalsPO): APIResult<AgentApprovalsPO> {
        try {
            let existing = getExecutor().findAgentApprovalsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<AgentApprovalsPO>(false, "agent_approvals不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.agentId.size > 0) {
                existingEntity.agentId = entity.agentId
            }
            if (entity.taskId.size > 0) {
                existingEntity.taskId = entity.taskId
            }
            if (entity.approvalType.size > 0) {
                existingEntity.approvalType = entity.approvalType
            }
            if (entity.content.size > 0) {
                existingEntity.content = entity.content
            }
            if (entity.status.size > 0) {
                existingEntity.status = entity.status
            }
            if (entity.userResponse.isSome()) {
                existingEntity.userResponse = entity.userResponse
            }
            existingEntity.timeoutMs = entity.timeoutMs
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.options.isSome()) {
                existingEntity.options = entity.options
            }
            if (entity.selectedOption.isSome()) {
                existingEntity.selectedOption = entity.selectedOption
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateAgentApprovals(existingEntity)
            
            if (rows > 0) {
                return APIResult<AgentApprovalsPO>(existingEntity)
            } else {
                return APIResult<AgentApprovalsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentApprovalsPO>(false, e.message)
        }
    }

    /**
     * 批量更新agent_approvals
     * @param entities agent_approvals列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<AgentApprovalsPO>): APIResult<ArrayList<AgentApprovalsPO>> {
        try {
            let updatedEntities = ArrayList<AgentApprovalsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateAgentApprovals(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<AgentApprovalsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<AgentApprovalsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<AgentApprovalsPO>>(false, e.message)
        }
    }

    /**
     * 删除agent_approvals（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findAgentApprovalsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "agent_approvals不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteAgentApprovalsById(entityId)
            } else {
                rows = getExecutor().softDeleteAgentApprovalsById(entityId)
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
     * 批量删除agent_approvals
     * @param ids agent_approvalsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteAgentApprovals(ids)
            } else {
                rows = getExecutor().batchSoftDeleteAgentApprovals(ids)
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
     * 恢复软删除的agent_approvals
     * @param entityId agent_approvalsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<AgentApprovalsPO> {
        try {
            let rows = getExecutor().restoreAgentApprovalsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findAgentApprovalsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<AgentApprovalsPO>(entity)
                } else {
                    return APIResult<AgentApprovalsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<AgentApprovalsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentApprovalsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的agent_approvals
     * @param ids agent_approvalsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreAgentApprovalsById(id)
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
     * 根据ID获取agent_approvals（无权限检查）
     * @param entityId ID
     * @return agent_approvals对象
     */
    public func getById(entityId: String): APIResult<AgentApprovalsPO> {
        try {
            let result = getExecutor().findAgentApprovalsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<AgentApprovalsPO>(entity)
            } else {
                return APIResult<AgentApprovalsPO>(false, "未找到该agent_approvals")
            }
        } catch (e: Exception) {
            return APIResult<AgentApprovalsPO>(false, e.message)
        }
    }

    /**
     * 获取agent_approvals列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_approvals列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<AgentApprovalsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllAgentApprovalsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentApprovalsPO>(), 0)
        }
    }

    /**
     * 获取agent_approvals列表（分页，支持排序和过滤，无权限过滤）
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
     * @return agent_approvals列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentApprovalsPO>, Int64) {
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
            let pagination = getExecutor().findAgentApprovalsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentApprovalsPO>(), 0)
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
     * 获取agent_approvals列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return agent_approvals列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentApprovalsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_approvals")

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
            let pagination = getExecutor().findAgentApprovalsByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentApprovalsPO>(), 0)
        }
    }

    /**
     * 获取agent_approvals列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return agent_approvals列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentApprovalsPO>, Int64) {
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
            let pagination = getExecutor().findAgentApprovalsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentApprovalsPO>(), 0)
        }
    }

    /**
     * 获取所有agent_approvals列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_approvals列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<AgentApprovalsPO>, Int64) {
        let pagination = getExecutor().findAllAgentApprovalsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取agent_approvals
     * @param ids ID列表
     * @return agent_approvals列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<AgentApprovalsPO> {
        getExecutor().findAgentApprovalsByIds(ids)
    }

    /**
     * 统计用户的agent_approvals数量
     * @param userId 用户ID
     * @return agent_approvals数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countAgentApprovalsByCreator(userId)
    }

    /**
     * 统计所有agent_approvals数量
     * @return agent_approvals数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllAgentApprovals()
    }

    /**
     * 获取agent_approvals列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return agent_approvals列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<AgentApprovalsPO>, Int64) {
        let pagination = getExecutor().findAgentApprovalsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_approvals）
     * @return 删除结果
     */
    public func emptyRecycleBinAgentApprovals(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinAgentApprovals()

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

    public func createWithPermission(entity: AgentApprovalsPO, creatorId: String): APIResult<AgentApprovalsPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "agent_approvals")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<AgentApprovalsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "agent_approvals")
            if (!hasPermission) {
                return APIResult<AgentApprovalsPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<AgentApprovalsPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentApprovalsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_approvals")

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

            let pagination = getExecutor().findAgentApprovalsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentApprovalsPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: AgentApprovalsPO, userId: String): APIResult<AgentApprovalsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_approvals")
            if (!hasPermission) {
                return APIResult<AgentApprovalsPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<AgentApprovalsPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_approvals")
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
     * 记录一次「人在回路」决策的完整结果（spec 5.15 / Ch13.4）。
     *
     * 背景：`web_request_approval`（真正被 SOP 走的那条路径，见第二十轮接线）此前**完全不落库**，
     * 只有 WebSocket 通道的 `WebHumanAgent` 会写 agent_approvals —— 于是 spec 5.15 规则 5
     * 「agent_approvals 记录 selected_option」在真实链路上是不可达的。这里把落库能力补到调用方。
     *
     * 幂等与容错：每次审批 = 一条新记录（不做 upsert），失败只记日志返回 false，
     * 由调用方决定是否影响主流程 —— 绝不能因为落库失败把用户的选择丢掉。
     *
     * @param record 工具侧产出的决策快照
     * @return true=已写入 agent_approvals
     */
    public func recordDecision(record: ApprovalDecisionRecord): Bool {
        let entity = AgentApprovalsPO()

        // agent_id：优先用决策点归属技能，退化到通道名，便于按技能回溯审批历史
        var agentId = record.skillName
        if (agentId.isEmpty()) {
            agentId = "webmcp"
        }
        entity.agentId = agentId

        // approval_type：区分「决策点选择」与「普通确认」，后者无 options / selected_option
        var approvalType = "confirm"
        if (!record.decisionPointId.isEmpty()) {
            approvalType = "decision_point"
        }
        entity.approvalType = approvalType

        // content：把技能/决策点 id 一并写进去，事后能直接从正文看出这是哪个决策点
        var header = record.action
        if (!record.decisionPointId.isEmpty()) {
            header = "[${record.skillName}/${record.decisionPointId}] ${record.action}"
        }
        if (record.details.isEmpty()) {
            entity.content = header
        } else {
            entity.content = "${header}\n${record.details}"
        }

        entity.status = record.status
        entity.timeoutMs = record.timeoutMs
        entity.creator = None<String>
        entity.createdAt = DateTime.now()
        entity.updatedAt = DateTime.now()
        entity.deletedAt = None<DateTime>

        if (!record.userResponse.isEmpty()) {
            entity.userResponse = Some(record.userResponse)
        } else {
            entity.userResponse = None<String>
        }
        // 选项集：记录"当时给了哪些方案"，供事后复盘
        if (!record.options.isEmpty()) {
            entity.options = Some(record.options)
        } else {
            entity.options = None<String>
        }
        // ← Ch13.4 要求的落库字段：用户实际选中（或自动兜底采用）的选项 id
        if (!record.selectedOption.isEmpty()) {
            entity.selectedOption = Some(record.selectedOption)
        } else {
            entity.selectedOption = None<String>
        }

        try {
            let result = create(entity, "system")
            if (!result.success) {
                let reason = match (result.reason) {
                    case Some(msg) => msg
                    case None => "unknown error"
                }
                LogUtils.error("AgentApprovalsService: 审批决策落库失败 approval_type=${approvalType} decision_point=${record.decisionPointId}: ${reason}")
                return false
            }
            LogUtils.info("AgentApprovalsService: 已记录审批决策 status=${record.status} selected_option='${record.selectedOption}' auto_default=${record.autoDefaulted} decision_point='${record.decisionPointId}'")
            return true
        } catch (e: Exception) {
            LogUtils.error("AgentApprovalsService: 审批决策落库异常: ${e.message}")
            return false
        }
    }
}
