/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * Contains constants representing the name of the Registered Claim Names as defined in Section 4.1 of
 * RFC 7529
 */
public abstract class RegisteredClaims {
    /*
     * The "iss" (issuer) claim identifies the principal that issued the JWT.
     * Refer RFC 7529 Section 4.1.1
     */
    public static let ISSUER = "iss"

    /*
     * The "sub" (subject) claim identifies the principal that is the subject of the JWT.
     * Refer RFC 7529 Section 4.1.2
     */
    public static let SUBJECT = "sub"

    /*
     * The "aud" (audience) claim identifies the recipients that the JWT is intended for.
     * Refer RFC 7529 Section 4.1.3
     */
    public static let AUDIENCE = "aud"

    /*
     * The "exp" (expiration time) claim identifies the expiration time on or after which the JWT MUST NOT be
     * accepted for processing.
     * Refer RFC 7529 Section 4.1.4
     */
    public static let EXPIRES_AT = "exp"

    /*
     * The "nbf" (not before) claim identifies the time before which the JWT MUST NOT be accepted for processing.
     * Refer RFC 7529 Section 4.1.5
     */
    public static let NOT_BEFORE = "nbf"

    /*
     * The "iat" (issued at) claim identifies the time at which the JWT was issued.
     * Refer RFC 7529 Section 4.1.6
     */
    public static let ISSUED_AT = "iat"

    /*
     * The "jti" (JWT ID) claim provides a unique identifier for the JWT.
     * Refer RFC 7529 Section 4.1.7
     */
    public static let JWT_ID = "jti"
}
