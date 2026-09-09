/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.entity

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.{ArrayList}
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}

/**
 * EntityDAO - entity数据访问接口
 *
 * 提供entity表的标准CRUD操作，遵循UCTOO V4 ORM规范。
 * 插件轨实现（plugingen 生成）：与 PO 同包，无跨包 import。
 */
@DAO
public interface EntityDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入entity（id由数据库自动生成UUID）
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
     */
    func findEntityById(id: String): Option<EntityPO> {
        executor.setSql('''
            select id, link, privacy_level, stars, description, group_id, picture, images, content, json, city, price, birthday, owner, creator, created_at, updated_at, deleted_at, end_time, start_time, status from entity where id = ${arg(id)}
        ''').first<EntityPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新entity
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
                creator = ${arg(entity.creator)},
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
     */
    func softDeleteEntityById(id: String): Int64 {
        executor.setSql('''
            update entity set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的entity
     */
    func restoreEntityById(id: String): Int64 {
        executor.setSql('''
            update entity set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除entity
     */
    func deleteEntityById(id: String): Int64 {
        executor.setSql('''
            delete from entity where id = ${arg(id)}
        ''').delete
    }

    /**
     * 批量软删除entity
     */
    func batchSoftDeleteEntity(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update entity set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除entity
     */
    func batchDeleteEntity(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from entity where id ${IN(ids)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有entity
     */
    func findAllEntityPage(page: Int64, size: Int64): Pagination<EntityPO> {
        executor.page<EntityPO>('''
            select id, link, privacy_level, stars, description, group_id, picture, images, content, json, city, price, birthday, owner, creator, created_at, updated_at, deleted_at, end_time, start_time, status from entity order by created_at desc
        ''', size, page: page)
    }

    /**
     * 批量查询entity
     */
    func findEntityByIds(ids: ArrayList<String>): ArrayList<EntityPO> {
        if (ids.isEmpty()) {
            return ArrayList<EntityPO>()
        }
        executor.setSql('''
            select id, link, privacy_level, stars, description, group_id, picture, images, content, json, city, price, birthday, owner, creator, created_at, updated_at, deleted_at, end_time, start_time, status from entity where id ${IN(ids)}
        ''').list<EntityPO>()
    }

    /**
     * 动态条件分页查询entity（Prisma 风格 filter/sort 构建轨）
     */
    func findEntityByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<EntityPO> {
        let fromClause = executor.FROM<EntityPO>()

        if (!whereClause.isEmpty()) {
            fromClause.WHERE(whereClause)
        }

        if (!orderByClause.isEmpty()) {
            fromClause.ORDER_BY { => orderByClause }
        } else {
            fromClause.ORDER_BY { => "created_at DESC" }
        }

        fromClause.page<EntityPO>(size, page: page)
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的entity数量
     */
    func countEntityByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from entity where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有entity数量
     */
    func countAllEntity(): Int64 {
        executor.setSql('''
            select count(*) from entity
        ''').first<Int64>() ?? 0
    }

    /**
     * 清空回收站（硬删除所有已软删除的entity）
     * @return 影响行数
     */
    func emptyRecycleBinEntity(): Int64 {
        executor.setSql('''
            delete from entity where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
