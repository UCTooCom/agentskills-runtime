/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public abstract class ClaimsHolder {
    private let claims: Map<String, Any>

    protected init(claims: Map<String, Any>) {
        this.claims = claims
    }

    func getClaims(): Map<String, Any> {
        return claims
    }
}
