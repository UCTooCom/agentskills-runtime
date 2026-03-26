/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.PermissionsPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * PermissionsDAO - permissions数据访问接口
 * 
 * 提供标准CRUD操作，遵循UCTOO V4 ORM规范
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
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入permissions（id由数据库自动生成UUID）
     * @param entity permissions对象
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
                method
            ) values(
                ${arg(entity.permissionName)},
                ${arg(entity.level)},
                ${arg(entity.icon)},
                ${arg(entity.module)},
                ${arg(entity.component)},
                ${arg(entity.redirect)},
                ${arg(entity.permissionType)},
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
                ${arg(entity.method)}
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
                type = ${arg(entity.permissionType)},
                hidden = ${arg(entity.hidden)},
                weight = ${arg(entity.weight)},
                deleted_at = ${arg(entity.deletedAt)},
                keepalive = ${arg(entity.keepalive)},
                path = ${arg(entity.path)},
                title = ${arg(entity.title)},
                parent_id = ${arg(entity.parentId)},
                meta = ${arg(entity.meta)},
                method = ${arg(entity.method)},
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
     * 查询所有permissions（不分页）
     * @return permissions列表
     */
    func listAllPermissions(): ArrayList<PermissionsPO> {
        executor.setSql('''
            select * from permissions order by created_at desc
        ''').list<PermissionsPO>()
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

    //#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 查询用户所属的角色ID列表 - V4标准RBAC
     * @param userId 用户ID
     * @return 角色ID列表
     */
    func findUserRoles(userId: String): ArrayList<String> {
        let result = ArrayList<String>()
        let rows = executor.setSql('''
            SELECT role_id FROM user_has_roles
            WHERE user_id = ${arg(userId)} AND deleted_at IS NULL
        ''').list<PermissionsPO>()

        for (row in rows) {
            result.add(row.id)
        }

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
}
