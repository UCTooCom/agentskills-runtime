/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines the functions used for outputting logs.
 */

package logcj.utils

/**
 * Align the character string to the right and supplement the specified character in the remaining bits.
 *
 * @param str character string to be converted.
 * @param limit limit num.
 * @param placeholder placeholder.
 * @return return the processed result.
 */
public func flushLeft(str: String, limit: Int64, placeholder: String): String {
    var len = limit - str.size
    if (len == limit) {
        return str
    }

    var result: StringBuilder = StringBuilder()
    for (i in 0..len) {
        result.append(placeholder)
    }
    result.append(str)
    return result.toString()
}

/**
 * Parse a number with K/M/G suffixes based on thousands (1000) or 2^10 (1024) Algorithm to be improved.
 *
 * @param str character string to be converted.
 * @param mult mult.
 * @param defaultValue default value.
 * @return Data after the algorithm improved.
 */
public func strToNumBySuffix(str: String, mult: Int64, defaultValue: Int64): Int64 {
    var num = 1
    let len = str.size
    var numStr = str
    if (str.endsWith("g") || str.endsWith("G")) {
        num = num * mult * mult * mult
        numStr = str[0..len - 1]
    } else if (str.endsWith("m") || str.endsWith("M")) {
        num = num * mult * mult
        numStr = str[0..len - 1]
    } else if (str.endsWith("k") || str.endsWith("K")) {
        num = num * mult
        numStr = str[0..len - 1]
    }
    try {
        let parsed = Int64.parse(numStr)
        return parsed * num
    } catch (e: IllegalArgumentException) {
        return defaultValue
    }
}

/**
 * Converting numeric strings to int64.
 *
 * @param str character string to be converted.
 * @param defaultValue the default value is returned when the conversion is abnormal.
 * @return deta of the Int64 type is returned.
 */
public func getNumByString(str: String, defaultValue: Int64): Int64 {
    try {
        return Int64.parse(str)
    } catch (e: IllegalArgumentException) {
        return defaultValue
    }
}
