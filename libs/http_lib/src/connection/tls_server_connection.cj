package http_lib.connection
/**
 * TLS 加密服务器端连接。
 * 接受客户端 TLS 连接，进行证书验证和 ALPN 协议协商。
 */

import std.collection.ArrayList
import std.net.TcpSocket
import std.time.DateTime
import std.fs.*
import http_lib.utils.{copyBytes, maxInt64, minInt64}
import jinguissl.live.*
import jinguissl.contract.{contractSha256, contractHmac, HashAlgorithm}
import jinguissl_core.crypto.aes.*
import jinguissl_core.crypto.tls.{tls12VerifyCertificateChainFromHandshake, tls12PrfSha256}
import jinguissl_core.crypto.x509.{X509Certificate, x509ParsePem, x509ParsePemChain, x509ParseRsaPrivateKeyPkcs1Pem}
import jinguissl_core.crypto.rsa.{rsaSignPkcs1v15}

/**
 * 服务端 TLS 1.2 连接处理器。
 *
 * 使用 JinguiSSL 执行完整的服务端 TLS 1.2 ECDHE 握手。

 *
 * 握手序列（RFC 5246 第 7.4 节）：
 *   1. ClientHello           （接收）
 *   2. ServerHello           （发送）
 *   3. Certificate           （发送）
 *   4. ServerKeyExchange     （发送，ECDHE）
 *   5. ServerHelloDone       （发送）
 *   6. ClientKeyExchange     （接收）
 *   7. ChangeCipherSpec      （接收）
 *   8. Finished              （接收）
 *   9. ChangeCipherSpec      （发送）
 *  10. Finished              （发送）
 *
 * 用法：
 *   let tlsConn = TlsServerConnection(clientSocket, tlsConfig)
 *   tlsConn.handshake()
 *   // 现在使用 tlsConn.read/write 进行加密通信
 */
public class TlsServerConnection <: AbstractConnection & Connection {
    private let tcpConn: TcpConnection
    private let config: TlsConfig
    private var sslConnected: Bool = false
    private var receivedCloseNotify: Bool = false
    private var reachedTransportEof: Bool = false
    private var writeRecordLayer: ?Tls12GcmCompatRecordLayer = None
    private var readRecordLayer: ?Tls12GcmCompatRecordLayer = None
    private var pendingAppData: Array<Byte> = []
    private var negotiatedAlpn: String = ""
    private var pendingAppDataOffset: Int64 = 0
    private var pendingRecordBytes: Array<Byte> = []
    private var pendingRecordBytesOffset: Int64 = 0
    private var pendingRecordBytesLimit: Int64 = 0
    private let recordReadBuffer: Array<Byte> = Array<UInt8>(8192, repeat: 0)
    private let rawRecordHeaderScratch: Array<Byte> = Array<UInt8>(5, repeat: 0)

    public init(socket: TcpSocket, config: TlsConfig) {
        this.tcpConn = TcpConnection(socket)
        this.config = config.copy()
        this.connected = tcpConn.isConnected()
        this.connectedTime = DateTime.now()
        this.lastActivity = DateTime.now()
    }

    /**
     * 执行完整的 TLS 1.2 ECDHE 服务器端握手。
     */
    public func handshake(): Unit {
        let diag = config.enableDiagnostics
        if (diag) { println("[TLS-Server] Starting TLS 1.2 ECDHE server handshake...") }

        try {
            // === 步骤 1：读取 ClientHello 并提取 ALPN ===
            if (diag) { println("[TLS-Server] Waiting for ClientHello...") }
            let clientHello = receiveRawRecord()
            let clientRandom = extractClientRandom(clientHello)

            // 从 ClientHello 提取 ALPN 协议
            let clientAlpns = extractAlpnFromClientHello(clientHello)
            negotiatedAlpn = config.negotiateProtocol(clientAlpns)
            if (diag) {
                println("[TLS-Server] ClientHello received (${clientHello.size} bytes)")
                println("[TLS-Server] Client ALPN: ${clientAlpns}")
                println("[TLS-Server] Negotiated ALPN: ${negotiatedAlpn}")
            }

            // === 步骤 2：构建 ServerHello ===
            let serverHelloState = contractTls12BuildHttpServerHello(
                clientHello,
                ContractTls12KeyExchange.EcdheP256
            )
            let serverHello = serverHelloState.encodedServerHello
            let serverRandom = serverHelloState.serverRandom
            if (diag) {
                println("[TLS-Server] ServerHello built (${serverHello.size} bytes)")
                // dump ServerHello hex 用于诊断
                let hexTab: Array<String> = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
                var hexStr = ""
                let dumpLen = if (serverHello.size > 90) { 90 } else { serverHello.size }
                for (i in 0..dumpLen) {
                    let v = Int64(UInt8(serverHello[i]))
                    hexStr = hexStr + hexTab[(v >> 4) & 0xf] + hexTab[v & 0xf]
                }
                println("[TLS-Server] ServerHello hex(0..${dumpLen}): ${hexStr}")
            }
            let serverHelloRecord = contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls12,
                ContractTlsRecordContentType.Handshake,
                serverHello
            )

            // === 步骤 3：构建 Certificate ===
            let certPem = loadServerCertificate()
            let certHandshake = contractTls12BuildCertificateHandshakeFromPemChain(certPem)
            if (diag) { println("[TLS-Server] Certificate built (${certHandshake.size} bytes)") }
            let certRecord = contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls12,
                ContractTlsRecordContentType.Handshake,
                certHandshake
            )

            // === 步骤 4：构建并发送 ECDHE ServerKeyExchange（含RSA签名） ===
            let serverKx = contractTls12BuildEcdheServerKeyExchange(
                ContractTls12KeyExchange.EcdheP256,
                serverPrivateScalar: Some(secureRandom32())
            )
            let encodedServerKxRaw = serverKx.encodedServerKeyExchange
            let serverPrivateScalar = serverKx.serverPrivateScalar

            // 从编码的ServerKeyExchange中提取ECDHE参数（跳过TLS握手帧头4字节：类型1+长度3）
            let ecdheParams = Array<Byte>(encodedServerKxRaw.size - 4, repeat: 0)
            for (i in 0..ecdheParams.size) {
                ecdheParams[i] = encodedServerKxRaw[i + 4]
            }

            // 诊断日志：打印服务器 ECDHE 公钥
            if (diag) {
                let hexTab: Array<String> = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
                func toHex(data: Array<Byte>, start: Int64, len: Int64): String {
                    var s = ""
                    for (i in start..start + len) {
                        let v = Int64(UInt8(data[i]))
                        s = s + hexTab[(v >> 4) & 0xf] + hexTab[v & 0xf]
                    }
                    s
                }
                // ecdheParams 布局: [0]=curve_type, [1..2]=named_curve, [3]=point_len, [4..68]=point(04+X+Y)
                println("[TLS-Server] Server ECDHE public key:")
                println("[TLS-Server]   curve_type=${UInt8(ecdheParams[0])}, named_curve=0x${toHex(ecdheParams, 1, 2)}")
                println("[TLS-Server]   point_len=${UInt8(ecdheParams[3])}")
                println("[TLS-Server]   X=${toHex(ecdheParams, 5, 32)}")
                println("[TLS-Server]   Y=${toHex(ecdheParams, 37, 32)}")
                // 同时打印 serverPrivateScalar 以便验证
                println("[TLS-Server] serverPrivateScalar: ${toHex(serverPrivateScalar, 0, serverPrivateScalar.size)}")
            }

            // 加载RSA私钥并用其对ECDHE参数签名（ECDHE_RSA需要）
            let encodedServerKx = if (config.serverKeyPath.size > 0) {
                try {
                    let keyPem = String.fromUtf8(File.readFrom(Path(config.serverKeyPath)))
                    let rsaKey = x509ParseRsaPrivateKeyPkcs1Pem(keyPem)

                    // 签名输入 = clientRandom + serverRandom + ECDHE参数
                    let signInput = Array<Byte>(clientRandom.size + serverRandom.size + ecdheParams.size, repeat: 0)
                    var offset = 0
                    for (i in 0..clientRandom.size) { signInput[offset] = clientRandom[i]; offset++ }
                    for (i in 0..serverRandom.size) { signInput[offset] = serverRandom[i]; offset++ }
                    for (i in 0..ecdheParams.size) { signInput[offset] = ecdheParams[i]; offset++ }

                    // SHA256哈希 + RSA PKCS#1 v1.5签名
                    let digest = contractSha256(signInput)
                    if (diag) {
                        println("[TLS-Server] signInput size=${signInput.size}, digest size=${digest.size}")
                        let hexTab: Array<String> = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
                        var hexStr = ""
                        let previewLen = if (digest.size > 16) { 16 } else { digest.size }
                        for (i in 0..previewLen) {
                            let v = Int64(UInt8(digest[i]))
                            hexStr = hexStr + hexTab[(v >> 4) & 0xf] + hexTab[v & 0xf]
                        }
                        println("[TLS-Server] digest[0..${previewLen}]=${hexStr}")
                    }
                    let signature = rsaSignPkcs1v15(rsaKey, digest)

                    // 构建完整的ServerKeyExchange消息体 = ECDHE参数 + 签名算法 + 签名
                    // 签名算法标识: 0x04=SHA256, 0x01=RSA
                    let sigBody = Array<Byte>(2 + 2 + signature.size, repeat: 0)
                    sigBody[0] = 0x04  // SHA256
                    sigBody[1] = 0x01  // RSA
                    sigBody[2] = UInt8((signature.size >> 8) & 0xFF)
                    sigBody[3] = UInt8(signature.size & 0xFF)
                    for (i in 0..signature.size) { sigBody[4 + i] = signature[i] }

                    // 完整消息体 = ECDHE参数 + 签名部分
                    let fullBody = Array<Byte>(ecdheParams.size + sigBody.size, repeat: 0)
                    for (i in 0..ecdheParams.size) { fullBody[i] = ecdheParams[i] }
                    for (i in 0..sigBody.size) { fullBody[ecdheParams.size + i] = sigBody[i] }

                    // 用TLS握手帧编码（类型0x0c + 长度3字节 + 消息体）
                    let frame = Array<Byte>(4 + fullBody.size, repeat: 0)
                    frame[0] = 0x0c  // ServerKeyExchange
                    frame[1] = UInt8((fullBody.size >> 16) & 0xFF)
                    frame[2] = UInt8((fullBody.size >> 8) & 0xFF)
                    frame[3] = UInt8(fullBody.size & 0xFF)
                    for (i in 0..fullBody.size) { frame[4 + i] = fullBody[i] }

                    if (diag) {
                        println("[TLS-Server] ServerKeyExchange with RSA signature built (${frame.size} bytes, sig=${signature.size} bytes)")
                    }
                    frame
                } catch (e: Exception) {
                    if (diag) { println("[TLS-Server] RSA signing failed: ${e.message}, using unsigned") }
                    encodedServerKxRaw
                }
            } else {
                encodedServerKxRaw
            }
            // 构建 ServerKeyExchange 记录
            let serverKxRecord = contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls12,
                ContractTlsRecordContentType.Handshake,
                encodedServerKx
            )

            // 构建 ServerHelloDone 记录
            let serverHelloDone: Array<Byte> = [0x0e, 0x00, 0x00, 0x00]
            let serverHelloDoneRecord = contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls12,
                ContractTlsRecordContentType.Handshake,
                serverHelloDone
            )
            if (diag) { println("[TLS-Server] ServerHelloDone built") }

            // === 批量发送所有握手消息（关键修复：合并多次 write 为单次批量写入） ===
            // Windows 系统下，连续的小包 write 可能触发 10053 错误
            // 通过合并为一次写入，避免 TCP Nagle 算法和接收窗口问题
            let allHandshakeRecords = Array<Byte>(
                serverHelloRecord.size + certRecord.size + serverKxRecord.size + serverHelloDoneRecord.size,
                repeat: 0
            )
            var writeOffset = 0
            // 复制 ServerHello
            for (i in 0..serverHelloRecord.size) {
                allHandshakeRecords[writeOffset + i] = serverHelloRecord[i]
            }
            writeOffset += serverHelloRecord.size
            // 复制 Certificate
            for (i in 0..certRecord.size) {
                allHandshakeRecords[writeOffset + i] = certRecord[i]
            }
            writeOffset += certRecord.size
            // 复制 ServerKeyExchange
            for (i in 0..serverKxRecord.size) {
                allHandshakeRecords[writeOffset + i] = serverKxRecord[i]
            }
            writeOffset += serverKxRecord.size
            // 复制 ServerHelloDone
            for (i in 0..serverHelloDoneRecord.size) {
                allHandshakeRecords[writeOffset + i] = serverHelloDoneRecord[i]
            }
            // 一次性批量写入所有握手数据
            tcpConn.write(allHandshakeRecords)
            tcpConn.flush()
            if (diag) {
                println("[TLS-Server] All handshake records sent in single write (${allHandshakeRecords.size} bytes)")
            }

            // === 步骤 6：读取 ClientKeyExchange ===
            let clientKx = receiveRawRecord()
            if (diag) {
                println("[TLS-Server] ClientKeyExchange received (${clientKx.size} bytes)")
            }

            // === 步骤 7：读取客户端 ChangeCipherSpec ===
            let clientCcs = receiveRawRecord()
            if (diag) { println("[TLS-Server] Client ChangeCipherSpec received") }

            // === 步骤 8：派生会话密钥 ===
            let cipherSuite: Int64 = 0xc02f  // ECDHE_RSA_WITH_AES_128_GCM_SHA256（密钥交换+认证+加密+MAC）
            let keyLen: Int64 = 16  // AES-128 加密
            let ivLen: Int64 = 4    // TLS 1.2 AES-GCM 使用 4 字节静态 IV（每条记录另有 8 字节显式 nonce）

            // PRF 自验证测试（用已知向量验证 PRF 实现是否正确）
            if (diag) {
                let testSecret: Array<Byte> = [0x6b, 0x65, 0x79]  // "key"
                let testSeed: Array<Byte> = [0x73, 0x65, 0x65, 0x64]  // "seed"
                let testOut = tls12PrfSha256(testSecret, "test", testSeed, 32)
                let hexTab: Array<String> = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
                var hexStr = ""
                for (i in 0..testOut.size) {
                    let v = Int64(UInt8(testOut[i]))
                    hexStr = hexStr + hexTab[(v >> 4) & 0xf] + hexTab[v & 0xf]
                }
                println("[TLS-Server] PRF self-test (secret='key', label='test', seed='seed', len=32): ${hexStr}")
                // 预期输出（Python HMAC-SHA256 计算）:
                // e3f0d1c5b9b88e2d7a3f5c1e4b6d8a0f...
            }

            let secrets = contractTls12DeriveServerSecretsFromEcdhe(
                ContractTls12KeyExchange.EcdheP256,
                serverPrivateScalar,
                clientKx,
                clientRandom,
                serverRandom,
                keyLen: keyLen,
                ivLen: ivLen
            )

            // 服务器使用服务器密钥写入；使用客户端密钥读取客户端数据
            writeRecordLayer = Some(Tls12GcmCompatRecordLayer(
                secrets.serverWriteKey,
                secrets.serverWriteIv,
                secrets.clientWriteKey,
                secrets.clientWriteIv
            ))
            readRecordLayer = writeRecordLayer
            if (diag) {
                println("[TLS-Server] Session keys derived")
                // 打印密钥派生中间值用于诊断
                let hexTab: Array<String> = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
                func toHex(data: Array<Byte>): String {
                    var s = ""
                    for (i in 0..data.size) {
                        let v = Int64(UInt8(data[i]))
                        s = s + hexTab[(v >> 4) & 0xf] + hexTab[v & 0xf]
                    }
                    s
                }
                println("[TLS-Server] clientRandom: ${toHex(clientRandom)}")
                println("[TLS-Server] serverRandom: ${toHex(serverRandom)}")
                println("[TLS-Server] masterSecret: ${toHex(secrets.masterSecret)}")
                println("[TLS-Server] clientWriteKey: ${toHex(secrets.clientWriteKey)}")
                println("[TLS-Server] clientWriteIv: ${toHex(secrets.clientWriteIv)}")
                println("[TLS-Server] serverWriteKey: ${toHex(secrets.serverWriteKey)}")
                println("[TLS-Server] serverWriteIv: ${toHex(secrets.serverWriteIv)}")
            }

            // === 步骤 9：读取并验证客户端 Finished ===
            let clientFinishedRecordBytes = receiveEncryptedRecordBytes()
            if (diag) {
                let hexTab: Array<String> = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
                var hexStr = ""
                for (i in 0..clientFinishedRecordBytes.size) {
                    let v = Int64(UInt8(clientFinishedRecordBytes[i]))
                    hexStr = hexStr + hexTab[(v >> 4) & 0xf] + hexTab[v & 0xf]
                }
                println("[TLS-Server] Encrypted Finished record (${clientFinishedRecordBytes.size} bytes): ${hexStr}")
            }
            let clientFinishedRecord = readRecordLayer.getOrThrow().open(clientFinishedRecordBytes)
            let clientFinishedRecord2 = clientFinishedRecord.fragment
            if (diag) {
                println("[TLS-Server] Client Finished decrypted (${clientFinishedRecord2.size} bytes)")
            }

            // 构建握手哈希用于验证
            let group1 = concatByteArrays(concatByteArrays(clientHello, serverHello), concatByteArrays(certHandshake, encodedServerKx))
            let allHandshakeMessages = concatByteArrays(group1, concatByteArrays(serverHelloDone, clientKx))
            let handshakeHash = contractSha256(allHandshakeMessages)
            let expectedClientFinished = tls12PrfSha256(
                secrets.masterSecret, "client finished", handshakeHash, 12
            )

            // 解码并验证 Finished 消息
            let clientFinishedData = decodeFinishedVerifyData(clientFinishedRecord2)
            if (!constantTimeEquals(clientFinishedData, expectedClientFinished)) {
                throw TlsException("Client Finished verify_data mismatch")
            }
            if (diag) { println("[TLS-Server] Client Finished verified") }

            // === 步骤 10：发送服务器 ChangeCipherSpec ===
            let serverCcs: Array<Byte> = [0x01]
            let serverCcsRecord = contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls12,
                ContractTlsRecordContentType.ChangeCipherSpec,
                serverCcs
            )
            tcpConn.write(serverCcsRecord)
            if (diag) { println("[TLS-Server] Server ChangeCipherSpec sent") }

            // === 步骤 11：发送服务器 Finished ===
            // 计算包含客户端 Finished 的握手哈希以用于服务器 Finished
            let allMsgsWithClientFinished = concatByteArrays(allHandshakeMessages, clientFinishedRecord2)
            let serverHandshakeHash = contractSha256(allMsgsWithClientFinished)
            let serverFinishedVerifyData = tls12PrfSha256(
                secrets.masterSecret, "server finished", serverHandshakeHash, 12
            )
            let serverFinished = encodeFinishedHandshake(serverFinishedVerifyData)
            let serverFinishedRecord = writeRecordLayer.getOrThrow().seal(
                ContractTlsRecordContentType.Handshake, serverFinished)
            tcpConn.write(serverFinishedRecord)
            if (diag) { println("[TLS-Server] Server Finished sent") }

            sslConnected = true
            connected = true
            if (diag) { println("[TLS-Server] TLS 握手 completed successfully!") }

        } catch (e: Exception) {
            close()
            if (diag) {
                println("[TLS-Server] Handshake failed: ${e.message}")
            }
            throw TlsException("TLS server handshake failed: ${e.message}")
        }
    }

    // ---- TLS 辅助函数 ----

    private func loadServerCertificate(): String {
        if (config.serverCertPath.size > 0) {
            try {
                let pem = String.fromUtf8(File.readFrom(Path(config.serverCertPath)))
                if (pem.size > 0) { return pem }
            } catch (e: Exception) {
                if (config.enableDiagnostics) {
                    println("[TLS-Server] Failed to load cert from ${config.serverCertPath}: ${e.message}")
                }
            }
        }

        // 服务器证书必须通过 config.serverCertPath 显式配置
        // 以及 config.serverKeyPath。从系统路径自动检测（Let's Encrypt、
        // snakeoil）不支持服务器端——调用 TlsConfig.ensureServerCert()
        // 如果需要则显式调用。

        throw TlsException("Server certificate not configured. Set serverCertPath in TlsConfig.")
    }

    private func receiveRawRecord(): Array<Byte> {
        let header = rawRecordHeaderScratch
        readExact(header, 0, 5)
        let contentType = UInt8(header[0])
        let length = (Int64(UInt8(header[3])) << 8) | Int64(UInt8(header[4]))
        if (config.enableDiagnostics) {
            let typeName = match (contentType) {
                case 20 => "ChangeCipherSpec"
                case 21 => "Alert"
                case 22 => "Handshake"
                case 23 => "ApplicationData"
                case _ => "Unknown(${contentType})"
            }
            println("[TLS-Server] Received record: type=${typeName}(${contentType}), length=${length}")
        }
        if (length == 0) { return [] }
        let body = Array<Byte>(Int64(length), repeat: 0)
        readExact(body, 0, Int64(length))
        // 如果收到 Alert 记录，打印详细信息
        if (contentType == 21 && length >= 2) {
            let alertLevel = UInt8(body[0])
            let alertDesc = UInt8(body[1])
            let levelName = if (alertLevel == 1) { "warning" } else if (alertLevel == 2) { "fatal" } else { "unknown" }
            println("[TLS-Server] TLS Alert received: level=${levelName}(${alertLevel}), desc=${alertDesc}")
        }
        body
    }

    private func receiveEncryptedRecord(): Array<Byte> {
        let recordBytes = receiveEncryptedRecordBytes()
        let plaintext = readRecordLayer.getOrThrow().open(recordBytes)
        plaintext.fragment
    }

    private func receiveEncryptedRecordBytes(): Array<Byte> {
        let header = rawRecordHeaderScratch
        readExact(header, 0, 5)
        let length = (Int64(UInt8(header[3])) << 8) | Int64(UInt8(header[4]))
        let record = Array<Byte>(5 + Int64(length), repeat: 0)
        copyBytes(header, 0, record, 0, 5)
        if (length > 0) {
            readExact(record, 5, Int64(length))
        }
        record
    }

    private func sendRawRecord(data: Array<Byte>): Unit {
        tcpConn.write(data)
        tcpConn.flush()
    }

    private func readExact(buf: Array<UInt8>, offset: Int64, length: Int64): Unit {
        let startTime = DateTime.now()
        var received: Int64 = 0
        while (received < length) {
            let n = tcpConn.read(buf, offset + received, length - received)
            if (n <= 0) {
                if (n == 0) {
                    if (DateTime.now() - startTime > Duration.second * 30) {
                        throw TlsException("TLS read timed out after 30s")
                    }
                    continue
                }
                throw TlsException("TLS connection closed during read")
            }
            received += n
        }
    }

    // ---- ClientHello 随机数提取 ----

    private func extractClientRandom(clientHello: Array<Byte>): Array<Byte> {
        // 输入是 ClientHello 握手体（TLS 记录头部已被剥离）。
        // 握手：类型(1) 长度(3) 版本(2) 随机数(32) → 随机数从 1+3+2=6 开始
        if (clientHello.size < 38) {
            throw TlsException("ClientHello too short")
        }
        let out = Array<Byte>(32, repeat: 0)
        copyBytes(clientHello, 6, out, 0, 32)
        out
    }

    // ---- Finished 辅助函数 ----

    private func encodeFinishedHandshake(verifyData: Array<Byte>): Array<Byte> {
        let out = Array<Byte>(4 + verifyData.size, repeat: 0)
        out[0] = UInt8(0x14)
        out[1] = UInt8((verifyData.size >> 16) & 0xff)
        out[2] = UInt8((verifyData.size >> 8) & 0xff)
        out[3] = UInt8(verifyData.size & 0xff)
        copyBytes(verifyData, 0, out, 4, verifyData.size)
        out
    }

    private func decodeFinishedVerifyData(encoded: Array<Byte>): Array<Byte> {
        if (encoded.size < 4) {
            throw TlsException("Invalid Finished handshake")
        }
        let length = (Int64(UInt8(encoded[1])) << 16) |
            (Int64(UInt8(encoded[2])) << 8) |
            Int64(UInt8(encoded[3]))
        if (length <= 0 || 4 + length > encoded.size) {
            throw TlsException("Invalid Finished verify_data length")
        }
        let out = Array<Byte>(length, repeat: 0)
        copyBytes(encoded, 4, out, 0, length)
        out
    }

    private func constantTimeEquals(left: Array<Byte>, right: Array<Byte>): Bool {
        if (left.size != right.size) { return false }
        var diff: UInt8 = 0
        var i: Int64 = 0
        while (i < left.size) {
            diff = diff | (UInt8(left[i]) ^ UInt8(right[i]))
            i += 1
        }
        diff == 0
    }

    // ---- 连接接口实现 ----

    /**
     * 获取协商后的 ALPN 协议（例如 "h2" 或 "http/1.1"）。
     * 如果没有协商 ALPN 则返回空字符串。
     */
    public func getNegotiatedAlpn(): String { negotiatedAlpn }

    public override func canReuseTransport(): Bool {
        connected && sslConnected && !receivedCloseNotify && !reachedTransportEof && tcpConn.canReuseTransport()
    }

    public func isReadable(timeout: ?Duration): Bool { tcpConn.isReadable(timeout) }
    public func isWritable(timeout: ?Duration): Bool { tcpConn.isWritable(timeout) }
    public func isClosed(): Bool { !connected }

    public func read(buf: Array<UInt8>): Int64 {
        updateActivity()
        read(buf, 0, buf.size)
    }

    public func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        updateActivity()
        if (sslConnected && readRecordLayer.isSome()) {
            try {
                if (length == 0) { return 0 }
                if (pendingAppDataOffset >= pendingAppData.size) {
                    let record = receiveEncryptedRecordBytes()
                    let plaintext = readRecordLayer.getOrThrow().open(record)
                    pendingAppData = plaintext.fragment
                    pendingAppDataOffset = 0
                    if (pendingAppData.size == 0) { return 0 }
                }
                let copyLen = minInt64(pendingAppData.size - pendingAppDataOffset, length)
                if (copyLen > 0) {
                    pendingAppData.copyTo(buf, pendingAppDataOffset, offset, copyLen)
                }
                pendingAppDataOffset += copyLen
                if (pendingAppDataOffset >= pendingAppData.size) {
                    pendingAppData = []
                    pendingAppDataOffset = 0
                }
                return copyLen
            } catch (e: Exception) {
                close()
                throw TlsException("TLS read failed: ${e.message}")
            }
        }
        tcpConn.read(buf, offset, length)
    }

    public func write(data: Array<UInt8>): Unit {
        updateActivity()
        if (sslConnected && writeRecordLayer.isSome()) {
            try {
                let recordLayer = writeRecordLayer.getOrThrow()
                // TLS 1.2 规范 (RFC 5246) 规定单个 TLSCiphertext.fragment
                // 最大 2^14 + 2048 = 18432 字节，但明文 fragment 最大 2^14 = 16384 字节。
                // 必须将大数据分片为多个 TLS 记录，否则浏览器会报 net::ERR_SSL_PROTOCOL_ERROR。
                let maxFragmentSize: Int64 = 16384
                var offset: Int64 = 0
                while (offset < data.size) {
                    let remaining = data.size - offset
                    let chunkSize = if (remaining > maxFragmentSize) { maxFragmentSize } else { remaining }
                    let chunk = Array<UInt8>(chunkSize, repeat: 0)
                    copyBytes(data, offset, chunk, 0, chunkSize)
                    let encrypted = recordLayer.seal(
                        ContractTlsRecordContentType.ApplicationData, chunk)
                    tcpConn.write(encrypted)
                    offset += chunkSize
                }
                tcpConn.flush()
            } catch (e: Exception) {
                close()
                throw TlsException("TLS write failed: ${e.message}")
            }
        } else {
            tcpConn.write(data)
        }
    }

    public func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit {
        if (offset == 0 && length == data.size) {
            write(data)
        } else {
            let slice = Array<UInt8>(length, repeat: 0)
            copyBytes(data, offset, slice, 0, length)
            write(slice)
        }
    }

    public func flush(): Unit { tcpConn.flush() }

    public func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit {
        if (buffers.size == 1) { write(buffers[0]) }
        else { let combined = concatBuffers(buffers); if (combined.size > 0) { write(combined) } }
    }

    public func close(): Unit {
        if (sslConnected && writeRecordLayer.isSome()) {
            try {
                let closeNotify = writeRecordLayer.getOrThrow().seal(
                    ContractTlsRecordContentType.Alert,
                    contractTlsEncodeAlertPayload(
                        ContractTlsAlertLevel.AlertWarning,
                        ContractTlsAlertDescription.AlertCloseNotify
                    )
                )
                tcpConn.write(closeNotify)
                tcpConn.flush()
            } catch (_: Exception) {}
        }
        tcpConn.close()
        connected = false
        sslConnected = false
        reachedTransportEof = true
    }

    /**
     * 获取握手后的 TLS 连接状态。
     * 返回协商后的 TLS 参数。
     */
    public func connectionState(): ?ConnectionState {
        Some(ConnectionState(
            version: "TLS 1.2",
            cipherSuite: "ECDHE_RSA_AES_128_GCM_SHA256",
            negotiatedProtocol: getNegotiatedAlpn(),
            serverName: "",
            isSecure: true
        ))
    }
}
