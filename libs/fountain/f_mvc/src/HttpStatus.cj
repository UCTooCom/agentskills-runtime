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

public class HttpStatus <: ToString & Equatable<HttpStatus> {
    // 1xx Informational

    /**
     * 100 Continue.
     * https://tools.ietf.org/html/rfc7231#section-6.2.1
     * HTTP/1.1: Semantics and Content, section 6.2.1
     */
    public static let CONTINUE = HttpStatus(
        HttpStatusCode.STATUS_CONTINUE,
        Series.INFORMATIONAL,
        "Continue"
    )

    /**
     * 101 Switching Protocols.
     * https://tools.ietf.org/html/rfc7231#section-6.2.2
     * HTTP/1.1: Semantics and Content, section 6.2.2
     */
    public static let SWITCHING_PROTOCOLS = HttpStatus(
        HttpStatusCode.STATUS_SWITCHING_PROTOCOLS,
        Series.INFORMATIONAL,
        "Switching Protocols"
    )

    /**
     * 102 Processing.
     * https://tools.ietf.org/html/rfc2518#section-10.1
     * WebDAV
     */
    public static let PROCESSING = HttpStatus(
        HttpStatusCode.STATUS_PROCESSING,
        Series.INFORMATIONAL,
        "Processing"
    )

    /**
     * 103 Checkpoint.
     * https://code.google.com/p/gears/wiki/ResumableHttpRequestsProposal
     * A proposal for supporting
     * resumable POST/PUT HTTP requests in HTTP/1.0
     */
    public static let CHECKPOINT = HttpStatus(
        HttpStatusCode.STATUS_EARLY_HINTS,
        Series.INFORMATIONAL,
        "Checkpoint"
    )
    public static let EARLY_HINTS = HttpStatus(
        HttpStatusCode.STATUS_EARLY_HINTS,
        Series.INFORMATIONAL,
        "Early Hints"
    )

    // 2xx Success

    /**
     * 200 OK.
     * https://tools.ietf.org/html/rfc7231#section-6.3.1
     * HTTP/1.1: Semantics and Content, section 6.3.1
     */
    public static let OK = HttpStatus(
        HttpStatusCode.STATUS_OK,
        Series.SUCCESSFUL,
        "OK"
    )

    /**
     * 201 Created.
     * https://tools.ietf.org/html/rfc7231#section-6.3.2
     * HTTP/1.1: Semantics and Content, section 6.3.2
     */
    public static let CREATED = HttpStatus(
        HttpStatusCode.STATUS_CREATED,
        Series.SUCCESSFUL,
        "Created"
    )

    /**
     * 202 Accepted.
     * https://tools.ietf.org/html/rfc7231#section-6.3.3
     * HTTP/1.1: Semantics and Content, section 6.3.3
     */
    public static let ACCEPTED = HttpStatus(
        HttpStatusCode.STATUS_ACCEPTED,
        Series.SUCCESSFUL,
        "Accepted"
    )

    /**
     * 203 Non-Authoritative Information.
     * https://tools.ietf.org/html/rfc7231#section-6.3.4
     * HTTP/1.1: Semantics and Content, section 6.3.4
     */
    public static let NON_AUTHORITATIVE_INFORMATION = HttpStatus(
        HttpStatusCode.STATUS_NON_AUTHORITATIVE_INFO,
        Series.SUCCESSFUL,
        "Non-Authoritative Information"
    )

    /**
     * 204 No Content.
     * https://tools.ietf.org/html/rfc7231#section-6.3.5
     * HTTP/1.1: Semantics and Content, section 6.3.5
     */
    public static let NO_CONTENT = HttpStatus(
        HttpStatusCode.STATUS_NO_CONTENT,
        Series.SUCCESSFUL,
        "No Content"
    )

    /**
     * 205 Reset Content.
     * https://tools.ietf.org/html/rfc7231#section-6.3.6
     * HTTP/1.1: Semantics and Content, section 6.3.6
     */
    public static let RESET_CONTENT = HttpStatus(
        HttpStatusCode.STATUS_RESET_CONTENT,
        Series.SUCCESSFUL,
        "Reset Content"
    )

    /**
     * 206 Partial Content.
     * https://tools.ietf.org/html/rfc7233#section-4.1
     * HTTP/1.1: Range Requests, section 4.1
     */
    public static let PARTIAL_CONTENT = HttpStatus(
        HttpStatusCode.STATUS_PARTIAL_CONTENT,
        Series.SUCCESSFUL,
        "Partial Content"
    )

    /**
     * 207 Multi-Status.
     * https://tools.ietf.org/html/rfc4918#section-13
     * WebDAV
     */
    public static let MULTI_STATUS = HttpStatus(
        HttpStatusCode.STATUS_MULTI_STATUS,
        Series.SUCCESSFUL,
        "Multi-Status"
    )

    /**
     * 208 Already Reported.
     * https://tools.ietf.org/html/rfc5842#section-7.1
     * WebDAV Binding Extensions
     */
    public static let ALREADY_REPORTED = HttpStatus(
        HttpStatusCode.STATUS_ALREADY_REPORTED,
        Series.SUCCESSFUL,
        "Already Reported"
    )

    /**
     * 226 IM Used.
     * https://tools.ietf.org/html/rfc3229#section-10.4.1
     * Delta encoding in HTTP
     */
    public static let IM_USED = HttpStatus(
        HttpStatusCode.STATUS_IM_USED,
        Series.SUCCESSFUL,
        "IM Used"
    )

    // 3xx Redirection

    /**
     * 300 Multiple Choices.
     * https://tools.ietf.org/html/rfc7231#section-6.4.1
     * HTTP/1.1: Semantics and Content, section 6.4.1
     */
    public static let MULTIPLE_CHOICES = HttpStatus(
        HttpStatusCode.STATUS_MULTIPLE_CHOICES,
        Series.REDIRECTION,
        "Multiple Choices"
    )

    /**
     * 301 Moved Permanently.
     * https://tools.ietf.org/html/rfc7231#section-6.4.2
     * HTTP/1.1: Semantics and Content, section 6.4.2
     */
    public static let MOVED_PERMANENTLY = HttpStatus(
        HttpStatusCode.STATUS_MOVED_PERMANENTLY,
        Series.REDIRECTION,
        "Moved Permanently"
    )

    /**
     * 302 Found.
     * https://tools.ietf.org/html/rfc7231#section-6.4.3
     * HTTP/1.1: Semantics and Content, section 6.4.3
     */
    public static let FOUND = HttpStatus(
        HttpStatusCode.STATUS_FOUND,
        Series.REDIRECTION,
        "Found"
    )

    /**
     * 302 Moved Temporarily.
     * https://tools.ietf.org/html/rfc1945#section-9.3
     * HTTP/1.0, section 9.3
     * deprecated in favor of FOUND which will be returned from HttpStatus.valueOf = HttpStatus(302)
     */
    public static let MOVED_TEMPORARILY = HttpStatus(
        HttpStatusCode.STATUS_FOUND,
        Series.REDIRECTION,
        "Moved Temporarily"
    )

    /**
     * 303 See Other.
     * https://tools.ietf.org/html/rfc7231#section-6.4.4
     * HTTP/1.1: Semantics and Content, section 6.4.4
     */
    public static let SEE_OTHER = HttpStatus(
        HttpStatusCode.STATUS_SEE_OTHER,
        Series.REDIRECTION,
        "See Other"
    )

    /**
     * 304 Not Modified.
     * https://tools.ietf.org/html/rfc7232#section-4.1
     * HTTP/1.1: Conditional Requests, section 4.1
     */
    public static let NOT_MODIFIED = HttpStatus(
        HttpStatusCode.STATUS_NOT_MODIFIED,
        Series.REDIRECTION,
        "Not Modified"
    )

    /**
     * 305 Use Proxy.
     * https://tools.ietf.org/html/rfc7231#section-6.4.5
     * HTTP/1.1: Semantics and Content, section 6.4.5
     * deprecated due to security concerns regarding in-band configuration of a proxy
     */
    public static let USE_PROXY = HttpStatus(
        HttpStatusCode.STATUS_USE_PROXY,
        Series.REDIRECTION,
        "Use Proxy"
    )

    /**
     * 307 Temporary Redirect.
     * https://tools.ietf.org/html/rfc7231#section-6.4.7
     * HTTP/1.1: Semantics and Content, section 6.4.7
     */
    public static let TEMPORARY_REDIRECT = HttpStatus(
        HttpStatusCode.STATUS_TEMPORARY_REDIRECT,
        Series.REDIRECTION,
        "Temporary Redirect"
    )

    /**
     * 308 Permanent Redirect.
     * https://tools.ietf.org/html/rfc7238
     * RFC 7238
     */
    public static let PERMANENT_REDIRECT = HttpStatus(
        HttpStatusCode.STATUS_PERMANENT_REDIRECT,
        Series.REDIRECTION,
        "Permanent Redirect"
    )

    // --- 4xx Client Error ---

    /**
     * 400 Bad Request.
     * https://tools.ietf.org/html/rfc7231#section-6.5.1
     * HTTP/1.1: Semantics and Content, section 6.5.1
     */
    public static let BAD_REQUEST = HttpStatus(
        HttpStatusCode.STATUS_BAD_REQUEST,
        Series.CLIENT_ERROR,
        "Bad Request"
    )

    /**
     * 401 Unauthorized.
     * https://tools.ietf.org/html/rfc7235#section-3.1
     * HTTP/1.1: Authentication, section 3.1
     */
    public static let UNAUTHORIZED = HttpStatus(
        HttpStatusCode.STATUS_UNAUTHORIZED,
        Series.CLIENT_ERROR,
        "Unauthorized"
    )

    /**
     * 402 Payment Required.
     * https://tools.ietf.org/html/rfc7231#section-6.5.2
     * HTTP/1.1: Semantics and Content, section 6.5.2
     */
    public static let PAYMENT_REQUIRED = HttpStatus(
        HttpStatusCode.STATUS_PAYMENT_REQUIRED,
        Series.CLIENT_ERROR,
        "Payment Required"
    )

    /**
     * 403 Forbidden.
     * https://tools.ietf.org/html/rfc7231#section-6.5.3
     * HTTP/1.1: Semantics and Content, section 6.5.3
     */
    public static let FORBIDDEN = HttpStatus(
        HttpStatusCode.STATUS_FORBIDDEN,
        Series.CLIENT_ERROR,
        "Forbidden"
    )

    /**
     * 404 Not Found.
     * https://tools.ietf.org/html/rfc7231#section-6.5.4
     * HTTP/1.1: Semantics and Content, section 6.5.4
     */
    public static let NOT_FOUND = HttpStatus(
        HttpStatusCode.STATUS_NOT_FOUND,
        Series.CLIENT_ERROR,
        "Not Found"
    )

    /**
     * 405 Method Not Allowed.
     * https://tools.ietf.org/html/rfc7231#section-6.5.5
     * HTTP/1.1: Semantics and Content, section 6.5.5
     */
    public static let METHOD_NOT_ALLOWED = HttpStatus(
        HttpStatusCode.STATUS_METHOD_NOT_ALLOWED,
        Series.CLIENT_ERROR,
        "Method Not Allowed"
    )

    /**
     * 406 Not Acceptable.
     * https://tools.ietf.org/html/rfc7231#section-6.5.6
     * HTTP/1.1: Semantics and Content, section 6.5.6
     */
    public static let NOT_ACCEPTABLE = HttpStatus(
        HttpStatusCode.STATUS_NOT_ACCEPTABLE,
        Series.CLIENT_ERROR,
        "Not Acceptable"
    )

    /**
     * 407 Proxy Authentication Required.
     * https://tools.ietf.org/html/rfc7235#section-3.2
     * HTTP/1.1: Authentication, section 3.2
     */
    public static let PROXY_AUTHENTICATION_REQUIRED = HttpStatus(
        HttpStatusCode.STATUS_PROXY_AUTH_REQUIRED,
        Series.CLIENT_ERROR,
        "Proxy Authentication Required"
    )

    /**
     * 408 Request Timeout.
     * https://tools.ietf.org/html/rfc7231#section-6.5.7
     * HTTP/1.1: Semantics and Content, section 6.5.7
     */
    public static let REQUEST_TIMEOUT = HttpStatus(
        HttpStatusCode.STATUS_REQUEST_TIMEOUT,
        Series.CLIENT_ERROR,
        "Request Timeout"
    )

    /**
     * 409 Conflict.
     * https://tools.ietf.org/html/rfc7231#section-6.5.8
     * HTTP/1.1: Semantics and Content, section 6.5.8
     */
    public static let CONFLICT = HttpStatus(
        HttpStatusCode.STATUS_CONFLICT,
        Series.CLIENT_ERROR,
        "Conflict"
    )

    /**
     * 410 Gone.
     * https://tools.ietf.org/html/rfc7231#section-6.5.9
     *
     *     HTTP/1.1: Semantics and Content, section 6.5.9
     */
    public static let GONE = HttpStatus(
        HttpStatusCode.STATUS_GONE,
        Series.CLIENT_ERROR,
        "Gone"
    )

    /**
     * 411 Length Required.
     * https://tools.ietf.org/html/rfc7231#section-6.5.10
     *
     *     HTTP/1.1: Semantics and Content, section 6.5.10
     */
    public static let LENGTH_REQUIRED = HttpStatus(
        HttpStatusCode.STATUS_LENGTH_REQUIRED,
        Series.CLIENT_ERROR,
        "Length Required"
    )

    /**
     * 412 Precondition failed.
     * https://tools.ietf.org/html/rfc7232#section-4.2
     *
     *     HTTP/1.1: Conditional Requests, section 4.2
     */
    public static let PRECONDITION_FAILED = HttpStatus(
        HttpStatusCode.STATUS_PRECONDITION_FAILED,
        Series.CLIENT_ERROR,
        "Precondition Failed"
    )

    /**
     * 413 Payload Too Large.
     * https://tools.ietf.org/html/rfc7231#section-6.5.11
     *
     *     HTTP/1.1: Semantics and Content, section 6.5.11
     */
    public static let PAYLOAD_TOO_LARGE = HttpStatus(
        HttpStatusCode.STATUS_REQUEST_CONTENT_TOO_LARGE,
        Series.CLIENT_ERROR,
        "Payload Too Large"
    )

    /**
     * 413 Request Entity Too Large.
     * https://tools.ietf.org/html/rfc2616#section-10.4.14
     * HTTP/1.1, section 10.4.14
     * deprecated in favor of PAYLOAD_TOO_LARGE which will be
     * returned from HttpStatus.valueOf = HttpStatus(413)
     */
    public static let REQUEST_ENTITY_TOO_LARGE = HttpStatus(
        HttpStatusCode.STATUS_REQUEST_CONTENT_TOO_LARGE,
        Series.CLIENT_ERROR,
        "Request Entity Too Large"
    )

    /*
     * 414 URI Too Long.
     * https://tools.ietf.org/html/rfc7231#section-6.5.12
     * HTTP/1.1: Semantics and Content, section 6.5.12
     */
    public static let URI_TOO_LONG = HttpStatus(
        HttpStatusCode.STATUS_REQUEST_URI_TOO_LONG,
        Series.CLIENT_ERROR,
        "URI Too Long"
    )

    /**
     * 414 Request-URI Too Long.
     * https://tools.ietf.org/html/rfc2616#section-10.4.15
     * HTTP/1.1, section 10.4.15
     * deprecated in favor of URI_TOO_LONG which will be returned from HttpStatus.valueOf = HttpStatus(414)
     */
    public static let REQUEST_URI_TOO_LONG = HttpStatus(
        HttpStatusCode.STATUS_REQUEST_URI_TOO_LONG,
        Series.CLIENT_ERROR,
        "Request-URI Too Long"
    )

    /**
     * 415 Unsupported Media Type.
     * https://tools.ietf.org/html/rfc7231#section-6.5.13
     * HTTP/1.1: Semantics and Content, section 6.5.13
     */
    public static let UNSUPPORTED_MEDIA_TYPE = HttpStatus(
        HttpStatusCode.STATUS_UNSUPPORTED_MEDIA_TYPE,
        Series.CLIENT_ERROR,
        "Unsupported Media Type"
    )

    /**
     * 416 Requested Range Not Satisfiable.
     * https://tools.ietf.org/html/rfc7233#section-4.4
     * HTTP/1.1: Range Requests, section 4.4
     */
    public static let REQUESTED_RANGE_NOT_SATISFIABLE = HttpStatus(
        HttpStatusCode.STATUS_REQUESTED_RANGE_NOT_SATISFIABLE,
        Series.CLIENT_ERROR,
        "Requested range not satisfiable"
    )

    /**
     * 417 Expectation Failed.
     * https://tools.ietf.org/html/rfc7231#section-6.5.14
     * HTTP/1.1: Semantics and Content, section 6.5.14
     */
    public static let EXPECTATION_FAILED = HttpStatus(
        HttpStatusCode.STATUS_EXPECTATION_FAILED,
        Series.CLIENT_ERROR,
        "Expectation Failed"
    )

    /**
     * 418 I'm a teapot.
     * https://tools.ietf.org/html/rfc2324#section-2.3.2
     * HTCPCP/1.0
     */
    public static let I_AM_A_TEAPOT = HttpStatus(
        HttpStatusCode.STATUS_TEAPOT,
        Series.CLIENT_ERROR,
        "I'm a teapot"
    )

    /**
     * deprecated See
     * https://tools.ietf.org/rfcdiff?difftype=--hwdiff&ampurl2=draft-ietf-webdav-protocol-06.txt
     * WebDAV Draft Changes
     */
    public static let INSUFFICIENT_SPACE_ON_RESOURCE = HttpStatus(
        419,
        Series.CLIENT_ERROR,
        "Insufficient Space On Resource"
    )

    /**
     * deprecated See
     * https://tools.ietf.org/rfcdiff?difftype=--hwdiff&ampurl2=draft-ietf-webdav-protocol-06.txt
     * WebDAV Draft Changes
     */
    public static let METHOD_FAILURE = HttpStatus(
        420,
        Series.CLIENT_ERROR,
        "Method Failure"
    )

    /**
     * deprecated
     * https://tools.ietf.org/rfcdiff?difftype=--hwdiff&ampurl2=draft-ietf-webdav-protocol-06.txt
     * WebDAV Draft Changes
     */
    public static let DESTINATION_LOCKED = HttpStatus(
        HttpStatusCode.STATUS_MISDIRECTED_REQUEST,
        Series.CLIENT_ERROR,
        "Destination Locked"
    )
    public static let MISDIRECTED_REQUEST = HttpStatus(
        HttpStatusCode.STATUS_MISDIRECTED_REQUEST,
        Series.CLIENT_ERROR,
        "Misdirected Request"
    )

    /**
     * 422 Unprocessable Entity.
     * https://tools.ietf.org/html/rfc4918#section-11.2
     * WebDAV
     */
    public static let UNPROCESSABLE_ENTITY = HttpStatus(
        HttpStatusCode.STATUS_UNPROCESSABLE_ENTITY,
        Series.CLIENT_ERROR,
        "Unprocessable Entity"
    )

    /**
     * 423 Locked.
     * https://tools.ietf.org/html/rfc4918#section-11.3
     * WebDAV
     */
    public static let LOCKED = HttpStatus(
        HttpStatusCode.STATUS_LOCKED,
        Series.CLIENT_ERROR,
        "Locked"
    )

    /**
     * 424 Failed Dependency.
     * https://tools.ietf.org/html/rfc4918#section-11.4
     * WebDAV
     */
    public static let FAILED_DEPENDENCY = HttpStatus(
        HttpStatusCode.STATUS_FAILED_DEPENDENCY,
        Series.CLIENT_ERROR,
        "Failed Dependency"
    )

    /**
     * 425 Too Early.
     * https://tools.ietf.org/html/rfc8470
     * RFC 8470
     */
    public static let TOO_EARLY = HttpStatus(
        HttpStatusCode.STATUS_TOO_EARLY,
        Series.CLIENT_ERROR,
        "Too Early"
    )

    /**
     * 426 Upgrade Required.
     * https://tools.ietf.org/html/rfc2817#section-6
     * Upgrading to TLS Within HTTP/1.1
     */
    public static let UPGRADE_REQUIRED = HttpStatus(
        HttpStatusCode.STATUS_UPGRADE_REQUIRED,
        Series.CLIENT_ERROR,
        "Upgrade Required"
    )

    /**
     * 428 Precondition Required.
     * https://tools.ietf.org/html/rfc6585#section-3
     * Additional HTTP Status Codes
     */
    public static let PRECONDITION_REQUIRED = HttpStatus(
        HttpStatusCode.STATUS_PRECONDITION_REQUIRED,
        Series.CLIENT_ERROR,
        "Precondition Required"
    )

    /**
     * 429 Too Many Requests.
     * https://tools.ietf.org/html/rfc6585#section-4
     * Additional HTTP Status Codes
     */
    public static let TOO_MANY_REQUESTS = HttpStatus(
        HttpStatusCode.STATUS_TOO_MANY_REQUESTS,
        Series.CLIENT_ERROR,
        "Too Many Requests"
    )

    /**
     * 431 Request Header Fields Too Large.
     * https://tools.ietf.org/html/rfc6585#section-5
     * Additional HTTP Status Codes
     */
    public static let REQUEST_HEADER_FIELDS_TOO_LARGE = HttpStatus(
        HttpStatusCode.STATUS_REQUEST_HEADER_FIELDS_TOO_LARGE,
        Series.CLIENT_ERROR,
        "Request Header Fields Too Large"
    )

    /**
     * 451 Unavailable For Legal Reasons.
     * https://tools.ietf.org/html/draft-ietf-httpbis-legally-restricted-status-04
     * An HTTP Status Code to Report Legal Obstacles
     */
    public static let UNAVAILABLE_FOR_LEGAL_REASONS = HttpStatus(
        HttpStatusCode.STATUS_UNAVAILABLE_FOR_LEGAL_REASONS,
        Series.CLIENT_ERROR,
        "Unavailable For Legal Reasons"
    )

    // --- 5xx Server Error ---

    /**
     * 500 Internal Server Error.
     * https://tools.ietf.org/html/rfc7231#section-6.6.1
     * HTTP/1.1: Semantics and Content, section 6.6.1
     */
    public static let INTERNAL_SERVER_ERROR = HttpStatus(
        HttpStatusCode.STATUS_INTERNAL_SERVER_ERROR,
        Series.SERVER_ERROR,
        "Internal Server Error"
    )

    /**
     * 501 Not Implemented.
     * https://tools.ietf.org/html/rfc7231#section-6.6.2
     * HTTP/1.1: Semantics and Content, section 6.6.2
     */
    public static let NOT_IMPLEMENTED = HttpStatus(
        HttpStatusCode.STATUS_NOT_IMPLEMENTED,
        Series.SERVER_ERROR,
        "Not Implemented"
    )

    /**
     * 502 Bad Gateway.
     * https://tools.ietf.org/html/rfc7231#section-6.6.3
     * HTTP/1.1: Semantics and Content, section 6.6.3
     */
    public static let BAD_GATEWAY = HttpStatus(
        HttpStatusCode.STATUS_BAD_GATEWAY,
        Series.SERVER_ERROR,
        "Bad Gateway"
    )

    /**
     * 503 Service Unavailable.
     * https://tools.ietf.org/html/rfc7231#section-6.6.4
     * HTTP/1.1: Semantics and Content, section 6.6.4
     */
    public static let SERVICE_UNAVAILABLE = HttpStatus(
        HttpStatusCode.STATUS_SERVICE_UNAVAILABLE,
        Series.SERVER_ERROR,
        "Service Unavailable"
    )

    /**
     * 504 Gateway Timeout.
     * https://tools.ietf.org/html/rfc7231#section-6.6.5
     * HTTP/1.1: Semantics and Content, section 6.6.5
     */
    public static let GATEWAY_TIMEOUT = HttpStatus(
        HttpStatusCode.STATUS_GATEWAY_TIMEOUT,
        Series.SERVER_ERROR,
        "Gateway Timeout"
    )

    /**
     * 505 HTTP Version Not Supported.
     * https://tools.ietf.org/html/rfc7231#section-6.6.6
     * HTTP/1.1: Semantics and Content, section 6.6.6
     */
    public static let HTTP_VERSION_NOT_SUPPORTED = HttpStatus(
        HttpStatusCode.STATUS_HTTP_VERSION_NOT_SUPPORTED,
        Series.SERVER_ERROR,
        "HTTP Version not supported"
    )

    /**
     * 506 Variant Also Negotiates
     * https://tools.ietf.org/html/rfc2295#section-8.1
     * Transparent Content Negotiation
     */
    public static let VARIANT_ALSO_NEGOTIATES = HttpStatus(
        HttpStatusCode.STATUS_VARIANT_ALSO_NEGOTIATES,
        Series.SERVER_ERROR,
        "Variant Also Negotiates"
    )

    /**
     * 507 Insufficient Storage
     * https://tools.ietf.org/html/rfc4918#section-11.5
     * WebDAV
     */
    public static let INSUFFICIENT_STORAGE = HttpStatus(
        HttpStatusCode.STATUS_INSUFFICIENT_STORAGE,
        Series.SERVER_ERROR,
        "Insufficient Storage"
    )

    /**
     * 508 Loop Detected
     * https://tools.ietf.org/html/rfc5842#section-7.2
     * WebDAV Binding Extensions
     */
    public static let LOOP_DETECTED = HttpStatus(
        HttpStatusCode.STATUS_LOOP_DETECTED,
        Series.SERVER_ERROR,
        "Loop Detected"
    )

    /**
     * 509 Bandwidth Limit Exceeded
     */
    public static let BANDWIDTH_LIMIT_EXCEEDED = HttpStatus(
        509,
        Series.SERVER_ERROR,
        "Bandwidth Limit Exceeded"
    )

    /**
     * 510 Not Extended
     * https://tools.ietf.org/html/rfc2774#section-7
     * HTTP Extension Framework
     */
    public static let NOT_EXTENDED = HttpStatus(
        HttpStatusCode.STATUS_NOT_EXTENDED,
        Series.SERVER_ERROR,
        "Not Extended"
    )

    /**
     * 511 Network Authentication Required.
     * https://tools.ietf.org/html/rfc6585#section-6
     * Additional HTTP Status Codes
     */
    public static let NETWORK_AUTHENTICATION_REQUIRED = HttpStatus(
        HttpStatusCode.STATUS_NETWORK_AUTHENTICATION_REQUIRED,
        Series.SERVER_ERROR,
        "Network Authentication Required"
    )
    private static let statuses = HashMap<UInt16, HttpStatus>()
    static init() {
        for (status in values) {
            statuses[status.value] = status
        }
    }
    private HttpStatus(
        public let value: UInt16,
        public let series: Series,
        public let reasonPhrase: String
    ) {}

    public static prop values: Array<HttpStatus> {
        get() {
            [
                CONTINUE,
                SWITCHING_PROTOCOLS,
                PROCESSING,
                CHECKPOINT,
                OK,
                CREATED,
                ACCEPTED,
                NON_AUTHORITATIVE_INFORMATION,
                NO_CONTENT,
                RESET_CONTENT,
                PARTIAL_CONTENT,
                MULTI_STATUS,
                ALREADY_REPORTED,
                IM_USED,
                MULTIPLE_CHOICES,
                MOVED_PERMANENTLY,
                FOUND,
                SEE_OTHER,
                NOT_MODIFIED,
                USE_PROXY,
                TEMPORARY_REDIRECT,
                PERMANENT_REDIRECT,
                BAD_REQUEST,
                UNAUTHORIZED,
                PAYMENT_REQUIRED,
                FORBIDDEN,
                NOT_FOUND,
                METHOD_NOT_ALLOWED,
                NOT_ACCEPTABLE,
                PROXY_AUTHENTICATION_REQUIRED,
                REQUEST_TIMEOUT,
                CONFLICT,
                GONE,
                LENGTH_REQUIRED,
                PRECONDITION_FAILED,
                PAYLOAD_TOO_LARGE,
                REQUEST_ENTITY_TOO_LARGE,
                URI_TOO_LONG,
                REQUEST_URI_TOO_LONG,
                UNSUPPORTED_MEDIA_TYPE,
                REQUESTED_RANGE_NOT_SATISFIABLE,
                EXPECTATION_FAILED,
                I_AM_A_TEAPOT,
                INSUFFICIENT_SPACE_ON_RESOURCE,
                METHOD_FAILURE,
                DESTINATION_LOCKED,
                UNPROCESSABLE_ENTITY,
                LOCKED,
                FAILED_DEPENDENCY,
                TOO_EARLY,
                UPGRADE_REQUIRED,
                PRECONDITION_REQUIRED,
                TOO_MANY_REQUESTS,
                REQUEST_HEADER_FIELDS_TOO_LARGE,
                UNAVAILABLE_FOR_LEGAL_REASONS,
                INTERNAL_SERVER_ERROR,
                NOT_IMPLEMENTED,
                BAD_GATEWAY,
                SERVICE_UNAVAILABLE,
                GATEWAY_TIMEOUT,
                HTTP_VERSION_NOT_SUPPORTED,
                VARIANT_ALSO_NEGOTIATES,
                INSUFFICIENT_STORAGE,
                LOOP_DETECTED,
                BANDWIDTH_LIMIT_EXCEEDED,
                NOT_EXTENDED,
                NETWORK_AUTHENTICATION_REQUIRED
            ]
        }
    }

    /**
     * Whether this status code is in the HTTP series
     * This is a shortcut for checking the value of series.

     */
    public prop is1xxInformational: Bool {
        get() {
            series == Series.INFORMATIONAL
        }
    }

    /**
     * Whether this status code is in the HTTP series
     * This is a shortcut for checking the value of series.

     */
    public prop is2xxSuccessful: Bool {
        get() {
            series == Series.SUCCESSFUL
        }
    }

    /**
     * Whether this status code is in the HTTP series
     * This is a shortcut for checking the value of series.
     */
    public prop is3xxRedirection: Bool {
        get() {
            series == Series.REDIRECTION
        }
    }

    /**
     * Whether this status code is in the HTTP series
     * This is a shortcut for checking the value of series.
     */
    public prop is4xxClientError: Bool {
        get() {
            series == Series.CLIENT_ERROR
        }
    }

    /**
     * Whether this status code is in the HTTP series
     * This is a shortcut for checking the value of series.
     */
    public prop is5xxServerError: Bool {
        get() {
            series == Series.SERVER_ERROR
        }
    }

    /**
     * Whether this status code is in the HTTP series
     * This is a shortcut for checking the value of series.
     * is4xxClientError()
     * is5xxServerError()
     */
    public prop isError: Bool {
        get() {
            is4xxClientError || is5xxServerError
        }
    }

    /**
     * Return a string representation of this status code.
     */
    public func toString(): String {
        return "${this.value} ${this.reasonPhrase}"
    }

    public operator func ==(other: HttpStatus): Bool {
        this.value == other.value
    }

    /**
     * Return the HttpStatus enum constant with the specified numeric value.
     * param status the numeric value of the enum to be returned
     * return the constant with the specified numeric value
     * throws IllegalArgumentException if this class has no constant for the specified numeric value
     */
    public static func valueOf(status: UInt16): HttpStatus {
        match (resolve(status)) {
            case Some(s) => s
            case _ => throw IllegalArgumentException("No matching constant for [${status}]")
        }
    }

    /**
     * Resolve the given status code to an HttpStatus, if possible.
     * param status the HTTP status code (potentially non-standard)
     * return the corresponding HttpStatus, or None<HttpStatus> if not found
     */
    public static func resolve(status: UInt16): ?HttpStatus {
        statuses.get(status)
    }
}
