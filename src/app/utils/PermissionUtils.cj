/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.utils

import magic.app.models.uctoo.DataAccessAuthorizationPO
import magic.app.core.{PermissionLevel, PermissionConfig, PermissionCache, hasPermission}
import magic.app.dao.uctoo.DataAccessAuthorizationDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils
import f_orm.*
import std.collection.{ArrayList, HashMap, HashSet}
import std.time.DateTime

public class PermissionUtils {
    private static let logger = "PermissionUtils"

    public static func hasWildcardPermission(userId: String): Bool {
        if (userId.isEmpty()) {
            return false
        }
        try {
            let executor = ORM.executor()
            let count = executor.setSql('''
                SELECT COUNT(*) FROM role_has_permission rhp
                INNER JOIN user_has_roles uhr ON rhp.role_id = uhr.role_id
                WHERE uhr.user_id = '${userId}' AND rhp.permission_name = '*'
                AND rhp.status = 1 AND uhr.status = 1
                AND rhp.deleted_at IS NULL AND uhr.deleted_at IS NULL
            ''').first<Int64>() ?? 0
            return count > 0
        } catch (e: Exception) {
            LogUtils.error(logger, "hasWildcardPermission error: ${e.message}")
            return false
        }
    }

    public static func checkReadPermission(userId: String, entityId: String, entityType: String): (Bool, String) {
        return checkUserHasPermission(userId, entityType, entityId, PermissionLevel.READ)
    }

    public static func checkWritePermission(userId: String, entityId: String, entityType: String): (Bool, String) {
        return checkUserHasPermission(userId, entityType, entityId, PermissionLevel.WRITE)
    }

    public static func checkAuthorizePermission(userId: String, entityId: String, entityType: String): (Bool, String) {
        return checkUserHasPermission(userId, entityType, entityId, PermissionLevel.AUTHORIZE)
    }

    public static func checkUserHasPermission(
        userId: String,
        entityType: String,
        entityId: String,
        requiredPermission: PermissionLevel
    ): (Bool, String) {
        if (userId.isEmpty() || entityId.isEmpty() || entityType.isEmpty()) {
            LogUtils.error(logger, "checkUserHasPermission rejected: invalid params userId=${userId}, entityId=${entityId}, entityType=${entityType}")
            return (false, "参数无效")
        }

        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(entityType)) {
            LogUtils.info(logger, "checkUserHasPermission: table=${entityType} RLP disabled, allow")
            return (true, "")
        }

        if (hasWildcardPermission(userId)) {
            LogUtils.info(logger, "checkUserHasPermission: userId=${userId} has wildcard, allow")
            return (true, "")
        }

        let cachedPermission = PermissionCache.get(userId, entityType, entityId)
        if (let Some(perm) <- cachedPermission) {
            let userLevel = PermissionLevel.fromInt32OrDefault(perm)
            if (hasPermission(userLevel, requiredPermission)) {
                return (true, "")
            }
            if (perm == Int32(0)) {
                return (false, "您没有访问此数据的权限")
            }
        }

        try {
            let executor = ORM.executor()

            let creatorCheck = executor.setSql('''
                SELECT COUNT(*) FROM ${entityType} WHERE id = '${entityId}' AND creator = '${userId}' AND deleted_at IS NULL
            ''').first<Int64>() ?? 0

            if (creatorCheck > 0) {
                PermissionCache.put(userId, entityType, entityId, PermissionLevel.AUTHORIZE.value())
                return (true, "")
            }

            let dao = (executor as DataAccessAuthorizationDAO).getOrThrow()
            let authorizations = dao.findAuthByUserIdAndEntityTypeAndEntityId(userId, entityType, entityId)

            if (authorizations.isEmpty()) {
                PermissionCache.put(userId, entityType, entityId, Int32(0))
                return (false, "您没有访问此数据的权限")
            }

            var maxPermission = Int32(0)
            for (auth in authorizations) {
                if (auth.permission > maxPermission) {
                    maxPermission = auth.permission
                }
            }

            PermissionCache.put(userId, entityType, entityId, maxPermission)

            let userLevel = PermissionLevel.fromInt32OrDefault(maxPermission)
            if (hasPermission(userLevel, requiredPermission)) {
                return (true, "")
            }

            return (false, "您没有${requiredPermission.toString()}此数据的权限")
        } catch (e: Exception) {
            LogUtils.error(logger, "Permission check failed: ${e.message}")
            return (false, "权限检查过程中发生错误")
        }
    }

    public static func appendPermissionFilter(userId: String, entityType: String): (String, ArrayList<String>) {
        if (userId.isEmpty() || entityType.isEmpty()) {
            LogUtils.error(logger, "appendPermissionFilter rejected: invalid params userId=${userId}, entityType=${entityType}")
            return ("1=1", ArrayList<String>())
        }

        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(entityType)) {
            return ("1=1", ArrayList<String>())
        }

        if (hasWildcardPermission(userId)) {
            return ("1=1", ArrayList<String>())
        }

        try {
            let cachedFilter = PermissionCache.getFilterCache(userId, entityType)
            if (let Some(rawIds) <- cachedFilter) {
                let ids = ArrayList<String>()
                for (id in rawIds) {
                    if (!id.isEmpty()) {
                        ids.add(id)
                    }
                }
                if (ids.isEmpty()) {
                    return ("creator = '${userId}'", ArrayList<String>())
                }
                return (buildFilterCondition(ids, userId), ArrayList<String>())
            }

            let executor = ORM.executor()
            let dao = (executor as DataAccessAuthorizationDAO).getOrThrow()
            let authorizations = dao.findAuthByUserIdAndEntityTypeAndPermissionGte(userId, entityType, PermissionLevel.READ.value())

            let seen = HashSet<String>()
            let authorizedIds = ArrayList<String>()
            for (auth in authorizations) {
                let eid = auth.entityId
                if (!eid.isEmpty() && !seen.contains(eid)) {
                    seen.add(eid)
                    authorizedIds.add(eid)
                }
            }

            PermissionCache.putFilterCache(userId, entityType, authorizedIds)

            if (authorizedIds.isEmpty()) {
                return ("creator = '${userId}'", ArrayList<String>())
            }

            return (buildFilterCondition(authorizedIds, userId), ArrayList<String>())
        } catch (e: Exception) {
            LogUtils.error(logger, "Failed to generate permission filter: ${e.message}")
            return ("creator = '${userId}'", ArrayList<String>())
        }
    }

    public static func getUserAuthorizedEntityIds(
        userId: String,
        entityType: String,
        requiredPermission: PermissionLevel
    ): ArrayList<String> {
        if (userId.isEmpty() || entityType.isEmpty()) {
            LogUtils.error(logger, "getUserAuthorizedEntityIds rejected: invalid params userId=${userId}, entityType=${entityType}")
            return ArrayList<String>()
        }

        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(entityType)) {
            return ArrayList<String>()
        }

        try {
            let executor = ORM.executor()
            let dao = (executor as DataAccessAuthorizationDAO).getOrThrow()
            let authorizations = dao.findAuthByUserIdAndEntityTypeAndPermissionGte(userId, entityType, requiredPermission.value())

            let seen = HashSet<String>()
            let authorizedIds = ArrayList<String>()
            for (auth in authorizations) {
                let eid = auth.entityId
                if (!eid.isEmpty() && !seen.contains(eid)) {
                    seen.add(eid)
                    authorizedIds.add(eid)
                }
            }

            return authorizedIds
        } catch (e: Exception) {
            LogUtils.error(logger, "Failed to get authorized entity IDs: ${e.message}")
            return ArrayList<String>()
        }
    }

    public static func autoGrantCreatorPermission(userId: String, entityId: String, entityType: String): Bool {
        if (userId.isEmpty() || entityId.isEmpty() || entityType.isEmpty()) {
            LogUtils.error(logger, "Auto-grant rejected: invalid params userId=${userId}, entityId=${entityId}, entityType=${entityType}")
            return false
        }
        try {
            let executor = ORM.executor()
            let dao = (executor as DataAccessAuthorizationDAO).getOrThrow()
            let auth = DataAccessAuthorizationPO()
            auth.entityId = entityId
            auth.entityType = entityType
            auth.userId = userId
            auth.permission = PermissionLevel.AUTHORIZE.value()
            auth.creator = Some(userId)
            auth.createdAt = DateTime.now()
            auth.updatedAt = DateTime.now()

            let id = dao.insertDataAccessAuthorization(auth)

            PermissionCache.invalidate(userId, entityType, entityId)

            if (id.isEmpty()) {
                LogUtils.error(logger, "Auto-grant creator permission failed for ${entityType}:${entityId}")
                return false
            }
            return true
        } catch (e: Exception) {
            LogUtils.error(logger, "Auto-grant creator permission error: ${e.message}")
            return false
        }
    }

    public static func batchCheckUserHasPermission(
        userId: String,
        entityType: String,
        entityIds: ArrayList<String>,
        requiredPermission: PermissionLevel
    ): HashMap<String, Bool> {
        let result = HashMap<String, Bool>()

        if (userId.isEmpty() || entityType.isEmpty()) {
            LogUtils.error(logger, "batchCheckUserHasPermission rejected: invalid params userId=${userId}, entityType=${entityType}")
            return result
        }

        if (entityIds.size > 100) {
            LogUtils.error(logger, "Batch check exceeded 100 limit: ${entityIds.size}")
            return result
        }

        if (!PermissionConfig.isRowLevelPermissionEnabledForTable(entityType)) {
            for (id in entityIds) {
                result[id] = true
            }
            return result
        }

        try {
            let uncachedIds = ArrayList<String>()
            for (entityId in entityIds) {
                if (entityId.isEmpty()) {
                    result[entityId] = false
                    continue
                }
                let cachedPerm = PermissionCache.get(userId, entityType, entityId)
                if (let Some(perm) <- cachedPerm) {
                    let userLevel = PermissionLevel.fromInt32OrDefault(perm)
                    result[entityId] = hasPermission(userLevel, requiredPermission)
                } else {
                    uncachedIds.add(entityId)
                }
            }

            if (uncachedIds.isEmpty()) {
                return result
            }

            let executor = ORM.executor()
            let dao = (executor as DataAccessAuthorizationDAO).getOrThrow()
            let authorizations = dao.findAuthByUserIdAndEntityTypeAndEntityIds(userId, entityType, uncachedIds)

            let authMap = HashMap<String, Int32>()
            for (auth in authorizations) {
                if (auth.entityId.isEmpty()) {
                    continue
                }
                let currentPerm = authMap.get(auth.entityId)
                if (currentPerm.isSome()) {
                    if (auth.permission > currentPerm.getOrThrow()) {
                        authMap[auth.entityId] = auth.permission
                    }
                } else {
                    authMap[auth.entityId] = auth.permission
                }
            }

            for (entityId in uncachedIds) {
                if (authMap.contains(entityId)) {
                    let perm = authMap.get(entityId).getOrThrow()
                    let userLevel = PermissionLevel.fromInt32OrDefault(perm)
                    result[entityId] = hasPermission(userLevel, requiredPermission)
                    PermissionCache.put(userId, entityType, entityId, perm)
                } else {
                    result[entityId] = false
                    PermissionCache.put(userId, entityType, entityId, Int32(0))
                }
            }

            return result
        } catch (e: Exception) {
            LogUtils.error(logger, "Batch permission check failed: ${e.message}")
            for (id in entityIds) {
                if (!result.contains(id)) {
                    result[id] = false
                }
            }
            return result
        }
    }

    public static func createDataAccessRule(
        entityType: String,
        entityId: String,
        userId: String,
        permission: PermissionLevel,
        authorizerId: String
    ): (Bool, String) {
        if (entityId.isEmpty() || entityType.isEmpty() || userId.isEmpty() || authorizerId.isEmpty()) {
            LogUtils.error(logger, "createDataAccessRule rejected: invalid params entityId=${entityId}, entityType=${entityType}, userId=${userId}, authorizerId=${authorizerId}")
            return (false, "参数无效: entityId/entityType/userId不能为空")
        }
        try {
            let (hasAuthPerm, reason) = checkUserHasPermission(authorizerId, entityType, entityId, PermissionLevel.AUTHORIZE)
            if (!hasAuthPerm) {
                return (false, "授权者没有授权权限: ${reason}")
            }

            if (permission.value() > PermissionLevel.AUTHORIZE.value()) {
                return (false, "越权授权: 不能授予超出自身权限的级别")
            }

            let executor = ORM.executor()
            let dao = (executor as DataAccessAuthorizationDAO).getOrThrow()
            let existing = dao.findAuthByUserIdAndEntityTypeAndEntityId(userId, entityType, entityId)
            if (!existing.isEmpty()) {
                for (auth in existing) {
                    if (auth.permission >= permission.value()) {
                        return (true, "授权已存在")
                    }
                }
            }

            let auth = DataAccessAuthorizationPO()
            auth.entityId = entityId
            auth.entityType = entityType
            auth.userId = userId
            auth.permission = permission.value()
            auth.creator = Some(authorizerId)
            auth.createdAt = DateTime.now()
            auth.updatedAt = DateTime.now()

            let id = dao.insertDataAccessAuthorization(auth)

            PermissionCache.invalidate(userId, entityType, entityId)

            if (!id.isEmpty()) {
                return (true, "")
            } else {
                return (false, "创建授权记录失败")
            }
        } catch (e: Exception) {
            LogUtils.error(logger, "Create data access rule failed: ${e.message}")
            return (false, "创建授权规则失败")
        }
    }

    public static func deleteDataAccessRule(authId: String, operatorId: String, entityType: String, entityId: String): (Bool, String) {
        if (authId.isEmpty() || entityType.isEmpty() || entityId.isEmpty()) {
            LogUtils.error(logger, "deleteDataAccessRule rejected: invalid params authId=${authId}, entityType=${entityType}, entityId=${entityId}")
            return (false, "参数无效: authId/entityType/entityId不能为空")
        }
        try {
            let executor = ORM.executor()
            let dao = (executor as DataAccessAuthorizationDAO).getOrThrow()
            let rows = dao.softDeleteDataAccessAuthorizationById(authId)

            PermissionCache.invalidateByEntity(entityType, entityId)

            if (rows > 0) {
                return (true, "")
            } else {
                return (false, "删除授权记录失败")
            }
        } catch (e: Exception) {
            LogUtils.error(logger, "Delete data access rule failed: ${e.message}")
            return (false, "删除授权规则失败")
        }
    }

    private static func buildFilterCondition(authorizedIds: ArrayList<String>, userId: String): String {
        if (authorizedIds.isEmpty()) {
            return "creator = '${userId}'"
        }
        let sb = StringBuilder()
        sb.append("(creator = '${userId}' OR id IN (")
        var first = true
        for (id in authorizedIds) {
            if (id.isEmpty()) {
                continue
            }
            if (!first) {
                sb.append(",")
            }
            sb.append("'")
            sb.append(id)
            sb.append("'")
            first = false
        }
        sb.append("))")
        return sb.toString()
    }
}
