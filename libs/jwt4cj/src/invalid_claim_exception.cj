/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public open class InvalidClaimException <: JWTVerificationException {
    public init(message: String) {
        super(message)
    }
}
