package http_lib.connection

/**
 * 连接基类，提供通用的连接管理功能.
 * 
 * 记录连接的建立时间、最近活动时间、地址信息和超时配置。
 * 子类通过继承获得 isConnected()、canReuseTransport() 等基础状态查询，
 * 以及活动时间戳更新（updateActivity）和读写超时设置方法。
 */

import std.time.DateTime

/**
 * 连接基类，提供通用的连接管理功能.
 */
public abstract class AbstractConnection <: Connection {
    protected var connected: Bool = false
    protected var localAddr: String = ""
    protected var remoteAddr: String = ""
    protected var connectedTime: DateTime = DateTime.now()
    protected var lastActivity: DateTime = DateTime.now()
    protected var readTimeout: ?Duration = None
    protected var writeTimeout: ?Duration = None

    public open func isConnected(): Bool { connected }

    public open func canReuseTransport(): Bool { connected }

    public func localAddress(): String { localAddr }
    public func remoteAddress(): String { remoteAddr }
    public func connectedAt(): DateTime { connectedTime }
    public func lastActivityAt(): DateTime { lastActivity }

    public func updateActivity(): Unit {
        lastActivity = DateTime.now()
    }

    public open func setReadTimeout(timeout: Duration): Unit {
        readTimeout = Some(timeout)
    }

    public open func setWriteTimeout(timeout: Duration): Unit {
        writeTimeout = Some(timeout)
    }

    public open func setTimeout(timeout: Duration): Unit {
        readTimeout = Some(timeout)
        writeTimeout = Some(timeout)
    }

    protected func isTimedOut(startTime: DateTime, timeout: ?Duration): Bool {
        match (timeout) {
            case Some(t) => DateTime.now() - startTime > t
            case None => false
        }
    }

    public open func connectionState(): ?ConnectionState { None }
}
