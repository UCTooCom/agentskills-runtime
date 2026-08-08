package http_lib.client
/**
 * Cookie Jar：HTTP 客户端 cookie 存储和管理（RFC 6265）。
 * 支持持久化存储、域名/路径匹配和过期淘汰。
 */

import kaca_cookies.{CookieJar as KacaCookieJar, SameSite, StoredCookie}
import std.sync.Mutex
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * CookieJar 自动 Cookie 管理。
 *
 * 封装 kaca_cookies.CookieJar 以提供自动的 Cookie/Set-Cookie
 * HTTP 请求和响应的头部管理。通过 Mutex 实现线程安全。
 */
public class HttpClientCookieJar {
    private var jar: KacaCookieJar
    private var mu: Mutex

    public init() {
        this.jar = KacaCookieJar()
        this.mu = Mutex()
    }

    /**
     * 从响应中提取 Set-Cookie 头部并存储 cookie。
     */
    public func extractCookies(host: String, path: String, isSecure: Bool, response: HttpResponse): Unit {
        synchronized(mu) {
            let setCookieValues = response.headers.getAll("set-cookie")
            if (setCookieValues.size == 0) {
                return
            }
            jar.setCookieStrings(
                setCookieValues,
                requestHost: host,
                requestPath: path,
                isSecureContext: isSecure,
                isFromHttp: true
            )
        }
    }

    /**
     * 获取请求的 Cookie 头部值。
     * 如果没有匹配的 cookie 则返回空字符串。
     */
    public func getCookieHeader(host: String, path: String, isSecure: Bool, isSameSite!: Bool = true): String {
        synchronized(mu) {
            jar.requestCookieHeader(
                requestHost: host,
                requestPath: path,
                isSecureContext: isSecure,
                requestIsSameSite: isSameSite
            )
        }
    }

    /**
     * 通过设置 Cookie 头部将存储的 cookie 应用于请求。
     * getCookieHeader 自行处理锁，因此此处不需要互斥锁。
     */
    public func applyCookies(host: String, path: String, isSecure: Bool, request: HttpRequest): Unit {
        let cookieHeader = getCookieHeader(host, path, isSecure)
        if (cookieHeader.size > 0) {
            request.headers.set("Cookie", cookieHeader)
        }
    }

    /**
     * 清除所有存储的 cookie。
     */
    public func clear(): Unit {
        synchronized(mu) {
            jar.clear()
        }
    }
}
