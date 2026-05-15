/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

    //#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.PermissionsPO
import magic.log.LogUtils

/**
 * PermissionsDAO - permissions数据访问接口
 *
 * 提供permissions表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface PermissionsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入permissions（id由数据库自动生成UUID）
     * @param entity PermissionsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertPermissions(entity: PermissionsPO): String {
        executor.setSql('''
            insert into permissions(
                permission_name,
                level,
                icon,
                module,
                component,
                redirect,
                type,
                hidden,
                weight,
                creator,
                created_at,
                updated_at,
                deleted_at,
                keepalive,
                path,
                title,
                parent_id,
                meta,
                method,
                menu_type,
                locale
            ) values(
${arg(entity.permissionName)},
                ${arg(entity.level)},
                ${arg(entity.icon)},
                ${arg(entity.module)},
                ${arg(entity.component)},
                ${arg(entity.redirect)},
                ${arg(entity.typeVal)},
                ${arg(entity.hidden)},
                ${arg(entity.weight)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.keepalive)},
                ${arg(entity.path)},
                ${arg(entity.title)},
                ${arg(entity.parentId)},
                ${arg(entity.meta)},
                ${arg(entity.method)},
                ${arg(entity.menuType)},
                ${arg(entity.locale)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询permissions
     * @param id permissionsID
     * @return permissions对象（Option类型）
     */
    func findPermissionsById(id: String): Option<PermissionsPO> {
        executor.setSql('''
            select * from permissions where id = ${arg(id)}
        ''').first<PermissionsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新permissions
     * @param entity permissions对象
     * @return 影响行数
     */
    func updatePermissions(entity: PermissionsPO): Int64 {
        executor.setSql('''
            update permissions set
                permission_name = ${arg(entity.permissionName)},
                level = ${arg(entity.level)},
                icon = ${arg(entity.icon)},
                module = ${arg(entity.module)},
                component = ${arg(entity.component)},
                redirect = ${arg(entity.redirect)},
                type = ${arg(entity.typeVal)},
                hidden = ${arg(entity.hidden)},
                weight = ${arg(entity.weight)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                keepalive = ${arg(entity.keepalive)},
                path = ${arg(entity.path)},
                title = ${arg(entity.title)},
                parent_id = ${arg(entity.parentId)},
                meta = ${arg(entity.meta)},
                method = ${arg(entity.method)},
                menu_type = ${arg(entity.menuType)},
                locale = ${arg(entity.locale)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除permissions
     * @param id permissionsID
     * @return 影响行数
     */
    func softDeletePermissionsById(id: String): Int64 {
        executor.setSql('''
            update permissions set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的permissions
     * @param id permissionsID
     * @return 影响行数
     */
    func restorePermissionsById(id: String): Int64 {
        executor.setSql('''
            update permissions set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除permissions
     * @param id permissionsID
     * @return 影响行数
     */
    func deletePermissionsById(id: String): Int64 {
        executor.setSql('''
            delete from permissions where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有permissions
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllPermissionsPage(page: Int64, size: Int64): Pagination<PermissionsPO> {
        executor.page<PermissionsPO>('''
            select * from permissions order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询permissions列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findPermissionsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<PermissionsPO> {
        executor.page<PermissionsPO>('''
            select * from permissions where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }



    /**
     * 批量查询permissions
     * @param ids ID列表
     * @return permissions列表
     */
    func findPermissionsByIds(ids: ArrayList<String>): ArrayList<PermissionsPO> {
        executor.setSql('''
            select * from permissions where id ${IN(ids)}
        ''').list<PermissionsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的permissions数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countPermissionsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from permissions where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有permissions数量
     * @return 数量
     */
    func countAllPermissions(): Int64 {
        executor.setSql('''
            select count(*) from permissions
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询permissions列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findPermissionsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<PermissionsPO> {
        let sql = StringBuilder()
        sql.append("select * from permissions where 1=1")

        if (let Some(linkVal) <- link) {
            if (linkVal != "") {
                sql.append(" and link like ${arg('%' + linkVal + '%')}")
            }
        }

        if (let Some(descVal) <- description) {
            if (descVal != "") {
                sql.append(" and description like ${arg('%' + descVal + '%')}")
            }
        }

        // 处理 deleted_at 筛选
        if (let Some(deletedAtVal) <- deletedAt) {
            if (deletedAtVal == "null") {
                // 未删除的数据
                sql.append(" and deleted_at is null")
            } else if (deletedAtVal == "not_null") {
                // 已删除的数据（回收站）
                sql.append(" and deleted_at is not null")
            }
        }

        sql.append(" order by created_at desc")

        executor.page<PermissionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除permissions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeletePermissions(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update permissions set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除permissions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeletePermissions(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from permissions where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询permissions（支持完整查询操作符）
     *
     * @param whereClause WHERE 子句字符串（不包含 WHERE 关键字）
     * @param orderByClause ORDER BY 子句字符串（不包含 ORDER BY 关键字）
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     *
     * 使用示例：
     * - whereClause: "name LIKE '%test%' AND status = 'active'"
     * - orderByClause: "created_at DESC, name ASC"
     */
    func findPermissionsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<PermissionsPO> {
        let sql = StringBuilder()
        sql.append("select * from permissions")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<PermissionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询permissions
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findPermissionsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<PermissionsPO> {
        let fromClause = executor.FROM<PermissionsPO>()

        // 应用 WHERE 条件
        if (!whereClause.isEmpty()) {
            fromClause.WHERE(whereClause)
        }

        // 应用 ORDER BY
        if (!orderByClause.isEmpty()) {
            fromClause.ORDER_BY { => orderByClause }
        } else {
            fromClause.ORDER_BY { => "created_at DESC" }
        }

        // 执行分页查询
        fromClause.page<PermissionsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的permissions）
     * @return 影响行数
     */
    func emptyRecycleBinPermissions(): Int64 {
        executor.setSql('''
            delete from permissions where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========
    /**
     * 查询所有permissions（不分页）
     * @return permissions列表
     */
    func listAllPermissions(): ArrayList<PermissionsPO> {
        executor.setSql('''
            SELECT * FROM permissions
            WHERE deleted_at IS NULL
            ORDER BY type ASC, weight ASC
        ''').list<PermissionsPO>()
    }
    
    /**
     * 查询用户所属的角色ID列表 - V4标准RBAC
     * @param userId 用户ID
     * @return 角色ID列表
     */
    func findUserRoles(userId: String): ArrayList<String> {
        LogUtils.info("[findUserRoles] START for userId: ${userId}")
        let result = executor.setSql('''
            SELECT role_id FROM user_has_roles
            WHERE user_id = ${arg(userId)} AND deleted_at IS NULL
        ''').list<String>()
        LogUtils.info("[findUserRoles] SUCCESS: Found ${result.size} roles")
        return result
    }

    /**
     * 查询角色是否拥有指定权限 - V4标准RBAC
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 权限记录(如果存在)
     */
    func findRolePermission(roleId: String, permissionName: String): ?PermissionsPO {
        executor.setSql('''
            SELECT p.* FROM permissions p
            INNER JOIN role_has_permission rhp ON p.permission_name = rhp.permission_name
            WHERE rhp.role_id = ${arg(roleId)}
              AND rhp.permission_name = ${arg(permissionName)}
              AND p.deleted_at IS NULL
              AND rhp.deleted_at IS NULL
            LIMIT 1
        ''').first<PermissionsPO>()
    }
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 根据权限名称查询权限
     * @param permissionName 权限名称
     * @return 权限对象
     */
    public func findPermissionsByPermissionName(permissionName: String): ?PermissionsPO {
        executor.setSql('''
            SELECT * FROM permissions 
            WHERE permission_name = ${arg(permissionName)} AND deleted_at IS NULL 
            LIMIT 1
        ''').first<PermissionsPO>()
    }
    
    /**
     * 根据角色ID获取权限名称列表 - V4标准RBAC
     * @param roleId 角色ID
     * @return 权限名称列表
     */
    public func findRolePermissionNames(roleId: String): ArrayList<String> {
        LogUtils.info("[findRolePermissionNames] START for roleId: ${roleId}")
        let result = executor.setSql('''
            SELECT permission_name FROM role_has_permission
            WHERE role_id = ${arg(roleId)} AND deleted_at IS NULL
        ''').list<String>()
        LogUtils.info("[findRolePermissionNames] SUCCESS: Found ${result.size} permissions")
        return result
    }
    
    /**
     * 根据权限名称列表查询权限
     * @param permissionNames 权限名称列表
     * @return 权限列表
     */
    public func findPermissionsByNames(permissionNames: ArrayList<String>): ArrayList<PermissionsPO> {
        if (permissionNames.size == 0) {
            return ArrayList<PermissionsPO>()
        }
        
        executor.setSql('''
            SELECT * FROM permissions 
            WHERE permission_name ${IN(permissionNames)} 
              AND deleted_at IS NULL
            ORDER BY weight ASC
        ''').list<PermissionsPO>()
    }
    
    /**
     * 查询所有菜单权限（type=1且menu_type不为空）
     * @return 权限列表
     */
    public func findAllMenuPermissions(): ArrayList<PermissionsPO> {
        executor.setSql('''
            SELECT * FROM permissions 
            WHERE type = 1 
              AND menu_type IS NOT NULL 
              AND deleted_at IS NULL
            ORDER BY weight ASC
        ''').list<PermissionsPO>()
    }

    /**
     * 删除指定parent_id下所有type=3的API权限节点
     * 用于刷新路由权限时先清除旧的API权限节点
     * @param parentId API父菜单ID
     * @return 影响行数
     */
    public func deleteApiPermissionsByParentId(parentId: String): Int64 {
        executor.setSql('''
            DELETE FROM permissions 
            WHERE parent_id = ${arg(parentId)} 
              AND type = 3
        ''').delete
    }

    /**
     * 根据permissionName和method查询权限
     * 用于检查API权限节点是否已存在（同一路径+方法组合）
     * @param permissionName 权限名称(路由路径)
     * @param method HTTP方法
     * @return 权限对象
     */
    public func findPermissionsByNameAndMethod(permissionName: String, method: String): ?PermissionsPO {
        executor.setSql('''
            SELECT * FROM permissions 
            WHERE permission_name = ${arg(permissionName)} 
              AND method = ${arg(method)} 
              AND deleted_at IS NULL 
            LIMIT 1
        ''').first<PermissionsPO>()
    }

    public func findApiPermissionsByParentId(parentId: String): ArrayList<PermissionsPO> {
        executor.setSql('''
            SELECT * FROM permissions 
            WHERE parent_id = ${arg(parentId)} 
              AND type = 3 
              AND deleted_at IS NULL
        ''').list<PermissionsPO>()
    }

    public func findOrphanApiPermissions(): ArrayList<PermissionsPO> {
        executor.setSql('''
            SELECT * FROM permissions 
            WHERE parent_id IS NULL 
              AND type = 3 
              AND deleted_at IS NULL
        ''').list<PermissionsPO>()
    }

    public func updateParentIdForApiPermissions(parentId: String): Int64 {
        executor.setSql('''
            UPDATE permissions 
            SET parent_id = ${arg(parentId)}, 
                updated_at = NOW() 
            WHERE parent_id IS NULL 
              AND type = 3 
              AND deleted_at IS NULL
        ''').update
    }

    public func softDeleteApiPermissionsByIds(ids: ArrayList<String>): Int64 {
        if (ids.size == 0) {
            return Int64(0)
        }
        executor.setSql('''
            UPDATE permissions 
            SET deleted_at = NOW() 
            WHERE id ${IN(ids)} 
              AND deleted_at IS NULL
        ''').update
    }

    public func updatePermissionNameAndMethod(oldName: String, newName: String, newMethod: String): Int64 {
        executor.setSql('''
            UPDATE permissions 
            SET permission_name = ${arg(newName)}, 
                method = ${arg(newMethod)}, 
                path = ${arg(newName)}, 
                updated_at = NOW() 
            WHERE permission_name = ${arg(oldName)} 
              AND deleted_at IS NULL
        ''').update
    }

    /**
     * 查询所有未删除的权限节点（全量查询，超级管理员专用）
     * @return 所有 deleted_at 为空的权限列表
     */
    public func findAllActivePermissions(): ArrayList<PermissionsPO> {
        executor.setSql('''
            SELECT * FROM permissions 
            WHERE deleted_at IS NULL 
            ORDER BY type ASC, weight ASC
        ''').list<PermissionsPO>()
    }

    /**
     * 检查权限名称是否存在于 permissions 表
     * @param permissionName 权限名称
     * @return 是否存在
     */
    public func existsPermissionByName(permissionName: String): Bool {
        let result = executor.setSql('''
            SELECT COUNT(*) as cnt FROM permissions 
            WHERE permission_name = ${arg(permissionName)} 
              AND deleted_at IS NULL
        ''').singleFirst<Int64>()
        result > 0
    }
}
