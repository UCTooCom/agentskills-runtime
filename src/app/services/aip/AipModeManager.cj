/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import magic.app.services.aip.model.AipMode
import magic.app.services.aip.acps.{AcpsRegistryAdapter, AcpsCaAdapter, AcpsDiscoveryAdapter, AcpsMqAdapter}
import magic.app.core.response.APIResult
import magic.log.LogUtils
import magic.utils.getEnv
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonNull, JsonString, JsonBool}

public class AipModeManager {
    private var currentMode: AipMode = AipMode.Local
    private var registryEndpoint: Option<String> = None<String>
    private var caEndpoint: Option<String> = None<String>
    private var discoveryEndpoint: Option<String> = None<String>
    private var mqEndpoint: Option<String> = None<String>
    private var protocolVersion: String = "2.1.0"

    public init() {
        this.loadConfig()
    }

    public func getCurrentMode(): AipMode {
        return this.currentMode
    }

    public func isInterconnectionMode(): Bool {
        return match (this.currentMode) {
            case AipMode.Interconnection => true
            case AipMode.Local => false
        }
    }

    public func switchToInterconnection(): Bool {
        if (this.checkAcpsAvailability()) {
            this.currentMode = AipMode.Interconnection
            LogUtils.info("AIP mode switched to Interconnection")
            return true
        } else {
            LogUtils.warn("AIP mode switch to Interconnection failed: ACPs services not available")
            return false
        }
    }

    public func switchToLocal(): Unit {
        this.currentMode = AipMode.Local
        LogUtils.info("AIP mode switched to Local")
    }

    public func checkAcpsAvailability(): Bool {
        var registryAvailable = match (this.registryEndpoint) {
            case Some(ep) => !ep.isEmpty()
            case None => false
        }
        var caAvailable = match (this.caEndpoint) {
            case Some(ep) => !ep.isEmpty()
            case None => false
        }
        return registryAvailable && caAvailable
    }

    public func checkAcpsConnectivity(): AcpsConnectivityResult {
        let result = AcpsConnectivityResult()

        let registryAdapter = AcpsRegistryAdapter()
        result.registryReachable = registryAdapter.checkConnectivity()

        let caAdapter = AcpsCaAdapter()
        result.caReachable = caAdapter.checkConnectivity()

        let discoveryAdapter = AcpsDiscoveryAdapter()
        result.discoveryReachable = discoveryAdapter.checkConnectivity()

        let mqAdapter = AcpsMqAdapter()
        result.mqReachable = mqAdapter.checkConnectivity()

        result.overallAvailable = result.registryReachable && result.caReachable
        return result
    }

    public func upgradeToInterconnection(): APIResult<Bool> {
        if (this.isInterconnectionMode()) {
            return APIResult<Bool>(false, "已在互联模式下运行")
        }

        let connectivity = this.checkAcpsConnectivity()
        if (!connectivity.overallAvailable) {
            var reasons = ArrayList<String>()
            if (!connectivity.registryReachable) { reasons.add("注册服务不可达") }
            if (!connectivity.caReachable) { reasons.add("CA服务不可达") }
            var reasonStr = ""
            var first = true
            for (r in reasons) {
                if (!first) { reasonStr = reasonStr + ", " }
                reasonStr = reasonStr + r
                first = false
            }
            LogUtils.warn("AipModeManager", "Upgrade to interconnection failed: ${reasonStr}")
            return APIResult<Bool>(false, "升级到互联模式失败: ${reasonStr}")
        }

        this.currentMode = AipMode.Interconnection
        LogUtils.info("AipModeManager", "AIP mode upgraded to Interconnection")
        return APIResult<Bool>(true)
    }

    public func degradeToLocal(reason: String): APIResult<Bool> {
        if (!this.isInterconnectionMode()) {
            return APIResult<Bool>(false, "已在本地模式下运行")
        }

        try {
            let mqAdapter = AcpsMqAdapter()
            let mqResult = mqAdapter.releaseAllResources()
            if (!mqResult.success) {
                LogUtils.warn("AipModeManager", "AIP-MQ-014: MQ资源释放失败: ${mqResult.reason ?? "unknown"}")
            }
        } catch (e: Exception) {
            LogUtils.warn("AipModeManager", "AIP-MQ-014: MQ资源释放异常: ${e.message}")
        }

        let prevMode = this.currentMode
        this.currentMode = AipMode.Local
        LogUtils.warn("AipModeManager", "AIP mode degraded from ${match (prevMode) { case AipMode.Interconnection => "interconnection" case AipMode.Local => "local" }} to local: ${reason}")
        return APIResult<Bool>(true)
    }

    public func checkAndAutoDegrade(): Bool {
        if (!this.isInterconnectionMode()) {
            return false
        }

        let connectivity = this.checkAcpsConnectivity()
        if (!connectivity.overallAvailable) {
            this.autoDegrade("ACPs服务连通性检查失败: registry=${connectivity.registryReachable}, ca=${connectivity.caReachable}")
            return true
        }
        return false
    }

    public func autoDegrade(reason: String): Unit {
        if (this.isInterconnectionMode()) {
            LogUtils.warn("AIP auto degrading to Local mode: ${reason}")
            this.currentMode = AipMode.Local
        }
    }

    public func getRegistryEndpoint(): Option<String> {
        return this.registryEndpoint
    }

    public func getCaEndpoint(): Option<String> {
        return this.caEndpoint
    }

    public func getDiscoveryEndpoint(): Option<String> {
        return this.discoveryEndpoint
    }

    public func getMqEndpoint(): Option<String> {
        return this.mqEndpoint
    }

    public func getProtocolVersion(): String {
        return this.protocolVersion
    }

    public func getConfigJson(): JsonObject {
        var map = HashMap<String, JsonValue>()
        map.add("mode", match (this.currentMode) {
            case AipMode.Local => JsonString("local")
            case AipMode.Interconnection => JsonString("interconnection")
        })
        map.add("protocol_version", JsonString(this.protocolVersion))
        map.add("registry_endpoint", optionToJsonValue(this.registryEndpoint))
        map.add("ca_endpoint", optionToJsonValue(this.caEndpoint))
        map.add("discovery_endpoint", optionToJsonValue(this.discoveryEndpoint))
        map.add("mq_endpoint", optionToJsonValue(this.mqEndpoint))
        map.add("acps_available", JsonBool(this.checkAcpsAvailability()))
        return JsonObject(map)
    }

    private func loadConfig(): Unit {
        let modeStr = getEnvWithDefault("AIP_MODE", "auto")
        this.registryEndpoint = getOptionalEnv("AIP_REGISTRY_ENDPOINT")
        this.caEndpoint = getOptionalEnv("AIP_CA_ENDPOINT")
        this.discoveryEndpoint = getOptionalEnv("AIP_DISCOVERY_ENDPOINT")
        this.mqEndpoint = getOptionalEnv("AIP_MQ_ENDPOINT")

        let envVersion = getEnvWithDefault("AIP_PROTOCOL_VERSION", "")
        if (!envVersion.isEmpty()) {
            this.protocolVersion = envVersion
        }

        if (modeStr == "interconnection") {
            if (this.checkAcpsAvailability()) {
                this.currentMode = AipMode.Interconnection
                LogUtils.info("AIP started in Interconnection mode")
            } else {
                this.currentMode = AipMode.Local
                LogUtils.warn("AIP configured as interconnection but ACPs not available, falling back to Local mode")
            }
        } else if (modeStr == "local") {
            this.currentMode = AipMode.Local
            LogUtils.info("AIP started in Local mode")
        } else {
            if (this.checkAcpsAvailability()) {
                this.currentMode = AipMode.Interconnection
                LogUtils.info("AIP auto-detected Interconnection mode")
            } else {
                this.currentMode = AipMode.Local
                LogUtils.info("AIP auto-detected Local mode")
            }
        }
    }

    private func getEnvWithDefault(key: String, defaultValue: String): String {
        return match (getEnv(key)) {
            case Some(v) => if (v.isEmpty()) { defaultValue } else { v }
            case None => defaultValue
        }
    }

    private func getOptionalEnv(key: String): Option<String> {
        return match (getEnv(key)) {
            case Some(v) => if (v.isEmpty()) { None<String> } else { Some(v) }
            case None => None<String>
        }
    }

    private static func optionToJsonValue(opt: Option<String>): JsonValue {
        if (let Some(v) <- opt) {
            return JsonString(v)
        } else {
            return JsonNull()
        }
    }
}

public class AcpsConnectivityResult {
    public var registryReachable: Bool = false
    public var caReachable: Bool = false
    public var discoveryReachable: Bool = false
    public var mqReachable: Bool = false
    public var overallAvailable: Bool = false

    public init() {}
}