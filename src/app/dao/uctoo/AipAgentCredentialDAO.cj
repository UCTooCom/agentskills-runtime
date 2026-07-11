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
import magic.app.models.uctoo.AipAgentCredentialPO
import magic.log.LogUtils

/**
 * AipAgentCredentialDAO - aip_agent_credential数据访问接口
 *
 * 提供aip_agent_credential表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AipAgentCredentialDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入aip_agent_credential（id由数据库自动生成UUID）
     * @param entity AipAgentCredentialPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAipAgentCredential(entity: AipAgentCredentialPO): String {
        executor.setSql('''
            insert into aip_agent_credential(
                agent_identity_id,
                credential_type,
                issuer,
                serial_number,
                not_before,
                not_after,
                credential_status,
                certificate_pem,
                public_key,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentIdentityId)},
                ${arg(entity.credentialType)},
                ${arg(entity.issuer)},
                ${arg(entity.serialNumber)},
                ${arg(entity.notBefore)},
                ${arg(entity.notAfter)},
                ${arg(entity.credentialStatus)},
                ${arg(entity.certificatePem)},
                ${arg(entity.publicKey)},
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
     * 根据ID查询aip_agent_credential
     * @param id aip_agent_credentialID
     * @return aip_agent_credential对象（Option类型）
     */
    func findAipAgentCredentialById(id: String): Option<AipAgentCredentialPO> {
        executor.setSql('''
            select id, agent_identity_id, credential_type, issuer, serial_number, not_before, not_after, credential_status, certificate_pem, public_key, creator, created_at, updated_at, deleted_at from aip_agent_credential where id = ${arg(id)}
        ''').first<AipAgentCredentialPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新aip_agent_credential
     * @param entity aip_agent_credential对象
     * @return 影响行数
     */
    func updateAipAgentCredential(entity: AipAgentCredentialPO): Int64 {
        executor.setSql('''
            update aip_agent_credential set
                agent_identity_id = ${arg(entity.agentIdentityId)},
                credential_type = ${arg(entity.credentialType)},
                issuer = ${arg(entity.issuer)},
                serial_number = ${arg(entity.serialNumber)},
                not_before = ${arg(entity.notBefore)},
                not_after = ${arg(entity.notAfter)},
                credential_status = ${arg(entity.credentialStatus)},
                certificate_pem = ${arg(entity.certificatePem)},
                public_key = ${arg(entity.publicKey)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除aip_agent_credential
     * @param id aip_agent_credentialID
     * @return 影响行数
     */
    func softDeleteAipAgentCredentialById(id: String): Int64 {
        executor.setSql('''
            update aip_agent_credential set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的aip_agent_credential
     * @param id aip_agent_credentialID
     * @return 影响行数
     */
    func restoreAipAgentCredentialById(id: String): Int64 {
        executor.setSql('''
            update aip_agent_credential set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除aip_agent_credential
     * @param id aip_agent_credentialID
     * @return 影响行数
     */
    func deleteAipAgentCredentialById(id: String): Int64 {
        executor.setSql('''
            delete from aip_agent_credential where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有aip_agent_credential
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAipAgentCredentialPage(page: Int64, size: Int64): Pagination<AipAgentCredentialPO> {
        executor.page<AipAgentCredentialPO>('''
            select id, agent_identity_id, credential_type, issuer, serial_number, not_before, not_after, credential_status, certificate_pem, public_key, creator, created_at, updated_at, deleted_at from aip_agent_credential order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询aip_agent_credential列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipAgentCredentialByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AipAgentCredentialPO> {
        executor.page<AipAgentCredentialPO>('''
            select id, agent_identity_id, credential_type, issuer, serial_number, not_before, not_after, credential_status, certificate_pem, public_key, creator, created_at, updated_at, deleted_at from aip_agent_credential where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有aip_agent_credential（不分页）
     * @return aip_agent_credential列表
     */
    func listAllAipAgentCredential(): ArrayList<AipAgentCredentialPO> {
        executor.setSql('''
            select id, agent_identity_id, credential_type, issuer, serial_number, not_before, not_after, credential_status, certificate_pem, public_key, creator, created_at, updated_at, deleted_at from aip_agent_credential order by created_at desc
        ''').list<AipAgentCredentialPO>()
    }

    /**
     * 批量查询aip_agent_credential
     * @param ids ID列表
     * @return aip_agent_credential列表
     */
    func findAipAgentCredentialByIds(ids: ArrayList<String>): ArrayList<AipAgentCredentialPO> {
        if (ids.isEmpty()) {
            return ArrayList<AipAgentCredentialPO>()
        }
        executor.setSql('''
            select id, agent_identity_id, credential_type, issuer, serial_number, not_before, not_after, credential_status, certificate_pem, public_key, creator, created_at, updated_at, deleted_at from aip_agent_credential where id ${IN(ids)}
        ''').list<AipAgentCredentialPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的aip_agent_credential数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAipAgentCredentialByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from aip_agent_credential where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有aip_agent_credential数量
     * @return 数量
     */
    func countAllAipAgentCredential(): Int64 {
        executor.setSql('''
            select count(*) from aip_agent_credential
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询aip_agent_credential列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipAgentCredentialByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AipAgentCredentialPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_identity_id, credential_type, issuer, serial_number, not_before, not_after, credential_status, certificate_pem, public_key, creator, created_at, updated_at, deleted_at from aip_agent_credential where 1=1")

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

        executor.page<AipAgentCredentialPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除aip_agent_credential
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAipAgentCredential(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update aip_agent_credential set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除aip_agent_credential
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAipAgentCredential(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from aip_agent_credential where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询aip_agent_credential（支持完整查询操作符）
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
    func findAipAgentCredentialByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipAgentCredentialPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_identity_id, credential_type, issuer, serial_number, not_before, not_after, credential_status, certificate_pem, public_key, creator, created_at, updated_at, deleted_at from aip_agent_credential")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AipAgentCredentialPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询aip_agent_credential
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipAgentCredentialByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipAgentCredentialPO> {
        let fromClause = executor.FROM<AipAgentCredentialPO>()

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
        fromClause.page<AipAgentCredentialPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的aip_agent_credential）
     * @return 影响行数
     */
    func emptyRecycleBinAipAgentCredential(): Int64 {
        executor.setSql('''
            delete from aip_agent_credential where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
