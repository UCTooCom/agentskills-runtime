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
import magic.app.models.uctoo.AipAgentDescriptionPO
import magic.log.LogUtils

/**
 * AipAgentDescriptionDAO - aip_agent_description数据访问接口
 *
 * 提供aip_agent_description表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AipAgentDescriptionDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入aip_agent_description（id由数据库自动生成UUID）
     * @param entity AipAgentDescriptionPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAipAgentDescription(entity: AipAgentDescriptionPO): String {
        executor.setSql('''
            insert into aip_agent_description(
                agent_identity_id,
                agent_id,
                agent_id_code,
                name,
                alias,
                version,
                description,
                icon_address,
                provider,
                access_address,
                access_method,
                serving_area,
                authentication,
                capabilities,
                default_input_types,
                default_output_types,
                skills,
                discoverable,
                publish_status,
                published_at,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentIdentityId)},
                ${arg(entity.agentId)},
                ${arg(entity.agentIdCode)},
                ${arg(entity.name)},
                ${arg(entity.alias)},
                ${arg(entity.version)},
                ${arg(entity.description)},
                ${arg(entity.iconAddress)},
                ${arg(entity.provider)},
                ${arg(entity.accessAddress)},
                ${arg(entity.accessMethod)},
                ${arg(entity.servingArea)},
                ${arg(entity.authentication)},
                ${arg(entity.capabilities)},
                ${arg(entity.defaultInputTypes)},
                ${arg(entity.defaultOutputTypes)},
                ${arg(entity.skills)},
                ${arg(entity.discoverable)},
                ${arg(entity.publishStatus)},
                ${arg(entity.publishedAt)},
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
     * 根据ID查询aip_agent_description
     * @param id aip_agent_descriptionID
     * @return aip_agent_description对象（Option类型）
     */
    func findAipAgentDescriptionById(id: String): Option<AipAgentDescriptionPO> {
        executor.setSql('''
            select id, agent_identity_id, agent_id, agent_id_code, name, alias, version, description, icon_address, provider, access_address, access_method, serving_area, authentication, capabilities, default_input_types, default_output_types, skills, discoverable, publish_status, published_at, creator, created_at, updated_at, deleted_at from aip_agent_description where id = ${arg(id)}
        ''').first<AipAgentDescriptionPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新aip_agent_description
     * @param entity aip_agent_description对象
     * @return 影响行数
     */
    func updateAipAgentDescription(entity: AipAgentDescriptionPO): Int64 {
        executor.setSql('''
            update aip_agent_description set
                agent_identity_id = ${arg(entity.agentIdentityId)},
                agent_id = ${arg(entity.agentId)},
                agent_id_code = ${arg(entity.agentIdCode)},
                name = ${arg(entity.name)},
                alias = ${arg(entity.alias)},
                version = ${arg(entity.version)},
                description = ${arg(entity.description)},
                icon_address = ${arg(entity.iconAddress)},
                provider = ${arg(entity.provider)},
                access_address = ${arg(entity.accessAddress)},
                access_method = ${arg(entity.accessMethod)},
                serving_area = ${arg(entity.servingArea)},
                authentication = ${arg(entity.authentication)},
                capabilities = ${arg(entity.capabilities)},
                default_input_types = ${arg(entity.defaultInputTypes)},
                default_output_types = ${arg(entity.defaultOutputTypes)},
                skills = ${arg(entity.skills)},
                discoverable = ${arg(entity.discoverable)},
                publish_status = ${arg(entity.publishStatus)},
                published_at = ${arg(entity.publishedAt)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除aip_agent_description
     * @param id aip_agent_descriptionID
     * @return 影响行数
     */
    func softDeleteAipAgentDescriptionById(id: String): Int64 {
        executor.setSql('''
            update aip_agent_description set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的aip_agent_description
     * @param id aip_agent_descriptionID
     * @return 影响行数
     */
    func restoreAipAgentDescriptionById(id: String): Int64 {
        executor.setSql('''
            update aip_agent_description set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除aip_agent_description
     * @param id aip_agent_descriptionID
     * @return 影响行数
     */
    func deleteAipAgentDescriptionById(id: String): Int64 {
        executor.setSql('''
            delete from aip_agent_description where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有aip_agent_description
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAipAgentDescriptionPage(page: Int64, size: Int64): Pagination<AipAgentDescriptionPO> {
        executor.page<AipAgentDescriptionPO>('''
            select id, agent_identity_id, agent_id, agent_id_code, name, alias, version, description, icon_address, provider, access_address, access_method, serving_area, authentication, capabilities, default_input_types, default_output_types, skills, discoverable, publish_status, published_at, creator, created_at, updated_at, deleted_at from aip_agent_description order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询aip_agent_description列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipAgentDescriptionByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AipAgentDescriptionPO> {
        executor.page<AipAgentDescriptionPO>('''
            select id, agent_identity_id, agent_id, agent_id_code, name, alias, version, description, icon_address, provider, access_address, access_method, serving_area, authentication, capabilities, default_input_types, default_output_types, skills, discoverable, publish_status, published_at, creator, created_at, updated_at, deleted_at from aip_agent_description where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有aip_agent_description（不分页）
     * @return aip_agent_description列表
     */
    func listAllAipAgentDescription(): ArrayList<AipAgentDescriptionPO> {
        executor.setSql('''
            select id, agent_identity_id, agent_id, agent_id_code, name, alias, version, description, icon_address, provider, access_address, access_method, serving_area, authentication, capabilities, default_input_types, default_output_types, skills, discoverable, publish_status, published_at, creator, created_at, updated_at, deleted_at from aip_agent_description order by created_at desc
        ''').list<AipAgentDescriptionPO>()
    }

    /**
     * 批量查询aip_agent_description
     * @param ids ID列表
     * @return aip_agent_description列表
     */
    func findAipAgentDescriptionByIds(ids: ArrayList<String>): ArrayList<AipAgentDescriptionPO> {
        if (ids.isEmpty()) {
            return ArrayList<AipAgentDescriptionPO>()
        }
        executor.setSql('''
            select id, agent_identity_id, agent_id, agent_id_code, name, alias, version, description, icon_address, provider, access_address, access_method, serving_area, authentication, capabilities, default_input_types, default_output_types, skills, discoverable, publish_status, published_at, creator, created_at, updated_at, deleted_at from aip_agent_description where id ${IN(ids)}
        ''').list<AipAgentDescriptionPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的aip_agent_description数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAipAgentDescriptionByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from aip_agent_description where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有aip_agent_description数量
     * @return 数量
     */
    func countAllAipAgentDescription(): Int64 {
        executor.setSql('''
            select count(*) from aip_agent_description
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询aip_agent_description列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipAgentDescriptionByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AipAgentDescriptionPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_identity_id, agent_id, agent_id_code, name, alias, version, description, icon_address, provider, access_address, access_method, serving_area, authentication, capabilities, default_input_types, default_output_types, skills, discoverable, publish_status, published_at, creator, created_at, updated_at, deleted_at from aip_agent_description where 1=1")

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

        executor.page<AipAgentDescriptionPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除aip_agent_description
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAipAgentDescription(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update aip_agent_description set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除aip_agent_description
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAipAgentDescription(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from aip_agent_description where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询aip_agent_description（支持完整查询操作符）
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
    func findAipAgentDescriptionByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipAgentDescriptionPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_identity_id, agent_id, agent_id_code, name, alias, version, description, icon_address, provider, access_address, access_method, serving_area, authentication, capabilities, default_input_types, default_output_types, skills, discoverable, publish_status, published_at, creator, created_at, updated_at, deleted_at from aip_agent_description")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AipAgentDescriptionPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询aip_agent_description
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipAgentDescriptionByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipAgentDescriptionPO> {
        let fromClause = executor.FROM<AipAgentDescriptionPO>()

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
        fromClause.page<AipAgentDescriptionPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的aip_agent_description）
     * @return 影响行数
     */
    func emptyRecycleBinAipAgentDescription(): Int64 {
        executor.setSql('''
            delete from aip_agent_description where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
