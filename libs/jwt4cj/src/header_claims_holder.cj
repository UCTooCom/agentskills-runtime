/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class HeaderClaimsHolder <: ClaimsHolder {
    public init(claims: Map<String, Any>) {
        super(claims)
    }
}
