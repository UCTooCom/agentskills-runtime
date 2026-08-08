package jinguissl.live

import std.collection.ArrayList
import jinguissl_core.crypto.ecc.EcPrivateKey
import jinguissl_core.crypto.error.*
import jinguissl_core.crypto.rsa.RsaPrivateKey
import jinguissl_core.crypto.tls.{
    Tls13HandshakeSecrets,
    Tls13ServerHandshakeFlight,
    TlsHttpNegotiationPolicy,
    tls13BuildHttpServerHandshakeContextX25519
}
import jinguissl_core.crypto.x25519.x25519PublicFromPrivate
import jinguissl_core.crypto.x509.{
    X509Certificate,
    x509ParseEcPrivateKeyPkcs8Pem,
    x509ParsePemChain,
    x509ParseRsaPrivateKeyPkcs8Pem
}

class ContractAcceptedTransportTls13X25519Context {
    public let session: ContractHttpServerAcceptedTransportSession
    public let secrets: Tls13HandshakeSecrets
    public let binding: ContractTls13CipherBinding

    public init(
        session: ContractHttpServerAcceptedTransportSession,
        secrets: Tls13HandshakeSecrets,
        binding: ContractTls13CipherBinding
    ) {
        this.session = session
        this.secrets = secrets
        this.binding = binding
    }
}

public func contractBuildHttpServerInitialHandshakeFacade(
    session: ContractHttpServerAcceptedTransportSession
): ContractHttpServerInitialHandshakeFacade {
    session.initialHandshake
}

private func contractBuildHttpServerInitialHandshakeFacadeFromContext(
    flight: ContractTls13HttpServerFlight,
    secrets: Tls13HandshakeSecrets,
    binding: ContractTls13CipherBinding
): ContractHttpServerInitialHandshakeFacade {
    let (clientHandshakeKey, clientHandshakeIv) = contractTls13DeriveApplicationTrafficKeyIv(
        secrets.clientHsTrafficSecret,
        keyLen: binding.keyLen,
        ivLen: binding.ivLen
    )
    let (serverHandshakeKey, serverHandshakeIv) = contractTls13DeriveApplicationTrafficKeyIv(
        secrets.serverHsTrafficSecret,
        keyLen: binding.keyLen,
        ivLen: binding.ivLen
    )
    let handshakeKeyMaterial = ContractTls13ApplicationKeyMaterial(
        clientHandshakeKey,
        clientHandshakeIv,
        serverHandshakeKey,
        serverHandshakeIv
    )
    let handshakeChannel = contractTls13CreateServerRecordChannel(
        handshakeKeyMaterial,
        algorithm: binding.algorithm
    )
    let records = ArrayList<Array<Byte>>()
    records.add(
        contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            flight.serverHello
        )
    )
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.encryptedExtensions))
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.certificateHandshake))
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.certificateVerifyHandshake))
    records.add(handshakeChannel.seal(ContractTlsRecordContentType.Handshake, flight.finishedHandshake))
    ContractHttpServerInitialHandshakeFacade(flight, records.toArray())
}

public func contractAttachAcceptedTransportTls13X25519Request(
    request: ContractHttpServerAcceptedTransportTls13X25519Request
): ContractHttpServerAcceptedTransportSession {
    contractAttachAcceptedTransportTls13X25519(
        request.transport,
        request.plan,
        request.encodedClientHello,
        request.serverKeyExchangePrivate,
        policy: request.policy
    )
}

private func contractWithStableAcceptedTransportSurface(
    session: ContractHttpServerAcceptedTransportSession
): ContractHttpServerAcceptedTransportSession {
    if (!session.secureSessionReady) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "stable accepted transport publication requires a ready secure session"
        )
    }
    ContractHttpServerAcceptedTransportSession(
        session.transport,
        ContractAcceptedTransportSessionStatus.Ready,
        ContractHttpServerAttachResult(
            session.result.serverFlight,
            tlsVersion: session.result.tlsVersion,
            cipherSuite: session.result.cipherSuite,
            negotiatedAlpn: session.result.negotiatedAlpn,
            requestedServerName: session.result.requestedServerName,
            acknowledgedServerName: session.result.acknowledgedServerName,
            secureSessionReady: true,
            attachSurface: "stable-accepted-transport-session"
        ),
        session.initialHandshake,
        session.keyMaterial,
        session.recordChannel
    )
}

public func contractAttachStableAcceptedTransportTls13X25519Request(
    request: ContractHttpServerAcceptedTransportTls13X25519Request
): ContractHttpServerAcceptedTransportSession {
    contractAttachStableAcceptedTransportTls13X25519(
        request.transport,
        request.plan,
        request.encodedClientHello,
        request.serverKeyExchangePrivate,
        policy: request.policy
    )
}

public func contractAttachStableAcceptedTransportTls13X25519(
    transport: ContractAcceptedTransportDescriptor,
    plan: ContractHttpServerAttachPlan,
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpServerAcceptedTransportSession {
    if (!plan.stableAttachGate.readyNow) {
        throw ContractException(
            ContractErrorCode.Unsupported,
            "stable accepted transport attach requires a ready HttpServerStableAttach gate"
        )
    }
    contractWithStableAcceptedTransportSurface(
        contractAttachAcceptedTransportTls13X25519(
            transport,
            plan,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
    )
}

public func contractAttachAcceptedTransportTls13X25519(
    transport: ContractAcceptedTransportDescriptor,
    plan: ContractHttpServerAttachPlan,
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractHttpServerAcceptedTransportSession {
    contractBuildAcceptedTransportTls13X25519Context(
        transport,
        plan,
        encodedClientHello,
        serverKeyExchangePrivate,
        policy: policy
    ).session
}

func contractBuildAcceptedTransportTls13X25519Context(
    transport: ContractAcceptedTransportDescriptor,
    plan: ContractHttpServerAttachPlan,
    encodedClientHello: Array<Byte>,
    serverKeyExchangePrivate: Array<Byte>,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractAcceptedTransportTls13X25519Context {
    try {
        let material = plan.startup.material
        let certChain = x509ParsePemChain(material.certificateChainPemBundle())
        if (certChain.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "accepted transport certificate chain must not be empty")
        }
        let certChainDer = acceptedTransportDerChainFromCertificates(certChain)
        let certificatePrivateKeyRsa: ?RsaPrivateKey = acceptedTransportTryParseRsaPrivateKeyPkcs8Pem(material.privateKeyPem)
        let certificatePrivateKeyEcdsa: ?EcPrivateKey = if (let Some(_value) <- certificatePrivateKeyRsa) {
            None
        } else {
            acceptedTransportTryParseEcPrivateKeyPkcs8Pem(material.privateKeyPem)
        }
        if (
            !acceptedTransportIsSomeRsaPrivateKey(certificatePrivateKeyRsa) &&
            !acceptedTransportIsSomeEcPrivateKey(certificatePrivateKeyEcdsa)
        ) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "accepted transport certificate private key must be PKCS8 RSA or EC"
            )
        }

        let serverKeyShare = x25519PublicFromPrivate(serverKeyExchangePrivate)
        let context = tls13BuildHttpServerHandshakeContextX25519(
            encodedClientHello,
            serverKeyExchangePrivate,
            serverKeyShare,
            certChainDer,
            certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
            certificatePrivateKeyRsa: certificatePrivateKeyRsa,
            policy: acceptedTransportToTlsHttpNegotiationPolicy(policy)
        )
        let flight = acceptedTransportFromTls13ServerHandshakeFlight(context.flight)
        let binding = contractTls13ResolveCipherBindingFromServerFlight(flight)
        let keyMaterial = ContractTls13ApplicationKeyMaterial(
            context.secrets.clientWriteKey,
            context.secrets.clientWriteIv,
            context.secrets.serverWriteKey,
            context.secrets.serverWriteIv
        )
        let serverChannel = contractTls13CreateServerRecordChannel(
            keyMaterial,
            algorithm: binding.algorithm
        )
        let initialHandshake = contractBuildHttpServerInitialHandshakeFacadeFromContext(
            flight,
            context.secrets,
            binding
        )
        let result = ContractHttpServerAttachResult(
            flight,
            tlsVersion: ContractTlsVersion.Tls13,
            cipherSuite: binding.cipherSuiteName,
            negotiatedAlpn: flight.selectedAlpn,
            requestedServerName: flight.requestedServerName,
            acknowledgedServerName: flight.acknowledgedServerName,
            secureSessionReady: true,
            attachSurface: "accepted-transport-session"
        )
        let session = ContractHttpServerAcceptedTransportSession(
            transport,
            ContractAcceptedTransportSessionStatus.Ready,
            result,
            initialHandshake,
            keyMaterial,
            serverChannel
        )
        ContractAcceptedTransportTls13X25519Context(
            session,
            context.secrets,
            binding
        )
    } catch (e: ContractException) {
        throw e
    } catch (e: CryptoException) {
        throw ContractException(
            acceptedTransportMapCryptoErrorForOperation(e, "tls"),
            "accepted transport TLS1.3 X25519 attach failed: ${e.message}"
        )
    }
}

public func contractCloseAcceptedTransportSession(
    session: ContractHttpServerAcceptedTransportSession,
    reason!: String = "close_notify"
): ContractHttpServerAcceptedTransportSession {
    ContractHttpServerAcceptedTransportSession(
        session.transport,
        ContractAcceptedTransportSessionStatus.Closed,
        ContractHttpServerAttachResult(
            session.result.serverFlight,
            tlsVersion: session.result.tlsVersion,
            cipherSuite: session.result.cipherSuite,
            negotiatedAlpn: session.result.negotiatedAlpn,
            requestedServerName: session.result.requestedServerName,
            acknowledgedServerName: session.result.acknowledgedServerName,
            secureSessionReady: false,
            attachSurface: session.result.attachSurface
        ),
        session.initialHandshake,
        session.keyMaterial,
        session.recordChannel,
        closeReason: reason
    )
}

private func acceptedTransportDerChainFromCertificates(certChain: Array<X509Certificate>): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    for (cert in certChain) {
        out.add(cert.der.clone())
    }
    out.toArray()
}

private func acceptedTransportTryParseRsaPrivateKeyPkcs8Pem(pkcs8Pem: String): ?RsaPrivateKey {
    try {
        Some(x509ParseRsaPrivateKeyPkcs8Pem(pkcs8Pem))
    } catch (e: CryptoException) {
        if (e.code == ParseError) {
            return None
        }
        throw e
    }
}

private func acceptedTransportTryParseEcPrivateKeyPkcs8Pem(pkcs8Pem: String): ?EcPrivateKey {
    try {
        Some(x509ParseEcPrivateKeyPkcs8Pem(pkcs8Pem))
    } catch (e: CryptoException) {
        if (e.code == ParseError) {
            return None
        }
        throw e
    }
}

private func acceptedTransportIsSomeRsaPrivateKey(value: ?RsaPrivateKey): Bool {
    if (let Some(_inner) <- value) {
        return true
    }
    false
}

private func acceptedTransportIsSomeEcPrivateKey(value: ?EcPrivateKey): Bool {
    if (let Some(_inner) <- value) {
        return true
    }
    false
}

private func acceptedTransportFromTls13ServerHandshakeFlight(
    flight: Tls13ServerHandshakeFlight
): ContractTls13HttpServerFlight {
    ContractTls13HttpServerFlight(
        flight.serverHello,
        flight.encryptedExtensions,
        flight.authFlight.certificateHandshake,
        flight.authFlight.certificateVerifyHandshake,
        flight.authFlight.finishedHandshake,
        flight.transcriptHash,
        selectedAlpn: flight.selectedAlpn,
        requestedServerName: flight.requestedServerName,
        acknowledgedServerName: flight.acknowledgedServerName
    )
}

private func acceptedTransportToTlsHttpNegotiationPolicy(
    policy: ContractTlsHttpNegotiationPolicy
): TlsHttpNegotiationPolicy {
    TlsHttpNegotiationPolicy(
        requireServerName: policy.requireServerName,
        allowedServerNames: policy.allowedServerNames,
        alpnPreference: policy.alpnPreference
    )
}

private func acceptedTransportMapCryptoErrorForOperation(e: CryptoException, operation: String): ContractErrorCode {
    if (operation == "tls") {
        if (e.code == ParseError) {
            return ContractErrorCode.VerifyFailed
        }
        if (e.code == CryptoErrorCode.Unsupported) {
            return ContractErrorCode.Unsupported
        }
    }
    contractMapCryptoErrorCode(e.code)
}
