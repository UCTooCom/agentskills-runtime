/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.acps

import std.collection.*
import stdx.encoding.json.*
import magic.utils.http.HttpUtils
import magic.utils.getEnv
import magic.log.LogUtils

public class AcpsDiscoveryAdapter {
    private func getDiscoveryUrl(): String {
        getEnv("AIPS_DISCOVERY_URL") ?? "http://localhost:9082"
    }

    private func buildHeaders(): HashMap<String, String> {
        let header = HashMap<String, String>()
        header.add("Content-Type", "application/json")
        header.add("Accept", "application/json")
        let token = getEnv("AIPS_DISCOVERY_TOKEN")
        if (token.isSome()) {
            header.add("Authorization", "Bearer ${token.getOrThrow()}")
        }
        return header
    }

    public func discover(requestBody: JsonObject): Option<String> {
        try {
            let url = "${getDiscoveryUrl()}/api/v1/discovery/search"
            let result = HttpUtils.post(url, buildHeaders(), requestBody)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsDiscoveryAdapter", "discover failed: ${e.message}")
            return None<String>
        }
    }

    public func checkConnectivity(): Bool {
        try {
            let url = "${getDiscoveryUrl()}/health"
            let header = HashMap<String, String>()
            let result = HttpUtils.get(url, header, None<JsonObject>)
            return result.isSome()
        } catch (e: Exception) {
            LogUtils.warn("AcpsDiscoveryAdapter", "checkConnectivity failed: ${e.message}")
            return false
        }
    }
}