/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import std.collection.*
import std.time.DateTime
import std.core.Duration
import std.convert.*
import f_orm.*
import magic.app.models.uctoo.{AgentsPO, AipDiscoveryCachePO}
import magic.app.dao.uctoo.{AgentsDAO, AipDiscoveryCacheDAO}
import magic.app.core.response.APIResult
import magic.app.services.aip.model.LocalDiscoveryRequest
import magic.app.services.aip.acps.AcpsDiscoveryAdapter
import magic.log.LogUtils
import stdx.encoding.json.*
import magic.utils.getEnv
import f_util.UUID

public class AipDiscoveryService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    public func discoverLocal(request: LocalDiscoveryRequest): APIResult<ArrayList<AgentsPO>> {
        try {
            var sql = StringBuilder()
            sql.append("select * from agents where discoverable = true and deleted_at is null")

            if (request.name.isSome()) {
                let nameVal = request.name.getOrThrow()
                if (!nameVal.isEmpty()) {
                    sql.append(" and name like '%")
                    sql.append(nameVal.replace("'", "''"))
                    sql.append("%'")
                }
            }
            if (request.descriptionKeyword.isSome()) {
                let kw = request.descriptionKeyword.getOrThrow()
                if (!kw.isEmpty()) {
                    sql.append(" and description like '%")
                    sql.append(kw.replace("'", "''"))
                    sql.append("%'")
                }
            }

            sql.append(" order by created_at desc")

            if (request.limit > 0) {
                sql.append(" limit ${request.limit}")
            }
            if (request.page > 0 && request.limit > 0) {
                sql.append(" offset ${(request.page - 1) * request.limit}")
            }

            let agents = getExecutor().setSql(sql.toString()).list<AgentsPO>()
            LogUtils.info("AipDiscoveryService", "Local discovery found ${agents.size} agents")

            return APIResult<ArrayList<AgentsPO>>(agents)
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryService", "discoverLocal failed: ${e.message}")
            return APIResult<ArrayList<AgentsPO>>(false, "本地智能体发现失败: ${e.message}")
        }
    }

    public func discoverLocalById(agentId: String): APIResult<AgentsPO> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<AgentsPO>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()
            if (!agent.discoverable) {
                return APIResult<AgentsPO>(false, "该智能体不允许被发现")
            }
            return APIResult<AgentsPO>(agent)
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryService", "discoverLocalById failed: ${e.message}")
            return APIResult<AgentsPO>(false, "查询智能体失败: ${e.message}")
        }
    }

    public func discoverInterconnection(queryCondition: String, creatorId: String): APIResult<String> {
        try {
            let discoveryAdapter = AcpsDiscoveryAdapter()

            var reqMap = HashMap<String, JsonValue>()
            reqMap.add("query", JsonString(queryCondition))
            let reqBody = JsonObject(reqMap)

            let result = discoveryAdapter.discover(reqBody)
            if (result.isNone()) {
                return APIResult<String>(false, "AIP-DISC-001: ACPs发现服务请求失败")
            }

            let resultStr = result.getOrThrow()

            var cacheTtl: Int64 = 300
            let ttlStr = getEnv("AIP_DISCOVERY_CACHE_TTL")
            if (ttlStr.isSome()) {
                let parsed = Int64.parse(ttlStr.getOrThrow())
                if (parsed > 0) { cacheTtl = parsed }
            }

            let cache = AipDiscoveryCachePO()
            cache.queryHash = UUID.random().toString()
            cache.queryCondition = queryCondition
            cache.resultSet = resultStr
            cache.resultCount = 0
            cache.cachedAt = DateTime.now()
            cache.expiresAt = DateTime.now() + Duration.second * cacheTtl
            cache.creator = creatorId
            cache.createdAt = DateTime.now()
            cache.updatedAt = DateTime.now()

            getExecutor().insertAipDiscoveryCache(cache)

            LogUtils.info("AipDiscoveryService", "Interconnection discovery completed, cached: ${cache.queryHash}")
            return APIResult<String>(resultStr)
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryService", "discoverInterconnection failed: ${e.message}")
            return APIResult<String>(false, "AIP-DISC-001: 互联智能体发现失败: ${e.message}")
        }
    }

    public func getDiscoveryCache(queryHash: String): APIResult<AipDiscoveryCachePO> {
        try {
            let cacheOpt = getExecutor().setSql(
                "select * from aip_discovery_cache where query_hash = '${queryHash}' and deleted_at is null and expires_at > NOW() order by created_at desc limit 1"
            ).first<AipDiscoveryCachePO>()

            if (cacheOpt.isNone()) {
                return APIResult<AipDiscoveryCachePO>(false, "AIP-DISC-002: 未找到有效的发现缓存")
            }

            return APIResult<AipDiscoveryCachePO>(cacheOpt.getOrThrow())
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryService", "getDiscoveryCache failed: ${e.message}")
            return APIResult<AipDiscoveryCachePO>(false, "AIP-DISC-002: 查询发现缓存失败: ${e.message}")
        }
    }

    public func cleanExpiredCache(): APIResult<Int64> {
        try {
            let now = DateTime.now().toString()
            let sqlStr = "update aip_discovery_cache set deleted_at = '${now}' where deleted_at is null and expires_at <= NOW()"
            let affected = getExecutor().setSql(sqlStr).update
            LogUtils.info("AipDiscoveryService", "Cleaned ${affected} expired discovery cache records")
            return APIResult<Int64>(affected)
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryService", "cleanExpiredCache failed: ${e.message}")
            return APIResult<Int64>(false, "清理过期发现缓存失败: ${e.message}")
        }
    }

    public func refreshCache(queryHash: String, creatorId: String): APIResult<AipDiscoveryCachePO> {
        try {
            let cacheOpt = getExecutor().setSql(
                "select * from aip_discovery_cache where query_hash = '${queryHash}' and deleted_at is null order by created_at desc limit 1"
            ).first<AipDiscoveryCachePO>()

            if (cacheOpt.isNone()) {
                return APIResult<AipDiscoveryCachePO>(false, "AIP-DISC-003: 未找到发现缓存记录")
            }

            let oldCache = cacheOpt.getOrThrow()

            let discoveryAdapter = AcpsDiscoveryAdapter()
            var reqMap = HashMap<String, JsonValue>()
            reqMap.add("query", JsonString(oldCache.queryCondition))
            let reqBody = JsonObject(reqMap)

            let result = discoveryAdapter.discover(reqBody)
            if (result.isNone()) {
                return APIResult<AipDiscoveryCachePO>(false, "AIP-DISC-003: 刷新发现缓存失败，ACPs发现服务不可达")
            }

            let resultStr = result.getOrThrow()

            var cacheTtl: Int64 = 300
            let ttlStr = getEnv("AIP_DISCOVERY_CACHE_TTL")
            if (ttlStr.isSome()) {
                let parsed = Int64.parse(ttlStr.getOrThrow())
                if (parsed > 0) { cacheTtl = parsed }
            }

            let newCache = AipDiscoveryCachePO()
            newCache.queryHash = UUID.random().toString()
            newCache.queryCondition = oldCache.queryCondition
            newCache.resultSet = resultStr
            newCache.resultCount = 0
            newCache.cachedAt = DateTime.now()
            newCache.expiresAt = DateTime.now() + Duration.second * cacheTtl
            newCache.creator = creatorId
            newCache.createdAt = DateTime.now()
            newCache.updatedAt = DateTime.now()

            getExecutor().insertAipDiscoveryCache(newCache)

            let now = DateTime.now().toString()
            getExecutor().setSql("update aip_discovery_cache set deleted_at = '${now}' where query_hash = '${queryHash}' and deleted_at is null").update

            LogUtils.info("AipDiscoveryService", "Refreshed discovery cache: ${queryHash} -> ${newCache.queryHash}")
            return APIResult<AipDiscoveryCachePO>(newCache)
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryService", "refreshCache failed: ${e.message}")
            return APIResult<AipDiscoveryCachePO>(false, "AIP-DISC-003: 刷新发现缓存失败: ${e.message}")
        }
    }
}