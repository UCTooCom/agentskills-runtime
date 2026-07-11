/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.models.uctoo.TasksPO
import magic.app.dao.uctoo.TasksDAO
// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.CompanyPO
import magic.app.dao.uctoo.CompanyDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * CompanyService - company服务类
 *
 * 提供company相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class CompanyService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建company
     * @param entity CompanyPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: CompanyPO, creatorId: String): APIResult<CompanyPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertCompany(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<CompanyPO>(entity)
            } else {
                return APIResult<CompanyPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<CompanyPO>(false, e.message)
        }
    }

    /**
     * 更新company（无权限检查）
     * @param entityId ID
     * @param entity CompanyPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: CompanyPO): APIResult<CompanyPO> {
        try {
            let existing = getExecutor().findCompanyById(entityId)
            
            if (existing.isNone()) {
                return APIResult<CompanyPO>(false, "company不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.companyName.size > 0) {
                existingEntity.companyName = entity.companyName
            }
            if (entity.region.size > 0) {
                existingEntity.region = entity.region
            }
            if (entity.socialCreditCode.size > 0) {
                existingEntity.socialCreditCode = entity.socialCreditCode
            }
            if (entity.establishedTime.size > 0) {
                existingEntity.establishedTime = entity.establishedTime
            }
            if (entity.registeredCapital.size > 0) {
                existingEntity.registeredCapital = entity.registeredCapital
            }
            if (entity.registeredAddress.size > 0) {
                existingEntity.registeredAddress = entity.registeredAddress
            }
            if (entity.mailingAddress.size > 0) {
                existingEntity.mailingAddress = entity.mailingAddress
            }
            if (entity.legalRepresentative.size > 0) {
                existingEntity.legalRepresentative = entity.legalRepresentative
            }
            if (entity.legalRepresentativemobile.size > 0) {
                existingEntity.legalRepresentativemobile = entity.legalRepresentativemobile
            }
            if (entity.legalRepresentativeEmail.size > 0) {
                existingEntity.legalRepresentativeEmail = entity.legalRepresentativeEmail
            }
            if (entity.contactName.size > 0) {
                existingEntity.contactName = entity.contactName
            }
            if (entity.contactMobile.size > 0) {
                existingEntity.contactMobile = entity.contactMobile
            }
            if (entity.contactEmail.size > 0) {
                existingEntity.contactEmail = entity.contactEmail
            }
            if (entity.contactTitle.size > 0) {
                existingEntity.contactTitle = entity.contactTitle
            }
            if (entity.website.size > 0) {
                existingEntity.website = entity.website
            }
            if (entity.companyLogo.isSome()) {
                existingEntity.companyLogo = entity.companyLogo
            }
            if (entity.associatedProjectManager.isSome()) {
                existingEntity.associatedProjectManager = entity.associatedProjectManager
            }
            existingEntity.verified = entity.verified
            if (entity.companyIntroduction.size > 0) {
                existingEntity.companyIntroduction = entity.companyIntroduction
            }
            if (entity.businessLicence.size > 0) {
                existingEntity.businessLicence = entity.businessLicence
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.orgDescription.isSome()) {
                existingEntity.orgDescription = entity.orgDescription
            }
            if (entity.memberCount.isSome()) {
                existingEntity.memberCount = entity.memberCount
            }
            if (entity.taskCount.isSome()) {
                existingEntity.taskCount = entity.taskCount
            }
            if (entity.followerCount.isSome()) {
                existingEntity.followerCount = entity.followerCount
            }
            if (entity.isVerified.isSome()) {
                existingEntity.isVerified = entity.isVerified
            }
            if (entity.orgType.isSome()) {
                existingEntity.orgType = entity.orgType
            }
            if (entity.tags.isSome()) {
                existingEntity.tags = entity.tags
            }
            existingEntity.pointsBalance = entity.pointsBalance

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateCompany(existingEntity)
            
            if (rows > 0) {
                return APIResult<CompanyPO>(existingEntity)
            } else {
                return APIResult<CompanyPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<CompanyPO>(false, e.message)
        }
    }

    /**
     * 批量更新company
     * @param entities company列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<CompanyPO>): APIResult<ArrayList<CompanyPO>> {
        try {
            let updatedEntities = ArrayList<CompanyPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateCompany(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<CompanyPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<CompanyPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<CompanyPO>>(false, e.message)
        }
    }

    /**
     * 删除company（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findCompanyById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "company不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteCompanyById(entityId)
            } else {
                rows = getExecutor().softDeleteCompanyById(entityId)
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
     * 批量删除company
     * @param ids companyID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteCompany(ids)
            } else {
                rows = getExecutor().batchSoftDeleteCompany(ids)
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
     * 恢复软删除的company
     * @param entityId companyID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<CompanyPO> {
        try {
            let rows = getExecutor().restoreCompanyById(entityId)

            if (rows > 0) {
                let result = getExecutor().findCompanyById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<CompanyPO>(entity)
                } else {
                    return APIResult<CompanyPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<CompanyPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<CompanyPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的company
     * @param ids companyID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreCompanyById(id)
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
     * 根据ID获取company（无权限检查）
     * @param entityId ID
     * @return company对象
     */
    public func getById(entityId: String): APIResult<CompanyPO> {
        try {
            let result = getExecutor().findCompanyById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<CompanyPO>(entity)
            } else {
                return APIResult<CompanyPO>(false, "未找到该company")
            }
        } catch (e: Exception) {
            return APIResult<CompanyPO>(false, e.message)
        }
    }

    /**
     * 获取company列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return company列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<CompanyPO>, Int64) {
        try {
            let pagination = getExecutor().findAllCompanyPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<CompanyPO>(), 0)
        }
    }

    /**
     * 获取company列表（分页，支持排序和过滤，无权限过滤）
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
     * @return company列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<CompanyPO>, Int64) {
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
            let pagination = getExecutor().findCompanyByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<CompanyPO>(), 0)
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
     * 获取company列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return company列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<CompanyPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "company")

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
            let pagination = getExecutor().findCompanyByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<CompanyPO>(), 0)
        }
    }

    /**
     * 获取company列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return company列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<CompanyPO>, Int64) {
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
            let pagination = getExecutor().findCompanyByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<CompanyPO>(), 0)
        }
    }

    /**
     * 获取所有company列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return company列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<CompanyPO>, Int64) {
        let pagination = getExecutor().findAllCompanyPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取company
     * @param ids ID列表
     * @return company列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<CompanyPO> {
        getExecutor().findCompanyByIds(ids)
    }

    /**
     * 统计用户的company数量
     * @param userId 用户ID
     * @return company数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countCompanyByCreator(userId)
    }

    /**
     * 统计所有company数量
     * @return company数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllCompany()
    }

    /**
     * 获取company列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return company列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<CompanyPO>, Int64) {
        let pagination = getExecutor().findCompanyByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的company）
     * @return 删除结果
     */
    public func emptyRecycleBinCompany(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinCompany()

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

    public func createWithPermission(entity: CompanyPO, creatorId: String): APIResult<CompanyPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "company")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<CompanyPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "company")
            if (!hasPermission) {
                return APIResult<CompanyPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<CompanyPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<CompanyPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "company")

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

            let pagination = getExecutor().findCompanyByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<CompanyPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: CompanyPO, userId: String): APIResult<CompanyPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "company")
            if (!hasPermission) {
                return APIResult<CompanyPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<CompanyPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "company")
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

    // ==================== 公开页面与积分相关方法 ====================

    /**
     * 公开组织分页查询
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param orgType 组织类型筛选（空字符串表示不筛选）
     * @param tag 标签筛选（空字符串表示不筛选）
     * @param sortBy 排序方式：latest/popular/tasks
     * @return 组织列表和总数
     */
    public func listPublicCompanies(page: Int64, pageSize: Int64, orgType: String, tag: String, sortBy: String): (ArrayList<CompanyPO>, Int64) {
        let executor = getExecutor()
        let pagination = executor.queryPublicCompaniesWithPagination(page, pageSize, orgType, tag, sortBy)
        return (pagination.list, pagination.rows)
    }

    /**
     * 公开组织分页查询（Prisma风格）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param sort 排序字段
     * @param filter 过滤条件（JSON格式）
     * @return 组织列表和总数
     */
    public func listPublicCompaniesWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<CompanyPO>, Int64) {
        try {
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            var publicWhere = "deleted_at is null and org_type is not null and org_type != ''"
            if (!whereClause.isEmpty()) {
                publicWhere = publicWhere + " and (" + whereClause + ")"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)
            var finalOrderBy = orderByClause
            if (finalOrderBy.isEmpty()) {
                finalOrderBy = "order by created_at desc"
            }

            let pagination = getExecutor().findCompanyByCondition(
                publicWhere,
                finalOrderBy,
                Int64(page),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("CompanyService", "listPublicCompaniesWithFilter error: ${e.message}")
            return (ArrayList<CompanyPO>(), 0)
        }
    }

    /**
     * 我的组织列表（Prisma风格）
     * @param userId 用户ID
     * @param role 角色（member/admin/follower）
     * @param page 页码
     * @param pageSize 每页数量
     * @param sort 排序字段
     * @param filter 过滤条件
     * @return 组织列表和总数
     */
    public func getMyCompaniesWithFilter(
        userId: String,
        role: String,
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<CompanyPO>, Int64) {
        try {
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            var myWhere = "id in (select company_id from user_has_companies where user_id = '${userId}' and role = '${role}' and deleted_at is null)"
            if (!whereClause.isEmpty()) {
                myWhere = myWhere + " and (" + whereClause + ")"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)
            var finalOrderBy = orderByClause
            if (finalOrderBy.isEmpty()) {
                finalOrderBy = "order by created_at desc"
            }

            let pagination = getExecutor().findCompanyByCondition(
                myWhere,
                finalOrderBy,
                Int64(page),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("CompanyService", "getMyCompaniesWithFilter error: ${e.message}")
            return (ArrayList<CompanyPO>(), 0)
        }
    }

    /**
     * 公开组织详情
     */
    public func getPublicCompanyDetail(companyId: String): APIResult<CompanyPO> {
        let executor = getExecutor()
        let result = executor.findPublicCompanyById(companyId)
        if (let Some(entity) <- result) {
            return APIResult<CompanyPO>(entity)
        } else {
            return APIResult<CompanyPO>(false, "组织不存在或不可见")
        }
    }

    /**
     * 查询组织积分余额
     * 委托给 PointTransactionsService
     */
    public func getCompanyPointsBalance(companyId: String): Int64 {
        let pointService = PointTransactionsService()
        return pointService.getCompanyPointsBalance(companyId)
    }

    /**
     * 充值组织积分（预留接口，需要管理员权限）
     * @param companyId 组织ID
     * @param points 充值积分
     * @param operatorId 操作者ID
     * @return 新的积分余额
     */
    public func rechargePoints(companyId: String, points: Int64, operatorId: String): APIResult<Int64> {
        try {
            if (points <= 0) {
                return APIResult<Int64>(false, "充值积分必须大于0")
            }
            let executor = getExecutor()
            // 查询当前余额
            let currentBalanceOpt = executor.findPointsBalance(companyId)
            let currentBalance = match (currentBalanceOpt) {
                case Some(b) => b
                case None => throw Exception("公司不存在")
            }
            // 增加余额
            let rows = executor.addPointsBalance(companyId, points)
            if (rows == 0) {
                return APIResult<Int64>(false, "充值失败")
            }
            let newBalance = currentBalance + points
            // 记录充值流水
            let pointService = PointTransactionsService()
            pointService.recordChargeTransaction(companyId, points, currentBalance, newBalance, operatorId)
            return APIResult<Int64>(newBalance)
        } catch (e: Exception) {
            return APIResult<Int64>(false, e.message)
        }
    }

    /**
     * 查询组织下的任务列表
     */
    public func getCompanyTasks(companyId: String, page: Int64, pageSize: Int64): (ArrayList<TasksPO>, Int64) {
        let executor = getExecutor()
        let pagination = executor.findTasksByCompanyId(companyId, page, pageSize)
        return (pagination.list, pagination.rows)
    }

    /**
     * 查询组织成员列表
     * @param companyId 组织ID
     * @return 成员列表
     */
    public func getOrgMembers(companyId: String): ArrayList<HashMap<String, Any>> {
        let executor = getExecutor()
        executor.findOrgMembers(companyId)
    }
}
