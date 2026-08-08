/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class BaseVerification <: Verification {
    private var algorithm: Algorithm
    private var expectedChecks: ArrayList<ExpectedCheckHolder>
    private var defaultLeeway: Int64
    private var customLeeways: HashMap<String, Int64>
    private var ignoreIssuedAt1: Bool = false
    private var time: DateTime

    init(algorithm: Algorithm) {
        this.algorithm = algorithm
        this.expectedChecks = ArrayList()
        this.customLeeways = HashMap()
        this.defaultLeeway = 0
        this.time = DateTime.ofEpoch(second: 0, nanosecond: 0)
    }

    public func withAnyOfAudience(audience: Array<String>): Verification {
        let value: ArrayList<String> = ArrayList<String>(audience)
        return withAnyOfAudience(value)
    }

    public func withArrayClaim(name: String, items: Array<String>): Verification {
        let value: ArrayList<String> = ArrayList<String>(items)
        return withArrayClaim(name, value)
    }

    public func withAudience(audience: Array<String>): Verification {
        let value: ArrayList<String> = ArrayList<String>(audience)
        return withAudience(value)
    }

    public func withArrayClaim(name: String, items: Array<Int64>): Verification {
        let value: ArrayList<Int64> = ArrayList<Int64>(items)
        return withArrayClaim(name, value)
    }

    public func withIssuer(issuer: Array<String>): Verification {
        let value: ArrayList<String> = ArrayList<String>(issuer)

        let fun = {
            claim: Claim, _: DecodedJWT =>
            if (claim.isMissing()) {
                return false
            }
            try {
                let _: String = claim.asString()
            } catch (e: Exception) {
                return false
            }

            if (value.size == 0 || !value.contains(claim.asString())) {
                throw IncorrectClaimException(
                    "The Claim 'iss' value doesn't match the required issuer.",
                    RegisteredClaims.ISSUER,
                    claim
                )
            }
            return true
        }
        addCheck(RegisteredClaims.ISSUER, fun)
        return this
    }

    public func withIssuer(issuer: String): Verification {
        return withIssuer([issuer])
    }

    public func withSubject(subject: String): Verification {
        let fun = extractFun({claim: Claim => subject == claim.asString()})

        addCheck(RegisteredClaims.SUBJECT, fun)
        return this
    }

    public func withAudience(audience: ArrayList<String>): Verification {
        let value: ArrayList<String> = audience
        let fun = {
            claim: Claim, decodedJWT: DecodedJWT =>
            if (claim.isMissing()) {
                return false
            }

            if (!assertValidAudienceClaim(decodedJWT.getAudience(), value, true)) {
                throw IncorrectClaimException(
                    "The Claim 'aud' value doesn't contain the required audience.",
                    RegisteredClaims.AUDIENCE,
                    claim
                )
            }
            return true
        }

        addCheck(RegisteredClaims.AUDIENCE, fun)
        return this
    }

    public func withAnyOfAudience(audience: ArrayList<String>): Verification {
        let value: ArrayList<String> = audience

        let fun = {
            claim: Claim, decodedJWT: DecodedJWT =>
            if (claim.isMissing()) {
                return false
            }

            if (!assertValidAudienceClaim(decodedJWT.getAudience(), value, false)) {
                throw IncorrectClaimException(
                    "The Claim 'aud' value doesn't contain the required audience.",
                    RegisteredClaims.AUDIENCE,
                    claim
                )
            }
            return true
        }
        addCheck(RegisteredClaims.AUDIENCE, fun)
        return this
    }

    public func acceptLeeway(leeway: Int64): Verification {
        assertPositive(leeway)
        this.defaultLeeway = leeway
        return this
    }

    public func acceptExpiresAt(leeway: Int64): Verification {
        assertPositive(leeway)
        customLeeways.add(RegisteredClaims.EXPIRES_AT, leeway)
        return this
    }

    public func acceptNotBefore(leeway: Int64): Verification {
        assertPositive(leeway)
        customLeeways.add(RegisteredClaims.NOT_BEFORE, leeway)
        return this
    }

    public func acceptIssuedAt(leeway: Int64): Verification {
        assertPositive(leeway)
        customLeeways.add(RegisteredClaims.ISSUED_AT, leeway)
        return this
    }

    public func ignoreIssuedAt(): Verification {
        this.ignoreIssuedAt1 = true
        return this
    }

    public func withJWTId(jwtId: String): Verification {
        let fun = extractFun({claim: Claim => jwtId == claim.asString()})
        addCheck(RegisteredClaims.JWT_ID, fun)
        return this
    }

    public func withClaimPresence(name: String): Verification {
        //since addCheck already checks presence, we just return true
        let fun = {
            _: Claim, _: DecodedJWT => true
        }
        withClaim(name, fun)
        return this
    }

    public func withNullClaim(name: String): Verification {
        let fun = {claim: Claim, _: DecodedJWT => claim.isNull()}
        withClaim(name, fun)
        return this
    }

    public func withClaim(name: String, value: Bool): Verification {
        let fun = extractFun({claim: Claim => value == claim.asBool()})
        addCheck(name, fun)
        return this
    }

    func extractFun(fun: (Claim) -> Bool): (Claim, DecodedJWT) -> Bool {
        {
            claim: Claim, _: DecodedJWT =>
            if (claim.isMissing()) {
                return false
            }
            try {
                return fun(claim)
            } catch (e: Exception) {
                return false
            }
        }
    }

    public func withClaim(name: String, value: Int64): Verification {
        let fun = extractFun({claim: Claim => value == claim.asInt()})
        addCheck(name, fun)
        return this
    }

    public func withClaim(name: String, value: Float64): Verification {
        let fun = extractFun({claim: Claim => value == claim.asFloat()})
        addCheck(name, fun)
        return this
    }

    public func withClaim(name: String, value: String): Verification {
        // { a: Int64, b: Int64 => print(a-b);false }
        let fun = extractFun({claim: Claim => value == claim.asString()})
        addCheck(name, fun)
        return this
    }

    public func withClaim(name: String, value: DateTime): Verification { // 比较时间
        // Since date-time claims are serialized as epoch seconds,
        // we need to compare them with only seconds-granularity
        let fun = extractFun({claim: Claim => value == claim.asTime()})
        addCheck(name, fun)
        return this
    }

    public func withClaim(name: String, predicate: (Claim, DecodedJWT) -> Bool): Verification {
        // let fun = {claim: Claim, decodedJWT: DecodedJWT => predicate(claim, decodedJWT)}
        // addCheck(name, fun)
        expectedChecks.add(constructExpectedCheck(name, predicate))
        return this
    }

    public func withArrayClaim(name: String, items: ArrayList<String>): Verification {
        let fun = {claim: Claim, _: DecodedJWT => assertValidCollectionClaim(claim, items)}
        addCheck(name, fun)
        return this
    }

    public func withArrayClaim(name: String, items: ArrayList<Int64>): Verification {
        let fun = {claim: Claim, _: DecodedJWT => assertValidCollectionClaim(claim, items)}
        addCheck(name, fun)
        return this
    }

    public func build(): JWTVerifier {
        return this.build(DateTime.now())
    }

    private func build(time: DateTime): JWTVerifier {
        this.time = time
        addMandatoryClaimChecks()
        return BaseJWTVerifier(algorithm, expectedChecks)
    }

    private func getLeewayFor(name: String): Int64 {
        if (customLeeways.contains(name)) {
            return customLeeways.get(name).getOrThrow()
        } else {
            return defaultLeeway
        }
    }

    private func addMandatoryClaimChecks() {
        let expiresAtLeeway: Int64 = getLeewayFor(RegisteredClaims.EXPIRES_AT)
        let notBeforeLeeway: Int64 = getLeewayFor(RegisteredClaims.NOT_BEFORE)
        let issuedAtLeeway: Int64 = getLeewayFor(RegisteredClaims.ISSUED_AT)

        let fun = {
            claim: Claim, _: DecodedJWT => assertValidInstantClaim(
                RegisteredClaims.EXPIRES_AT,
                claim,
                expiresAtLeeway,
                true
            )
        }
        let fun1 = {
            claim: Claim, _: DecodedJWT => assertValidInstantClaim(
                RegisteredClaims.NOT_BEFORE,
                claim,
                notBeforeLeeway,
                false
            )
        }
        let fun2 = {
            claim: Claim, _: DecodedJWT => assertValidInstantClaim(
                RegisteredClaims.ISSUED_AT,
                claim,
                issuedAtLeeway,
                false
            )
        }

        expectedChecks.add(constructExpectedCheck(RegisteredClaims.EXPIRES_AT, fun))
        expectedChecks.add(constructExpectedCheck(RegisteredClaims.NOT_BEFORE, fun1))
        if (!ignoreIssuedAt1) {
            expectedChecks.add(constructExpectedCheck(RegisteredClaims.ISSUED_AT, fun2))
        }
    }

    private func assertValidCollectionClaim(claim: Claim, expectedClaimValue: ArrayList<String>): Bool {
        if (claim.isMissing()) {
            return false
        }
        let claimArr = asStringList(claim)
        for (pattern in expectedClaimValue) {
            if (!claimArr.contains(pattern)) {
                return false
            }
        }
        return true
    }

    private func assertValidCollectionClaim(claim: Claim, expectedClaimValue: ArrayList<Int64>): Bool {
        if (claim.isMissing()) {
            return false
        }
        let claimArrInt = asIntList(claim)
        for (pattern in expectedClaimValue) {
            if (!claimArrInt.contains(pattern)) {
                return false
            }
        }
        return true
    }

    private func assertValidInstantClaim(claimName: String, claim: Claim, leeway: Int64, shouldBeFuture: Bool): Bool {
        if (claim.isMissing()) {
            return true
        }

        var claimVal: DateTime = claim.asTime()
        var now: DateTime = time
        var isValid: Bool
        if (shouldBeFuture) {
            isValid = assertInstantIsFuture(claimVal, leeway, now)
            if (!isValid) {
                throw TokenExpiredException("The Token has expired on ${claimVal}.", claimVal)
            }
        } else {
            isValid = assertInstantIsPast(claimVal, leeway, now)
            print(isValid)
            if (!isValid) {
                throw IncorrectClaimException("The Token can't be used before ${claimVal}.", claimName, claim)
            }
        }
        return true
    }

    private func assertInstantIsFuture(claimVal: DateTime, leeway: Int64, now: DateTime): Bool {
        var between = Duration.second * leeway
        return !((now - between) > claimVal)
    }

    private func assertInstantIsPast(claimVal: DateTime, leeway: Int64, now: DateTime): Bool {
        var between = Duration.second * leeway
        return !((now + between) < claimVal)
    }

    private func assertValidAudienceClaim(
        audience: ArrayList<String>,
        values: ArrayList<String>,
        shouldContainAll: Bool
    ): Bool {
        var containsAll: Bool = true
        for (value in values) {
            if (!audience.contains(value)) {
                containsAll = false
                break
            }
        }

        var disjoint: Bool = true
        for (value in values) {
            if (audience.contains(value)) {
                disjoint = false
                break
            }
        }

        return !((shouldContainAll && !containsAll) || (!shouldContainAll && disjoint))
    }

    private func assertPositive(leeway: Int64) {
        if (leeway < 0) {
            throw IllegalArgumentException("Leeway value can't be negative.")
        }
    }

    private func addCheck(name: String, predicate: (Claim, DecodedJWT) -> Bool) {
        let fun = {
            claim: Claim, decodedJWT: DecodedJWT =>
            if (claim.isMissing()) {
                throw MissingClaimException(name)
            }
            return predicate(claim, decodedJWT)
        }
        expectedChecks.add(constructExpectedCheck(name, fun))
    }

    private func constructExpectedCheck(claimName: String, check: (Claim, DecodedJWT) -> Bool): ExpectedCheckHolder {
        return ExpectedCheckHolderImpl(claimName, check)
    }
}
