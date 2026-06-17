/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.sync

import magic.app.core.router.Router
import magic.app.controllers.sync.SyncController
import magic.app.services.sync.{SyncService, SyncLogService}
import magic.log.LogUtils

/**
 * 同步管理路由配置
 * 提供文件系统与数据库同步的 API 端点
 */
public class SyncRoute {
    private let _router: Router
    private let _controller: SyncController

    public init(router: Router) {
        this._router = router
        let syncService = SyncService()
        let syncLogService = SyncLogService()
        this._controller = SyncController(syncService, syncLogService)
    }

    /**
     * 注册所有同步管理路由
     */
    public func register(): Unit {
        // 同步状态概览
        _router.get("/api/v1/uctoo/sync/summary", { req, res =>
            _controller.getSummary(req, res)
        })
        
        // 获取实体同步状态
        _router.get("/api/v1/uctoo/sync/status/:entityType", { req, res =>
            _controller.getStatus(req, res)
        })
        
        // 从文件系统同步到数据库
        _router.post("/api/v1/uctoo/sync/from-fs", { req, res =>
            _controller.syncFromFileSystem(req, res)
        })
        
        // 从数据库同步到文件系统
        _router.post("/api/v1/uctoo/sync/to-fs/:entityType/:entityId", { req, res =>
            _controller.syncToFileSystem(req, res)
        })
        
        // 全量同步
        _router.post("/api/v1/uctoo/sync/all", { req, res =>
            _controller.syncAll(req, res)
        })
        
        // 同步日志查询
        _router.get("/api/v1/uctoo/sync/logs", { req, res =>
            _controller.getLogs(req, res)
        })
        
        // 健康检查
        _router.get("/api/v1/uctoo/sync/health", { req, res =>
            res.status(200).json("{\"status\":\"ok\",\"service\":\"sync-api\"}")
        })
        
        LogUtils.info("Sync routes registered successfully")
    }
}
