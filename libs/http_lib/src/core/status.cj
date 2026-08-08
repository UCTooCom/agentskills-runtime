package http_lib.core

/**
 * HTTP 状态码及对应原因短语。
 */
public class HttpStatus <: ToString {
    public let code: UInt16
    public let reasonPhrase: String

    public init(code: UInt16, reasonPhrase!: String = "") {
        this.code = code
        this.reasonPhrase = if (reasonPhrase.size > 0) {
            reasonPhrase
        } else {
            defaultReasonPhrase(code)
        }
    }

    // --- 1xx 信息性 ---
    public static let CONTINUE = HttpStatus(100)
    public static let SWITCHING_PROTOCOLS = HttpStatus(101)
    public static let PROCESSING = HttpStatus(102)
    public static let EARLY_HINTS = HttpStatus(103)

    // --- 2xx 成功 ---
    public static let OK = HttpStatus(200)
    public static let CREATED = HttpStatus(201)
    public static let ACCEPTED = HttpStatus(202)
    public static let NON_AUTHORITATIVE_INFORMATION = HttpStatus(203)
    public static let NO_CONTENT = HttpStatus(204)
    public static let RESET_CONTENT = HttpStatus(205)
    public static let PARTIAL_CONTENT = HttpStatus(206)
    public static let MULTI_STATUS = HttpStatus(207)
    public static let ALREADY_REPORTED = HttpStatus(208)
    public static let IM_USED = HttpStatus(226)

    // --- 3xx 重定向 ---
    public static let MULTIPLE_CHOICES = HttpStatus(300)
    public static let MOVED_PERMANENTLY = HttpStatus(301)
    public static let FOUND = HttpStatus(302)
    public static let SEE_OTHER = HttpStatus(303)
    public static let NOT_MODIFIED = HttpStatus(304)
    public static let TEMPORARY_REDIRECT = HttpStatus(307)
    public static let PERMANENT_REDIRECT = HttpStatus(308)

    // --- 4xx 客户端错误 ---
    public static let BAD_REQUEST = HttpStatus(400)
    public static let UNAUTHORIZED = HttpStatus(401)
    public static let PAYMENT_REQUIRED = HttpStatus(402)
    public static let FORBIDDEN = HttpStatus(403)
    public static let NOT_FOUND = HttpStatus(404)
    public static let METHOD_NOT_ALLOWED = HttpStatus(405)
    public static let NOT_ACCEPTABLE = HttpStatus(406)
    public static let PROXY_AUTHENTICATION_REQUIRED = HttpStatus(407)
    public static let REQUEST_TIMEOUT = HttpStatus(408)
    public static let CONFLICT = HttpStatus(409)
    public static let GONE = HttpStatus(410)
    public static let LENGTH_REQUIRED = HttpStatus(411)
    public static let PRECONDITION_FAILED = HttpStatus(412)
    public static let PAYLOAD_TOO_LARGE = HttpStatus(413)
    public static let URI_TOO_LONG = HttpStatus(414)
    public static let UNSUPPORTED_MEDIA_TYPE = HttpStatus(415)
    public static let RANGE_NOT_SATISFIABLE = HttpStatus(416)
    public static let EXPECTATION_FAILED = HttpStatus(417)
    public static let IM_A_TEAPOT = HttpStatus(418)
    public static let MISDIRECTED_REQUEST = HttpStatus(421)
    public static let UNPROCESSABLE_ENTITY = HttpStatus(422)
    public static let LOCKED = HttpStatus(423)
    public static let FAILED_DEPENDENCY = HttpStatus(424)
    public static let TOO_EARLY = HttpStatus(425)
    public static let UPGRADE_REQUIRED = HttpStatus(426)
    public static let PRECONDITION_REQUIRED = HttpStatus(428)
    public static let TOO_MANY_REQUESTS = HttpStatus(429)
    public static let REQUEST_HEADER_FIELDS_TOO_LARGE = HttpStatus(431)
    public static let UNAVAILABLE_FOR_LEGAL_REASONS = HttpStatus(451)

    // --- 5xx 服务器错误 ---
    public static let INTERNAL_SERVER_ERROR = HttpStatus(500)
    public static let NOT_IMPLEMENTED = HttpStatus(501)
    public static let BAD_GATEWAY = HttpStatus(502)
    public static let SERVICE_UNAVAILABLE = HttpStatus(503)
    public static let GATEWAY_TIMEOUT = HttpStatus(504)
    public static let HTTP_VERSION_NOT_SUPPORTED = HttpStatus(505)
    public static let VARIANT_ALSO_NEGOTIATES = HttpStatus(506)
    public static let INSUFFICIENT_STORAGE = HttpStatus(507)
    public static let LOOP_DETECTED = HttpStatus(508)
    public static let NOT_EXTENDED = HttpStatus(510)
    public static let NETWORK_AUTHENTICATION_REQUIRED = HttpStatus(511)

    public func isInformational(): Bool { code >= 100 && code < 200 }
    public func isSuccess(): Bool { code >= 200 && code < 300 }
    public func isRedirection(): Bool { code >= 300 && code < 400 }
    public func isClientError(): Bool { code >= 400 && code < 500 }
    public func isServerError(): Bool { code >= 500 && code < 600 }

    public func toString(): String {
        "${code} ${reasonPhrase}"
    }

    public operator func ==(that: HttpStatus): Bool {
        this.code == that.code
    }

    public operator func !=(that: HttpStatus): Bool {
        this.code != that.code
    }
}

/**
 * 返回标准 HTTP 状态码对应的 RFC 原因短语。
 * 使用 std.convert 进行高效的状态码匹配。
 */
public func statusText(code: UInt16): String {
    defaultReasonPhrase(code)
}

/**
 * 内部默认原因短语映射。
 */
private func defaultReasonPhrase(code: UInt16): String {
    match (code) {
        case 100 => "Continue"
        case 101 => "Switching Protocols"
        case 102 => "Processing"
        case 103 => "Early Hints"
        case 200 => "OK"
        case 201 => "Created"
        case 202 => "Accepted"
        case 203 => "Non-Authoritative Information"
        case 204 => "No Content"
        case 205 => "Reset Content"
        case 206 => "Partial Content"
        case 207 => "Multi-Status"
        case 208 => "Already Reported"
        case 226 => "IM Used"
        case 300 => "Multiple Choices"
        case 301 => "Moved Permanently"
        case 302 => "Found"
        case 303 => "See Other"
        case 304 => "Not Modified"
        case 307 => "Temporary Redirect"
        case 308 => "Permanent Redirect"
        case 400 => "Bad Request"
        case 401 => "Unauthorized"
        case 402 => "Payment Required"
        case 403 => "Forbidden"
        case 404 => "Not Found"
        case 405 => "Method Not Allowed"
        case 406 => "Not Acceptable"
        case 407 => "Proxy Authentication Required"
        case 408 => "Request Timeout"
        case 409 => "Conflict"
        case 410 => "Gone"
        case 411 => "Length Required"
        case 412 => "Precondition Failed"
        case 413 => "Payload Too Large"
        case 414 => "URI Too Long"
        case 415 => "Unsupported Media Type"
        case 416 => "Range Not Satisfiable"
        case 417 => "Expectation Failed"
        case 418 => "I'm a Teapot"
        case 421 => "Misdirected Request"
        case 422 => "Unprocessable Entity"
        case 423 => "Locked"
        case 424 => "Failed Dependency"
        case 425 => "Too Early"
        case 426 => "Upgrade Required"
        case 428 => "Precondition Required"
        case 429 => "Too Many Requests"
        case 431 => "Request Header Fields Too Large"
        case 451 => "Unavailable For Legal Reasons"
        case 500 => "Internal Server Error"
        case 501 => "Not Implemented"
        case 502 => "Bad Gateway"
        case 503 => "Service Unavailable"
        case 504 => "Gateway Timeout"
        case 505 => "HTTP Version Not Supported"
        case 506 => "Variant Also Negotiates"
        case 507 => "Insufficient Storage"
        case 508 => "Loop Detected"
        case 510 => "Not Extended"
        case 511 => "Network Authentication Required"
        case _ => ""
    }
}
