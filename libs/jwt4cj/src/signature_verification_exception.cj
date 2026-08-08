/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class SignatureVerificationException <: JWTVerificationException {
    public init(algorithmName: String) {
        super("The Token's Signature resulted invalid when verified using the Algorithm: " + algorithmName)
    }
}
