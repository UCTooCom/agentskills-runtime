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
import magic.app.models.uctoo.GroupHasPermissionPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * GroupHasPermissionDAO - 组权限关联数据访问接口
 * 
 * 提供group_has_permission表的标准CRUD操作，遵循UCTOO V4 ORM规范
 * 
 * 注意: 此表使用复合主键 (group_id, permission_name)
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface GroupHasPermissionDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入groupHasPermission（复合主键由调用方提供）
     * @param groupHasPermission groupHasPermission对象
     * @return 插入成功返回true，失败返回false
     */
    func insertGroupHasPermission(groupHasPermission: GroupHasPermissionPO): Bool {
        executor.setSql('''
            insert into group_has_permission(
                group_id,
                permission_name,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(groupHasPermission.groupIdProp)},
                ${arg(groupHasPermission.permissionNameProp)},
                ${arg(groupHasPermission.statusProp)},
                ${arg(groupHasPermission.creatorProp)},
                ${arg(groupHasPermission.createdAtProp)},
                ${arg(groupHasPermission.updatedAtProp)},
                ${arg(groupHasPermission.deletedAtProp)}
            )
        ''').update > 0
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据复合主键查询groupHasPermission
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return groupHasPermission对象（Option类型）
     */
    func findGroupHasPermissionById(groupId: String, permissionName: String): Option<GroupHasPermissionPO> {
        executor.setSql('''
            select * from group_has_permission 
            where group_id = ${arg(groupId)} 
            and permission_name = ${arg(permissionName)}
        ''').first<GroupHasPermissionPO>()
    }
    
    /**
     * 根据groupId查询所有关联的权限
     * @param groupId 组ID
     * @return groupHasPermission列表
     */
    func findGroupHasPermissionsByGroupId(groupId: String): ArrayList<GroupHasPermissionPO> {
        executor.setSql('''
            select * from group_has_permission 
            where group_id = ${arg(groupId)}
            order by created_at desc
        ''').list<GroupHasPermissionPO>()
    }
    
    /**
     * 根据permissionName查询所有关联的组
     * @param permissionName 权限名称
     * @return groupHasPermission列表
     */
    func findGroupHasPermissionsByPermissionName(permissionName: String): ArrayList<GroupHasPermissionPO> {
        executor.setSql('''
            select * from group_has_permission 
            where permission_name = ${arg(permissionName)}
            order by created_at desc
        ''').list<GroupHasPermissionPO>()
    }
    
    /**
     * 根据多个groupId查询所有关联的权限
     * @param groupIds 组ID列表
     * @return groupHasPermission列表
     */
    func findGroupHasPermissionsByGroupIds(groupIds: ArrayList<String>): ArrayList<GroupHasPermissionPO> {
        if (groupIds.isEmpty()) {
            return ArrayList<GroupHasPermissionPO>()
        }
        
        // 构建IN子句
        let inClause = StringBuilder()
        for (i in 0..groupIds.size) {
            if (i > 0) {
                inClause.append(",")
            }
            inClause.append("${arg(groupIds[i])}")
        }
        
        executor.setSql('''
            select * from group_has_permission 
            where group_id in (${inClause.toString()})
            order by created_at desc
        ''').list<GroupHasPermissionPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新groupHasPermission（根据复合主键）
     * @param groupHasPermission groupHasPermission对象
     * @return 更新成功返回true，失败返回false
     */
    func updateGroupHasPermission(groupHasPermission: GroupHasPermissionPO): Bool {
        executor.setSql('''
            update group_has_permission set
                status = ${arg(groupHasPermission.statusProp)},
                creator = ${arg(groupHasPermission.creatorProp)},
                updated_at = ${arg(DateTime.now())},
                deleted_at = ${arg(groupHasPermission.deletedAtProp)}
            where group_id = ${arg(groupHasPermission.groupIdProp)}
            and permission_name = ${arg(groupHasPermission.permissionNameProp)}
        ''').update > 0
    }
    
    /**
     * 更新状态
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @param status 新状态
     * @return 更新成功返回true，失败返回false
     */
    func updateGroupHasPermissionStatus(groupId: String, permissionName: String, status: Int32): Bool {
        executor.setSql('''
            update group_has_permission set
                status = ${arg(status)},
                updated_at = ${arg(DateTime.now())}
            where group_id = ${arg(groupId)}
            and permission_name = ${arg(permissionName)}
        ''').update > 0
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 删除groupHasPermission（根据复合主键）
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return 删除成功返回true，失败返回false
     */
    func deleteGroupHasPermission(groupId: String, permissionName: String): Bool {
        executor.setSql('''
            delete from group_has_permission 
            where group_id = ${arg(groupId)} 
            and permission_name = ${arg(permissionName)}
        ''').update > 0
    }
    
    /**
     * 软删除groupHasPermission（根据复合主键）
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return 软删除成功返回true，失败返回false
     */
    func softDeleteGroupHasPermission(groupId: String, permissionName: String): Bool {
        executor.setSql('''
            update group_has_permission set
                deleted_at = ${arg(DateTime.now())}
            where group_id = ${arg(groupId)}
            and permission_name = ${arg(permissionName)}
        ''').update > 0
    }
    
    /**
     * 删除组的所有权限关联
     * @param groupId 组ID
     * @return 删除成功返回true，失败返回false
     */
    func deleteGroupHasPermissionsByGroupId(groupId: String): Bool {
        executor.setSql('''
            delete from group_has_permission 
            where group_id = ${arg(groupId)}
        ''').update > 0
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计组拥有的权限数量
     * @param groupId 组ID
     * @return 权限数量
     */
    func countGroupHasPermissionsByGroupId(groupId: String): Int64 {
        executor.setSql('''
            select count(*) from group_has_permission 
            where group_id = ${arg(groupId)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计权限被多少组使用
     * @param permissionName 权限名称
     * @return 组数量
     */
    func countGroupHasPermissionsByPermissionName(permissionName: String): Int64 {
        executor.setSql('''
            select count(*) from group_has_permission 
            where permission_name = ${arg(permissionName)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 检查组是否拥有权限
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return 存在返回true，不存在返回false
     */
    func existsGroupHasPermission(groupId: String, permissionName: String): Bool {
        let count = executor.setSql('''
            select count(*) from group_has_permission 
            where group_id = ${arg(groupId)} 
            and permission_name = ${arg(permissionName)}
        ''').first<Int64>() ?? 0
        count > 0
    }
    
    //#endregion AutoCreateCode
}
