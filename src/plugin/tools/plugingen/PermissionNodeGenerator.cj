/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import std.time.DateTime
import f_orm.{ORM, SqlExecutor}
import magic.app.models.uctoo.PermissionsPO
import magic.app.models.uctoo.I18PO

/**
 * PermissionNodeGenerator - 权限菜单节点生成器（sync 轨与 process 轨共用）
 *
 * 向 permissions 表写入三级菜单结构：
 *   database -> database.{dbName} -> database.{dbName}.{tableName}
 * 并向 i18 表插入多语言 title。
 *
 * 为什么必须建节点：前端侧边栏菜单树来自 `PermissionsService.getUserMenuTree`
 * （持有通配符的角色走 `findAllMenuPermissions()`，即 `permissions WHERE type=1
 * AND menu_type IS NOT NULL AND deleted_at IS NULL`）。**没有节点 = 页面上不了菜单**，
 * 缺一环就让 crudweb 生成的页面「存在但点不到」。
 * 后端 API 层反而不受影响 —— 超级管理员角色在 role_has_permission 里持有 '*'，
 * RequirePermissionMiddleware 的 hasWildcardPermission 会直接放行。
 *
 * 幂等语义：节点已存在则跳过；被软删除则恢复；不存在才创建。
 * 与 crudgen 的 CrudGenerator.generatePermissionNodes 同口径（含 creator 默认值）。
 *
 * ⚠️ component 必须写成 `database/{dbName}/{tableName}/index`，才能对上 crudweb
 * 的产物路径 `web/src/views/database/{dbName}/{tableName}/index.vue`。
 */
public class PermissionNodeGenerator {

    /// 默认 creator（与 crudgen 一致，根管理员 UUID）
    private static let DEFAULT_CREATOR = "505cf909-5e0e-4dde-b215-74274d2cc548"

    /**
     * 生成一张表的权限菜单节点（幂等，不更新已存在节点）
     *
     * @param dbName 数据库名
     * @param tableName 表名
     * @return 成功与否
     */
    public func generatePermissionNodes(dbName: String, tableName: String): Bool {
        try {
            let executor = ORM.executor()
            let tablePermissionName = "database.${dbName}.${tableName}"

            // 1. 获取或创建 database 父节点（处理软删除）
            let (databaseParentId, parentCreator) = this.ensureDatabaseParentNode(executor)

            // 2. 获取或创建 database.{dbName} 节点（处理软删除）
            let dbNodeId = this.ensureDatabaseNode(executor, dbName, databaseParentId, parentCreator)

            // 3. 检查表权限节点是否存在（包括软删除的）
            let existingTable = executor.setSql('''
                SELECT * FROM permissions
                WHERE permission_name = ${arg(tablePermissionName)}
            ''').first<PermissionsPO>()

            match (existingTable) {
                case Some(table) =>
                    if (table.deletedAt.isNone()) {
                        println("表权限节点已存在: ${tablePermissionName}")
                    } else {
                        executor.setSql('''
                            UPDATE permissions
                            SET deleted_at = NULL,
                                updated_at = NOW(),
                                title = ${arg("menu.${tablePermissionName}")},
                                path = ${arg(tableName)},
                                parent_id = ${arg(dbNodeId)}
                            WHERE id = ${arg(table.id)}
                        ''').update
                        println("已恢复软删除的表权限节点: ${tablePermissionName}")
                    }
                case None =>
                    let now = DateTime.now()
                    let tablePermission = PermissionsPO()
                    tablePermission.permissionName = tablePermissionName
                    tablePermission.typeVal = 1
                    tablePermission.hidden = 1
                    tablePermission.weight = 1
                    tablePermission.creator = Some(parentCreator)
                    tablePermission.createdAt = now
                    tablePermission.updatedAt = now
                    tablePermission.path = Some(tableName)
                    tablePermission.title = Some(tableName)
                    tablePermission.parentId = Some(dbNodeId)
                    tablePermission.menuType = Some("normal")
                    tablePermission.locale = Some("menu.database.${dbName}.${tableName}")
                    tablePermission.component = Some("database/${dbName}/${tableName}/index")

                    executor.setSql('''
                        INSERT INTO permissions(
                            id, permission_name, level, icon, module, component, redirect,
                            type, hidden, weight, creator, created_at, updated_at,
                            deleted_at, keepalive, path, title, parent_id, meta,
                            method, menu_type, locale
                        ) VALUES (
                            gen_random_uuid(),
                            ${arg(tablePermission.permissionName)},
                            ${optArg(tablePermission.level)},
                            ${optArg(tablePermission.icon)},
                            ${optArg(tablePermission.module)},
                            ${optArg(tablePermission.component)},
                            ${optArg(tablePermission.redirect)},
                            ${optArg(tablePermission.typeVal)},
                            ${optArg(tablePermission.hidden)},
                            ${optArg(tablePermission.weight)},
                            ${arg(parentCreator)},
                            NOW(),
                            NOW(),
                            null,
                            1,
                            ${arg(tablePermission.path.getOrThrow())},
                            ${arg(tablePermission.title.getOrThrow())},
                            ${arg(dbNodeId)},
                            ${optArg(tablePermission.meta)},
                            ${optArg(tablePermission.method)},
                            ${arg(tablePermission.menuType.getOrThrow())},
                            ${arg(tablePermission.locale.getOrThrow())}
                        )
                    ''').update

                    println("已生成表权限节点: ${tablePermissionName}")

                    // 插入 i18 多语言数据
                    match (tablePermission.locale) {
                        case Some(localeKey) => this.insertI18Data(executor, localeKey, tableName)
                        case None => println("locale 为空，跳过 i18 数据插入")
                    }
            }

            return true
        } catch (e: Exception) {
            println("生成权限节点失败: ${e.message}")
            return false
        }
    }

    /// 确保 database 父节点存在（幂等，处理软删除）
    /// @return (parentId, creator)
    private func ensureDatabaseParentNode(executor: SqlExecutor): (String, String) {
        let databasePermissionName = "database"

        let existing = executor.setSql('''
            SELECT * FROM permissions
            WHERE permission_name = ${arg(databasePermissionName)} AND deleted_at IS NULL
        ''').first<PermissionsPO>()

        match (existing) {
            case Some(node) =>
                let creator = match (node.creator) {
                    case Some(c) => c
                    case None => DEFAULT_CREATOR
                }
                return (node.id, creator)
            case None =>
                let softDeleted = executor.setSql('''
                    SELECT * FROM permissions
                    WHERE permission_name = ${arg(databasePermissionName)} AND deleted_at IS NOT NULL
                    ORDER BY updated_at DESC
                    LIMIT 1
                ''').first<PermissionsPO>()

                match (softDeleted) {
                    case Some(deletedNode) =>
                        executor.setSql('''
                            UPDATE permissions
                            SET deleted_at = NULL, updated_at = NOW()
                            WHERE id = ${arg(deletedNode.id)}
                        ''').update
                        println("已恢复软删除的权限节点: ${databasePermissionName}")
                        let creator = match (deletedNode.creator) {
                            case Some(c) => c
                            case None => DEFAULT_CREATOR
                        }
                        return (deletedNode.id, creator)
                    case None =>
                        let creator = DEFAULT_CREATOR

                        executor.setSql('''
                            INSERT INTO permissions(
                                id, permission_name, level, icon, module, component, redirect,
                                type, hidden, weight, creator, created_at, updated_at,
                                deleted_at, keepalive, path, title, parent_id, meta,
                                method, menu_type, locale
                            ) VALUES (
                                gen_random_uuid(),
                                ${arg(databasePermissionName)},
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                1,
                                1,
                                1,
                                ${arg(creator)},
                                NOW(),
                                NOW(),
                                null,
                                1,
                                ${arg(databasePermissionName)},
                                ${arg(databasePermissionName)},
                                NULL,
                                NULL,
                                NULL,
                                'normal',
                                ${arg("menu.${databasePermissionName}")}
                            )
                        ''').update

                        println("已生成权限节点: ${databasePermissionName}")

                        let newNode = executor.setSql('''
                            SELECT * FROM permissions
                            WHERE permission_name = ${arg(databasePermissionName)} AND deleted_at IS NULL
                        ''').first<PermissionsPO>()

                        match (newNode) {
                            case Some(n) => return (n.id, creator)
                            case None => return (DEFAULT_CREATOR, creator)
                        }
                }
        }
    }

    /// 确保 database.{dbName} 节点存在（幂等，处理软删除）
    /// @return dbNodeId - 数据库节点ID
    private func ensureDatabaseNode(executor: SqlExecutor, dbName: String, parentId: String, creator: String): String {
        let dbPermissionName = "database.${dbName}"

        let existing = executor.setSql('''
            SELECT * FROM permissions
            WHERE permission_name = ${arg(dbPermissionName)} AND deleted_at IS NULL
        ''').first<PermissionsPO>()

        match (existing) {
            case Some(node) =>
                return node.id
            case None =>
                let softDeleted = executor.setSql('''
                    SELECT * FROM permissions
                    WHERE permission_name = ${arg(dbPermissionName)} AND deleted_at IS NOT NULL
                    ORDER BY updated_at DESC
                    LIMIT 1
                ''').first<PermissionsPO>()

                match (softDeleted) {
                    case Some(deletedNode) =>
                        executor.setSql('''
                            UPDATE permissions
                            SET deleted_at = NULL,
                                updated_at = NOW(),
                                parent_id = ${arg(parentId)}
                            WHERE id = ${arg(deletedNode.id)}
                        ''').update
                        println("已恢复软删除的数据库节点: ${dbPermissionName}")
                        return deletedNode.id
                    case None =>
                        executor.setSql('''
                            INSERT INTO permissions(
                                id, permission_name, level, icon, module, component, redirect,
                                type, hidden, weight, creator, created_at, updated_at,
                                deleted_at, keepalive, path, title, parent_id, meta,
                                method, menu_type, locale
                            ) VALUES (
                                gen_random_uuid(),
                                ${arg(dbPermissionName)},
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                NULL,
                                1,
                                1,
                                1,
                                ${arg(creator)},
                                NOW(),
                                NOW(),
                                null,
                                1,
                                ${arg(dbName)},
                                ${arg(dbName)},
                                ${arg(parentId)},
                                NULL,
                                NULL,
                                'normal',
                                ${arg("menu.${dbPermissionName}")}
                            )
                        ''').update

                        println("已生成数据库节点: ${dbPermissionName}")

                        let newNode = executor.setSql('''
                            SELECT * FROM permissions
                            WHERE permission_name = ${arg(dbPermissionName)} AND deleted_at IS NULL
                        ''').first<PermissionsPO>()

                        match (newNode) {
                            case Some(n) => return n.id
                            case None => return DEFAULT_CREATOR
                        }
                }
        }
    }

    /// 插入 i18 多语言数据（幂等，处理软删除）
    private func insertI18Data(executor: SqlExecutor, key: String, content: String): Unit {
        try {
            let existing = executor.setSql('''
                SELECT * FROM i18
                WHERE key = ${arg(key)} AND deleted_at IS NULL
            ''').first<I18PO>()

            match (existing) {
                case Some(i18) =>
                    println("i18 数据已存在: ${key}")
                case None =>
                    let softDeleted = executor.setSql('''
                        SELECT * FROM i18
                        WHERE key = ${arg(key)} AND deleted_at IS NOT NULL
                        ORDER BY updated_at DESC
                        LIMIT 1
                    ''').first<I18PO>()

                    match (softDeleted) {
                        case Some(deletedI18) =>
                            executor.setSql('''
                                UPDATE i18
                                SET deleted_at = NULL,
                                    content = ${arg(content)},
                                    updated_at = NOW()
                                WHERE id = ${arg(deletedI18.id)}
                            ''').update
                            println("已恢复软删除的 i18 数据: ${key}")
                        case None =>
                            executor.setSql('''
                                INSERT INTO i18(
                                    id, key, content, lang_id, creator, created_at, updated_at, deleted_at
                                ) VALUES (
                                    gen_random_uuid(),
                                    ${arg(key)},
                                    ${arg(content)},
                                    '00000000-0000-0000-0000-000000000002',
                                    NULL,
                                    NOW(),
                                    NOW(),
                                    NULL
                                )
                            ''').update
                            println("已生成 i18 数据: ${key}")
                    }
            }
        } catch (e: Exception) {
            println("插入 i18 数据失败: ${e.message}")
        }
    }
}
