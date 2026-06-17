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
import magic.app.models.uctoo.AgentGroupsPO
import magic.log.LogUtils

/**
 * AgentGroupsDAO - agent_groups数据访问接口
 *
 * 提供agent_groups表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AgentGroupsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入agent_groups（id由数据库自动生成UUID）
     * @param entity AgentGroupsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAgentGroups(entity: AgentGroupsPO): String {
        executor.setSql('''
            insert into agent_groups(
                name,
                group_type,
                leader_id,
                member_ids,
                config,
                status,
                max_round,
                description,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.name)},
                ${arg(entity.groupType)},
                ${arg(entity.leaderId)},
                ${arg(entity.memberIds)},
                ${arg(entity.config)},
                ${arg(entity.status)},
                ${arg(entity.maxRound)},
                ${arg(entity.description)},
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
     * 根据ID查询agent_groups
     * @param id agent_groupsID
     * @return agent_groups对象（Option类型）
     */
    func findAgentGroupsById(id: String): Option<AgentGroupsPO> {
        executor.setSql('''
            select id, name, group_type, leader_id, member_ids, config, status, max_round, description, creator, created_at, updated_at, deleted_at from agent_groups where id = ${arg(id)}
        ''').first<AgentGroupsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新agent_groups
     * @param entity agent_groups对象
     * @return 影响行数
     */
    func updateAgentGroups(entity: AgentGroupsPO): Int64 {
        executor.setSql('''
            update agent_groups set
                name = ${arg(entity.name)},
                group_type = ${arg(entity.groupType)},
                leader_id = ${arg(entity.leaderId)},
                member_ids = ${arg(entity.memberIds)},
                config = ${arg(entity.config)},
                status = ${arg(entity.status)},
                max_round = ${arg(entity.maxRound)},
                description = ${arg(entity.description)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除agent_groups
     * @param id agent_groupsID
     * @return 影响行数
     */
    func softDeleteAgentGroupsById(id: String): Int64 {
        executor.setSql('''
            update agent_groups set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的agent_groups
     * @param id agent_groupsID
     * @return 影响行数
     */
    func restoreAgentGroupsById(id: String): Int64 {
        executor.setSql('''
            update agent_groups set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除agent_groups
     * @param id agent_groupsID
     * @return 影响行数
     */
    func deleteAgentGroupsById(id: String): Int64 {
        executor.setSql('''
            delete from agent_groups where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有agent_groups
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAgentGroupsPage(page: Int64, size: Int64): Pagination<AgentGroupsPO> {
        executor.page<AgentGroupsPO>('''
            select id, name, group_type, leader_id, member_ids, config, status, max_round, description, creator, created_at, updated_at, deleted_at from agent_groups order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询agent_groups列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentGroupsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AgentGroupsPO> {
        executor.page<AgentGroupsPO>('''
            select id, name, group_type, leader_id, member_ids, config, status, max_round, description, creator, created_at, updated_at, deleted_at from agent_groups where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有agent_groups（不分页）
     * @return agent_groups列表
     */
    func listAllAgentGroups(): ArrayList<AgentGroupsPO> {
        executor.setSql('''
            select id, name, group_type, leader_id, member_ids, config, status, max_round, description, creator, created_at, updated_at, deleted_at from agent_groups order by created_at desc
        ''').list<AgentGroupsPO>()
    }

    /**
     * 批量查询agent_groups
     * @param ids ID列表
     * @return agent_groups列表
     */
    func findAgentGroupsByIds(ids: ArrayList<String>): ArrayList<AgentGroupsPO> {
        if (ids.isEmpty()) {
            return ArrayList<AgentGroupsPO>()
        }
        executor.setSql('''
            select id, name, group_type, leader_id, member_ids, config, status, max_round, description, creator, created_at, updated_at, deleted_at from agent_groups where id ${IN(ids)}
        ''').list<AgentGroupsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的agent_groups数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAgentGroupsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from agent_groups where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有agent_groups数量
     * @return 数量
     */
    func countAllAgentGroups(): Int64 {
        executor.setSql('''
            select count(*) from agent_groups
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询agent_groups列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentGroupsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AgentGroupsPO> {
        let sql = StringBuilder()
        sql.append("select id, name, group_type, leader_id, member_ids, config, status, max_round, description, creator, created_at, updated_at, deleted_at from agent_groups where 1=1")

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

        executor.page<AgentGroupsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除agent_groups
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAgentGroups(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update agent_groups set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除agent_groups
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAgentGroups(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from agent_groups where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询agent_groups（支持完整查询操作符）
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
    func findAgentGroupsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentGroupsPO> {
        let sql = StringBuilder()
        sql.append("select id, name, group_type, leader_id, member_ids, config, status, max_round, description, creator, created_at, updated_at, deleted_at from agent_groups")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AgentGroupsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询agent_groups
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentGroupsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentGroupsPO> {
        let fromClause = executor.FROM<AgentGroupsPO>()

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
        fromClause.page<AgentGroupsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_groups）
     * @return 影响行数
     */
    func emptyRecycleBinAgentGroups(): Int64 {
        executor.setSql('''
            delete from agent_groups where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
