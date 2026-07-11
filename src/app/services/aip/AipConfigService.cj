/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import std.collection.*
import f_orm.*
import f_orm.sql.Pagination
import magic.app.core.response.APIResult
import magic.app.models.uctoo.AgentsPO
import magic.app.services.aip.model.AipMode
import magic.app.services.aip.acps.{AcpsRegistryAdapter, AcpsCaAdapter, AcpsDiscoveryAdapter, AcpsMqAdapter}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool}
import magic.log.LogUtils

public class AipConfigService {
    private let modeManager: AipModeManager

    public init() {
        this.modeManager = AipModeManager()
    }

    public func getConfig(): APIResult<JsonObject> {
        try {
            return APIResult<JsonObject>(modeManager.getConfigJson())
        } catch (e: Exception) {
            LogUtils.error("AipConfigService", "getConfig failed: ${e.message}")
            return APIResult<JsonObject>(false, "获取AIP配置失败: ${e.message}")
        }
    }

    public func getMode(): APIResult<AipMode> {
        try {
            return APIResult<AipMode>(modeManager.getCurrentMode())
        } catch (e: Exception) {
            LogUtils.error("AipConfigService", "getMode failed: ${e.message}")
            return APIResult<AipMode>(false, "获取AIP运行模式失败: ${e.message}")
        }
    }

    public func switchMode(targetMode: AipMode): APIResult<Bool> {
        try {
            let result = match (targetMode) {
                case AipMode.Interconnection => modeManager.switchToInterconnection()
                case AipMode.Local => 
                    modeManager.switchToLocal()
                    true
            }
            let modeStr = match (targetMode) {
                case AipMode.Local => "local"
                case AipMode.Interconnection => "interconnection"
            }
            LogUtils.info("AipConfigService", "Mode switched to ${modeStr}")
            return APIResult<Bool>(result)
        } catch (e: Exception) {
            LogUtils.error("AipConfigService", "switchMode failed: ${e.message}")
            return APIResult<Bool>(false, "切换AIP运行模式失败: ${e.message}")
        }
    }

    public func healthCheckLocal(): APIResult<JsonObject> {
        try {
            var overallStatus = "healthy"
            var components = HashMap<String, JsonValue>()

            let dbStatus = checkDatabaseHealth()
            components.add("database", dbStatus)
            if (dbStatus.toString().contains("unhealthy")) { overallStatus = "degraded" }

            let discoveryStatus = checkDiscoveryHealth()
            components.add("localDiscovery", discoveryStatus)

            let interactionStatus = checkInteractionHealth()
            components.add("localInteraction", interactionStatus)

            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString(overallStatus))
            map.add("mode", JsonString("local"))
            map.add("components", JsonObject(components))

            return APIResult<JsonObject>(JsonObject(map))
        } catch (e: Exception) {
            LogUtils.error("AipConfigService", "healthCheckLocal failed: ${e.message}")

            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("unhealthy"))
            map.add("mode", JsonString("local"))
            map.add("error", JsonString(e.message))
            return APIResult<JsonObject>(JsonObject(map))
        }
    }

    private func checkDatabaseHealth(): JsonValue {
        try {
            let executor = ORM.executor()
            let agents = executor.setSql("select count(*) as cnt from agents where deleted_at is null").singleFirst<Int64>() ?? 0
            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("healthy"))
            map.add("agentCount", JsonString(agents.toString()))
            return JsonObject(map)
        } catch (e: Exception) {
            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("unhealthy"))
            map.add("error", JsonString(e.message))
            return JsonObject(map)
        }
    }

    private func checkDiscoveryHealth(): JsonValue {
        try {
            let executor = ORM.executor()
            let discoverable = executor.setSql("select count(*) as cnt from agents where discoverable = true and deleted_at is null").singleFirst<Int64>() ?? 0
            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("healthy"))
            map.add("discoverableAgentCount", JsonString(discoverable.toString()))
            return JsonObject(map)
        } catch (e: Exception) {
            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("healthy"))
            map.add("note", JsonString("discovery check skipped"))
            return JsonObject(map)
        }
    }

    private func checkInteractionHealth(): JsonValue {
        try {
            let executor = ORM.executor()
            let sessions = executor.setSql("select count(*) as cnt from agent_messages where aip_session_id is not null and deleted_at is null").singleFirst<Int64>() ?? 0
            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("healthy"))
            map.add("aipMessageCount", JsonString(sessions.toString()))
            return JsonObject(map)
        } catch (e: Exception) {
            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("healthy"))
            map.add("note", JsonString("interaction check skipped"))
            return JsonObject(map)
        }
    }

    public func healthCheckInterconnection(): APIResult<JsonObject> {
        try {
            var overallStatus = "healthy"
            var components = HashMap<String, JsonValue>()

            let dbStatus = checkDatabaseHealth()
            components.add("database", dbStatus)
            if (dbStatus.toString().contains("unhealthy")) { overallStatus = "degraded" }

            let discoveryStatus = checkDiscoveryHealth()
            components.add("localDiscovery", discoveryStatus)

            let interactionStatus = checkInteractionHealth()
            components.add("localInteraction", interactionStatus)

            let registryAdapter = AcpsRegistryAdapter()
            let registryAvailable = registryAdapter.checkConnectivity()
            var registryMap = HashMap<String, JsonValue>()
            registryMap.add("status", JsonString(if (registryAvailable) { "healthy" } else { "unhealthy" }))
            registryMap.add("endpoint", JsonString(modeManager.getRegistryEndpoint().getOrDefault({ => "" })))
            components.add("registryService", JsonObject(registryMap))
            if (!registryAvailable) { overallStatus = "degraded" }

            let caAdapter = AcpsCaAdapter()
            let caAvailable = caAdapter.checkConnectivity()
            var caMap = HashMap<String, JsonValue>()
            caMap.add("status", JsonString(if (caAvailable) { "healthy" } else { "unhealthy" }))
            caMap.add("endpoint", JsonString(modeManager.getCaEndpoint().getOrDefault({ => "" })))
            components.add("caService", JsonObject(caMap))
            if (!caAvailable) { overallStatus = "degraded" }

            let discoveryAdapter = AcpsDiscoveryAdapter()
            let discoveryAvailable = discoveryAdapter.checkConnectivity()
            var discMap = HashMap<String, JsonValue>()
            discMap.add("status", JsonString(if (discoveryAvailable) { "healthy" } else { "unhealthy" }))
            discMap.add("endpoint", JsonString(modeManager.getDiscoveryEndpoint().getOrDefault({ => "" })))
            components.add("discoveryService", JsonObject(discMap))
            if (!discoveryAvailable) { overallStatus = "degraded" }

            var mqMap = HashMap<String, JsonValue>()
            let mqEndpoint = modeManager.getMqEndpoint()
            if (mqEndpoint.isSome()) {
                let mqAdapter = AcpsMqAdapter()
                let mqAvailable = mqAdapter.checkConnectivity()
                mqMap.add("status", JsonString(if (mqAvailable) { "healthy" } else { "unhealthy" }))
                mqMap.add("endpoint", JsonString(mqEndpoint.getOrThrow()))
                if (!mqAvailable) {
                    overallStatus = "degraded"
                }
            } else {
                mqMap.add("status", JsonString("not_configured"))
            }
            components.add("mqService", JsonObject(mqMap))

            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString(overallStatus))
            map.add("mode", JsonString("interconnection"))
            map.add("components", JsonObject(components))

            return APIResult<JsonObject>(JsonObject(map))
        } catch (e: Exception) {
            LogUtils.error("AipConfigService", "healthCheckInterconnection failed: ${e.message}")

            var map = HashMap<String, JsonValue>()
            map.add("status", JsonString("unhealthy"))
            map.add("mode", JsonString("interconnection"))
            map.add("error", JsonString(e.message))
            return APIResult<JsonObject>(JsonObject(map))
        }
    }
}