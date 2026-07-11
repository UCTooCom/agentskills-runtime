/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.tasks

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.TasksPO
import magic.app.services.uctoo.TasksService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.log.LogUtils

/**
 * PublicTasksController - 公开任务API控制器
 *
 * 提供无需登录即可访问的任务相关接口：
 * - GET /api/v1/uctoo/tasks/public/home-stats 首页统计
 * - GET /api/v1/uctoo/tasks/public/list 公开任务列表
 * - GET /api/v1/uctoo/tasks/public/:id 公开任务详情
 */
public class PublicTasksController {
    private var service: TasksService

    public init(service: TasksService) {
        this.service = service
    }

    /**
     * 首页统计数据
     * GET /api/v1/uctoo/tasks/public/home-stats
     */
    public func getHomeStats(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let stats = service.getHomeStats()
            // 构建 JSON 响应
            let jsonBuilder = StringBuilder()
            jsonBuilder.append("{\"errno\":\"0\",\"data\":{")
            var first = true
            for ((key, value) in stats) {
                if (!first) {
                    jsonBuilder.append(",")
                }
                jsonBuilder.append("\"${key}\":${value}")
                first = false
            }
            jsonBuilder.append("}}")
            res.status(200).json(jsonBuilder.toString())
        } catch (e: Exception) {
            LogUtils.error("PublicTasksController", "获取首页统计失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 公开任务列表
     * GET /api/v1/uctoo/tasks/public/:limit/:page
     * 支持参数：filter(JSON), sort(排序字段)
     */
    public func getPublicList(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")
            let pageSize = if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }
            let currentPage = if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }

            if (pageSize > 1000) {
                res.status(400).json("{\"errno\":\"40004\",\"errmsg\":\"请求数量不能超过1000条\"}")
                return
            }

            let sortParam = req.queryParam("sort") ?? ""
            let filterParam = req.queryParam("filter") ?? ""

            let (list, total) = service.listPublicTasksWithFilter(
                currentPage,
                pageSize,
                sortParam,
                filterParam
            )

            let totalPage = if (pageSize > 0) {
                Int32((total + Int64(pageSize) - 1) / Int64(pageSize))
            } else {
                Int32(0)
            }

            let entitiesJson = service.tasksToJsonWithCompanyName(list)
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"tasks\":${entitiesJson}}")
        } catch (e: Exception) {
            LogUtils.error("PublicTasksController", "获取公开任务列表失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 公开任务详情
     * GET /api/v1/uctoo/tasks/public/:id
     */
    public func getPublicDetail(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")
            if (let Some(taskId) <- id) {
                let result = service.getPublicTaskDetail(taskId)
                if (result.success) {
                    if (let Some(data) <- result.data) {
                        let taskJson = service.taskToJsonWithCompanyName(data)
                        res.status(200).json("{\"errno\":\"0\",\"data\":${taskJson}}")
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"任务不存在\"}")
                    }
                } else {
                    let reason = result.reason ?? "任务不可见"
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少任务ID参数\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PublicTasksController", "获取任务详情失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
}
