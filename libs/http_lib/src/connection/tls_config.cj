package http_lib.connection

import std.fs.{File, Path}
import jinguissl_core.crypto.x509.{X509Certificate, x509ParsePemChain}

/**
 * TLS 配置（证书加载、ALPN 设置、系统 CA 探测）。
TLS 配置与证书加载。
 *
 * ALPN（应用层协议协商）用于协商
 * HTTP/2（"h2"）与 HTTP/1.1（"http/1.1"）over TLS 的 ALPN 协商。
 *
 * 对于 HTTP/2 over TLS：
 *   nextProtos 应包含 "h2" 和 "http/1.1"
 *   服务器通告两者；客户端协商双方共同支持的最高协议。
 */
public class TlsConfig {
    public var verifyPeer: Bool = true
    public var verifyHost: Bool = true
    public var enableDiagnostics: Bool = false
    public var caCertPath: String = ""
    public var clientCertPath: String = ""
    public var clientKeyPath: String = ""
    // 服务器 TLS
    public var serverCertPath: String = ""
    public var serverKeyPath: String = ""
    // ALPN 协议协商（按 RFC 7301）
    public var nextProtos: Array<String> = ["h2", "http/1.1"]
    // 最低 TLS 版本（0 = 自动/默认）
    // 注意：当前由 JinguiSSL 在 TLS 1.2 的 ECDHE 中强制执行。
    // 这些字段为未来的 TLS 1.3 支持保留，并且
    // 尚未在握手层面强制执行。将它们设置为 0x0303
    // （TLS 1.2）或 0x0304（TLS 1.3）被接受但没有效果
    // 直到添加 TLS 1.3 支持。
    public var minVersion: UInt16 = 0  // 0x0303 = TLS 1.2, 0x0304 = TLS 1.3（协议版本号）
    public var maxVersion: UInt16 = 0
    // 路径为空时自动加载系统证书
    public var autoLoadSystemCerts: Bool = true

    public init() {}

    /**
     * 客户端默认 TLS 配置（验证对端，使用系统 CA）。
     */
    public static func default(): TlsConfig {
        let config = TlsConfig()
        config.nextProtos = ["h2", "http/1.1"]
        config
    }

    /**
     * 不安全 TLS 配置（跳过证书验证）。
     * 仅用于测试/开发。
     */
    public static func insecure(): TlsConfig {
        let config = TlsConfig()
        config.verifyPeer = false
        config.verifyHost = false
        config.nextProtos = ["h2", "http/1.1"]
        config
    }

    /**
     * 仅 HTTP/1.1 的 TLS 配置（无 HTTP/2 协商）。
     */
    public static func http1Only(): TlsConfig {
        let config = TlsConfig()
        config.nextProtos = ["http/1.1"]
        config
    }

    /**
     * 检查 ALPN 协商中是否启用了 HTTP/2。
    
     */
    public func supportsH2(): Bool {
        for (proto in nextProtos) {
            if (proto == "h2") { return true }
        }
        false
    }

    public func supportsHttp1(): Bool {
        for (proto in nextProtos) {
            if (proto == "http/1.1") { return true }
        }
        false
    }

    /**
     * 从客户端提供的 ALPN 列表中协商最佳协议。
     * 返回 "h2"、"http/1.1"，无匹配则返回 ""。
    
     */
    public func negotiateProtocol(clientProtos: Array<String>): String {
        // 服务器偏好：先尝试 h2，然后 http/1.1
        for (serverProto in nextProtos) {
            for (clientProto in clientProtos) {
                if (serverProto == clientProto) { return serverProto }
            }
        }
        ""
    }

    /**
     * 如果尚未设置，从系统 CA 包自动加载并设置 caCertPath。
     * Called automatically during TLS 握手 when autoLoadSystemCerts is true.
     */
    public func ensureCaCert(): TlsConfig {
        if (caCertPath.size > 0 || !autoLoadSystemCerts) { return this }
        let sysPath = detectSystemCaBundle()
        if (sysPath.size > 0) {
            caCertPath = sysPath
        }
        this
    }

    /**
     * 如果尚未设置，从系统自动加载并设置 serverCertPath。
     * 探测服务器证书的常见位置。
     */
    public func ensureServerCert(): TlsConfig {
        if (serverCertPath.size > 0 || !autoLoadSystemCerts) { return this }
        let sysCert = detectSystemServerCert()
        let sysKey = detectSystemServerKey()
        if (sysCert.size > 0 && sysKey.size > 0) {
            serverCertPath = sysCert
            serverKeyPath = sysKey
        }
        this
    }

    public func copy(): TlsConfig {
        let config = TlsConfig()
        config.verifyPeer = verifyPeer
        config.verifyHost = verifyHost
        config.enableDiagnostics = enableDiagnostics
        config.caCertPath = caCertPath
        config.clientCertPath = clientCertPath
        config.clientKeyPath = clientKeyPath
        config.serverCertPath = serverCertPath
        config.serverKeyPath = serverKeyPath
        config.nextProtos = nextProtos.clone()
        config.minVersion = minVersion
        config.maxVersion = maxVersion
        config.autoLoadSystemCerts = autoLoadSystemCerts
        config
    }
}

/**
 * 检测系统 CA 证书包路径。
 * 探测 Linux 发行版上的常见位置。
 * 返回第一个可读路径，如果未找到则返回空字符串。
 *

 */
public func detectSystemCaBundle(): String {
    let candidatePaths = [
        "/etc/ssl/certs/ca-certificates.crt",           // Debian/Ubuntu 路径
        "/etc/pki/tls/certs/ca-bundle.crt",              // RHEL/CentOS/Fedora 路径
        "/etc/ssl/ca-bundle.pem",                        // OpenSUSE 路径
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", // RHEL 7+ 路径
        "/etc/ssl/cert.pem",                             // Alpine/macOS 路径
        "/usr/local/etc/openssl/cert.pem",               // Homebrew OpenSSL 路径
        "/etc/pki/tls/cacert.pem",                       // 通用路径
        "/etc/ssl/certs/ca-bundle.crt",                  // 备选 Debian 路径
    ]
    for (path in candidatePaths) {
        try {
            let content = String.fromUtf8(File.readFrom(Path(path)))
            if (content.size > 0) {
                return path
            }
        } catch (_: Exception) {
            // 探测下一个路径
        }
    }
    ""
}

/**
 * 检测系统服务器证书（例如用于 HTTPS 服务）。
 * 探测 Let's Encrypt、certbot 和系统默认使用的常见位置。
 * 返回证书文件的路径，或空字符串。
 */
public func detectSystemServerCert(): String {
    let certPaths = [
        "/etc/letsencrypt/live/localhost/fullchain.pem",  // Let's Encrypt 证书
        "/etc/ssl/certs/ssl-cert-snakeoil.pem",           // Debian 自签名证书
        "/etc/pki/tls/certs/localhost.crt",               // 通用路径 localhost
        "/etc/ssl/server.crt",                            // 通用路径
        "/etc/pki/tls/certs/server.crt",                  // RHEL 类型
    ]
    for (path in certPaths) {
        try {
            let content = String.fromUtf8(File.readFrom(Path(path)))
            if (content.size > 0) { return path }
        } catch (_: Exception) {}
    }
    ""
}

/**
 * 检测系统服务器私钥。
 * 探测常见位置，与上述证书位置配对。
 */
public func detectSystemServerKey(): String {
    let keyPaths = [
        "/etc/letsencrypt/live/localhost/privkey.pem",    // Let's Encrypt 证书
        "/etc/ssl/private/ssl-cert-snakeoil.key",         // Debian 自签名证书
        "/etc/pki/tls/private/localhost.key",             // 通用路径 localhost
        "/etc/ssl/server.key",                            // 通用路径
        "/etc/pki/tls/private/server.key",                // RHEL 类型
    ]
    for (path in keyPaths) {
        try {
            let content = String.fromUtf8(File.readFrom(Path(path)))
            if (content.size > 0) { return path }
        } catch (_: Exception) {}
    }
    ""
}

/**
 * 加载并解析系统 CA 证书到 X509Certificate 数组。
 * 返回解析的信任锚，失败时返回空数组。
 */
public func loadSystemCerts(): Array<X509Certificate> {
    let bundlePath = detectSystemCaBundle()
    if (bundlePath.size == 0) { return [] }
    try {
        let pem = String.fromUtf8(File.readFrom(Path(bundlePath)))
        if (pem.size > 0) {
            return x509ParsePemChain(pem)
        }
    } catch (_: Exception) {}
    []
}
