/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * The Payload class represents the 2nd part of the JWT, where the Payload value is held.
 */
public interface Payload {
    /*
     * Get the value of the "iss" claim, or None if it's not available.
     *
     * @return the Issuer value or None.
     */
    func getIssuer(): String

    /*
     * Get the value of the "sub" claim, or None if it's not available.
     *
     * @return the Subject value or None.
     */
    func getSubject(): String

    /*
     * Get the value of the "aud" claim, or None if it's not available.
     *
     * @return the Audience value or None.
     */
    func getAudience(): ArrayList<String>

    /*
     * Get the value of the "exp" claim, or None if it's not available.
     *
     * @return the Expiration Time value or None.
     */
    func getExpiresAt(): DateTime

    /*
     * Get the value of the "nbf" claim, or None if it's not available.
     *
     * @return the Not Before value or None.
     */
    func getNotBefore(): DateTime

    /*
     * Get the value of the "iat" claim, or None if it's not available.
     *
     * @return the Issued At value or None.
     */
    func getIssuedAt(): DateTime

    /*
     * Get the value of the "jti" claim, or None if it's not available.
     *
     * @return the JWT ID value or None.
     */
    func getId(): String

    /*
     * Get a Claim given its name. If the Claim wasn't specified in the Payload, a 'null claim'
     * will be returned. All the methods of that claim will return None.
     *
     * @param name the name of the Claim to retrieve.
     * @return a non-null Claim.
     */
    func getClaim(name: String): Claim

    /*
     * Get the Claims defined in the Token.
     *
     * @return a non-null Map containing the Claims defined in the Token.
     */
    func getClaims(): Map<String, Claim>
}
