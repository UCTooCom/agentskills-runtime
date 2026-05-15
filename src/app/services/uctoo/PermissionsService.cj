/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.models.uctoo.RoleHasPermissionPO
import magic.app.dao.uctoo.RoleHasPermissionDAO
// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.PermissionsPO

import magic.app.dao.uctoo.PermissionsDAO

import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.log.LogUtils
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils

/**
 * PermissionsService - permissions服务类
 *
 * 提供permissions相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class PermissionsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建permissions
     * @param entity PermissionsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: PermissionsPO, creatorId: String): APIResult<PermissionsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertPermissions(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<PermissionsPO>(entity)
            } else {
                return APIResult<PermissionsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<PermissionsPO>(false, e.message)
        }
    }

    /**
     * 更新permissions
     * @param entityId ID
     * @param entity PermissionsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: PermissionsPO): APIResult<PermissionsPO> {
        try {
            let existing = getExecutor().findPermissionsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<PermissionsPO>(false, "permissions不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.permissionName.size > 0) {
                existingEntity.permissionName = entity.permissionName
            }
            if (entity.level.isSome()) {
                existingEntity.level = entity.level
            }
            if (entity.icon.isSome()) {
                existingEntity.icon = entity.icon
            }
            if (entity.module.isSome()) {
                existingEntity.module = entity.module
            }
            if (entity.component.isSome()) {
                existingEntity.component = entity.component
            }
            if (entity.redirect.isSome()) {
                existingEntity.redirect = entity.redirect
            }
            existingEntity.typeVal = entity.typeVal
            existingEntity.hidden = entity.hidden
            existingEntity.weight = entity.weight
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            existingEntity.keepalive = entity.keepalive
            if (entity.path.isSome()) {
                existingEntity.path = entity.path
            }
            if (entity.title.isSome()) {
                existingEntity.title = entity.title
            }
            if (entity.parentId.isSome()) {
                existingEntity.parentId = entity.parentId
            }
            if (entity.meta.isSome()) {
                existingEntity.meta = entity.meta
            }
            if (entity.method.isSome()) {
                existingEntity.method = entity.method
            }
            if (entity.menuType.isSome()) {
                existingEntity.menuType = entity.menuType
            }
            if (entity.locale.isSome()) {
                existingEntity.locale = entity.locale
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updatePermissions(existingEntity)
            
            if (rows > 0) {
                return APIResult<PermissionsPO>(existingEntity)
            } else {
                return APIResult<PermissionsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<PermissionsPO>(false, e.message)
        }
    }

    /**
     * 批量更新permissions
     * @param entities permissions列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<PermissionsPO>): APIResult<ArrayList<PermissionsPO>> {
        try {
            let updatedEntities = ArrayList<PermissionsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updatePermissions(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<PermissionsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<PermissionsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<PermissionsPO>>(false, e.message)
        }
    }

    /**
     * 删除permissions
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findPermissionsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "permissions不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deletePermissionsById(entityId)
            } else {
                rows = getExecutor().softDeletePermissionsById(entityId)
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
     * 批量删除permissions
     * @param ids permissionsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeletePermissions(ids)
            } else {
                rows = getExecutor().batchSoftDeletePermissions(ids)
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
     * 恢复软删除的permissions
     * @param entityId permissionsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<PermissionsPO> {
        try {
            let rows = getExecutor().restorePermissionsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findPermissionsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<PermissionsPO>(entity)
                } else {
                    return APIResult<PermissionsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<PermissionsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<PermissionsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的permissions
     * @param ids permissionsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restorePermissionsById(id)
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
     * 根据ID获取permissions
     * @param entityId ID
     * @return permissions对象
     */
    public func getById(entityId: String): APIResult<PermissionsPO> {
        try {
            let result = getExecutor().findPermissionsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<PermissionsPO>(entity)
            } else {
                return APIResult<PermissionsPO>(false, "未找到该permissions")
            }
        } catch (e: Exception) {
            return APIResult<PermissionsPO>(false, e.message)
        }
    }

    /**
     * 获取permissions列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return permissions列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<PermissionsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllPermissionsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "getList error: ${e.message}")
            return (ArrayList<PermissionsPO>(), 0)
        }
    }

    /**
     * 获取permissions列表（分页，支持排序和过滤）
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
     * @return permissions列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<PermissionsPO>, Int64) {
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
            let pagination = getExecutor().findPermissionsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "Failed to get list: ${e.message}")
            return (ArrayList<PermissionsPO>(), 0)
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
     * 获取permissions列表（带跳过参数）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return permissions列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<PermissionsPO>, Int64) {
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
            let pagination = getExecutor().findPermissionsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<PermissionsPO>(), 0)
        }
    }

    /**
     * 获取所有permissions列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return permissions列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<PermissionsPO>, Int64) {
        let pagination = getExecutor().findAllPermissionsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取permissions
     * @param ids ID列表
     * @return permissions列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<PermissionsPO> {
        getExecutor().findPermissionsByIds(ids)
    }

    /**
     * 统计用户的permissions数量
     * @param userId 用户ID
     * @return permissions数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countPermissionsByCreator(userId)
    }

    /**
     * 统计所有permissions数量
     * @return permissions数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllPermissions()
    }

    /**
     * 获取permissions列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return permissions列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<PermissionsPO>, Int64) {
        let pagination = getExecutor().findPermissionsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的permissions）
     * @return 删除结果
     */
    public func emptyRecycleBinPermissions(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinPermissions()

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
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 根据权限名称查询权限
     * @param permissionName 权限名称
     * @return 权限对象
     */
    public func findByPermissionName(permissionName: String): ?PermissionsPO {
        try {
            getExecutor().findPermissionsByPermissionName(permissionName)
        } catch (e: Exception) {
            None<PermissionsPO>
        }
    }

    /**
     * 获取用户所属的角色ID列表 - V4标准RBAC
     * @param userId 用户ID
     * @return 角色ID列表
     */
    public func getUserRoles(userId: String): ArrayList<String> {
        try {
            getExecutor().findUserRoles(userId)
        } catch (e: Exception) {
            ArrayList<String>()
        }
    }

    /**
     * 检查角色是否拥有指定权限 - V4标准RBAC
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 是否拥有权限
     */
    public func checkRolePermission(roleId: String, permissionName: String): Bool {
        try {
            let result = getExecutor().findRolePermission(roleId, permissionName)
            result.isSome()
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 获取用户菜单树 - V4标准RBAC
     * 参考 backend 的 getUserPermissionsTree 实现
     * 
     * 实现逻辑：
     * 1. 从 user_has_roles 获取用户所有角色ID
     * 2. 从 role_has_permission 获取角色所有权限名称
     * 3. 从 permissions 获取权限详情（type=1 为菜单）
     * 4. 构建树形结构返回
     * 
     * @param userId 用户ID
     * @return 菜单树
     */
    public func getUserMenuTree(userId: String): ArrayList<PermissionsPO> {
        try {
            LogUtils.info("=== [getUserMenuTree] START for userId: ${userId} ===")
            
            // 1. 获取用户所有角色ID
            LogUtils.info("[getUserMenuTree] Step 1: Calling findUserRoles...")
            let roleIds = getExecutor().findUserRoles(userId)
            LogUtils.info("[getUserMenuTree] Step 1: Found ${roleIds.size} role IDs")
            
            if (roleIds.size == 0) {
                LogUtils.info("[getUserMenuTree] No roles found, returning empty list")
                return ArrayList<PermissionsPO>()
            }
            
            // 打印所有角色ID
            for (i in 0..roleIds.size) {
                LogUtils.info("[getUserMenuTree] Role[${i}]: ${roleIds[i]}")
            }
            
            // 2. 获取角色所有权限名称
            LogUtils.info("[getUserMenuTree] Step 2: Getting permission names for each role...")
            let permissionNames = ArrayList<String>()
            var hasMenuWildcard = false
            for (roleId in roleIds) {
                LogUtils.info("[getUserMenuTree] Calling findRolePermissionNames for roleId: ${roleId}")
                let perms = getExecutor().findRolePermissionNames(roleId)
                LogUtils.info("[getUserMenuTree] Found ${perms.size} permissions for role: ${roleId}")
                
                for (permName in perms) {
                    if (!permissionNames.contains(permName)) {
                        permissionNames.add(permName)
                        LogUtils.info("[getUserMenuTree] Added permission: ${permName}")
                        
                        // 检查是否有菜单通配符权限
                        // * 表示所有权限，menu:* 表示所有菜单权限，/* 表示所有API权限
                        if (permName == "*" || permName == "menu:*") {
                            hasMenuWildcard = true
                            LogUtils.info("[getUserMenuTree] Found menu wildcard permission (${permName})")
                        }
                    }
                }
            }
            
            LogUtils.info("[getUserMenuTree] Total unique permission names: ${permissionNames.size}")
            
            if (permissionNames.size == 0) {
                LogUtils.info("[getUserMenuTree] No permissions found, returning empty list")
                return ArrayList<PermissionsPO>()
            }
            
            // 3. 获取权限详情
            var allPermissions = ArrayList<PermissionsPO>()
            
            // 如果有菜单通配符权限，直接获取所有菜单
            if (hasMenuWildcard) {
                LogUtils.info("[getUserMenuTree] Step 3: User has menu wildcard permission, getting all menus...")
                allPermissions = getExecutor().findAllMenuPermissions()
                LogUtils.info("[getUserMenuTree] Step 3: Found ${allPermissions.size} menu items (all menus)")
            } else {
                // 否则根据权限名称查询
                LogUtils.info("[getUserMenuTree] Step 3: Calling findPermissionsByNames...")
                allPermissions = getExecutor().findPermissionsByNames(permissionNames)
                LogUtils.info("[getUserMenuTree] Step 3: Found ${allPermissions.size} permission objects")
            }
            
            // 4. 构建树形结构
            // 注意：需要返回所有菜单（包括子菜单），让Controller层构建树形结构
            LogUtils.info("[getUserMenuTree] Step 4: Returning ${allPermissions.size} menu items for tree building")
            return allPermissions
        } catch (e: Exception) {
            LogUtils.error("[getUserMenuTree] EXCEPTION: ${e.message}")
            LogUtils.error("[getUserMenuTree] Stack trace: ${e}")
            ArrayList<PermissionsPO>()
        }
    }
    
    /**
     * 获取所有菜单树
     * @return 所有菜单列表（包括子菜单），让Controller层构建树形结构
     */
    public func getAllMenuTree(): ArrayList<PermissionsPO> {
        try {
            // 获取所有菜单类型的权限（type=1）
            let allPermissions = getExecutor().findAllMenuPermissions()
            LogUtils.info("[getAllMenuTree] Returning ${allPermissions.size} menu items for tree building")
            return allPermissions
        } catch (e: Exception) {
            LogUtils.error("getAllMenuTree failed: ${e.message}")
            ArrayList<PermissionsPO>()
        }
    }
    
    /**
     * 根据角色ID获取菜单树
     * @param roleId 角色ID
     * @return 所有菜单列表（包括子菜单），让Controller层构建树形结构
     */
    public func getRoleMenuTree(roleId: String): ArrayList<PermissionsPO> {
        try {
            // 获取角色所有权限名称
            let permissionNames = getExecutor().findRolePermissionNames(roleId)
            if (permissionNames.size == 0) {
                return ArrayList<PermissionsPO>()
            }
            
            // 获取权限详情
            let allPermissions = getExecutor().findPermissionsByNames(permissionNames)
            LogUtils.info("[getRoleMenuTree] Returning ${allPermissions.size} menu items for tree building")
            return allPermissions
        } catch (e: Exception) {
            LogUtils.error("getRoleMenuTree failed: ${e.message}")
            ArrayList<PermissionsPO>()
        }
    }
    
    /**
     * 获取用户所有权限 - 不区分权限类型
     * 
     * 实现逻辑：
     * 1. 从 user_has_roles 获取用户所有角色ID
     * 2. 从 role_has_permission 获取角色所有权限名称
     * 3. 从 permissions 获取所有权限详情（不区分类型）
     * 4. 返回权限列表
     * 
     * @param userId 用户ID
     * @return 权限列表
     */
    public func getUserAllPermissions(userId: String): ArrayList<PermissionsPO> {
        try {
            LogUtils.info("PermissionsService", "=== getUserAllPermissions() START for userId: ${userId} ===")
            
            // 1. 获取用户所有角色ID
            let roleIds = getExecutor().findUserRoles(userId)
            LogUtils.info("PermissionsService", "=== Found ${roleIds.size} roles for user ===")
            
            if (roleIds.size == 0) {
                LogUtils.info("PermissionsService", "=== No roles found, returning empty list ===")
                return ArrayList<PermissionsPO>()
            }
            
            // 2. 获取角色所有权限名称
            let permissionNames = ArrayList<String>()
            var hasWildcard = false
            
            for (roleId in roleIds) {
                let perms = getExecutor().findRolePermissionNames(roleId)
                for (permName in perms) {
                    if (!permissionNames.contains(permName)) {
                        permissionNames.add(permName)
                        
                        // 检查是否有通配符权限
                        if (permName == "*") {
                            hasWildcard = true
                        }
                    }
                }
            }
            
            LogUtils.info("PermissionsService", "=== Found ${permissionNames.size} unique permission names ===")
            
            if (permissionNames.size == 0) {
                LogUtils.info("PermissionsService", "=== No permissions found, returning empty list ===")
                return ArrayList<PermissionsPO>()
            }
            
            // 3. 获取权限详情
            var allPermissions = ArrayList<PermissionsPO>()
            
            // 如果有全局通配符权限，返回所有权限
            if (hasWildcard) {
                LogUtils.info("PermissionsService", "=== User has wildcard permission, returning all permissions ===")
                allPermissions = getExecutor().listAllPermissions()
            } else {
                // 否则根据权限名称查询
                allPermissions = getExecutor().findPermissionsByNames(permissionNames)
            }
            
            LogUtils.info("PermissionsService", "=== getUserAllPermissions() completed, returning ${allPermissions.size} permissions ===")
            return allPermissions
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== getUserAllPermissions() exception: ${e.message} ===")
            ArrayList<PermissionsPO>()
        }
    }

    /**
     * 删除指定parent_id下所有type=3的API权限节点
     * 用于刷新路由权限时先清除旧的API权限节点
     * @param parentId API父菜单ID
     * @return 影响行数
     */
    public func deleteApiPermissionsByParentId(parentId: String): Int64 {
        try {
            getExecutor().deleteApiPermissionsByParentId(parentId)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== deleteApiPermissionsByParentId() exception: ${e.message} ===")
            Int64(0)
        }
    }

    /**
     * 根据permissionName和method查询权限
     * @param permissionName 权限名称(路由路径)
     * @param method HTTP方法
     * @return 权限对象
     */
    public func findByNameAndMethod(permissionName: String, method: String): ?PermissionsPO {
        try {
            getExecutor().findPermissionsByNameAndMethod(permissionName, method)
        } catch (e: Exception) {
            None<PermissionsPO>
        }
    }

    public func findApiPermissionsByParentId(parentId: String): ArrayList<PermissionsPO> {
        try {
            getExecutor().findApiPermissionsByParentId(parentId)
        } catch (e: Exception) {
            ArrayList<PermissionsPO>()
        }
    }

    public func findOrphanApiPermissions(): ArrayList<PermissionsPO> {
        try {
            getExecutor().findOrphanApiPermissions()
        } catch (e: Exception) {
            ArrayList<PermissionsPO>()
        }
    }

    public func updateParentIdForApiPermissions(parentId: String): Int64 {
        try {
            getExecutor().updateParentIdForApiPermissions(parentId)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== updateParentIdForApiPermissions() exception: ${e.message} ===")
            Int64(0)
        }
    }

    public func softDeleteApiPermissionsByIds(ids: ArrayList<String>): Int64 {
        try {
            getExecutor().softDeleteApiPermissionsByIds(ids)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== softDeleteApiPermissionsByIds() exception: ${e.message} ===")
            Int64(0)
        }
    }

    public func updatePermissionNameAndMethod(oldName: String, newName: String, newMethod: String): Int64 {
        try {
            getExecutor().updatePermissionNameAndMethod(oldName, newName, newMethod)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== updatePermissionNameAndMethod() exception: ${e.message} ===")
            Int64(0)
        }
    }

    /**
     * 获取所有权限节点（deleted_at为空的全部记录）
     * 仅超级管理员可调用
     * @return 所有未删除的权限列表
     */
    public func getAllPermissions(): ArrayList<PermissionsPO> {
        try {
            LogUtils.info("PermissionsService", "=== getAllPermissions() called ===")
            let allPermissions = getExecutor().findAllActivePermissions()
            LogUtils.info("PermissionsService", "=== getAllPermissions() returned ${allPermissions.size} records ===")
            return allPermissions
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== getAllPermissions() exception: ${e.message} ===")
            ArrayList<PermissionsPO>()
        }
    }

    /**
     * 检查用户是否持有通配符权限 "*"
     * @param userId 用户ID
     * @return 是否超级管理员
     */
    public func checkUserHasWildcardPermission(userId: String): Bool {
        try {
            let roleIds = getExecutor().findUserRoles(userId)
            if (roleIds.size == 0) {
                return false
            }
            for (roleId in roleIds) {
                let permNames = getExecutor().findRolePermissionNames(roleId)
                if (permNames.contains("*")) {
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== checkUserHasWildcardPermission() exception: ${e.message} ===")
            return false
        }
    }

    /**
     * 递归获取权限及其所有父级权限名称
     * @param permissionName 当前权限名称
     * @param collected 已收集的权限名称集合（用于去重）
     * @return 权限名称列表（包含当前权限和所有父级权限）
     */
    private func collectPermissionWithParents(permissionName: String, collected: HashSet<String>): ArrayList<String> {
        if (collected.contains(permissionName)) {
            return ArrayList<String>()
        }
        
        collected.add(permissionName)
        let result = ArrayList<String>()
        result.add(permissionName)
        
        // 查询当前权限的父级权限
        let permission = getExecutor().findPermissionsByPermissionName(permissionName)
        if (let Some(perm) <- permission) {
            if (let Some(parentId) <- perm.parentId) {
                // 根据parentId查询父级权限的permissionName
                let parentPermission = getExecutor().findPermissionsById(parentId)
                if (let Some(parentPerm) <- parentPermission) {
                    let parentPermName = parentPerm.permissionName
                    if (!parentPermName.isEmpty()) {
                        let parentPermissions = collectPermissionWithParents(parentPermName, collected)
                        // 手动遍历添加，因为ArrayList没有addAll方法
                        for (p in parentPermissions) {
                            result.add(p)
                        }
                    }
                }
            }
        }
        
        return result
    }

    /**
     * 批量授权：将权限节点授权给用户角色（包含父级菜单权限）
     * @param permissionNames 权限名称列表
     * @param roleIds 角色ID列表
     * @param creator 创建者
     * @return 授权结果JSON字符串
     */
    public func batchAuthorize(permissionNames: ArrayList<String>, roleIds: ArrayList<String>, creator: String): APIResult<String> {
        try {
            LogUtils.info("PermissionsService", "=== batchAuthorize() called, permissionNames=${permissionNames.size}, roleIds=${roleIds.size} ===")
            
            let rolePermExecutor = ORM.executor()
            var authorizedCount = 0
            var skippedCount = 0
            let now = DateTime.now()
            
            // 收集所有需要授权的权限（包含父级）
            let allPermissionNames = HashSet<String>()
            for (permName in permissionNames) {
                if (!getExecutor().existsPermissionByName(permName)) {
                    skippedCount++
                    LogUtils.info("PermissionsService", "=== Permission ${permName} not found, skipped ===")
                    continue
                }
                let permsWithParents = collectPermissionWithParents(permName, HashSet<String>())
                // 手动遍历添加，因为HashSet没有addAll方法
                for (p in permsWithParents) {
                    allPermissionNames.add(p)
                }
            }
            
            LogUtils.info("PermissionsService", "=== Total permissions to authorize (including parents): ${allPermissionNames.size} ===")
            
            for (roleId in roleIds) {
                for (permName in allPermissionNames) {
                    if (rolePermExecutor.existsRoleHasPermission(roleId, permName)) {
                        skippedCount++
                        continue
                    }
                    
                    let entity = RoleHasPermissionPO()
                    entity.roleId = roleId
                    entity.permissionName = permName
                    entity.status = Some<Int32>(1)
                    entity.creator = Some(creator)
                    entity.createdAt = now
                    entity.updatedAt = now
                    
                    let success = rolePermExecutor.insertRoleHasPermission(entity)
                    if (success) {
                        authorizedCount++
                        LogUtils.info("PermissionsService", "=== Authorized permission ${permName} for role ${roleId} ===")
                    } else {
                        skippedCount++
                    }
                }
            }
            
            let resultJson = "{\"authorized_count\":${authorizedCount},\"skipped_count\":${skippedCount},\"message\":\"授权完成\"}"
            LogUtils.info("PermissionsService", "=== batchAuthorize() completed: authorized=${authorizedCount}, skipped=${skippedCount} ===")
            return APIResult<String>(resultJson)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== batchAuthorize() exception: ${e.message} ===")
            return APIResult<String>(false, e.message)
        }
    }

    /**
     * 批量取消授权：从用户角色中移除指定的权限节点（不级联取消子级）
     * @param permissionNames 权限名称列表
     * @param roleIds 角色ID列表
     * @return 取消授权结果JSON字符串
     */
    public func batchRevoke(permissionNames: ArrayList<String>, roleIds: ArrayList<String>): APIResult<String> {
        try {
            LogUtils.info("PermissionsService", "=== batchRevoke() called, permissionNames=${permissionNames.size}, roleIds=${roleIds.size} ===")
            
            let rolePermExecutor = ORM.executor()
            var revokedCount = 0
            var skippedCount = 0
            
            // 直接使用传入的权限名称，不级联取消子级
            for (roleId in roleIds) {
                for (permName in permissionNames) {
                    if (!rolePermExecutor.existsRoleHasPermission(roleId, permName)) {
                        skippedCount++
                        continue
                    }
                    
                    let success = rolePermExecutor.deleteRoleHasPermission(roleId, permName)
                    if (success) {
                        revokedCount++
                        LogUtils.info("PermissionsService", "=== Revoked permission ${permName} for role ${roleId} ===")
                    } else {
                        skippedCount++
                    }
                }
            }
            
            let resultJson = "{\"revoked_count\":${revokedCount},\"skipped_count\":${skippedCount},\"message\":\"取消授权完成\"}"
            LogUtils.info("PermissionsService", "=== batchRevoke() completed: revoked=${revokedCount}, skipped=${skippedCount} ===")
            return APIResult<String>(resultJson)
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== batchRevoke() exception: ${e.message} ===")
            return APIResult<String>(false, e.message)
        }
    }
}
