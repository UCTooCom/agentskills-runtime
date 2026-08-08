/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * Constructs and holds the checks required for a JWT to be considered valid.
 */
public interface Verification {
    /*
     * Verifies whether the JWT contains an Issuer ("iss") claim that equals to the value provided.
     * This check is case-sensitive.
     *
     * @param issuer the required Issuer value.
     * @return this same Verification instance.
     */
    func withIssuer(issuer: String): Verification {
        return withIssuer([issuer])
    }

    /*
     * Verifies whether the JWT contains an Issuer ("iss") claim that contains all the values provided.
     * This check is case-sensitive. An empty array is considered as a None.
     *
     * @param issuer the required Issuer value. If multiple values are given, the claim must at least match one of them
     * @return this same Verification instance.
     */
    func withIssuer(issuer: Array<String>): Verification

    /*
     * Verifies whether the JWT contains a Subject ("sub") claim that equals to the value provided.
     * This check is case-sensitive.
     *
     * @param subject the required Subject value
     * @return this same Verification instance.
     */
    func withSubject(subject: String): Verification

    /*
     * Verifies whether the JWT contains an Audience ("aud") claim that contains all the values provided.
     * This check is case-sensitive. An empty array is considered as a None.
     *
     * @param audience the required Audience value
     * @return this same Verification instance.
     */
    func withAudience(audience: Array<String>): Verification

    /*
     * Verifies whether the JWT contains an Audience ("aud") claim contain at least one of the specified audiences.
     * This check is case-sensitive. An empty array is considered as a None.
     *
     * @param audience the required Audience value for which the "aud" claim must contain at least one value.
     * @return this same Verification instance.
     */
    func withAnyOfAudience(audience: Array<String>): Verification

    /*
     * Verifies whether the JWT contains an Audience ("aud") claim contain at least one of the specified audiences.
     * This check is case-sensitive. An empty array is considered as a None.
     *
     * @param audience the required Audience value for which the "aud" claim must contain at least one value.
     * @return this same Verification instance.
     */
    func withAnyOfAudience(audience: ArrayList<String>): Verification

    /*
     * Define the default window in seconds in which the Not Before, Issued At and Expires At Claims
     * will still be valid. Setting a specific leeway value on a given Claim will override this value for that Claim.
     *
     * @param leeway the window in seconds in which the Not Before, Issued At and Expires At Claims will still be valid.
     * @return this same Verification instance.
     * @throws IllegalArgumentException leeway is negative.
     */
    func acceptLeeway(leeway: Int64): Verification

    /*
     * Set a specific leeway window in seconds in which the Expires At ("exp") Claim will still be valid.
     * Expiration Date is always verified when the value is present.
     * This method overrides the value set with acceptLeeway
     *
     * @param leeway the window in seconds in which the Expires At Claim will still be valid.
     * @return this same Verification instance.
     * @throws IllegalArgumentException leeway is negative.
     */
    func acceptExpiresAt(leeway: Int64): Verification

    /*
     * Set a specific leeway window in seconds in which the Not Before ("nbf") Claim will still be valid.
     * Not Before Date is always verified when the value is present.
     * This method overrides the value set with acceptLeeway
     *
     * @param leeway the window in seconds in which the Not Before Claim will still be valid.
     * @return this same Verification instance.
     * @throws IllegalArgumentException leeway is negative.
     */
    func acceptNotBefore(leeway: Int64): Verification

    /*
     * Set a specific leeway window in seconds in which the Issued At ("iat") Claim will still be valid.
     * This method overrides the value set with {@link #acceptLeeway(long)}.
     * By default, the Issued At claim is always verified when the value is present,
     * unless disabled with {@link #ignoreIssuedAt()}.
     * If Issued At Verification has been disabled, no Verification of the Issued At claim will be performed,
     * and this method has no effect.
     *
     * @param leeway the window in seconds in which the Issued At Claim will still be valid.
     * @return this same Verification instance.
     * @throws IllegalArgumentException leeway is negative.
     */
    func acceptIssuedAt(leeway: Int64): Verification

    /*
     * Verifies whether the JWT contains a JWT ID ("jti") claim that equals to the value provided.
     * This check is case-sensitive.
     *
     * @param jwtId the required ID value
     * @return this same Verification instance.
     */
    func withJWTId(jwtId: String): Verification

    /*
     * Verifies whether the claim is present in the JWT, with any value including None.
     *
     * @param name the Claim's name.
     * @return this same Verification instance
     * @throws IllegalArgumentException the name is None.
     */
    func withClaimPresence(name: String): Verification

    /*
     * Verifies whether the claim is present with a None value.
     *
     * @param name the Claim's name.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withNullClaim(name: String): Verification

    /*
     * Verifies whether the claim is equal to the given Boolean value.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withClaim(name: String, value: Bool): Verification

    func withClaim(name: String, predicate: (Claim, DecodedJWT) -> Bool): Verification

    /*
     * Verifies whether the claim is equal to the given value:Int64.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withClaim(name: String, value: Int64): Verification

    /*
     * Verifies whether the claim is equal to the given value:Int64.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withClaim(name: String, value: Float64): Verification

    /*
     * Verifies whether the claim is equal to the given value:String.
     * This check is case-sensitive.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withClaim(name: String, value: String): Verification

    /*
     * Verifies whether the claim is equal to the given value:Time.
     * Note that date-time claims are serialized as seconds since the epoch:
     * when verifying date-time claim value, any time units more granular than seconds will not be considered.
     *
     * @param name  the Claim's name.
     * @param value the Claim's value.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withClaim(name: String, value: DateTime): Verification

    /*
     * Verifies whether the claim contain at least the given String items.
     *
     * @param name  the Claim's name.
     * @param items the items the Claim must contain.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withArrayClaim(name: String, items: Array<String>): Verification

    /*
     * Verifies whether the claim contain at least the given Integer items.
     *
     * @param name  the Claim's name.
     * @param items the items the Claim must contain.
     * @return this same Verification instance.
     * @throws IllegalArgumentException the name is None.
     */
    func withArrayClaim(name: String, items: Array<Int64>): Verification

    /*
     * Skip the Issued At ("iat") claim Verification. By default, the Verification is performed.
     *
     * @return this same Verification instance.
     */
    func ignoreIssuedAt(): Verification

    /*
     * Creates a new and reusable instance of the JWTVerifier with the configuration already provided.
     *
     * @return a new jwt.interfaces.JWTVerifier instance.
     */
    func build(): JWTVerifier
}
