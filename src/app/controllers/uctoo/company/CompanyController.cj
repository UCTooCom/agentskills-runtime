/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.company

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.services.uctoo.UserHasCompanyService
import magic.app.models.uctoo.UserHasCompanyPO
// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.CompanyPO
import magic.app.services.uctoo.CompanyService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class CompanyController {
    private var service: CompanyService

    public init(service: CompanyService) {
        this.service = service
    }

    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let userIdStr = userId.getOrThrow() as String
            if (let Some(str) <- userIdStr) {
                if (str.isEmpty()) {
                    res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                    return
                }

                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let entity = mapToEntity(b)
                    let result = service.createWithPermission(entity, str)
                    if (result.success) {
                        if (result.data.isSome()) {
                            let data = result.data.getOrThrow()
                            res.status(200).json(data.toJson())
                        } else {
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建失败\"}")
                        }
                    } else {
                        let reason = result.reason ?? "创建失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let ids = b.get("ids")
                let id = b.get("id")

                let deletedAt = b.get("deleted_at")
                let isRestore = if (let Some(da) <- deletedAt) {
                    let daStr = da as String
                    if (let Some(s) <- daStr) {
                        s == "0"
                    } else {
                        false
                    }
                } else {
                    false
                }

                if (let Some(idsVal) <- ids) {
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        let idArray = parseIdsArray(idsStr)

                        if (isRestore) {
                            let result = service.restoreMultiple(idArray)
                            if (result.success) {
                                res.status(200).json("{\"desc\":\"恢复成功\"}")
                            } else {
                                let reason = result.reason ?? "批量恢复失败"
                                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                            }
                        } else {
                            let entities = ArrayList<CompanyPO>()
                            for (idStr in idArray) {
                                let entity = mapToEntity(b)
                                entity.id = idStr
                                entities.add(entity)
                            }

                            let result = service.updateMultiple(entities)
                            if (result.success) {
                                if (let Some(data) <- result.data) {
                                    let sb = StringBuilder()
                                    sb.append("[")
                                    let size = data.size
                                    for (i in 0..size) {
                                        sb.append(data[i].toJson())
                                        if (i < size - 1) {
                                            sb.append(",")
                                        }
                                    }
                                    sb.append("]")
                                    res.status(200).json(sb.toString())
                                } else {
                                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"批量更新失败\"}")
                                }
                            } else {
                                let reason = result.reason ?? "批量更新失败"
                                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                            }
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"IDs参数格式错误\"}")
                    }
                } else {
                    if (let Some(idVal) <- id) {
                        let idStrOpt = idVal as String
                        if (let Some(idStr) <- idStrOpt) {
                            if (isRestore) {
                                let result = service.restore(idStr)
                                if (result.success) {
                                    if (let Some(data) <- result.data) {
                                        res.status(200).json(data.toJson())
                                    } else {
                                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"恢复失败\"}")
                                    }
                                } else {
                                    let reason = result.reason ?? "恢复失败"
                                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                                }
                            } else {
                                let entity = mapToEntity(b)
                                let editUserId = req.getLocals("userId")
                                var editUserIdStr = ""
                                if (let Some(u) <- editUserId) {
                                    let sOpt = u as String
                                    if (let Some(s) <- sOpt) { editUserIdStr = s }
                                }
                                let result = if (editUserIdStr.isEmpty()) {
                                    service.update(idStr, entity)
                                } else {
                                    service.updateWithPermission(idStr, entity, editUserIdStr)
                                }
                                if (result.success) {
                                    if (let Some(data) <- result.data) {
                                        res.status(200).json(data.toJson())
                                    } else {
                                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"更新失败\"}")
                                    }
                                } else {
                                    let reason = result.reason ?? "更新失败"
                                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                                }
                            }
                        } else {
                            res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"ID参数格式错误\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
                    }
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let id = b.get("id")
                let ids = b.get("ids")
                let forceOpt = b.get("force")
                let force = parseForce(forceOpt)

                if (let Some(idsVal) <- ids) {
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        let idArray = parseIdsArray(idsStr)
                        let result = service.deleteMultiple(idArray, force)
                        if (result.success) {
                            res.status(200).json("{\"desc\":\"删除成功\"}")
                        } else {
                            let reason = result.reason ?? "批量删除失败"
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"IDs参数格式错误\"}")
                    }
                } else if (let Some(idVal) <- id) {
                    let idStrOpt = idVal as String
                    if (let Some(idStr) <- idStrOpt) {
                        let delUserId = req.getLocals("userId")
                        var delUserIdStr = ""
                        if (let Some(u) <- delUserId) {
                            let sOpt = u as String
                            if (let Some(s) <- sOpt) { delUserIdStr = s }
                        }
                        let result = if (delUserIdStr.isEmpty()) {
                            service.delete(idStr, force)
                        } else {
                            service.deleteWithPermission(idStr, force, delUserIdStr)
                        }
                        if (result.success) {
                            res.status(200).json("{\"desc\":\"删除成功\"}")
                        } else {
                            let reason = result.reason ?? "删除失败"
                            res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"ID参数格式错误\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")

            if (let Some(idVal) <- id) {
                let userId = req.getLocals("userId")
                var userIdStr = ""
                if (let Some(u) <- userId) {
                    let sOpt = u as String
                    if (let Some(s) <- sOpt) { userIdStr = s }
                }
                let result = if (userIdStr.isEmpty()) {
                    service.getById(idVal)
                } else {
                    service.getByIdWithPermission(idVal, userIdStr)
                }

                if (result.success) {
                    if (let Some(data) <- result.data) {
                        res.status(200).json(data.toJson())
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该company\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该company\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let currentPageParam = req.queryParam("currentPage")
            let pageSizeParam = req.queryParam("pageSize")

            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")

            let pageSize = if (let Some(ps) <- pageSizeParam) {
                Int32.parse(ps)
            } else if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }

            let currentPage = if (let Some(cp) <- currentPageParam) {
                Int32.parse(cp)
            } else if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }

            if (pageSize > 1000) {
                res.status(400).json(APIError("40004", "请求数量不能超过1000条").toJson())
                return
            }

            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")

            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            var filterStr = ""
            if (let Some(f) <- filterParam) {
                let decodedFilter = f.replace("%7B", "{")
                    .replace("%7D", "}")
                    .replace("%22", "\"")
                    .replace("%3A", ":")
                    .replace("%2C", ",")
                    .replace("+", " ")
                filterStr = decodedFilter
            }

            let userId = req.getLocals("userId")
            var userIdStr = ""
            if (let Some(u) <- userId) {
                let sOpt = u as String
                if (let Some(s) <- sOpt) { userIdStr = s }
            }

            let (entities, total) = if (userIdStr.isEmpty()) {
                service.getListWithFilter(
                    currentPage,
                    pageSize,
                    sortStr,
                    filterStr
                )
            } else {
                service.getListWithPermission(
                    currentPage,
                    pageSize,
                    sortStr,
                    filterStr,
                    userIdStr
                )
            }

            let totalPage = if (pageSize > 0) {
                Int32((total + Int64(pageSize) - 1) / Int64(pageSize))
            } else {
                Int32(0)
            }

            var entitiesJson = ""
            for (e in entities) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"companys\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func getManyWithSkip(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")
            let skipParam = req.pathParam("skip")

            let limitNum = if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }

            let pageNum = if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }

            let skipNum = if (let Some(s) <- skipParam) {
                Int32.parse(s)
            } else {
                Int32(0)
            }

            if (limitNum > 1000) {
                res.status(400).json(APIError("40004", "请求数量不能超过1000条").toJson())
                return
            }

            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")

            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            let filterStr = if (let Some(f) <- filterParam) { f } else { "" }

            let userId = req.getLocals("userId")
            var userIdStr = ""
            if (let Some(u) <- userId) {
                let sOpt = u as String
                if (let Some(s) <- sOpt) { userIdStr = s }
            }

            let (entities, total) = if (userIdStr.isEmpty()) {
                service.getListWithSkip(pageNum - 1, limitNum, skipNum, sortStr, filterStr)
            } else {
                service.getListWithSkipWithPermission(pageNum - 1, limitNum, skipNum, sortStr, filterStr, userIdStr)
            }

            let totalPage = if (limitNum > 0) {
                Int32((total + Int64(limitNum) - 1) / Int64(limitNum))
            } else {
                Int32(0)
            }

            var entitiesJson = ""
            for (e in entities) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"companys\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinCompany(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinCompany()
            if (result.success) {
                res.status(200).json("{\"desc\":\"清空回收站成功\"}")
            } else {
                let reason = result.reason ?? "清空回收站失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func parseBody(req: HttpRequest): ?Map<String, Any> {
        try {
            let body = req.body

            if (body.isEmpty()) {
                return None<Map<String, Any>>
            }

            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                return None<Map<String, Any>>
            }

            let jsonObj = jsonValue.asObject()
            let map = HashMap<String, Any>()

            for ((key, value) in jsonObj.getFields()) {
                let anyValue = jsonValueToAny(value)
                map.add(key, anyValue)
            }

            return Some<Map<String, Any>>(map)
        } catch (e: Exception) {
            return None<Map<String, Any>>
        }
    }

    private func jsonValueToAny(value: JsonValue): Any {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue()
        } else if (value is JsonFloat) {
            return value.asFloat().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else {
            return ""
        }
    }

    private func mapToEntity(map: Map<String, Any>): CompanyPO {
        let entity = CompanyPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(companyName) <- map.get("company_name")) {
            let companyNameStr = companyName as String
            if (let Some(s) <- companyNameStr) {
                entity.companyName = s
            }
        }
        if (let Some(region) <- map.get("region")) {
            let regionStr = region as String
            if (let Some(s) <- regionStr) {
                entity.region = s
            }
        }
        if (let Some(socialCreditCode) <- map.get("social_credit_code")) {
            let socialCreditCodeStr = socialCreditCode as String
            if (let Some(s) <- socialCreditCodeStr) {
                entity.socialCreditCode = s
            }
        }
        if (let Some(establishedTime) <- map.get("established_time")) {
            let establishedTimeStr = establishedTime as String
            if (let Some(s) <- establishedTimeStr) {
                entity.establishedTime = s
            }
        }
        if (let Some(registeredCapital) <- map.get("registered_capital")) {
            let registeredCapitalStr = registeredCapital as String
            if (let Some(s) <- registeredCapitalStr) {
                entity.registeredCapital = s
            }
        }
        if (let Some(registeredAddress) <- map.get("registered_address")) {
            let registeredAddressStr = registeredAddress as String
            if (let Some(s) <- registeredAddressStr) {
                entity.registeredAddress = s
            }
        }
        if (let Some(mailingAddress) <- map.get("mailing_address")) {
            let mailingAddressStr = mailingAddress as String
            if (let Some(s) <- mailingAddressStr) {
                entity.mailingAddress = s
            }
        }
        if (let Some(legalRepresentative) <- map.get("legal_representative")) {
            let legalRepresentativeStr = legalRepresentative as String
            if (let Some(s) <- legalRepresentativeStr) {
                entity.legalRepresentative = s
            }
        }
        if (let Some(legalRepresentativemobile) <- map.get("legal_representativeMobile")) {
            let legalRepresentativemobileStr = legalRepresentativemobile as String
            if (let Some(s) <- legalRepresentativemobileStr) {
                entity.legalRepresentativemobile = s
            }
        }
        if (let Some(legalRepresentativeEmail) <- map.get("legal_representative_email")) {
            let legalRepresentativeEmailStr = legalRepresentativeEmail as String
            if (let Some(s) <- legalRepresentativeEmailStr) {
                entity.legalRepresentativeEmail = s
            }
        }
        if (let Some(contactName) <- map.get("contact_name")) {
            let contactNameStr = contactName as String
            if (let Some(s) <- contactNameStr) {
                entity.contactName = s
            }
        }
        if (let Some(contactMobile) <- map.get("contact_mobile")) {
            let contactMobileStr = contactMobile as String
            if (let Some(s) <- contactMobileStr) {
                entity.contactMobile = s
            }
        }
        if (let Some(contactEmail) <- map.get("contact_email")) {
            let contactEmailStr = contactEmail as String
            if (let Some(s) <- contactEmailStr) {
                entity.contactEmail = s
            }
        }
        if (let Some(contactTitle) <- map.get("contact_title")) {
            let contactTitleStr = contactTitle as String
            if (let Some(s) <- contactTitleStr) {
                entity.contactTitle = s
            }
        }
        if (let Some(website) <- map.get("website")) {
            let websiteStr = website as String
            if (let Some(s) <- websiteStr) {
                entity.website = s
            }
        }
        if (let Some(companyLogo) <- map.get("company_logo")) {
            let companyLogoStr = companyLogo as String
            if (let Some(s) <- companyLogoStr) {
                entity.companyLogo = Some<String>(s)
            }
        }
        if (let Some(associatedProjectManager) <- map.get("associated_project_manager")) {
            let associatedProjectManagerStr = associatedProjectManager as String
            if (let Some(s) <- associatedProjectManagerStr) {
                entity.associatedProjectManager = Some<String>(s)
            }
        }
        if (let Some(verified) <- map.get("verified")) {
            let verifiedInt = verified as Int64
            if (let Some(v) <- verifiedInt) {
                entity.verified = Int32(v)
            }
        }
        if (let Some(companyIntroduction) <- map.get("company_introduction")) {
            let companyIntroductionStr = companyIntroduction as String
            if (let Some(s) <- companyIntroductionStr) {
                entity.companyIntroduction = s
            }
        }
        if (let Some(businessLicence) <- map.get("business_licence")) {
            let businessLicenceStr = businessLicence as String
            if (let Some(s) <- businessLicenceStr) {
                entity.businessLicence = s
            }
        }
        if (let Some(creator) <- map.get("creator")) {
            let creatorStr = creator as String
            if (let Some(s) <- creatorStr) {
                entity.creator = Some<String>(s)
            }
        }
        if (let Some(createdAt) <- map.get("created_at")) {
        }
        if (let Some(updatedAt) <- map.get("updated_at")) {
        }
        if (let Some(deletedAt) <- map.get("deleted_at")) {
            // DateTime类型, 由数据库处理
        }
        if (let Some(orgDescription) <- map.get("org_description")) {
            let orgDescriptionStr = orgDescription as String
            if (let Some(s) <- orgDescriptionStr) {
                entity.orgDescription = Some<String>(s)
            }
        }
        if (let Some(memberCount) <- map.get("member_count")) {
            let memberCountInt = memberCount as Int64
            if (let Some(v) <- memberCountInt) {
                entity.memberCount = Some<Int32>(Int32(v))
            }
        }
        if (let Some(taskCount) <- map.get("task_count")) {
            let taskCountInt = taskCount as Int64
            if (let Some(v) <- taskCountInt) {
                entity.taskCount = Some<Int32>(Int32(v))
            }
        }
        if (let Some(followerCount) <- map.get("follower_count")) {
            let followerCountInt = followerCount as Int64
            if (let Some(v) <- followerCountInt) {
                entity.followerCount = Some<Int32>(Int32(v))
            }
        }
        if (let Some(isVerified) <- map.get("is_verified")) {
            let isVerifiedBool = isVerified as Bool
            if (let Some(v) <- isVerifiedBool) {
                entity.isVerified = Some<Bool>(v)
            }
        }
        if (let Some(orgType) <- map.get("org_type")) {
            let orgTypeStr = orgType as String
            if (let Some(s) <- orgTypeStr) {
                entity.orgType = Some<String>(s)
            }
        }
        if (let Some(tags) <- map.get("tags")) {
            let tagsStr = tags as String
            if (let Some(s) <- tagsStr) {
                entity.tags = Some<String>(s)
            }
        }
        if (let Some(pointsBalance) <- map.get("points_balance")) {
            let pointsBalanceInt = pointsBalance as Int64
            if (let Some(v) <- pointsBalanceInt) {
                entity.pointsBalance = v
            }
        }
        return entity
    }


    private func parseForce(forceOpt: ?Any): Bool {
        if (let Some(f) <- forceOpt) {
            let fInt64 = f as Int64
            if (let Some(v) <- fInt64) {
                v == 1
            } else {
                let fInt32 = f as Int32
                if (let Some(v) <- fInt32) {
                    v == 1
                } else {
                    let fStr = f as String
                    if (let Some(s) <- fStr) {
                        s == "true" || s == "1"
                    } else {
                        false
                    }
                }
            }
        } else {
            false
        }
    }

    private func parseIdsArray(idsStr: String): ArrayList<String> {
        let idArray = ArrayList<String>()
        if (idsStr.isEmpty()) {
            return idArray
        }
        try {
            let jsonValue = JsonValue.fromStr(idsStr)
            if (jsonValue is JsonArray) {
                let arr = jsonValue.asArray()
                for (item in arr.getItems()) {
                    if (item is JsonString) {
                        let jsonStr = item.asString()
                        let val = jsonStr.getValue()
                        if (!val.isEmpty()) {
                            idArray.add(val)
                        }
                    } else if (item is JsonObject) {
                        let obj = item.asObject()
                        if (let Some(idsObj) <- obj.get("ids")) {
                            if (idsObj is JsonArray) {
                                let idsArr = idsObj.asArray()
                                for (subItem in idsArr.getItems()) {
                                    if (subItem is JsonString) {
                                        let jsonStr = subItem.asString()
                                        let val = jsonStr.getValue()
                                        if (!val.isEmpty()) {
                                            idArray.add(val)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if (jsonValue is JsonObject) {
                let obj = jsonValue.asObject()
                if (let Some(idsVal) <- obj.get("ids")) {
                    if (idsVal is JsonArray) {
                        let idsArr = idsVal.asArray()
                        for (item in idsArr.getItems()) {
                            if (item is JsonString) {
                                let jsonStr = item.asString()
                                let val = jsonStr.getValue()
                                if (!val.isEmpty()) {
                                    idArray.add(val)
                                }
                            }
                        }
                    } else if (idsVal is JsonString) {
                        let jsonStr = idsVal.asString()
                        let val = jsonStr.getValue()
                        if (!val.isEmpty()) {
                            idArray.add(val)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            let parts = idsStr.split(",")
            for (part in parts) {
                let trimmed = part.trimAscii()
                if (!trimmed.isEmpty() && trimmed != "[" && trimmed != "]" && trimmed != "{" && trimmed != "}") {
                    idArray.add(trimmed)
                }
            }
        }
        return idArray
    }

    private func parseLimit(limit: ?String): Int32 {
        if (let Some(l) <- limit) {
            Int32.parse(l)
        } else {
            10
        }
    }

    private func parsePage(page: ?String): Int32 {
        if (let Some(p) <- page) {
            Int32.parse(p)
        } else {
            1
        }
    }

    public func export(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取所有company数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,company_name,region,social_credit_code,established_time,registered_capital,registered_address,mailing_address,legal_representative,legal_representativeMobile,legal_representative_email,contact_name,contact_mobile,contact_email,contact_title,website,company_logo,associated_project_manager,verified,company_introduction,business_licence,creator,created_at,updated_at,deleted_at,org_description,member_count,task_count,follower_count,is_verified,org_type,tags,points_balance\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.companyName}" + ",")
                sb.append("\"" + "${entity.region}" + ",")
                sb.append("\"" + "${entity.socialCreditCode}" + ",")
                sb.append("\"" + "${entity.establishedTime}" + ",")
                sb.append("\"" + "${entity.registeredCapital}" + ",")
                sb.append("\"" + "${entity.registeredAddress}" + ",")
                sb.append("\"" + "${entity.mailingAddress}" + ",")
                sb.append("\"" + "${entity.legalRepresentative}" + ",")
                sb.append("\"" + "${entity.legalRepresentativemobile}" + ",")
                sb.append("\"" + "${entity.legalRepresentativeEmail}" + ",")
                sb.append("\"" + "${entity.contactName}" + ",")
                sb.append("\"" + "${entity.contactMobile}" + ",")
                sb.append("\"" + "${entity.contactEmail}" + ",")
                sb.append("\"" + "${entity.contactTitle}" + ",")
                sb.append("\"" + "${entity.website}" + ",")
                sb.append(if (let Some(v) <- entity.companyLogo) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.associatedProjectManager) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.verified}")
                sb.append(",")
                sb.append("\"" + "${entity.companyIntroduction}" + ",")
                sb.append("\"" + "${entity.businessLicence}" + ",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.orgDescription) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.memberCount) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.taskCount) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.followerCount) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.isVerified) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.orgType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.tags) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.pointsBalance}")
                sb.append(",")
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=company_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode

    // ==================== 定制接口 ====================

    /**
     * 切换关注状态（关注/取消关注组织）
     * POST /api/v1/uctoo/company/:id/toggle-follow
     */
    public func toggleFollow(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let userIdStr = (userId.getOrThrow() as String).getOrThrow()
            let companyId = req.pathParam("id") ?? ""
            if (companyId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少组织ID\"}")
                return
            }
            let userHasCompanyService = UserHasCompanyService()
            // 检查当前是否已关注
            if (userHasCompanyService.isMember(userIdStr, companyId)) {
                // 已是成员或已关注，尝试取消关注
                let result = userHasCompanyService.unfollowCompany(companyId, userIdStr)
                if (result.success) {
                    res.status(200).json("{\"errno\":\"0\",\"data\":{\"following\":false}}")
                } else {
                    let reason = result.reason ?? "取消关注失败"
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                }
            } else {
                // 未关注，执行关注
                let result = userHasCompanyService.followCompany(companyId, userIdStr)
                if (result.success) {
                    res.status(200).json("{\"errno\":\"0\",\"data\":{\"following\":true}}")
                } else {
                    let reason = result.reason ?? "关注失败"
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                }
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 加入组织
     * POST /api/v1/uctoo/company/:id/join
     */
    public func joinCompany(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let userIdStr = (userId.getOrThrow() as String).getOrThrow()
            let companyId = req.pathParam("id") ?? ""
            if (companyId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少组织ID\"}")
                return
            }
            // 从请求体读取可选的 role 参数
            var role = ""
            let body = parseBody(req)
            if (let Some(b) <- body) {
                if (let Some(roleVal) <- b.get("role")) {
                    let roleStrOpt = roleVal as String
                    if (let Some(s) <- roleStrOpt) { role = s }
                }
            }
            let userHasCompanyService = UserHasCompanyService()
            let result = userHasCompanyService.joinCompany(companyId, userIdStr, role)
            if (result.success) {
                if (let Some(data) <- result.data) {
                    res.status(200).json("{\"errno\":\"0\",\"data\":{\"relationId\":\"${data}\"}}")
                } else {
                    res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"加入成功\"}")
                }
            } else {
                let reason = result.reason ?? "加入失败"
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 离开组织
     * POST /api/v1/uctoo/company/:id/leave
     */
    public func leaveCompany(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let userIdStr = (userId.getOrThrow() as String).getOrThrow()
            let companyId = req.pathParam("id") ?? ""
            if (companyId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少组织ID\"}")
                return
            }
            let userHasCompanyService = UserHasCompanyService()
            let result = userHasCompanyService.leaveCompany(companyId, userIdStr)
            if (result.success) {
                res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"已离开组织\"}")
            } else {
                let reason = result.reason ?? "离开组织失败"
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 获取我加入的组织列表
     * GET /api/v1/uctoo/company/my/:limit/:page?role=member
     */
    public func getMyCompanies(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let userIdStr = (userId.getOrThrow() as String).getOrThrow()

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

            let role = req.queryParam("role") ?? "member"
            let sortParam = req.queryParam("sort") ?? ""
            let filterParam = req.queryParam("filter") ?? ""

            let (list, total) = service.getMyCompaniesWithFilter(
                userIdStr,
                role,
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
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
}
