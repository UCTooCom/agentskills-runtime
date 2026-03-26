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
import magic.app.models.uctoo.RoleHasPermissionPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * RoleHasPermissionDAO - 角色权限关联数据访问接口
 * 
 * 提供role_has_permission表的标准CRUD操作，遵循UCTOO V4 ORM规范
 * 
 * 注意: 此表使用复合主键 (role_id, permission_name)
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface RoleHasPermissionDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入roleHasPermission（复合主键由调用方提供）
     * @param roleHasPermission roleHasPermission对象
     * @return 插入成功返回true，失败返回false
     */
    func insertRoleHasPermission(roleHasPermission: RoleHasPermissionPO): Bool {
        executor.setSql('''
            insert into role_has_permission(
                role_id,
                permission_name,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(roleHasPermission.roleId)},
                ${arg(roleHasPermission.permissionName)},
                ${arg(roleHasPermission.status)},
                ${arg(roleHasPermission.creator)},
                ${arg(roleHasPermission.createdAt)},
                ${arg(roleHasPermission.updatedAt)},
                ${arg(roleHasPermission.deletedAt)}
            )
        ''').update > 0
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据复合主键查询roleHasPermission
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return roleHasPermission对象（Option类型）
     */
    func findRoleHasPermissionById(roleId: String, permissionName: String): Option<RoleHasPermissionPO> {
        executor.setSql('''
            select * from role_has_permission 
            where role_id = ${arg(roleId)} 
            and permission_name = ${arg(permissionName)}
        ''').first<RoleHasPermissionPO>()
    }
    
    /**
     * 根据roleId查询所有关联的权限
     * @param roleId 角色ID
     * @return roleHasPermission列表
     */
    func findRoleHasPermissionsByRoleId(roleId: String): ArrayList<RoleHasPermissionPO> {
        executor.setSql('''
            select * from role_has_permission 
            where role_id = ${arg(roleId)}
            order by created_at desc
        ''').list<RoleHasPermissionPO>()
    }
    
    /**
     * 根据permissionName查询所有关联的角色
     * @param permissionName 权限名称
     * @return roleHasPermission列表
     */
    func findRoleHasPermissionsByPermissionName(permissionName: String): ArrayList<RoleHasPermissionPO> {
        executor.setSql('''
            select * from role_has_permission 
            where permission_name = ${arg(permissionName)}
            order by created_at desc
        ''').list<RoleHasPermissionPO>()
    }
    
    /**
     * 根据多个roleId查询所有关联的权限
     * @param roleIds 角色ID列表
     * @return roleHasPermission列表
     */
    func findRoleHasPermissionsByRoleIds(roleIds: ArrayList<String>): ArrayList<RoleHasPermissionPO> {
        if (roleIds.isEmpty()) {
            return ArrayList<RoleHasPermissionPO>()
        }
        
        // 构建IN子句
        let inClause = StringBuilder()
        for (i in 0..roleIds.size) {
            if (i > 0) {
                inClause.append(",")
            }
            inClause.append("${arg(roleIds[i])}")
        }
        
        executor.setSql('''
            select * from role_has_permission 
            where role_id in (${inClause.toString()})
            order by created_at desc
        ''').list<RoleHasPermissionPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新roleHasPermission（根据复合主键）
     * @param roleHasPermission roleHasPermission对象
     * @return 更新成功返回true，失败返回false
     */
    func updateRoleHasPermission(roleHasPermission: RoleHasPermissionPO): Bool {
        executor.setSql('''
            update role_has_permission set
                status = ${arg(roleHasPermission.status)},
                creator = ${arg(roleHasPermission.creator)},
                updated_at = ${arg(DateTime.now())},
                deleted_at = ${arg(roleHasPermission.deletedAt)}
            where role_id = ${arg(roleHasPermission.roleId)}
            and permission_name = ${arg(roleHasPermission.permissionName)}
        ''').update > 0
    }
    
    /**
     * 更新状态
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @param status 新状态
     * @return 更新成功返回true，失败返回false
     */
    func updateRoleHasPermissionStatus(roleId: String, permissionName: String, status: Int32): Bool {
        executor.setSql('''
            update role_has_permission set
                status = ${arg(status)},
                updated_at = ${arg(DateTime.now())}
            where role_id = ${arg(roleId)}
            and permission_name = ${arg(permissionName)}
        ''').update > 0
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 删除roleHasPermission（根据复合主键）
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 删除成功返回true，失败返回false
     */
    func deleteRoleHasPermission(roleId: String, permissionName: String): Bool {
        executor.setSql('''
            delete from role_has_permission 
            where role_id = ${arg(roleId)} 
            and permission_name = ${arg(permissionName)}
        ''').update > 0
    }
    
    /**
     * 软删除roleHasPermission（根据复合主键）
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 软删除成功返回true，失败返回false
     */
    func softDeleteRoleHasPermission(roleId: String, permissionName: String): Bool {
        executor.setSql('''
            update role_has_permission set
                deleted_at = ${arg(DateTime.now())}
            where role_id = ${arg(roleId)}
            and permission_name = ${arg(permissionName)}
        ''').update > 0
    }
    
    /**
     * 删除角色的所有权限关联
     * @param roleId 角色ID
     * @return 删除成功返回true，失败返回false
     */
    func deleteRoleHasPermissionsByRoleId(roleId: String): Bool {
        executor.setSql('''
            delete from role_has_permission 
            where role_id = ${arg(roleId)}
        ''').update > 0
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计角色拥有的权限数量
     * @param roleId 角色ID
     * @return 权限数量
     */
    func countRoleHasPermissionsByRoleId(roleId: String): Int64 {
        executor.setSql('''
            select count(*) from role_has_permission 
            where role_id = ${arg(roleId)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计权限被多少角色使用
     * @param permissionName 权限名称
     * @return 角色数量
     */
    func countRoleHasPermissionsByPermissionName(permissionName: String): Int64 {
        executor.setSql('''
            select count(*) from role_has_permission 
            where permission_name = ${arg(permissionName)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 检查角色是否拥有权限
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 存在返回true，不存在返回false
     */
    func existsRoleHasPermission(roleId: String, permissionName: String): Bool {
        let count = executor.setSql('''
            select count(*) from role_has_permission 
            where role_id = ${arg(roleId)} 
            and permission_name = ${arg(permissionName)}
        ''').first<Int64>() ?? 0
        count > 0
    }
    
    //#endregion AutoCreateCode
}
