/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.aip

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.aip.AipConfigService
import magic.log.LogUtils

public class AipHealthController {
    private var configService: AipConfigService

    public init() {
        this.configService = AipConfigService()
    }

    public func healthLocal(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = configService.healthCheckLocal()
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toString())
                } else {
                    res.status(500).json("{\"status\":\"unhealthy\",\"mode\":\"local\"}")
                }
            } else {
                let errMsg = result.reason ?? "unknown"
                res.status(503).json("{\"status\":\"unhealthy\",\"mode\":\"local\",\"error\":\"${errMsg}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipHealthController", "healthLocal failed: ${e.message}")
            res.status(503).json("{\"status\":\"unhealthy\",\"mode\":\"local\",\"error\":\"${e.message}\"}")
        }
    }

    public func healthInterconnection(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = configService.healthCheckInterconnection()
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toString())
                } else {
                    res.status(500).json("{\"status\":\"unhealthy\",\"mode\":\"interconnection\"}")
                }
            } else {
                let errMsg = result.reason ?? "unknown"
                res.status(503).json("{\"status\":\"unhealthy\",\"mode\":\"interconnection\",\"error\":\"${errMsg}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipHealthController", "healthInterconnection failed: ${e.message}")
            res.status(503).json("{\"status\":\"unhealthy\",\"mode\":\"interconnection\",\"error\":\"${e.message}\"}")
        }
    }
}