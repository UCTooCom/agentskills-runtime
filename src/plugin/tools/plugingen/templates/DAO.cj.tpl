/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package skill_{{name}}

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.{ArrayList}
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}

/**
 * {{className}}DAO - {{tableName}}数据访问接口
 *
 * 提供{{tableName}}表的标准CRUD操作，遵循UCTOO V4 ORM规范。
 * 插件轨实现（plugingen 生成）：与 PO 同包，无跨包 import。
 */
@DAO
public interface {{className}}DAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入{{tableName}}（id由数据库自动生成UUID）
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insert{{className}}(entity: {{className}}PO): String {
        executor.setSql('''
            insert into {{tableName}}(
{{insertColumns}}
            ) values(
{{insertValues}}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询{{tableName}}
     */
    func find{{className}}ById(id: String): Option<{{className}}PO> {
        executor.setSql('''
            select {{selectColumns}} from {{tableName}} where id = ${arg(id)}
        ''').first<{{className}}PO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新{{tableName}}
     * @return 影响行数
     */
    func update{{className}}(entity: {{className}}PO): Int64 {
        executor.setSql('''
            update {{tableName}} set
{{updateSets}}
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除{{tableName}}
     */
    func softDelete{{className}}ById(id: String): Int64 {
        executor.setSql('''
            update {{tableName}} set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的{{tableName}}
     */
    func restore{{className}}ById(id: String): Int64 {
        executor.setSql('''
            update {{tableName}} set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除{{tableName}}
     */
    func delete{{className}}ById(id: String): Int64 {
        executor.setSql('''
            delete from {{tableName}} where id = ${arg(id)}
        ''').delete
    }

    /**
     * 批量软删除{{tableName}}
     */
    func batchSoftDelete{{className}}(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update {{tableName}} set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除{{tableName}}
     */
    func batchDelete{{className}}(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from {{tableName}} where id ${IN(ids)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有{{tableName}}
     */
    func findAll{{className}}Page(page: Int64, size: Int64): Pagination<{{className}}PO> {
        executor.page<{{className}}PO>('''
            select {{selectColumns}} from {{tableName}} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 批量查询{{tableName}}
     */
    func find{{className}}ByIds(ids: ArrayList<String>): ArrayList<{{className}}PO> {
        if (ids.isEmpty()) {
            return ArrayList<{{className}}PO>()
        }
        executor.setSql('''
            select {{selectColumns}} from {{tableName}} where id ${IN(ids)}
        ''').list<{{className}}PO>()
    }

    /**
     * 动态条件分页查询{{tableName}}（Prisma 风格 filter/sort 构建轨）
     */
    func find{{className}}ByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<{{className}}PO> {
        let fromClause = executor.FROM<{{className}}PO>()

        if (!whereClause.isEmpty()) {
            fromClause.WHERE(whereClause)
        }

        if (!orderByClause.isEmpty()) {
            fromClause.ORDER_BY { => orderByClause }
        } else {
            fromClause.ORDER_BY { => "created_at DESC" }
        }

        fromClause.page<{{className}}PO>(size, page: page)
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的{{tableName}}数量
     */
    func count{{className}}ByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from {{tableName}} where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有{{tableName}}数量
     */
    func countAll{{className}}(): Int64 {
        executor.setSql('''
            select count(*) from {{tableName}}
        ''').first<Int64>() ?? 0
    }

    /**
     * 清空回收站（硬删除所有已软删除的{{tableName}}）
     * @return 影响行数
     */
    func emptyRecycleBin{{className}}(): Int64 {
        executor.setSql('''
            delete from {{tableName}} where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
