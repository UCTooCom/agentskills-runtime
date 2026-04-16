/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.EntityPO
import magic.log.LogUtils

/**
 * EntityDAO - 实体数据访问接口
 * 
 * 提供entity表的标准CRUD操作，遵循UCTOO V4 ORM规范
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface EntityDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入entity（id由数据库自动生成UUID）
     * @param entity entity对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertEntity(entity: EntityPO): String {
        executor.setSql('''
            insert into entity(
                link,
                privacy_level,
                stars,
                description,
                group_id,
                picture,
                images,
                content,
                json,
                city,
                price,
                birthday,
                owner,
                creator,
                created_at,
                updated_at,
                deleted_at,
                end_time,
                start_time,
                status
            ) values(
                ${arg(entity.link)},
                ${arg(entity.privacyLevel)},
                ${arg(entity.stars)},
                ${arg(entity.description)},
                ${arg(entity.groupId)},
                ${arg(entity.picture)},
                ${arg(entity.images)},
                ${arg(entity.content)},
                ${arg(entity.json)},
                ${arg(entity.city)},
                ${arg(entity.price)},
                ${arg(entity.birthday)},
                ${arg(entity.owner)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.endTime)},
                ${arg(entity.startTime)},
                ${arg(entity.status)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询entity
     * @param id entityID
     * @return entity对象（Option类型）
     */
    func findEntityById(id: String): Option<EntityPO> {
        executor.setSql('''
            select * from entity where id = ${arg(id)}
        ''').first<EntityPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新entity
     * @param entity entity对象
     * @return 影响行数
     */
    func updateEntity(entity: EntityPO): Int64 {
        executor.setSql('''
            update entity set
                link = ${arg(entity.link)},
                privacy_level = ${arg(entity.privacyLevel)},
                stars = ${arg(entity.stars)},
                description = ${arg(entity.description)},
                group_id = ${arg(entity.groupId)},
                picture = ${arg(entity.picture)},
                images = ${arg(entity.images)},
                content = ${arg(entity.content)},
                json = ${arg(entity.json)},
                city = ${arg(entity.city)},
                price = ${arg(entity.price)},
                birthday = ${arg(entity.birthday)},
                owner = ${arg(entity.owner)},
                deleted_at = ${arg(entity.deletedAt)},
                end_time = ${arg(entity.endTime)},
                start_time = ${arg(entity.startTime)},
                status = ${arg(entity.status)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除entity
     * @param id entityID
     * @return 影响行数
     */
    func softDeleteEntityById(id: String): Int64 {
        executor.setSql('''
            update entity set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的entity
     * @param id entityID
     * @return 影响行数
     */
    func restoreEntityById(id: String): Int64 {
        executor.setSql('''
            update entity set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除entity
     * @param id entityID
     * @return 影响行数
     */
    func deleteEntityById(id: String): Int64 {
        executor.setSql('''
            delete from entity where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有entity
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllEntityPage(page: Int64, size: Int64): Pagination<EntityPO> {
        executor.page<EntityPO>('''
            select * from entity order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询entity列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findEntityByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<EntityPO> {
        executor.page<EntityPO>('''
            select * from entity where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有entity（不分页）
     * @return entity列表
     */
    func listAllEntity(): ArrayList<EntityPO> {
        executor.setSql('''
            select * from entity order by created_at desc
        ''').list<EntityPO>()
    }
    
    /**
     * 批量查询entity
     * @param ids ID列表
     * @return entity列表
     */
    func findEntityByIds(ids: ArrayList<String>): ArrayList<EntityPO> {
        executor.setSql('''
            select * from entity where id ${IN(ids)}
        ''').list<EntityPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的entity数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countEntityByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from entity where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有entity数量
     * @return 数量
     */
    func countAllEntity(): Int64 {
        executor.setSql('''
            select count(*) from entity
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 分页查询entity列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findEntityByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<EntityPO> {
        let sql = StringBuilder()
        sql.append("select * from entity where 1=1")

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

        executor.page<EntityPO>(sql.toString(), size, page: page)
    }
    
    /**
     * 批量软删除entity
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteEntity(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update entity set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }
    
    /**
     * 批量硬删除entity
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteEntity(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from entity where id ${IN(ids)}
        ''').delete
    }
    
    /**
     * 动态条件查询entity（支持完整查询操作符）
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
    func findEntityByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<EntityPO> {
        let sql = StringBuilder()
        sql.append("select * from entity")
        
        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }
        
        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }
        
        executor.page<EntityPO>(sql.toString(), size, page: page)
    }
    
    /**
     * 使用 f_orm Condition API 查询entity
     * 
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findEntityByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<EntityPO> {
        let fromClause = executor.FROM<EntityPO>()
        
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
        fromClause.page<EntityPO>(size, page: page)
    }
    
    /**
     * 清空回收站（硬删除所有已软删除的entity）
     * @return 影响行数
     */
    func emptyRecycleBin(): Int64 {
        executor.setSql('''
            delete from entity where deleted_at is not null
        ''').delete
    }
}
