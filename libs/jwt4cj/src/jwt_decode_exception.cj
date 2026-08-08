/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class JWTDecodeException <: JWTVerificationException {
    public init(message: String) {
        super(message)
    }
}
