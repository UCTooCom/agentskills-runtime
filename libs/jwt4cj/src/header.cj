/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * The Header class represents the 1st part of the JWT, where the Header value is held.
 */
public interface Header {
    /*
     * Getter for the Algorithm "alg" claim defined in the JWT's Header. If the claim is missing it will return None.
     *
     * @return the Algorithm defined or None.
     */
    func getAlgorithm(): String

    /*
     * Getter for the Type "typ" claim defined in the JWT's Header. If the claim is missing it will return None.
     *
     * @return the Type defined or None.
     */
    func getType(): String

    /*
     * Getter for the Content Type "cty" claim defined in the JWT's Header. If the claim is missing it will return None.
     *
     * @return the Content Type defined or None.
     */
    func getContentType(): String

    /*
     * Get the value of the "kid" claim, or None if it's not available.
     *
     * @return the Key ID value or None.
     */
    func getKeyId(): String

    /*
     * Get a Private Claim given it's name. If the Claim wasn't specified in the Header, a 'null claim' will be
     * returned. All the methods of that claim will return None.
     *
     * @param name the name of the Claim to retrieve.
     * @return a non-null Claim.
     */
    func getHeaderClaim(name: String): Claim
}
