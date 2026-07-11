/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.acps

import std.collection.*
import stdx.encoding.json.*
import magic.utils.http.HttpUtils
import magic.utils.getEnv
import magic.log.LogUtils

public class AcpsCaAdapter {
    private func getCaUrl(): String {
        getEnv("AIPS_CA_URL") ?? "http://localhost:9081"
    }

    private func buildHeaders(): HashMap<String, String> {
        let header = HashMap<String, String>()
        header.add("Content-Type", "application/json")
        header.add("Accept", "application/json")
        let token = getEnv("AIPS_CA_TOKEN")
        if (token.isSome()) {
            header.add("Authorization", "Bearer ${token.getOrThrow()}")
        }
        return header
    }

    public func requestCertificate(requestBody: JsonObject): Option<String> {
        try {
            let url = "${getCaUrl()}/api/v1/certificate/request"
            let result = HttpUtils.post(url, buildHeaders(), requestBody)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsCaAdapter", "requestCertificate failed: ${e.message}")
            return None<String>
        }
    }

    public func verifyCertificate(certificateId: String): Option<String> {
        try {
            let url = "${getCaUrl()}/api/v1/certificate/${certificateId}/verify"
            let header = HashMap<String, String>()
            header.add("Accept", "application/json")
            let result = HttpUtils.get(url, header, None<JsonObject>)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsCaAdapter", "verifyCertificate failed: ${e.message}")
            return None<String>
        }
    }

    public func revokeCertificate(certificateId: String): Option<String> {
        try {
            let url = "${getCaUrl()}/api/v1/certificate/${certificateId}/revoke"
            let body = JsonObject()
            let result = HttpUtils.post(url, buildHeaders(), body)
            return result
        } catch (e: Exception) {
            LogUtils.error("AcpsCaAdapter", "revokeCertificate failed: ${e.message}")
            return None<String>
        }
    }

    public func checkConnectivity(): Bool {
        try {
            let url = "${getCaUrl()}/health"
            let header = HashMap<String, String>()
            let result = HttpUtils.get(url, header, None<JsonObject>)
            return result.isSome()
        } catch (e: Exception) {
            LogUtils.warn("AcpsCaAdapter", "checkConnectivity failed: ${e.message}")
            return false
        }
    }
}