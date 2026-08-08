/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package jwt4cj

public class Base64Util {
    public static func urlEncode(content: Array<UInt8>): String {
        return toBase64String(content).replace("+", "-").replace("/", "_").replace("=", "")
    }

    public static func urlEncode(content: String): String {
        return toBase64String(content.toArray()).replace("+", "-").replace("/", "_").replace("=", "")
    }

    public static func urlDecode2Byte(content: String): Array<UInt8> {
        var c = content.replace("-", "+").replace("_", "/")
        c += "=" * (4 - c.size & 3)
        return fromBase64String(c).getOrThrow()
    }

    public static func urlDecode(content: String): String {
        var c = content.replace("-", "+").replace("_", "/")
        c += "=" * (4 - c.size & 3)
        return String.fromUtf8(fromBase64String(c).getOrThrow())
    }
}
