package magic.app.services.aip

import std.collection.*
import magic.log.LogUtils

public class AicValidator {
    public static func validate(aic: String): AicValidationResult {
        if (aic.isEmpty()) {
            return AicValidationResult.error("AIC不能为空")
        }

        let parts = aic.split(".")
        if (parts.size < 6) {
            return AicValidationResult.error("AIC格式错误：段数不足，至少需要6段（GB/Z 185.2 OID格式）")
        }

        let oidPrefix = parts[0]
        if (oidPrefix != "1") {
            return AicValidationResult.error("AIC格式错误：OID前缀必须为1(ISO)")
        }

        let countryPart = parts[1]
        if (countryPart != "2") {
            return AicValidationResult.error("AIC格式错误：国家代码必须为2(中国)")
        }

        var memberBody = ""
        if (parts.size > 2) { memberBody = parts[2] }
        if (memberBody.isEmpty()) {
            return AicValidationResult.error("AIC格式错误：成员体标识为空")
        }

        var registrationServiceProvider = ""
        if (parts.size > 3) { registrationServiceProvider = parts[3] }
        if (registrationServiceProvider.isEmpty()) {
            return AicValidationResult.error("AIC格式错误：注册服务提供者标识为空")
        }

        var registrationRequester = ""
        if (parts.size > 4) { registrationRequester = parts[4] }
        if (registrationRequester.isEmpty()) {
            return AicValidationResult.error("AIC格式错误：注册请求者标识为空")
        }

        var ontologySerial = ""
        if (parts.size > 5) { ontologySerial = parts[5] }
        if (ontologySerial.isEmpty()) {
            return AicValidationResult.error("AIC格式错误：本体序列号为空")
        }

        var instanceSerial = "0"
        if (parts.size > 6) { instanceSerial = parts[6] }

        return AicValidationResult.success(
            oidPrefix: oidPrefix,
            country: countryPart,
            memberBody: memberBody,
            registrationServiceProvider: registrationServiceProvider,
            registrationRequester: registrationRequester,
            ontologySerial: ontologySerial,
            instanceSerial: instanceSerial
        )
    }

    public static func parseAic(aic: String): Option<AicParsedInfo> {
        let result = validate(aic)
        if (!result.valid) {
            return None<AicParsedInfo>
        }

        let info = AicParsedInfo(
            aic: aic,
            oidPrefix: result.oidPrefix,
            country: result.country,
            memberBody: result.memberBody,
            registrationServiceProvider: result.registrationServiceProvider,
            registrationRequester: result.registrationRequester,
            ontologySerial: result.ontologySerial,
            instanceSerial: result.instanceSerial
        )
        return Some<AicParsedInfo>(info)
    }
}

public class AicValidationResult {
    public var valid: Bool = false
    public var errorMsg: String = ""
    public var oidPrefix: String = ""
    public var country: String = ""
    public var memberBody: String = ""
    public var registrationServiceProvider: String = ""
    public var registrationRequester: String = ""
    public var ontologySerial: String = ""
    public var instanceSerial: String = ""

    public init() {}

    public static func error(msg: String): AicValidationResult {
        let r = AicValidationResult()
        r.valid = false
        r.errorMsg = msg
        return r
    }

    public static func success(oidPrefix!: String, country!: String, memberBody!: String,
        registrationServiceProvider!: String, registrationRequester!: String,
        ontologySerial!: String, instanceSerial!: String): AicValidationResult {
        let r = AicValidationResult()
        r.valid = true
        r.oidPrefix = oidPrefix
        r.country = country
        r.memberBody = memberBody
        r.registrationServiceProvider = registrationServiceProvider
        r.registrationRequester = registrationRequester
        r.ontologySerial = ontologySerial
        r.instanceSerial = instanceSerial
        return r
    }
}

public class AicParsedInfo {
    public var aic: String = ""
    public var oidPrefix: String = ""
    public var country: String = ""
    public var memberBody: String = ""
    public var registrationServiceProvider: String = ""
    public var registrationRequester: String = ""
    public var ontologySerial: String = ""
    public var instanceSerial: String = ""

    public init(aic!: String, oidPrefix!: String, country!: String, memberBody!: String,
        registrationServiceProvider!: String, registrationRequester!: String,
        ontologySerial!: String, instanceSerial!: String) {
        this.aic = aic
        this.oidPrefix = oidPrefix
        this.country = country
        this.memberBody = memberBody
        this.registrationServiceProvider = registrationServiceProvider
        this.registrationRequester = registrationRequester
        this.ontologySerial = ontologySerial
        this.instanceSerial = instanceSerial
    }
}