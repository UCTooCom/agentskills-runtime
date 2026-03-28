/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package f_mvc

/**
 * 1000 indicates a normal closure, meaning that the purpose for
 *      which the connection was established has been fulfilled.
 */
public const WS_NORMAL_CLOSE = 1000
/**
 * 1001 indicates that an endpoint is "going away", such as a server
 *      going down or a browser having navigated away from a page.
 */
public const WS_GOING_AWAY = 1001
/**
 * 1002 indicates that an endpoint is terminating the connection due
 *      to a protocol error.
 */
public const WS_PROTOCOL_ERROR = 1002
/**
 * 1003 indicates that an endpoint is terminating the connection
 *      because it has received a type of data it cannot accept (e.g., an
 *      endpoint that understands only text data MAY send this if it
 *      receives a binary message).
 */
public const WS_UNACCEPTABLE_DATA = 1003
/**
 * 1004 Reserved.  The specific meaning might be defined in the future.
 */
public const WS_RESERVED_FUTURE = 1004
/**
 * 1005 is a reserved value and MUST NOT be set as a status code in a
 *      Close control frame by an endpoint.  It is designated for use in
 *      applications expecting a status code to indicate that no status
 *      code was actually present.
 */
public const WS_RESERVED_DISEXISTENCE = 1005
/**
 * 1006 is a reserved value and MUST NOT be set as a status code in a
 *      Close control frame by an endpoint.  It is designated for use in
 *      applications expecting a status code to indicate that the
 *      connection was closed abnormally, e.g., without sending or
 *      receiving a Close control frame.
 */
public const WS_RESERVED_NO_CLOSE_FRAME = 1006
/**
 * 1007 indicates that an endpoint is terminating the connection
 *      because it has received data within a message that was not
 *      consistent with the type of the message (e.g., non-UTF-8 [RFC3629]
 *      data within a text message).
 */
public const WS_FRAME_TYPE_UNMATCH = 1008
/**
 * 1008 indicates that an endpoint is terminating the connection
 *      because it has received a message that violates its policy.  This
 *      is a generic status code that can be returned when there is no
 *      other more suitable status code (e.g., 1003 or 1009) or if there
 *      is a need to hide specific details about the policy.
 */
public const WS_ANTI_STRATEGY = 1008
/**
 * 1009 indicates that an endpoint is terminating the connection
 *      because it has received a message that is too big for it to
 *      process.
 */
public const WS_TOO_LARGE_FRAME = 1009
/**
 * 1010 indicates that an endpoint (client) is terminating the
 *      connection because it has expected the server to negotiate one or
 *      more extension, but the server didn't return them in the response
 *      message of the WebSocket handshake.  The list of extensions that
 *      are needed SHOULD appear in the /reason/ part of the Close frame.
 *      Note that this status code is not used by the server, because it
 *      can fail the WebSocket handshake instead.
 */
public const WS_NO_NECESSARY_EXTENSION = 1010
/**
 * 1011 indicates that a server is terminating the connection because
 *      it encountered an unexpected condition that prevented it from
 *      fulfilling the request.
 */
public const WS_UNEXPECTED_CONDITION = 1011
/**
 * 1015 is a reserved value and MUST NOT be set as a status code in a
 *      Close control frame by an endpoint.  It is designated for use in
 *      applications expecting a status code to indicate that the
 *      connection was closed due to a failure to perform a TLS handshake
 *      (e.g., the server certificate can't be verified).
 */
public const WS_FAILURE_TLS_HANDSHAKE = 1015

public struct WSCloseFrame{
    public let status: UInt16
    public let reason: String
    public init(payload: Array<Byte>){
        status = UInt16(payload[0]) << 8 | UInt16(payload[1])
        reason = String.fromUtf8(payload[2..payload.size])
    }
}