/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public open class ClaimsSerializer <: Serializer {
    public func serialize(holder: ClaimsHolder): String {
        let claims = holder.getClaims()
        for ((key, value) in claims) {
            put(key, value)
        }
        toString()
    }
}
