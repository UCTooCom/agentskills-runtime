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

public class MVCConfig {
    private static const confPrefix = "mvc"
    public static let DOWNLOAD_BUFFER_SIZE = "${confPrefix}_downloadHalfBufferSize"
    public static const DEFAULT_DOWNLOAD_BUFFER_SIZE = 4096

    public static let MVC_DEBUGGING = "${confPrefix}_debugging"
    public static const DEFAULT_MVC_DEBUGGING = false

    public static let ACCESS_CONTROL_ALLOW_ORIGIN = "${confPrefix}_accessControlAllowOrigin"
    public static const DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN = "*"

    public static let ACCESS_CONTROL_ALLOW_HEADERS = "${confPrefix}_accessControlAllowHeaders"
    public static const DEFAULT_ACCESS_CONTROL_ALLOW_HEADERS = "*"

    public static let ACCESS_CONTROL_MAX_AGE = "${confPrefix}_accessControlMaxAge"
    public static const DEFAULT_ACCESS_CONTROL_MAX_AGE = 0

    public static const DEFAULT_PRIVILEGE_FAILURE_MESSAGE_KIND = FailureMessageKind.Text

    public static let HOST = "${confPrefix}_host"
    public static let PORT = "${confPrefix}_port"
    public static let READ_TIMEOUT = "${confPrefix}_readTimeout"
    public static let WRITE_TIMEOUT = "${confPrefix}_writeTimeout"
    public static let READ_HEADER_TIMEOUT = "${confPrefix}_readHeaderTimeout"
    public static let KEEP_ALIVE_TIMEOUT = "${confPrefix}_keepAliveTimeout"
    public static let MAX_REQUEST_HEADER_SIZE = "${confPrefix}_maxRequestHeaderSize"
    public static let MAX_REQUEST_BODY_SIZE = "${confPrefix}_maxRequestBodySize"
    public static let HEADER_TABLE_SIZE = "${confPrefix}_headerTableSize"
    public static let MAX_CONCURRENT_STREAMS = "${confPrefix}_maxConcurrentSteams"
    public static let INITITAL_WINDOW_SIZE = "${confPrefix}_initialWindowSize"
    public static let MAX_FRAME_SIZE = "${confPrefix}_maxFrameSize"
    public static let MAX_HEADER_LIST_SIZE = "${confPrefix}_maxHeaderListSize"

    public static let SERVICE_POOL_CAPACITY = "${confPrefix}_servicePoolCapacity"
    public static let SERVICE_POOL_QUEUE_CAPACITY = "${confPrefix}_servicePoolQueueCapacity"
    public static let SERVICE_POOL_PREHEAT = "${confPrefix}_servicePoolPreheat"

    public static let TLS_PATH = "${confPrefix}_tlsPath"
    public static let TLS_VERIFY_MODE = "${confPrefix}_tlsVerifyMode"
    public static let TLS_SUPPORTED_ALPN_PROTOCOLS = "${confPrefix}_tlsSupportedAlpnProtocols"

    public static let INTERNAL_SERVER_ERROR_MESSAGE_KIND = "${confPrefix}_internalServerErrorMessageKind"
    public static let INTERNAL_SERVER_ERROR_MESSAGE = "${confPrefix}_internalServerErrorMessage"

    public static let MVC_OVERALL_ELAPSED_SWITCH = "${confPrefix}_overallElapsedSwitch"

    public static prop tlsConfig: ?TlsServerConfig {
        get() {
            if (let Some(path) <- Config.getString(TLS_PATH) && path.size > 0 && let paths <- path.split('|') &&
                paths.size == 2) {
                let x509Pem = String.fromUtf8(File.readFrom(paths[0]))
                let privateKeyPem = String.fromUtf8(File.readFrom(paths[1]))
                let x509 = X509Certificate.decodeFromPem(x509Pem)
                let privateKey = PrivateKey.decodeFromPem(privateKeyPem)
                var tls = TlsServerConfig(x509, privateKey)
                if (let Some(alpn) <- Config.getString(TLS_SUPPORTED_ALPN_PROTOCOLS) && alpn.size > 0 && let alpns <- alpn
                    .split('|') && alpns.size > 0) {
                    tls.supportedAlpnProtocols = alpns
                }
                if (let Some(mode) <- Config.getString(TLS_VERIFY_MODE) && mode.size > 0) {
                    tls.verifyMode = match (mode.toAsciiLower()) {
                        case "trustall" | 'trust_all' | 'trust-all' => TrustAll
                        case "default" => Default
                        case _ =>
                            let modePem = String.fromUtf8(File.readFrom(mode))
                            let custom = X509Certificate.decodeFromPem(modePem)
                            CustomCA(custom)
                    }
                }
                tls
            } else {
                None<TlsServerConfig>
            }
        }
    }

    private static prop isMVCDebugging: Bool {
        get() {
            Config.getValue<Bool>(MVC_DEBUGGING) ?? DEFAULT_MVC_DEBUGGING
        }
    }
    public static prop servicePoolConfig: ?ServicePoolConfig {
        get() {
            let capacity = Config.getValue<Int>(SERVICE_POOL_CAPACITY)
            let queueCapacity = Config.getValue<Int>(SERVICE_POOL_QUEUE_CAPACITY)
            let preheat = Config.getValue<Int>(SERVICE_POOL_PREHEAT)
            match ((capacity, queueCapacity, preheat)) {
                case (Some(c), Some(qc), Some(ph)) => ServicePoolConfig(
                    capacity: c,
                    queueCapacity: qc,
                    preheat: ph
                )
                case (Some(c), Some(qc), Option<Int64>.None) => ServicePoolConfig(
                    capacity: c,
                    queueCapacity: qc
                )
                case (Some(c), Option<Int64>.None, Option<Int64>.None) => ServicePoolConfig(capacity: c)
                case (Option<Int64>.None, Some(qc), Option<Int64>.None) => ServicePoolConfig(queueCapacity: qc)
                case (Some(c), Option<Int64>.None, Some(ph)) => ServicePoolConfig(
                    capacity: c,
                    preheat: ph
                )
                case (Option<Int64>.None, Option<Int64>.None, Some(ph)) => ServicePoolConfig(preheat: ph)
                case (Option<Int64>.None, Some(qc), Some(ph)) => ServicePoolConfig(
                    queueCapacity: qc,
                    preheat: ph
                )
                case _ => None<ServicePoolConfig>
            }
        }
    }
    public static prop host: String {
        get() {
            Config.getString(HOST) ?? "0.0.0.0"
        }
    }
    public static prop port: UInt16 {
        get() {
            let port = Config.getValue<Int>(PORT) ?? 8080
            UInt16(port)
        }
    }
    private static func duration(key: String) {
        match (Config.getString(key)) {
            case Some(x) => Duration.tryParse(x)
            case _ => None<Duration>
        }
    }

    public static prop readTimeout: ?Duration {
        get() {
            duration(READ_TIMEOUT)
        }
    }
    public static prop writeTimeout: ?Duration {
        get() {
            duration(WRITE_TIMEOUT)
        }
    }
    public static prop readHeaderTimeout: ?Duration {
        get() {
            duration(READ_HEADER_TIMEOUT)
        }
    }
    public static prop keepAliveTimeout: ?Duration {
        get() {
            duration(KEEP_ALIVE_TIMEOUT)
        }
    }
    public static prop maxRequestHeaderSize: ?Int64 {
        get() {
            Config.getValue<Int>(MAX_REQUEST_HEADER_SIZE)
        }
    }
    public static prop maxRequestBodySize: ?Int64 {
        get() {
            Config.getValue<Int>(MAX_REQUEST_BODY_SIZE)
        }
    }
    private static func uint32(key: String): ?UInt32 {
        match (Config.getValue<Int>(key)) {
            case Some(x) => UInt32(x)
            case _ => None
        }
    }
    public static prop headerTableSize: ?UInt32 {
        get() {
            uint32(HEADER_TABLE_SIZE)
        }
    }
    public static prop maxConcurrentStreams: ?UInt32 {
        get() {
            uint32(MAX_CONCURRENT_STREAMS)
        }
    }
    public static prop initialWindowSize: ?UInt32 {
        get() {
            uint32(INITITAL_WINDOW_SIZE)
        }
    }
    public static prop maxFrameSize: ?UInt32 {
        get() {
            uint32(MAX_FRAME_SIZE)
        }
    }
    public static prop maxHeaderListSize: ?UInt32 {
        get() {
            uint32(MAX_HEADER_LIST_SIZE)
        }
    }
    private static func getStatus(key: String, default: UInt16) {
        let status = match (Config.getValue<Int>(key)) {
            case Some(x) => UInt16(x)
            case _ => default
        }
        HttpStatus.valueOf(status)
    }
    private static func getMessageKind(key: String, default: FailureMessageKind) {
        match (Config.getString(key)?.trimAscii()) {
            case Some(x) where x.size > 0 => FailureMessageKind.parse(x)
            case _ => default
        }
    }

    public static func getInternalServerErrorMessageKind(){
        getMessageKind(INTERNAL_SERVER_ERROR_MESSAGE_KIND, FailureMessageKind.Text)
    }
    public static func getInternalServerErrorMessage(){
        Config.getString(INTERNAL_SERVER_ERROR_MESSAGE) ?? HttpStatus.INTERNAL_SERVER_ERROR.reasonPhrase
    }

    private static func bufferSize(bufferKey: String, default: Int64) {
        Config.bufferSize(bufferKey, default, isMVCDebugging)
    }
    public static prop downloadBufferSize: Int64 {
        get() {
            bufferSize(DOWNLOAD_BUFFER_SIZE, DEFAULT_DOWNLOAD_BUFFER_SIZE)
        }
    }
    
    public static prop accessControlAllowOrigin: String {
        get() {
            Config.getString(ACCESS_CONTROL_ALLOW_ORIGIN) ?? DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN
        }
    }
    public static prop accessControlAllowHeaders: String {
        get() {
            Config.getString(ACCESS_CONTROL_ALLOW_HEADERS) ?? DEFAULT_ACCESS_CONTROL_ALLOW_HEADERS
        }
    }
    public static prop accessControlMaxAge: Int64 {
        get() {
            Config.getValue<Int>(ACCESS_CONTROL_MAX_AGE) ?? DEFAULT_ACCESS_CONTROL_MAX_AGE
        }
    }
    public static prop mvcOverallElapsedSwitch: Bool {
        get(){
            Config.getValue<Bool>(MVC_OVERALL_ELAPSED_SWITCH) ?? false
        }
    }
}
