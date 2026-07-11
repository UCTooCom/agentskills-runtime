/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import cos.model.{PutObjectRequest}
import stdx.encoding.base64.fromBase64String

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.AttachmentsPO
import magic.app.dao.uctoo.AttachmentsDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * AttachmentsService - attachments服务类
 *
 * 提供attachments相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class AttachmentsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建attachments
     * @param entity AttachmentsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: AttachmentsPO, creatorId: String): APIResult<AttachmentsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertAttachments(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<AttachmentsPO>(entity)
            } else {
                return APIResult<AttachmentsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<AttachmentsPO>(false, e.message)
        }
    }

    /**
     * 更新attachments（无权限检查）
     * @param entityId ID
     * @param entity AttachmentsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: AttachmentsPO): APIResult<AttachmentsPO> {
        try {
            let existing = getExecutor().findAttachmentsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<AttachmentsPO>(false, "attachments不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.path.size > 0) {
                existingEntity.path = entity.path
            }
            if (entity.url.size > 0) {
                existingEntity.url = entity.url
            }
            if (entity.mimeType.size > 0) {
                existingEntity.mimeType = entity.mimeType
            }
            if (entity.fileExt.size > 0) {
                existingEntity.fileExt = entity.fileExt
            }
            existingEntity.filesize = entity.filesize
            if (entity.filename.size > 0) {
                existingEntity.filename = entity.filename
            }
            if (entity.driver.size > 0) {
                existingEntity.driver = entity.driver
            }
            if (entity.scene.isSome()) {
                existingEntity.scene = entity.scene
            }
            if (entity.typeVal.isSome()) {
                existingEntity.typeVal = entity.typeVal
            }
            if (entity.scId.isSome()) {
                existingEntity.scId = entity.scId
            }
            if (entity.aiTaskId.isSome()) {
                existingEntity.aiTaskId = entity.aiTaskId
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateAttachments(existingEntity)
            
            if (rows > 0) {
                return APIResult<AttachmentsPO>(existingEntity)
            } else {
                return APIResult<AttachmentsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<AttachmentsPO>(false, e.message)
        }
    }

    /**
     * 批量更新attachments
     * @param entities attachments列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<AttachmentsPO>): APIResult<ArrayList<AttachmentsPO>> {
        try {
            let updatedEntities = ArrayList<AttachmentsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateAttachments(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<AttachmentsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<AttachmentsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<AttachmentsPO>>(false, e.message)
        }
    }

    /**
     * 删除attachments（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findAttachmentsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "attachments不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteAttachmentsById(entityId)
            } else {
                rows = getExecutor().softDeleteAttachmentsById(entityId)
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
     * 批量删除attachments
     * @param ids attachmentsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteAttachments(ids)
            } else {
                rows = getExecutor().batchSoftDeleteAttachments(ids)
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
     * 恢复软删除的attachments
     * @param entityId attachmentsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<AttachmentsPO> {
        try {
            let rows = getExecutor().restoreAttachmentsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findAttachmentsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<AttachmentsPO>(entity)
                } else {
                    return APIResult<AttachmentsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<AttachmentsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<AttachmentsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的attachments
     * @param ids attachmentsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreAttachmentsById(id)
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
     * 根据ID获取attachments（无权限检查）
     * @param entityId ID
     * @return attachments对象
     */
    public func getById(entityId: String): APIResult<AttachmentsPO> {
        try {
            let result = getExecutor().findAttachmentsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<AttachmentsPO>(entity)
            } else {
                return APIResult<AttachmentsPO>(false, "未找到该attachments")
            }
        } catch (e: Exception) {
            return APIResult<AttachmentsPO>(false, e.message)
        }
    }

    /**
     * 获取attachments列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return attachments列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<AttachmentsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllAttachmentsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AttachmentsPO>(), 0)
        }
    }

    /**
     * 获取attachments列表（分页，支持排序和过滤，无权限过滤）
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
     * @return attachments列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AttachmentsPO>, Int64) {
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
            let pagination = getExecutor().findAttachmentsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AttachmentsPO>(), 0)
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
     * 获取attachments列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return attachments列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AttachmentsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "attachments")

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
            let pagination = getExecutor().findAttachmentsByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AttachmentsPO>(), 0)
        }
    }

    /**
     * 获取attachments列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return attachments列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AttachmentsPO>, Int64) {
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
            let pagination = getExecutor().findAttachmentsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AttachmentsPO>(), 0)
        }
    }

    /**
     * 获取所有attachments列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return attachments列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<AttachmentsPO>, Int64) {
        let pagination = getExecutor().findAllAttachmentsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取attachments
     * @param ids ID列表
     * @return attachments列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<AttachmentsPO> {
        getExecutor().findAttachmentsByIds(ids)
    }

    /**
     * 统计用户的attachments数量
     * @param userId 用户ID
     * @return attachments数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countAttachmentsByCreator(userId)
    }

    /**
     * 统计所有attachments数量
     * @return attachments数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllAttachments()
    }

    /**
     * 获取attachments列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return attachments列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<AttachmentsPO>, Int64) {
        let pagination = getExecutor().findAttachmentsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的attachments）
     * @return 删除结果
     */
    public func emptyRecycleBinAttachments(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinAttachments()

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

    public func createWithPermission(entity: AttachmentsPO, creatorId: String): APIResult<AttachmentsPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "attachments")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<AttachmentsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "attachments")
            if (!hasPermission) {
                return APIResult<AttachmentsPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<AttachmentsPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AttachmentsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "attachments")

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

            let pagination = getExecutor().findAttachmentsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AttachmentsPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: AttachmentsPO, userId: String): APIResult<AttachmentsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "attachments")
            if (!hasPermission) {
                return APIResult<AttachmentsPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<AttachmentsPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "attachments")
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
     * 上传文件到腾讯云 COS
     * @param request 上传请求
     * @param creatorId 创建者ID
     * @return 上传结果
     */
    public func uploadToCos(request: UploadRequest, creatorId: String): APIResult<AttachmentsPO> {
        try {
            eprintln("=== uploadToCos: start ===")
            
            // 1. 验证配置
            let secretId = CosConfig.getSecretId()
            let secretKey = CosConfig.getSecretKey()
            let bucket = CosConfig.getBucket()
            let region = CosConfig.getRegion()

            let secretIdStatus = if (secretId.isEmpty()) { "empty" } else { "set" }
            let secretKeyStatus = if (secretKey.isEmpty()) { "empty" } else { "set" }
            
            eprintln("=== uploadToCos: secretId=${secretIdStatus} ===")
            eprintln("=== uploadToCos: secretKey=${secretKeyStatus} ===")
            eprintln("=== uploadToCos: bucket=${bucket} ===")
            eprintln("=== uploadToCos: region=${region} ===")

            if (secretId.isEmpty() || secretKey.isEmpty() || bucket.isEmpty()) {
                return APIResult<AttachmentsPO>(false, "腾讯云 COS 配置不完整，请检查环境变量")
            }

            // 2. 解码 Base64 内容
            eprintln("=== uploadToCos: decoding base64, content length=${request.content.size} ===")
            eprintln("=== uploadToCos: content preview=${request.content[0..50]} ===")
            
            let fileContent = decodeBase64(request.content)
            eprintln("=== uploadToCos: decoded content size=${fileContent.size} ===")
            
            let fileSize = Int32(fileContent.size)

            // 3. 生成文件路径（使用原始文件名）
            let now = DateTime.now()
            let dateStr = now.toString()[0..10].replace("-", "")
            let originalFilename = sanitizeFilename(request.filename)
            let fileExt = getFileExt(originalFilename)
            let baseName = if (!fileExt.isEmpty()) { originalFilename[0..originalFilename.lastIndexOf(".").getOrThrow()] } else { originalFilename }
            let timestamp = (now - DateTime.UnixEpoch).toMilliseconds()
            let cosKey = "${dateStr}/${baseName}_${timestamp}${fileExt}"
            
            eprintln("=== uploadToCos: cosKey=${cosKey} ===")
            eprintln("=== uploadToCos: fileExt=${fileExt} ===")

            // 4. 上传到 COS
            eprintln("=== uploadToCos: getting COS client ===")
            let client = CosConfig.getClient()
            eprintln("=== uploadToCos: creating PutObjectRequest ===")
            
            let putRequest = PutObjectRequest(
                bucket,
                cosKey,
                fileContent,
                contentType: Some(request.mimeType),
                contentLength: Some(Int64(fileSize))
            )

            eprintln("=== uploadToCos: calling client.putObject ===")
            let result = client.putObject(putRequest)
            eprintln("=== uploadToCos: putObject succeeded, eTag=${result.eTag}, location=${result.location} ===")

            // 5. 构建 URL
            let cdnBaseUrl = CosConfig.getCdnBaseUrl()
            let cosUrl = if (!cdnBaseUrl.isEmpty()) {
                "${cdnBaseUrl}/${cosKey}"
            } else {
                "https://${bucket}.cos.${region}.myqcloud.com/${cosKey}"
            }
            
            eprintln("=== uploadToCos: cosUrl=${cosUrl} ===")

            // 6. 保存到数据库
            eprintln("=== uploadToCos: creating AttachmentsPO ===")
            let entity = AttachmentsPO()
            entity.path = cosKey
            entity.url = cosUrl
            entity.mimeType = request.mimeType
            entity.fileExt = if (fileExt.startsWith(".")) { fileExt[1..] } else { fileExt }
            entity.filesize = fileSize
            entity.filename = request.filename
            entity.driver = "qcloud"
            entity.scene = Some(request.scene)
            if (!request.`type`.isEmpty()) {
                entity.typeVal = Some(request.`type`)
            }
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            entity.creator = Some(creatorId)

            eprintln("=== uploadToCos: inserting to database ===")
            let id = getExecutor().insertAttachments(entity)
            eprintln("=== uploadToCos: insert result id=${id} ===")
            
            if (id.isEmpty()) {
                return APIResult<AttachmentsPO>(false, "保存附件记录失败")
            }

            entity.id = id
            eprintln("=== uploadToCos: success ===")
            return APIResult<AttachmentsPO>(entity)
        } catch (e: Exception) {
            eprintln("=== uploadToCos: exception caught: ${e.message} ===")
            e.printStackTrace()
            LogUtils.error("Upload to COS failed: ${e.message}")
            return APIResult<AttachmentsPO>(false, "上传失败: ${e.message}")
        }
    }

    private func sanitizeFilename(filename: String): String {
        var result = filename
        result = result.replace("/", "")
        result = result.replace("\\", "")
        result = result.replace("..", "")
        result = result.replace(":", "")
        result = result.replace("*", "")
        result = result.replace("?", "")
        result = result.replace("\"", "")
        result = result.replace("<", "")
        result = result.replace(">", "")
        result = result.replace("|", "")
        return result
    }

    private func padZero(n: Int64): String {
        if (n < 10) {
            return "0${n}"
        }
        return "${n}"
    }

    private func getFileExt(filename: String): String {
        if (let Some(idx) <- filename.lastIndexOf(".")) {
            return filename[idx..]
        }
        return ""
    }

    private func decodeBase64(content: String): Array<Byte> {
        // 使用标准库的 Base64 解码方法
        if (let Some(bytes) <- fromBase64String(content)) {
            return bytes
        }
        throw Exception("Base64 decode failed")
    }

    private func genUuid(): String {
        // 生成简化的 UUID
        let hex = "0123456789abcdef"
        var uuid = StringBuilder()
        let segments = [8, 4, 4, 4, 12]

        var count = 0
        for (i in 0..16) {
            if (i > 0 && count < 5) {
                uuid.append("-")
            }
            let idx = (i * 19) % 16
            uuid.append(hex[idx..idx+1])
            if (i == 3 || i == 5 || i == 7 || i == 9) {
                count++
            }
        }

        return uuid.toString()
    }
}
