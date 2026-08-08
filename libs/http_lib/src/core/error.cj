package http_lib.core

/**
 * HTTP 库基础异常类。
 * 所有 HTTP 相关异常均继承自此类。
 * 提供统一的异常层次结构，使上层调用者可以按类型统一捕获。
 * 子类覆盖含义更具体的场景。
 */
open public class HttpException <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * URL 格式无效时抛出的异常。
 *
 * 在客户端构造请求时，若传入的 URL 无法被 ParsedUrl.parse()
 * 解析（例如缺少协议、非法字符、格式错误），则抛出此异常。
 */
public class InvalidUrlException <: HttpException {
    public init(url: String) {
        super("无效的 URL: ${url}")
    }
}

/**
 * 连接建立失败时抛出的异常。
 *
 * 当 TCP 连接、TLS 握手或代理隧道建立过程中发生网络错误时抛出。
 * 通常由连接超时、DNS 解析失败或对端拒绝连接导致。
 */
public class ConnectionException <: HttpException {
    public init(host: String) {
        super("连接失败: ${host}")
    }
}

/**
 * 操作超时时抛出的异常。
 *
 * 在连接建立、请求传输或响应读取过程的等待时间超过
 * 各自配置的超时时间时抛出。超时值由 HttpTransport
 * 或 HttpServerConfig 中的字段控制。
 */
public class HttpTimeoutException <: HttpException {
    public init(operation: String) {
        super("操作超时: ${operation}")
    }
}

/**
 * HTTP 协议违规时抛出的异常。
 *
 * 在解析请求/响应时遇到不符合 RFC 7230/RFC 7231 格式的数据时抛出。
 * 常见场景：畸形的请求行、无效的头部字段、非法传输编码、
 * Content-Length 与 Transfer-Encoding 冲突。
 * 服务器在捕获此异常后应返回 400 Bad Request。
 */
public class ProtocolException <: HttpException {
    public init(message: String) {
        super(message)
    }
}

/**
 * 对象生命周期状态异常。
 *
 * 在对象状态不满足操作前提时抛出。常见场景：
 * 连接已关闭后继续读写、已销毁的缓冲区操作、未初始化的组件调用。
 */
public class HttpIllegalStateException <: HttpException {
    public init(message: String) {
        super(message)
    }
}

/**
 * 重定向次数超过上限时抛出的异常。
 *
 * 客户端在自动跟随重定向时，若跟踪次数达到 maxRedirects 限制，
 * 则停止跳转并抛出此异常，防止无限重定向循环。
 */
public class RedirectLimitExceededException <: HttpException {
    public init(maxRedirects: Int64) {
        super("重定向次数超过上限 (${maxRedirects})")
    }
}

/**
 * 不支持当前操作时抛出的异常。
 *
 * 当请求的操作在当前配置或连接状态下不可用时抛出。
 * 例如 HTTP/2 服务端推送在未启用时被调用，
 * 或不支持 TLS 的构建中尝试建立 TLS 连接。
 */
public class BodyReadAfterCloseException <: HttpException {
    public init() {
        super("body already closed")
    }
}

public class UnsupportedOperationException <: HttpException {
    public init(message: String) {
        super(message)
    }
}
