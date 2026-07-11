/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.acps

import std.collection.*
import stdx.encoding.json.*
import magic.utils.http.HttpUtils
import magic.utils.getEnv
import magic.log.LogUtils

public class AcpsRegistryAdapter {
    private func getRegistryUrl(): String {
        getEnv("AIPS_REGISTRY_URL") ?? "http://localhost:9080"
    }

    private func buildHeaders(): HashMap<String, String> {
        let header = HashMap<String, String>()
        header.add("Content-Type", "application/json")
        header.add("Accept", "application/json")
        let token = getEnv("AIPS_REGISTRY_TOKEN")
        if (token.isSome()) {
            header.add("Authorization", "Bearer ${token.getOrThrow()}")
        }
        return header
    }

    public func submitRegistration(requestBody: JsonObject): Option<String> {
        try {
            let url = "${getRegistryUrl()}/api/v1/registration/submit"
            let result = HttpUtils.post(url, buildHeaders(), requestBody)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsRegistryAdapter", "submitRegistration failed: ${e.message}")
            return None<String>
        }
    }

    public func submitUpdate(aic: String, requestBody: JsonObject): Option<String> {
        try {
            let url = "${getRegistryUrl()}/api/v1/registration/${aic}/update"
            let result = HttpUtils.post(url, buildHeaders(), requestBody)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsRegistryAdapter", "submitUpdate failed: ${e.message}")
            return None<String>
        }
    }

    public func submitRevocation(aic: String): Option<String> {
        try {
            let url = "${getRegistryUrl()}/api/v1/registration/${aic}/revoke"
            let body = JsonObject()
            let result = HttpUtils.post(url, buildHeaders(), body)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsRegistryAdapter", "submitRevocation failed: ${e.message}")
            return None<String>
        }
    }

    public func submitDescription(aic: String, requestBody: JsonObject): Option<String> {
        try {
            let url = "${getRegistryUrl()}/api/v1/registration/${aic}/description"
            let result = HttpUtils.post(url, buildHeaders(), requestBody)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsRegistryAdapter", "submitDescription failed: ${e.message}")
            return None<String>
        }
    }

    public func submitPublish(aic: String): Option<String> {
        try {
            let url = "${getRegistryUrl()}/api/v1/registration/${aic}/publish"
            let body = JsonObject()
            let result = HttpUtils.post(url, buildHeaders(), body)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsRegistryAdapter", "submitPublish failed: ${e.message}")
            return None<String>
        }
    }

    public func checkConnectivity(): Bool {
        try {
            let url = "${getRegistryUrl()}/health"
            let header = HashMap<String, String>()
            let result = HttpUtils.get(url, header, None<JsonObject>)
            return result.isSome()
        } catch (e: Exception) {
            LogUtils.warn("AcpsRegistryAdapter", "checkConnectivity failed: ${e.message}")
            return false
        }
    }
}