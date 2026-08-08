/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

class JWTCreator {
    private let algorithm: Algorithm
    private let headerJson: String
    private let payloadJson: String

    protected init(algorithm: Algorithm, headerClaims: Map<String, Any>, payloadClaims: Map<String, Any>) {
        this.algorithm = algorithm
        this.headerJson = HeaderSerializer().serialize(HeaderClaimsHolder(headerClaims))
        this.payloadJson = PayloadSerializer().serialize(PayloadClaimsHolder(payloadClaims))
    }

    protected func sign(): String {
        let headerB64 = Base64Util.urlEncode(headerJson)
        let payloadB64 = Base64Util.urlEncode(payloadJson)

        let signatureBytes = algorithm.sign("${headerB64}.${payloadB64}".toArray())
        let signature = Base64Util.urlEncode(signatureBytes)

        return "${headerB64}.${payloadB64}.${signature}"
    }

    static func builder(): Builder {
        Builder()
    }
}

public class Builder {
    private let payloadClaims: Map<String, Any>
    private let headerClaims: Map<String, Any>

    Builder() {
        this.payloadClaims = HashMap<String, Any>()
        this.headerClaims = HashMap<String, Any>()
    }

    /*
     * Add specific Claims to set as the Header.
     * If provided map is null then nothing is changed
     *
     * @param headerClaims the values to use as Claims in the token's Header.
     * @return this same Builder instance.
     */
    public func withHeader(headerClaims: Map<String, Any>): Builder {
        for ((key, value) in headerClaims) {
            this.headerClaims.add(key, value)
        }
        return this
    }

    /*
     * Add a specific Key Id ("kid") claim to the Header.
     * If the {@link Algorithm} used to sign this token was instantiated with a KeyProvider,
     * the 'kid' value will be taken from that provider and this one will be ignored.
     *
     * @param keyId the Key Id value.
     * @return this same Builder instance.
     */
    public func withKeyId(keyId: String): Builder {
        this.headerClaims.add(HeaderParams.KEY_ID, keyId)
        return this
    }

    /*
     * Add a specific Issuer ("iss") claim to the Payload.
     *
     * @param issuer the Issuer value.
     * @return this same Builder instance.
     */
    public func withIssuer(issuer: String): Builder {
        addClaim(RegisteredClaims.ISSUER, issuer)
        return this
    }

    /*
     * Add a specific Subject ("sub") claim to the Payload.
     *
     * @param subject the Subject value.
     * @return this same Builder instance.
     */
    public func withSubject(subject: String): Builder {
        addClaim(RegisteredClaims.SUBJECT, subject)
        return this
    }

    /*
     * Add a specific Audience ("aud") claim to the Payload.
     *
     * @param audience the Audience value.
     * @return this same Builder instance.
     */
    public func withAudience(audience: Array<String>): Builder {
        addClaim(RegisteredClaims.AUDIENCE, audience)
        return this
    }

    /*
     * Add a specific Expires At ("exp") claim to the payload. The claim will be written as seconds since the epoch.
     * Milliseconds will be truncated by rounding down to the nearest second.
     *
     * @param expiresAt the Expires At value.
     * @return this same Builder instance.
     */
    public func withExpiresAt(expiresAt: DateTime): Builder {
        addClaim(RegisteredClaims.EXPIRES_AT, expiresAt)
        return this
    }

    /*
     * Add a specific Not Before ("nbf") claim to the Payload. The claim will be written as seconds since the epoch:
     * Milliseconds will be truncated by rounding down to the nearest second.
     *
     * @param notBefore the Not Before value.
     * @return this same Builder instance.
     */
    public func withNotBefore(notBefore: DateTime): Builder {
        addClaim(RegisteredClaims.NOT_BEFORE, notBefore)
        return this
    }

    /*
     * Add a specific Issued At ("iat") claim to the Payload. The claim will be written as seconds since the epoch:
     * Milliseconds will be truncated by rounding down to the nearest second.
     *
     * @param issuedAt the Issued At value.
     * @return this same Builder instance.
     */
    public func withIssuedAt(issuedAt: DateTime): Builder {
        addClaim(RegisteredClaims.ISSUED_AT, issuedAt)
        return this
    }

    /*
     * Add a specific JWT Id ("jti") claim to the Payload.
     *
     * @param jwtId the Token Id value.
     * @return this same Builder instance.
     */
    public func withJWTId(jwtId: String): Builder {
        addClaim(RegisteredClaims.JWT_ID, jwtId)
        return this
    }

    /*
     * Add a custom Claim value.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Builder instance.
     */
    public func withClaim(name: String, value: Bool): Builder {
        addClaim(name, value)
        return this
    }

    /*
     * Add a custom Claim value.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Builder instance.
     */
    public func withClaim(name: String, value: Int64): Builder {
        addClaim(name, value)
        return this
    }

    /*
     * Add a custom Claim value.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Builder instance.
     */
    public func withClaim(name: String, value: Float64): Builder {
        addClaim(name, value)
        return this
    }

    /*
     * Add a custom Claim value.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Builder instance.
     */
    public func withClaim(name: String, value: String): Builder {
        addClaim(name, value)
        return this
    }

    /*
     * Add a custom Claim value. The claim will be written as seconds since the epoch.
     * Milliseconds will be truncated by rounding down to the nearest second.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Builder instance.
     */
    public func withClaim(name: String, value: DateTime): Builder {
        addClaim(name, value)
        return this
    }

    /*
     * Add a custom Map Claim with the given items.
     *
     * Accepted nested types are Map and List with basic types
     * Bool, Int64, Float64,
     * String and Time. Maps cannot contain null keys or values.
     * Lists can contain null elements.
     *
     * @param name the Claim's name.
     * @param map  the Claim's key-values.
     * @return this same Builder instance.
     * @throws IllegalArgumentException if the map contents does not validate.
     */
    public func withClaim(name: String, map: Map<String, Any>): Builder {
        // validate map contents
        if (!validateClaim(map)) {
            throw IllegalArgumentException("Expected map containing Map, List, Bool, Int64, Float64, String and Time")
        }
        addClaim(name, map)
        return this
    }

    /*
     * Add a custom List Claim with the given items.
     *
     * Accepted nested types are Map and List with basic types
     * Bool, Int64, Float64,
     * String and Time. Maps cannot contain null keys or values.
     * Lists can contain null elements.
     *
     * @param name the Claim's name.
     * @param list the Claim's list of values.
     * @return this same Builder instance.
     * @throws IllegalArgumentException if the list contents does not validate.
     */
    public func withClaim(name: String, list: ArrayList<Any>): Builder {
        // validate list contents
        if (!validateClaim(list)) {
            throw IllegalArgumentException("Expected list containing Map, List, Bool, Int64, Float64, String and Time")
        }
        addClaim(name, list)
        return this
    }

    public func withClaim(name: String, obj: NodeType): Builder {
        addClaim(name, obj)
        return this
    }

    /*
     * Add a custom claim with null value.
     *
     * @param name the Claim's name.
     * @return this same Builder instance.
     */
    public func withNullClaim(name: String): Builder {
        addClaim(name, NULL_NODE)
        return this
    }

    /*
     * Add a custom Array Claim with the given items.
     *
     * @param name  the Claim's name.
     * @param items the Claim's value.
     * @return this same Builder instance.
     */
    public func withArrayClaim(name: String, items: Array<String>): Builder {
        addClaim(name, items)
        return this
    }

    /*
     * Add a custom Array Claim with the given items.
     *
     * @param name  the Claim's name.
     * @param items the Claim's value.
     * @return this same Builder instance.
     */
    public func withArrayClaim(name: String, items: Array<Int64>): Builder {
        addClaim(name, items)
        return this
    }

    /*
     * Add specific Claims to set as the Payload. If the provided map is null then
     * nothing is changed.
     *
     * Accepted types are Map and List with basic types
     * Bool, Int64, Float64,
     * String and Time.
     * Maps and Lists can contain null elements.
     *
     * If any of the claims are invalid, none will be added.
     *
     * @param payloadClaims the values to use as Claims in the token's payload.
     * @return this same Builder instance.
     * @throws IllegalArgumentException if any of the claim keys or null,
     * or if the values are not of a supported type.
     */
    public func withPayload(payloadClaims: Map<String, Any>): Builder {
        if (!validatePayload(payloadClaims)) {
            throw IllegalArgumentException(
                "Claim values must only be of types Map, List, Bool, Int64, Float64, String, Time, and Null")
        }

        // add claims only after validating all claims so as not to corrupt the claims map of this builder
        for ((key, value) in payloadClaims) {
            addClaim(key, value)
        }

        return this
    }

    private func validatePayload(payload: Map<String, Any>): Bool {
        for ((_, value) in payload) {
            if (value is ArrayList<Any> && !validateClaim((value as ArrayList<Any>).getOrThrow())) {
                return false
            } else if (value is Map<String, Any> && !validateClaim((value as Map<String, Any>).getOrThrow())) {
                return false
            } else if (!isSupportedType(value)) {
                return false
            }
        }
        return true
    }

    private static func validateClaim(map: Map<String, Any>): Bool {
        // do not accept null values in maps
        for ((_, value) in map) {
            if (!isSupportedType(value)) {
                return false
            }
        }
        return true
    }

    private static func validateClaim(list: ArrayList<Any>): Bool {
        // accept null values in list
        for (object in list) {
            if (!isSupportedType(object)) {
                return false
            }
        }
        return true
    }

    private static func isSupportedType(value: Any): Bool {
        match (value) {
            case value: ArrayList<Any> => validateClaim(value)
            case value: Map<String, Any> => validateClaim(value)
            case _ => isBasicType(value)
        }
    }

    private static func isBasicType(value: Any): Bool {
        match (value) {
            case _: Bool => true
            case _: Int64 => true
            case _: Float64 => true
            case _: DateTime => true
            case _: String => true
            case _: Array<Int64> => true
            case _: Array<String> => true
            case _: NodeType => true
            case _ => false
        }
    }

    /*
     * Creates a  JWT and signs is with the given algorithm.
     *
     * @param algorithm used to sign the JWT
     * @return a  JWT token
     * @throws IllegalArgumentException if the provided algorithm is null.
     * @throws JWTCreationException     if the claims could not be converted to a valid JSON
     * or there was a problem with the signing key.
     */
    public func sign(algorithm: Algorithm): String {
        headerClaims.add(HeaderParams.ALGORITHM, algorithm.getName())
        if (!headerClaims.contains(HeaderParams.TYPE)) {
            headerClaims.add(HeaderParams.TYPE, "JWT")
        }
        return JWTCreator(algorithm, headerClaims, payloadClaims).sign()
    }

    private func addClaim(name: String, value: Any) {
        payloadClaims.add(name, value)
    }
}
