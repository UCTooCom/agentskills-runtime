/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

class BasePayload <: Payload {
    private let issuer: ?String
    private let subject: ?String
    private let audience: ?ArrayList<String>
    private let expiresAt: ?DateTime
    private let notBefore: ?DateTime
    private let issuedAt: ?DateTime
    private let jwtId: ?String
    private let tree: Map<String, Claim>

    init(
        issuer: ?String,
        subject: ?String,
        audience: ?ArrayList<String>,
        expiresAt: ?DateTime,
        notBefore: ?DateTime,
        issuedAt: ?DateTime,
        jwtId: ?String,
        tree: Map<String, Claim>
    ) {
        this.issuer = issuer
        this.subject = subject
        this.audience = audience
        this.expiresAt = expiresAt
        this.notBefore = notBefore
        this.issuedAt = issuedAt
        this.jwtId = jwtId
        this.tree = tree
    }

    public func getIssuer(): String {
        issuer.getOrThrow()
    }

    public func getSubject(): String {
        subject.getOrThrow()
    }

    public func getAudience(): ArrayList<String> {
        audience.getOrThrow()
    }

    public func getExpiresAt(): DateTime {
        expiresAt.getOrThrow()
    }

    public func getNotBefore(): DateTime {
        notBefore.getOrThrow()
    }

    public func getIssuedAt(): DateTime {
        issuedAt.getOrThrow()
    }

    public func getId(): String {
        jwtId.getOrThrow()
    }

    public func getClaim(name: String): Claim {
        tree.get(name) ?? MISSING_CLAIM
    }

    public func getClaims(): Map<String, Claim> {
        tree
    }
}
