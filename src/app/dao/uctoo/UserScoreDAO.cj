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
import magic.app.models.uctoo.UserScorePO
import magic.log.LogUtils

/**
 * UserScoreDAO - user_score数据访问接口
 *
 * 提供user_score表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserScoreDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入user_score（id由数据库自动生成UUID）
     * @param entity UserScorePO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserScore(entity: UserScorePO): String {
        executor.setSql('''
            insert into user_score(
                user_id,
                appid,
                from_umodel,
                total_score,
                team_score,
                volunteer_score,
                event_score,
                ext_score,
                medals,
                total_times,
                total_medals,
                annual_times,
                annual_medals,
                monthly_times,
                monthly_medals,
                ext_info,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.userId)},
                ${arg(entity.appid)},
                ${arg(entity.fromUmodel)},
                ${arg(entity.totalScore)},
                ${arg(entity.teamScore)},
                ${arg(entity.volunteerScore)},
                ${arg(entity.eventScore)},
                ${arg(entity.extScore)},
                ${arg(entity.medals)},
                ${arg(entity.totalTimes)},
                ${arg(entity.totalMedals)},
                ${arg(entity.annualTimes)},
                ${arg(entity.annualMedals)},
                ${arg(entity.monthlyTimes)},
                ${arg(entity.monthlyMedals)},
                ${arg(entity.extInfo)},
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
     * 根据ID查询user_score
     * @param id user_scoreID
     * @return user_score对象（Option类型）
     */
    func findUserScoreById(id: String): Option<UserScorePO> {
        executor.setSql('''
            select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score where id = ${arg(id)}
        ''').first<UserScorePO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新user_score
     * @param entity user_score对象
     * @return 影响行数
     */
    func updateUserScore(entity: UserScorePO): Int64 {
        executor.setSql('''
            update user_score set
                user_id = ${arg(entity.userId)},
                appid = ${arg(entity.appid)},
                from_umodel = ${arg(entity.fromUmodel)},
                total_score = ${arg(entity.totalScore)},
                team_score = ${arg(entity.teamScore)},
                volunteer_score = ${arg(entity.volunteerScore)},
                event_score = ${arg(entity.eventScore)},
                ext_score = ${arg(entity.extScore)},
                medals = ${arg(entity.medals)},
                total_times = ${arg(entity.totalTimes)},
                total_medals = ${arg(entity.totalMedals)},
                annual_times = ${arg(entity.annualTimes)},
                annual_medals = ${arg(entity.annualMedals)},
                monthly_times = ${arg(entity.monthlyTimes)},
                monthly_medals = ${arg(entity.monthlyMedals)},
                ext_info = ${arg(entity.extInfo)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除user_score
     * @param id user_scoreID
     * @return 影响行数
     */
    func softDeleteUserScoreById(id: String): Int64 {
        executor.setSql('''
            update user_score set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的user_score
     * @param id user_scoreID
     * @return 影响行数
     */
    func restoreUserScoreById(id: String): Int64 {
        executor.setSql('''
            update user_score set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除user_score
     * @param id user_scoreID
     * @return 影响行数
     */
    func deleteUserScoreById(id: String): Int64 {
        executor.setSql('''
            delete from user_score where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有user_score
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserScorePage(page: Int64, size: Int64): Pagination<UserScorePO> {
        executor.page<UserScorePO>('''
            select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询user_score列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserScoreByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserScorePO> {
        executor.page<UserScorePO>('''
            select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有user_score（不分页）
     * @return user_score列表
     */
    func listAllUserScore(): ArrayList<UserScorePO> {
        executor.setSql('''
            select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score order by created_at desc
        ''').list<UserScorePO>()
    }

    /**
     * 批量查询user_score
     * @param ids ID列表
     * @return user_score列表
     */
    func findUserScoreByIds(ids: ArrayList<String>): ArrayList<UserScorePO> {
        if (ids.isEmpty()) {
            return ArrayList<UserScorePO>()
        }
        executor.setSql('''
            select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score where id ${IN(ids)}
        ''').list<UserScorePO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的user_score数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserScoreByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_score where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有user_score数量
     * @return 数量
     */
    func countAllUserScore(): Int64 {
        executor.setSql('''
            select count(*) from user_score
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询user_score列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserScoreByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UserScorePO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score where 1=1")

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

        executor.page<UserScorePO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除user_score
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUserScore(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update user_score set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除user_score
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUserScore(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from user_score where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询user_score（支持完整查询操作符）
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
    func findUserScoreByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserScorePO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UserScorePO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询user_score
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserScoreByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserScorePO> {
        let fromClause = executor.FROM<UserScorePO>()

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
        fromClause.page<UserScorePO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_score）
     * @return 影响行数
     */
    func emptyRecycleBinUserScore(): Int64 {
        executor.setSql('''
            delete from user_score where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    // ==================== 积分系统定制查询方法 ====================

    /**
     * 按 userId + from_umodel 查询用户积分记录（核心方法）
     * 用于积分系统查找用户积分余额记录
     * @param userId 用户ID
     * @param fromUmodel 来源模型（固定为 uctoo_user）
     * @return 用户积分记录（Option类型）
     */
    func findByUserIdAndFromUmodel(userId: String, fromUmodel: String): Option<UserScorePO> {
        executor.setSql('''
            select id, user_id, appid, from_umodel, total_score, team_score, volunteer_score, event_score, ext_score, medals, total_times, total_medals, annual_times, annual_medals, monthly_times, monthly_medals, ext_info, creator, created_at, updated_at, deleted_at from user_score where user_id = ${arg(userId)} and from_umodel = ${arg(fromUmodel)} and deleted_at is null limit 1
        ''').first<UserScorePO>()
    }

    /**
     * 查询用户积分余额（total_score）
     * @param userId 用户ID
     * @param fromUmodel 来源模型（固定为 uctoo_user）
     * @return 积分余额，无记录返回0
     */
    func findTotalScoreByUserId(userId: String, fromUmodel: String): Int32 {
        executor.setSql('''
            select coalesce(total_score, 0) from user_score where user_id = ${arg(userId)} and from_umodel = ${arg(fromUmodel)} and deleted_at is null limit 1
        ''').first<Int32>() ?? 0
    }

    /**
     * 增加用户积分（原子操作）
     * @param userId 用户ID
     * @param fromUmodel 来源模型
     * @param points 增加的积分（必须>0）
     * @return 影响行数
     */
    func addTotalScore(userId: String, fromUmodel: String, points: Int32): Int64 {
        executor.setSql('''
            update user_score set total_score = coalesce(total_score, 0) + ${arg(points)}, updated_at = ${arg(DateTime.now())} where user_id = ${arg(userId)} and from_umodel = ${arg(fromUmodel)} and deleted_at is null
        ''').update
    }

    /**
     * 扣减用户积分（不低于0）
     * @param userId 用户ID
     * @param fromUmodel 来源模型
     * @param points 扣减的积分（必须>0）
     * @return 影响行数
     */
    func deductTotalScore(userId: String, fromUmodel: String, points: Int32): Int64 {
        executor.setSql('''
            update user_score set total_score = greatest(coalesce(total_score, 0) - ${arg(points)}, 0), updated_at = ${arg(DateTime.now())} where user_id = ${arg(userId)} and from_umodel = ${arg(fromUmodel)} and deleted_at is null
        ''').update
    }

    /**
     * 检查用户积分记录是否存在
     * @param userId 用户ID
     * @param fromUmodel 来源模型
     * @return 是否存在
     */
    func existsByUserIdAndFromUmodel(userId: String, fromUmodel: String): Bool {
        let count = executor.setSql('''
            select count(*) from user_score where user_id = ${arg(userId)} and from_umodel = ${arg(fromUmodel)} and deleted_at is null
        ''').first<Int64>() ?? 0
        return count > 0
    }
}
