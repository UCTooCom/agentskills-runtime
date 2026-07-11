/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.uctoo

//#region AutoCreateCode

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_data.macros.DataAssist
import f_data.{ObjectData, Data, DataConversionFlag, ObjectFields, MutableField, DataObject, f_data_tryFromData}
import f_orm.*
import json4cj.JsonValueSerializable
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}

/**
 * CompanyPO - company表持久化对象
 * 
 * 对应数据库表: company
 * 遵循UCTOO V4 ORM规范
 */
@DataAssist[fields]
@QueryMappersGenerator["company"]
public class CompanyPO {
        @ORMField['id']
    public var id: String = ""

        @ORMField['company_name']
    public var companyName: String = ""

        @ORMField['region']
    public var region: String = ""

        @ORMField['social_credit_code']
    public var socialCreditCode: String = ""

        @ORMField['established_time']
    public var establishedTime: String = ""

        @ORMField['registered_capital']
    public var registeredCapital: String = ""

        @ORMField['registered_address']
    public var registeredAddress: String = ""

        @ORMField['mailing_address']
    public var mailingAddress: String = ""

        @ORMField['legal_representative']
    public var legalRepresentative: String = ""

        @ORMField['legal_representativemobile']
    public var legalRepresentativemobile: String = ""

        @ORMField['legal_representative_email']
    public var legalRepresentativeEmail: String = ""

        @ORMField['contact_name']
    public var contactName: String = ""

        @ORMField['contact_mobile']
    public var contactMobile: String = ""

        @ORMField['contact_email']
    public var contactEmail: String = ""

        @ORMField['contact_title']
    public var contactTitle: String = ""

        @ORMField['website']
    public var website: String = ""

        @ORMField['company_logo']
    public var companyLogo: Option<String> = None<String>

        @ORMField['associated_project_manager']
    public var associatedProjectManager: Option<String> = None<String>

        @ORMField['verified']
    public var verified: Int32 = 0

        @ORMField['company_introduction']
    public var companyIntroduction: String = ""

        @ORMField['business_licence']
    public var businessLicence: String = ""

        @ORMField['creator']
    public var creator: Option<String> = None<String>

        @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

        @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

        @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

        @ORMField['org_description']
    public var orgDescription: Option<String> = None<String>

        @ORMField['member_count']
    public var memberCount: Option<Int32> = None<Int32>

        @ORMField['task_count']
    public var taskCount: Option<Int32> = None<Int32>

        @ORMField['follower_count']
    public var followerCount: Option<Int32> = None<Int32>

        @ORMField['is_verified']
    public var isVerified: Option<Bool> = None<Bool>

        @ORMField['org_type']
    public var orgType: Option<String> = None<String>

        @ORMField['tags']
    public var tags: Option<String> = None<String>

        @ORMField['points_balance']
    public var pointsBalance: Int64 = 0

    public init() {}

    public init(
                id: String,
                companyName: String,
                region: String,
                socialCreditCode: String,
                establishedTime: String,
                registeredCapital: String,
                registeredAddress: String,
                mailingAddress: String,
                legalRepresentative: String,
                legalRepresentativemobile: String,
                legalRepresentativeEmail: String,
                contactName: String,
                contactMobile: String,
                contactEmail: String,
                contactTitle: String,
                website: String,
                companyLogo: Option<String>,
                associatedProjectManager: Option<String>,
                verified: Int32,
                companyIntroduction: String,
                businessLicence: String,
                creator: Option<String>,
                createdAt: DateTime,
                updatedAt: DateTime,
                deletedAt: Option<DateTime>,
                orgDescription: Option<String>,
                memberCount: Option<Int32>,
                taskCount: Option<Int32>,
                followerCount: Option<Int32>,
                isVerified: Option<Bool>,
                orgType: Option<String>,
                tags: Option<String>,
                pointsBalance: Int64
    ) {
                this.id = id
                this.companyName = companyName
                this.region = region
                this.socialCreditCode = socialCreditCode
                this.establishedTime = establishedTime
                this.registeredCapital = registeredCapital
                this.registeredAddress = registeredAddress
                this.mailingAddress = mailingAddress
                this.legalRepresentative = legalRepresentative
                this.legalRepresentativemobile = legalRepresentativemobile
                this.legalRepresentativeEmail = legalRepresentativeEmail
                this.contactName = contactName
                this.contactMobile = contactMobile
                this.contactEmail = contactEmail
                this.contactTitle = contactTitle
                this.website = website
                this.companyLogo = companyLogo
                this.associatedProjectManager = associatedProjectManager
                this.verified = verified
                this.companyIntroduction = companyIntroduction
                this.businessLicence = businessLicence
                this.creator = creator
                this.createdAt = createdAt
                this.updatedAt = updatedAt
                this.deletedAt = deletedAt
                this.orgDescription = orgDescription
                this.memberCount = memberCount
                this.taskCount = taskCount
                this.followerCount = followerCount
                this.isVerified = isVerified
                this.orgType = orgType
                this.tags = tags
                this.pointsBalance = pointsBalance
    }

    /// 序列化为 JsonValue
    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", this.id.toJsonValue())
        map.add("company_name", this.companyName.toJsonValue())
        map.add("region", this.region.toJsonValue())
        map.add("social_credit_code", this.socialCreditCode.toJsonValue())
        map.add("established_time", this.establishedTime.toJsonValue())
        map.add("registered_capital", this.registeredCapital.toJsonValue())
        map.add("registered_address", this.registeredAddress.toJsonValue())
        map.add("mailing_address", this.mailingAddress.toJsonValue())
        map.add("legal_representative", this.legalRepresentative.toJsonValue())
        map.add("legal_representativeMobile", this.legalRepresentativemobile.toJsonValue())
        map.add("legal_representative_email", this.legalRepresentativeEmail.toJsonValue())
        map.add("contact_name", this.contactName.toJsonValue())
        map.add("contact_mobile", this.contactMobile.toJsonValue())
        map.add("contact_email", this.contactEmail.toJsonValue())
        map.add("contact_title", this.contactTitle.toJsonValue())
        map.add("website", this.website.toJsonValue())
        map.add("company_logo", optionToJsonValue(this.companyLogo))
        map.add("associated_project_manager", optionToJsonValue(this.associatedProjectManager))
        map.add("verified", this.verified.toJsonValue())
        map.add("company_introduction", this.companyIntroduction.toJsonValue())
        map.add("business_licence", this.businessLicence.toJsonValue())
        map.add("creator", optionToJsonValue(this.creator))
        map.add("created_at", this.createdAt.toJsonValue())
        map.add("updated_at", this.updatedAt.toJsonValue())
        map.add("deleted_at", optionToJsonValue(this.deletedAt))
        map.add("org_description", optionToJsonValue(this.orgDescription))
        map.add("member_count", optionToJsonValue(this.memberCount))
        map.add("task_count", optionToJsonValue(this.taskCount))
        map.add("follower_count", optionToJsonValue(this.followerCount))
        map.add("is_verified", optionToJsonValue(this.isVerified))
        map.add("org_type", optionToJsonValue(this.orgType))
        map.add("tags", optionToJsonValue(this.tags))
        map.add("points_balance", this.pointsBalance.toJsonValue())
        return JsonObject(map)
    }

    /// 辅助方法：将 Option<T> 转换为 JsonValue
    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }

    /// 序列化为 JSON 字符串
    public func toJson(): String {
        return this.toJsonValue().toString()
    }

//#endregion AutoCreateCode
}
