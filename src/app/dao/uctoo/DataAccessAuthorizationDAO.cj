/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.DataAccessAuthorizationPO
import magic.log.LogUtils

/**
 * DataAccessAuthorizationDAO - data_access_authorization数据访问接口
 *
 * 提供data_access_authorization表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface DataAccessAuthorizationDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入data_access_authorization（id由数据库自动生成UUID）
     * @param entity DataAccessAuthorizationPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertDataAccessAuthorization(entity: DataAccessAuthorizationPO): String {
        executor.setSql('''
            insert into data_access_authorization(
                entity_id,
                entity_type,
                user_id,
                permission,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.entityId)},
                ${arg(entity.entityType)},
                ${arg(entity.userId)},
                ${arg(entity.permission)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询data_access_authorization
     * @param id data_access_authorizationID
     * @return data_access_authorization对象（Option类型）
     */
    func findDataAccessAuthorizationById(id: String): Option<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization where id = ${arg(id)}
        ''').first<DataAccessAuthorizationPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新data_access_authorization
     * @param entity data_access_authorization对象
     * @return 影响行数
     */
    func updateDataAccessAuthorization(entity: DataAccessAuthorizationPO): Int64 {
        executor.setSql('''
            update data_access_authorization set
                entity_id = ${arg(entity.entityId)},
                entity_type = ${arg(entity.entityType)},
                user_id = ${arg(entity.userId)},
                permission = ${arg(entity.permission)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除data_access_authorization
     * @param id data_access_authorizationID
     * @return 影响行数
     */
    func softDeleteDataAccessAuthorizationById(id: String): Int64 {
        executor.setSql('''
            update data_access_authorization set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的data_access_authorization
     * @param id data_access_authorizationID
     * @return 影响行数
     */
    func restoreDataAccessAuthorizationById(id: String): Int64 {
        executor.setSql('''
            update data_access_authorization set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除data_access_authorization
     * @param id data_access_authorizationID
     * @return 影响行数
     */
    func deleteDataAccessAuthorizationById(id: String): Int64 {
        executor.setSql('''
            delete from data_access_authorization where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有data_access_authorization
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllDataAccessAuthorizationPage(page: Int64, size: Int64): Pagination<DataAccessAuthorizationPO> {
        executor.page<DataAccessAuthorizationPO>('''
            select * from data_access_authorization order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询data_access_authorization列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDataAccessAuthorizationByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<DataAccessAuthorizationPO> {
        executor.page<DataAccessAuthorizationPO>('''
            select * from data_access_authorization where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有data_access_authorization（不分页）
     * @return data_access_authorization列表
     */
    func listAllDataAccessAuthorization(): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization order by created_at desc
        ''').list<DataAccessAuthorizationPO>()
    }

    /**
     * 批量查询data_access_authorization
     * @param ids ID列表
     * @return data_access_authorization列表
     */
    func findDataAccessAuthorizationByIds(ids: ArrayList<String>): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization where id ${IN(ids)}
        ''').list<DataAccessAuthorizationPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的data_access_authorization数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countDataAccessAuthorizationByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from data_access_authorization where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有data_access_authorization数量
     * @return 数量
     */
    func countAllDataAccessAuthorization(): Int64 {
        executor.setSql('''
            select count(*) from data_access_authorization
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询data_access_authorization列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDataAccessAuthorizationByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<DataAccessAuthorizationPO> {
        let sql = StringBuilder()
        sql.append("select * from data_access_authorization where 1=1")

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

        executor.page<DataAccessAuthorizationPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除data_access_authorization
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteDataAccessAuthorization(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update data_access_authorization set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除data_access_authorization
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteDataAccessAuthorization(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from data_access_authorization where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询data_access_authorization（支持完整查询操作符）
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
    func findDataAccessAuthorizationByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<DataAccessAuthorizationPO> {
        let sql = StringBuilder()
        sql.append("select * from data_access_authorization")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<DataAccessAuthorizationPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询data_access_authorization
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDataAccessAuthorizationByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<DataAccessAuthorizationPO> {
        let fromClause = executor.FROM<DataAccessAuthorizationPO>()

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
        fromClause.page<DataAccessAuthorizationPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的data_access_authorization）
     * @return 影响行数
     */
    func emptyRecycleBinDataAccessAuthorization(): Int64 {
        executor.setSql('''
            delete from data_access_authorization where deleted_at is not null
        ''').delete
    }

    // ==================== 行级权限查询方法 ====================

    /**
     * 根据用户ID、实体类型和实体ID查询有效授权记录
     */
    func findAuthByUserIdAndEntityTypeAndEntityId(userId: String, entityType: String, entityId: String): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization
            where user_id = ${arg(userId)} and entity_type = ${arg(entityType)} and entity_id = ${arg(entityId)}
            and deleted_at is null
        ''').list<DataAccessAuthorizationPO>()
    }

    /**
     * 根据用户ID、实体类型和权限级别>=指定值查询有效授权记录
     */
    func findAuthByUserIdAndEntityTypeAndPermissionGte(userId: String, entityType: String, minPermission: Int32): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization
            where user_id = ${arg(userId)} and entity_type = ${arg(entityType)} and permission >= ${arg(minPermission)}
            and deleted_at is null
        ''').list<DataAccessAuthorizationPO>()
    }

    /**
     * 查询实体的所有有效授权记录
     */
    func findAuthByEntityTypeAndEntityId(entityType: String, entityId: String): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization
            where entity_type = ${arg(entityType)} and entity_id = ${arg(entityId)}
            and deleted_at is null
        ''').list<DataAccessAuthorizationPO>()
    }

    /**
     * 查询用户对某实体类型的所有有效授权记录
     */
    func findAuthByUserIdAndEntityType(userId: String, entityType: String): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization
            where user_id = ${arg(userId)} and entity_type = ${arg(entityType)}
            and deleted_at is null
        ''').list<DataAccessAuthorizationPO>()
    }

    /**
     * 批量查询用户对多个实体的有效授权记录
     */
    func findAuthByUserIdAndEntityTypeAndEntityIds(userId: String, entityType: String, entityIds: ArrayList<String>): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization
            where user_id = ${arg(userId)} and entity_type = ${arg(entityType)} and entity_id ${IN(entityIds)}
            and deleted_at is null
        ''').list<DataAccessAuthorizationPO>()
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
