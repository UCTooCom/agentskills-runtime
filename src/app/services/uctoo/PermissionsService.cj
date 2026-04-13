/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.PermissionsPO
import magic.app.dao.uctoo.PermissionsDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

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
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建permissions
     * @param entity permissions对象
     * @return 创建结果
     */
    public func create(entity: PermissionsPO): APIResult<PermissionsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
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
     * @param entityId permissionsID
     * @param entity permissions对象（只包含要更新的字段）
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
            if (entity.permissionType.isSome()) {
                existingEntity.permissionType = entity.permissionType
            }
            if (entity.hidden.isSome()) {
                existingEntity.hidden = entity.hidden
            }
            if (entity.weight.isSome()) {
                existingEntity.weight = entity.weight
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.keepalive.isSome()) {
                existingEntity.keepalive = entity.keepalive
            }
            if (entity.path.size > 0) {
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
     * @param entityId permissionsID
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
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findPermissionsById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deletePermissionsById(id)
                    } else {
                        rows = rows + getExecutor().softDeletePermissionsById(id)
                    }
                }
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
     * 
     * 设计说明：
     * - 通过ID获取permissions时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId permissionsID
     * @return permissions对象
     */
    public func getById(entityId: String): APIResult<PermissionsPO> {
        try {
            LogUtils.info("PermissionsService", "=== PermissionsService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findPermissionsById(entityId)
            LogUtils.info("PermissionsService", "=== findPermissionsById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("PermissionsService", "=== Permissions found, id: ${entity.id} ===")
                return APIResult<PermissionsPO>(entity)
            } else {
                LogUtils.info("PermissionsService", "=== Permissions not found for id: ${entityId} ===")
                return APIResult<PermissionsPO>(false, "未找到该permissions")
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionsService", "=== PermissionsService.getById() exception: ${e.message} ===")
            return APIResult<PermissionsPO>(false, e.message)
        }
    }
    
    /**
     * 获取permissions列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return permissions列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<PermissionsPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllPermissionsPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取permissions列表（带跳过参数）
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
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllPermissionsPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
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
}
