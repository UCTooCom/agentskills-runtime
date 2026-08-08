/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class TokenExpiredException <: JWTVerificationException {
    private var time: DateTime

    public init(message: String, time: DateTime) {
        super(message)
        this.time = time
    }

    public func getExpiredOn(): DateTime {
        return this.time
    }
}
