/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

/*
 * Parent to all the exception thrown while verifying a JWT.
 */
public open class JWTVerificationException <: Exception {
    public init(message: String) {
        super(message)
    }
}
