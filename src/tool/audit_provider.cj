/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import std.collection.HashMap
import stdx.encoding.json.JsonValue

public interface AuditProvider {
    func auditToolCall(
        userId: String,
        toolName: String,
        args: HashMap<String, JsonValue>,
        success: Bool,
        resultSize: Int64,
        durationMs: Int64,
        errorMessage: ?String,
        source: String,
        ip: String,
        permissionPath: String
    ): Unit
}