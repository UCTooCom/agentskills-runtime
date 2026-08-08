/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

abstract class TokenUtils {
    static func splitToken(token: String): Array<String> {
        let arr = token.split(".")
        if (arr.size != 3) {
            throw wrongNumberOfParts(arr.size)
        }
        arr
    }

    private static func wrongNumberOfParts(partCount: ToString) {
        JWTDecodeException("The token was expected to have 3 parts, but got ${partCount}.")
    }
}
