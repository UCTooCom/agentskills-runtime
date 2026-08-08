/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

class NoneAlgorithm <: Algorithm {
    init() {
        super("none", "none")
    }

    public func verify(jwt: DecodedJWT): Unit {
        if (jwt.getSignature() != "") {
            throw SignatureVerificationException("noneAlgorithm exception!")
        }
    }

    public func sign(_: Array<UInt8>, _: Array<UInt8>): Array<UInt8> {
        return Array<UInt8>()
    }

    public func sign(_: Array<UInt8>): Array<UInt8> {
        return Array<UInt8>()
    }
}
