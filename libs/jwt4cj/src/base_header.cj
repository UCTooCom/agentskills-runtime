/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

class BaseHeader <: Header {
    private let algorithm: ?String
    private let typ: ?String
    private let contentType: ?String
    private let keyId: ?String
    private let tree: Map<String, Claim>

    init(algorithm: ?String, typ: ?String, contentType: ?String, keyId: ?String, tree: Map<String, Claim>) {
        this.algorithm = algorithm
        this.typ = typ
        this.contentType = contentType
        this.keyId = keyId
        this.tree = tree
    }

    public func getAlgorithm(): String {
        algorithm.getOrThrow()
    }

    public func getType(): String {
        typ.getOrThrow()
    }

    public func getContentType(): String {
        contentType.getOrThrow()
    }

    public func getKeyId(): String {
        keyId.getOrThrow()
    }

    public func getHeaderClaim(name: String): Claim {
        tree.get(name) ?? MISSING_CLAIM
    }
}
