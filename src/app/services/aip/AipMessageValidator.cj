/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import magic.app.services.aip.model.LocalMessageRequest
import magic.log.LogUtils

public class AipMessageValidator {

    private static let VALID_SENDER_ROLES = ["requester", "provider", "broker", "observer"]

    public static func validate(request: LocalMessageRequest): Option<String> {
        let sessionErr = validateSessionId(request.sessionId)
        if (sessionErr.isSome()) { return sessionErr }

        let roleErr = validateSenderRole(request.senderRole)
        if (roleErr.isSome()) { return roleErr }

        let dataItemsErr = validateDataItems(request.dataItems)
        if (dataItemsErr.isSome()) { return dataItemsErr }

        return None<String>
    }

    private static func validateSessionId(sessionId: String): Option<String> {
        if (sessionId.isEmpty()) {
            return Some<String>("AIP-LOCAL-INTER-003: session_id不能为空")
        }
        if (sessionId.size < 8 || sessionId.size > 128) {
            return Some<String>("AIP-LOCAL-INTER-003: session_id长度必须在8-128之间")
        }
        return None<String>
    }

    private static func validateSenderRole(role: String): Option<String> {
        if (role.isEmpty()) {
            return Some<String>("AIP-LOCAL-INTER-003: sender_role不能为空")
        }
        var isValid = false
        for (validRole in VALID_SENDER_ROLES) {
            if (role == validRole) {
                isValid = true
                break
            }
        }
        if (!isValid) {
            return Some<String>("AIP-LOCAL-INTER-003: sender_role必须是requester/provider/broker/observer之一")
        }
        return None<String>
    }

    private static func validateDataItems(dataItems: Option<String>): Option<String> {
        if (dataItems.isSome()) {
            let items = dataItems.getOrThrow()
            if (!items.isEmpty() && !items.startsWith("[") ) {
                return Some<String>("AIP-LOCAL-INTER-003: data_items必须是JSON数组格式")
            }
        }
        return None<String>
    }
}