/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.company

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.{CompanyPO, TasksPO}
import magic.app.services.uctoo.CompanyService
import magic.app.services.uctoo.TasksService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.log.LogUtils

/**
 * PublicCompaniesController - 公开组织API控制器
 *
 * 提供无需登录即可访问的组织相关接口：
 * - GET /api/v1/uctoo/company/public/list 公开组织列表
 * - GET /api/v1/uctoo/company/public/:id 公开组织详情
 * - GET /api/v1/uctoo/company/public/:id/tasks 组织下的任务列表
 * - GET /api/v1/uctoo/company/public/:id/growth 组织成长数据
 */
public class PublicCompaniesController {
    private var service: CompanyService

    public init(service: CompanyService) {
        this.service = service
    }

    /**
     * 公开组织列表
     * GET /api/v1/uctoo/company/public/:limit/:page
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

            let (list, total) = service.listPublicCompaniesWithFilter(
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

            var entitiesJson = ""
            for (e in list) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"companys\":[${entitiesJson}]}")
        } catch (e: Exception) {
            LogUtils.error("PublicCompaniesController", "获取公开组织列表失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 公开组织详情
     * GET /api/v1/uctoo/company/public/:id
     */
    public func getPublicDetail(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")
            if (let Some(companyId) <- id) {
                let result = service.getPublicCompanyDetail(companyId)
                if (result.success) {
                    if (let Some(data) <- result.data) {
                        res.status(200).json("{\"errno\":\"0\",\"data\":${data.toJson().toString()}}")
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"组织不存在\"}")
                    }
                } else {
                    let reason = result.reason ?? "组织不可见"
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少组织ID参数\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PublicCompaniesController", "获取组织详情失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 组织下的任务列表
     * GET /api/v1/uctoo/company/public/:id/tasks/:limit/:page
     */
    public func getCompanyTasks(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")
            if (let Some(companyId) <- id) {
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

                let tasksService = TasksService()
                let (list, total) = tasksService.listPublicTasksByCompanyWithFilter(
                    companyId,
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

                let entitiesJson = tasksService.tasksToJsonWithCompanyName(list)
                res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"tasks\":${entitiesJson}}")
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少组织ID参数\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PublicCompaniesController", "获取组织任务列表失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 组织成长数据
     * GET /api/v1/uctoo/company/public/:id/growth
     * 返回组织的任务数、成员数、关注者数、积分余额等统计指标
     */
    public func getCompanyGrowth(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")
            if (let Some(companyId) <- id) {
                let result = service.getPublicCompanyDetail(companyId)
                if (result.success) {
                    if (let Some(company) <- result.data) {
                        let jsonBuilder = StringBuilder()
                        jsonBuilder.append("{\"errno\":\"0\",\"data\":{")
                        jsonBuilder.append("\"companyId\":\"${company.id}\",")
                        jsonBuilder.append("\"companyName\":\"${company.companyName}\",")
                        jsonBuilder.append("\"taskCount\":${company.taskCount},")
                        jsonBuilder.append("\"memberCount\":${company.memberCount},")
                        jsonBuilder.append("\"followerCount\":${company.followerCount},")
                        jsonBuilder.append("\"pointsBalance\":${company.pointsBalance},")
                        jsonBuilder.append("\"isVerified\":${company.isVerified}")
                        jsonBuilder.append("}}")
                        res.status(200).json(jsonBuilder.toString())
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"组织不存在\"}")
                    }
                } else {
                    let reason = result.reason ?? "组织不可见"
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少组织ID参数\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PublicCompaniesController", "获取组织成长数据失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 组织成员列表
     * GET /api/v1/uctoo/company/public/:id/members
     */
    public func getOrgMembers(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")
            if (let Some(companyId) <- id) {
                let members = service.getOrgMembers(companyId)
                var membersJson = ""
                for (member in members) {
                    if (!membersJson.isEmpty()) {
                        membersJson = membersJson + ","
                    }
                    let idVal = anyToString(member.get("id"), "")
                    let nickname = anyToString(member.get("nickname"), "")
                    let email = anyToString(member.get("email"), "")
                    let role = anyToString(member.get("member_role"), "member")
                    membersJson = membersJson + "{\"id\":\"${idVal}\",\"nickname\":\"${nickname}\",\"email\":\"${email}\",\"role\":\"${role}\"}"
                }
                res.status(200).json("{\"errno\":\"0\",\"data\":{\"members\":[${membersJson}]}}")
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少组织ID参数\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PublicCompaniesController", "获取组织成员列表失败: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /// 将 Any 类型转换为 String
    private func anyToString(val: ?Any, default: String): String {
        match (val) {
            case Some(v) =>
                let strOpt = v as String
                if (let Some(s) <- strOpt) { return s }
                let intOpt = v as Int64
                if (let Some(i) <- intOpt) { return i.toString() }
                return default
            case None => return default
        }
    }
}
