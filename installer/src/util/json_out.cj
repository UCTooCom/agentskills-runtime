package uc_installer.util

import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}

/// 以下小工具把仓颉基础类型包成 stdx.encoding.json 的 JsonValue，避免各处重复 import。
public func jstr(s: String): JsonValue { JsonString(s) }
public func jint(n: Int64): JsonValue { JsonInt(n) }
public func jbool(b: Bool): JsonValue { JsonBool(b) }
public func jnull(): JsonValue { JsonNull() }
public func jobj(): JsonObject { JsonObject() }
public func jarr(): JsonArray { JsonArray() }
