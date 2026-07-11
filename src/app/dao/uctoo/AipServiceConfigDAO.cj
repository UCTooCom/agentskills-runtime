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
import magic.app.models.uctoo.AipServiceConfigPO
import magic.log.LogUtils

/**
 * AipServiceConfigDAO - aip_service_config数据访问接口
 *
 * 提供aip_service_config表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AipServiceConfigDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入aip_service_config（id由数据库自动生成UUID）
     * @param entity AipServiceConfigPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAipServiceConfig(entity: AipServiceConfigPO): String {
        executor.setSql('''
            insert into aip_service_config(
                service_type,
                service_name,
                service_endpoint,
                protocol_version,
                config,
                enabled,
                health_status,
                last_health_check_at,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.serviceType)},
                ${arg(entity.serviceName)},
                ${arg(entity.serviceEndpoint)},
                ${arg(entity.protocolVersion)},
                ${arg(entity.config)},
                ${arg(entity.enabled)},
                ${arg(entity.healthStatus)},
                ${arg(entity.lastHealthCheckAt)},
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
     * 根据ID查询aip_service_config
     * @param id aip_service_configID
     * @return aip_service_config对象（Option类型）
     */
    func findAipServiceConfigById(id: String): Option<AipServiceConfigPO> {
        executor.setSql('''
            select id, service_type, service_name, service_endpoint, protocol_version, config, enabled, health_status, last_health_check_at, creator, created_at, updated_at, deleted_at from aip_service_config where id = ${arg(id)}
        ''').first<AipServiceConfigPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新aip_service_config
     * @param entity aip_service_config对象
     * @return 影响行数
     */
    func updateAipServiceConfig(entity: AipServiceConfigPO): Int64 {
        executor.setSql('''
            update aip_service_config set
                service_type = ${arg(entity.serviceType)},
                service_name = ${arg(entity.serviceName)},
                service_endpoint = ${arg(entity.serviceEndpoint)},
                protocol_version = ${arg(entity.protocolVersion)},
                config = ${arg(entity.config)},
                enabled = ${arg(entity.enabled)},
                health_status = ${arg(entity.healthStatus)},
                last_health_check_at = ${arg(entity.lastHealthCheckAt)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除aip_service_config
     * @param id aip_service_configID
     * @return 影响行数
     */
    func softDeleteAipServiceConfigById(id: String): Int64 {
        executor.setSql('''
            update aip_service_config set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的aip_service_config
     * @param id aip_service_configID
     * @return 影响行数
     */
    func restoreAipServiceConfigById(id: String): Int64 {
        executor.setSql('''
            update aip_service_config set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除aip_service_config
     * @param id aip_service_configID
     * @return 影响行数
     */
    func deleteAipServiceConfigById(id: String): Int64 {
        executor.setSql('''
            delete from aip_service_config where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有aip_service_config
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAipServiceConfigPage(page: Int64, size: Int64): Pagination<AipServiceConfigPO> {
        executor.page<AipServiceConfigPO>('''
            select id, service_type, service_name, service_endpoint, protocol_version, config, enabled, health_status, last_health_check_at, creator, created_at, updated_at, deleted_at from aip_service_config order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询aip_service_config列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipServiceConfigByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AipServiceConfigPO> {
        executor.page<AipServiceConfigPO>('''
            select id, service_type, service_name, service_endpoint, protocol_version, config, enabled, health_status, last_health_check_at, creator, created_at, updated_at, deleted_at from aip_service_config where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有aip_service_config（不分页）
     * @return aip_service_config列表
     */
    func listAllAipServiceConfig(): ArrayList<AipServiceConfigPO> {
        executor.setSql('''
            select id, service_type, service_name, service_endpoint, protocol_version, config, enabled, health_status, last_health_check_at, creator, created_at, updated_at, deleted_at from aip_service_config order by created_at desc
        ''').list<AipServiceConfigPO>()
    }

    /**
     * 批量查询aip_service_config
     * @param ids ID列表
     * @return aip_service_config列表
     */
    func findAipServiceConfigByIds(ids: ArrayList<String>): ArrayList<AipServiceConfigPO> {
        if (ids.isEmpty()) {
            return ArrayList<AipServiceConfigPO>()
        }
        executor.setSql('''
            select id, service_type, service_name, service_endpoint, protocol_version, config, enabled, health_status, last_health_check_at, creator, created_at, updated_at, deleted_at from aip_service_config where id ${IN(ids)}
        ''').list<AipServiceConfigPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的aip_service_config数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAipServiceConfigByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from aip_service_config where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有aip_service_config数量
     * @return 数量
     */
    func countAllAipServiceConfig(): Int64 {
        executor.setSql('''
            select count(*) from aip_service_config
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询aip_service_config列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipServiceConfigByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AipServiceConfigPO> {
        let sql = StringBuilder()
        sql.append("select id, service_type, service_name, service_endpoint, protocol_version, config, enabled, health_status, last_health_check_at, creator, created_at, updated_at, deleted_at from aip_service_config where 1=1")

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

        executor.page<AipServiceConfigPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除aip_service_config
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAipServiceConfig(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update aip_service_config set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除aip_service_config
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAipServiceConfig(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from aip_service_config where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询aip_service_config（支持完整查询操作符）
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
    func findAipServiceConfigByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipServiceConfigPO> {
        let sql = StringBuilder()
        sql.append("select id, service_type, service_name, service_endpoint, protocol_version, config, enabled, health_status, last_health_check_at, creator, created_at, updated_at, deleted_at from aip_service_config")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AipServiceConfigPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询aip_service_config
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipServiceConfigByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipServiceConfigPO> {
        let fromClause = executor.FROM<AipServiceConfigPO>()

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
        fromClause.page<AipServiceConfigPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的aip_service_config）
     * @return 影响行数
     */
    func emptyRecycleBinAipServiceConfig(): Int64 {
        executor.setSql('''
            delete from aip_service_config where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
