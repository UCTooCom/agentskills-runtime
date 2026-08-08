package http_lib.client
/**
 * HTTP 客户端追踪：请求/响应传播的 trace ID 支持。
 * 提供 OpenTelemetry 兼容的分布式追踪上下文管理。
 */

/**
 * HTTP 客户端诊断跟踪系统。
 * 提供请求生命周期中各阶段的事件钩子，
 * 包括 DNS 解析、连接建立、TLS 握手、请求发送、
 * 响应接收和重定向等阶段的时间点上报。
 */

/**
 * ClientTrace 请求诊断钩子（HTTP 请求生命周期事件）。

 *
 * 在 HttpClientConfig 上设置 ClientTrace 以观察连接建立、
 * TLS 握手以及请求/响应时序，用于诊断和日志记录。
 *
 * 用法：
 *   let trace = ClientTrace()
 *   trace.connectStartHook = {network, addr => println("正在连接到 ${addr}")}
 *   trace.connectDoneHook = {network, addr, err => println("已连接")}
 *   let config = HttpClientConfig()
 *   config.trace = trace
 *   let client = HttpClient(config: config)
 */
public class ClientTrace {
    /**
     * 当 DNS 查找开始时调用。
     * @param host 正在解析的主机名
     */
    public var dnsStartHook: ?(String) -> Unit = None

    /**
     * 当 DNS 查找完成时调用。
     * @param host 已解析的主机名
     * @param addrs 已解析的地址（失败时为空）
     */
    public var dnsDoneHook: ?(String, Array<String>) -> Unit = None

    /**
     * 当 TCP 连接即将建立时调用。
     * @param network "tcp" 或 "tcp6"
     * @param addr "主机:端口"
     */
    public var connectStartHook: ?(String, String) -> Unit = None

    /**
     * 当 TCP 连接完成（或失败）时调用。
     * @param network "tcp" 或 "tcp6"
     * @param addr "主机:端口"
     * @param err 错误消息，成功时为空
     */
    public var connectDoneHook: ?(String, String, String) -> Unit = None

    /**
     * Called when the TLS 握手 starts.
     */
    public var tlsHandshakeStartHook: ?() -> Unit = None

    /**
     * Called when the TLS 握手 completes.
     * @param version TLS 版本字符串（例如 "TLS 1.2"）
     * @param cipherSuite 密码套件名称
     * @param err 错误消息，成功时为空
     */
    public var tlsHandshakeDoneHook: ?(String, String, String) -> Unit = None

    /**
     * 当获取连接（从池中或新建）时调用。
     * @param reused 连接是否从连接池复用
     */
    public var gotConnectionHook: ?(Bool) -> Unit = None

    /**
     * 在完整请求写入连接后调用。
     */
    public var wroteRequestHook: ?() -> Unit = None

    /**
     * 当收到第一个响应字节时调用。
     */
    public var gotFirstResponseByteHook: ?() -> Unit = None

    public init() {}
}
