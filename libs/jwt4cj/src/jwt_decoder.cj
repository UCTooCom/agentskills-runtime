/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class JWTDecoder <: DecodedJWT {
    private let parts: Array<String>
    private let token: String
    private let header: Header
    private let payload: Payload

    public init(jwt: String) {
        this(JWTParser(), jwt)
    }

    init(parser: JWTParser, jwt: String) {
        this.token = jwt
        parts = TokenUtils.splitToken(jwt)
        var headerJson: String
        var payloadJson: String
        try {
            headerJson = Base64Util.urlDecode(parts[0])
            payloadJson = Base64Util.urlDecode(parts[1])
        } catch (e: NoneValueException) {
            throw JWTDecodeException("The input is not a valid base 64 encoded string.")
        }
        header = parser.parseHeader(headerJson)
        payload = parser.parsePayload(payloadJson)
    }

    public func getToken(): String {
        token
    }

    public func getHeader(): String {
        parts[0]
    }

    public func getPayload(): String {
        parts[1]
    }

    public func getSignature(): String {
        parts[2]
    }

    public func getAlgorithm(): String {
        header.getAlgorithm()
    }

    public func getType(): String {
        header.getType()
    }

    public func getContentType(): String {
        header.getContentType()
    }

    public func getKeyId(): String {
        header.getKeyId()
    }

    public func getHeaderClaim(name: String): Claim {
        header.getHeaderClaim(name)
    }

    public func getIssuer(): String {
        payload.getIssuer()
    }

    public func getSubject(): String {
        payload.getSubject()
    }

    public func getAudience(): ArrayList<String> {
        payload.getAudience()
    }

    public func getExpiresAt(): DateTime {
        payload.getExpiresAt()
    }

    public func getNotBefore(): DateTime {
        payload.getNotBefore()
    }

    public func getIssuedAt(): DateTime {
        payload.getIssuedAt()
    }

    public func getId(): String {
        payload.getId()
    }

    public func getClaim(name: String): Claim {
        payload.getClaim(name)
    }

    public func getClaims(): Map<String, Claim> {
        payload.getClaims()
    }
}
