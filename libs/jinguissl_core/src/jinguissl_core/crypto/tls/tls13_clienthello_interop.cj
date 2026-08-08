package jinguissl_core.crypto.tls

import std.collection.ArrayList
import jinguissl_core.crypto.compliance.{TLS_VERSION_1_2, TlsVersion}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

private let TLS13_INTEROP_VERSION_TLS13: Int64 = 0x0304
private let TLS13_INTEROP_EXT_SUPPORTED_GROUPS: Int64 = 0x000a
private let TLS13_INTEROP_EXT_SUPPORTED_VERSIONS: Int64 = 0x002b
private let TLS13_INTEROP_EXT_KEY_SHARE: Int64 = 0x0033

public class Tls13ClientHelloInteropSummary {
    public let legacyVersion: TlsVersion
    public let cipherSuites: Array<Int64>
    public let extensionTypes: Array<Int64>
    public let serverNames: Array<String>
    public let alpnProtocols: Array<String>
    public let supportedVersions: Array<Int64>
    public let supportedGroups: Array<Int64>
    public let keyShareGroups: Array<Int64>
    public let signatureSchemes: Array<Int64>

    public init(
        legacyVersion: TlsVersion,
        cipherSuites: Array<Int64>,
        extensionTypes: Array<Int64>,
        serverNames: Array<String>,
        alpnProtocols: Array<String>,
        supportedVersions: Array<Int64>,
        supportedGroups: Array<Int64>,
        keyShareGroups: Array<Int64>,
        signatureSchemes: Array<Int64>
    ) {
        this.legacyVersion = legacyVersion
        this.cipherSuites = cipherSuites.clone()
        this.extensionTypes = extensionTypes.clone()
        this.serverNames = serverNames.clone()
        this.alpnProtocols = alpnProtocols.clone()
        this.supportedVersions = supportedVersions.clone()
        this.supportedGroups = supportedGroups.clone()
        this.keyShareGroups = keyShareGroups.clone()
        this.signatureSchemes = signatureSchemes.clone()
    }
}

public class Tls13ClientHelloInteropProfile {
    public let serverName: String
    public let alpnProtocols: Array<String>
    public let cipherSuites: Array<Int64>
    public let supportedVersions: Array<Int64>
    public let supportedGroups: Array<Int64>
    public let keyShareGroups: Array<Int64>
    public let signatureSchemes: Array<Int64>

    public init(
        serverName!: String = "",
        alpnProtocols!: Array<String> = [],
        cipherSuites!: Array<Int64> = [],
        supportedVersions!: Array<Int64> = [TLS13_INTEROP_VERSION_TLS13],
        supportedGroups!: Array<Int64> = [],
        keyShareGroups!: Array<Int64> = [],
        signatureSchemes!: Array<Int64> = []
    ) {
        this.serverName = serverName
        this.alpnProtocols = alpnProtocols.clone()
        this.cipherSuites = cipherSuites.clone()
        this.supportedVersions = supportedVersions.clone()
        this.supportedGroups = supportedGroups.clone()
        this.keyShareGroups = keyShareGroups.clone()
        this.signatureSchemes = signatureSchemes.clone()
    }
}

public class Tls13ClientHelloInteropPrecheckReport {
    public let ready: Bool
    public let missing: Array<String>
    public let warnings: Array<String>

    public init(ready: Bool, missing: Array<String>, warnings: Array<String>) {
        this.ready = ready
        this.missing = missing.clone()
        this.warnings = warnings.clone()
    }
}

/**
 * tls13SummarizeClientHello.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13SummarizeClientHello(encodedClientHello: Array<Byte>): Tls13ClientHelloInteropSummary {
    tls13SummarizeDecodedClientHello(tlsDecodeClientHelloHandshake(encodedClientHello))
}

/**
 * tls13SummarizeDecodedClientHello.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13SummarizeDecodedClientHello(clientHello: TlsClientHello): Tls13ClientHelloInteropSummary {
    let extensionTypes = ArrayList<Int64>()
    for (ext in clientHello.extensions) {
        extensionTypes.add(ext.extType)
    }

    Tls13ClientHelloInteropSummary(
        clientHello.legacyVersion,
        clientHello.cipherSuites,
        extensionTypes.toArray(),
        tls13InteropSummarizeServerNames(clientHello.extensions),
        tls13InteropSummarizeAlpnProtocols(clientHello.extensions),
        tls13InteropSummarizeSupportedVersions(clientHello.extensions),
        tls13InteropSummarizeSupportedGroups(clientHello.extensions),
        tls13InteropSummarizeKeyShareGroups(clientHello.extensions),
        tls13InteropSummarizeSignatureSchemes(clientHello.extensions)
    )
}

/**
 * tls13PrecheckEncodedClientHelloInterop.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func tls13PrecheckEncodedClientHelloInterop(
    encodedClientHello: Array<Byte>,
    profile: Tls13ClientHelloInteropProfile
): Tls13ClientHelloInteropPrecheckReport {
    tls13PrecheckClientHelloInterop(tls13SummarizeClientHello(encodedClientHello), profile)
}

/**
 * tls13PrecheckClientHelloInterop.
 */
public func tls13PrecheckClientHelloInterop(
    summary: Tls13ClientHelloInteropSummary,
    profile: Tls13ClientHelloInteropProfile
): Tls13ClientHelloInteropPrecheckReport {
    let missing = ArrayList<String>()
    let warnings = ArrayList<String>()

    if (summary.legacyVersion != TLS_VERSION_1_2) {
        warnings.add("legacy_version expected TLS1.2 compatibility value, got ${summary.legacyVersion.toString()}")
    }
    if (profile.serverName.size > 0 && !tls13InteropContainsString(summary.serverNames, profile.serverName)) {
        missing.add("missing SNI ${profile.serverName}")
    }

    tls13InteropRequireAllStrings(missing, summary.alpnProtocols, profile.alpnProtocols, "ALPN")
    tls13InteropRequireAllInt64(missing, summary.cipherSuites, profile.cipherSuites, "cipher_suite")
    tls13InteropRequireAllInt64(missing, summary.supportedVersions, profile.supportedVersions, "supported_version")
    tls13InteropRequireAllInt64(missing, summary.supportedGroups, profile.supportedGroups, "supported_group")
    tls13InteropRequireAllInt64(missing, summary.keyShareGroups, profile.keyShareGroups, "key_share_group")
    tls13InteropRequireAllInt64(missing, summary.signatureSchemes, profile.signatureSchemes, "signature_scheme")

    Tls13ClientHelloInteropPrecheckReport(missing.size == 0, missing.toArray(), warnings.toArray())
}

private func tls13InteropSummarizeServerNames(extensions: Array<TlsExtension>): Array<String> {
    if (let Some(ext) <- tlsFindExtension(extensions, TLS_EXT_SERVER_NAME)) {
        return tlsParseServerNameExtension(ext)
    }
    []
}

private func tls13InteropSummarizeAlpnProtocols(extensions: Array<TlsExtension>): Array<String> {
    if (let Some(ext) <- tlsFindExtension(extensions, TLS_EXT_ALPN)) {
        return tlsParseAlpnExtension(ext)
    }
    []
}

private func tls13InteropSummarizeSupportedVersions(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tlsFindExtension(extensions, TLS13_INTEROP_EXT_SUPPORTED_VERSIONS)) {
        return tls13InteropParseClientSupportedVersionsExtension(ext)
    }
    []
}

private func tls13InteropSummarizeSupportedGroups(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tlsFindExtension(extensions, TLS13_INTEROP_EXT_SUPPORTED_GROUPS)) {
        return tls13InteropParseSupportedGroupsExtension(ext)
    }
    []
}

private func tls13InteropSummarizeKeyShareGroups(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tlsFindExtension(extensions, TLS13_INTEROP_EXT_KEY_SHARE)) {
        return tls13InteropParseClientKeyShareGroupIds(ext)
    }
    []
}

private func tls13InteropSummarizeSignatureSchemes(extensions: Array<TlsExtension>): Array<Int64> {
    if (let Some(ext) <- tlsFindExtension(extensions, TLS13_EXT_SIGNATURE_ALGORITHMS)) {
        return tls13InteropParseSignatureAlgorithmsExtension(ext)
    }
    []
}

private func tls13InteropParseClientSupportedVersionsExtension(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_INTEROP_EXT_SUPPORTED_VERSIONS) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not supported_versions")
    }
    if (extension.data.size < 3) {
        throw CryptoException(ParseError, "TLS1.3 supported_versions extension is too short")
    }
    let vectorLen = Int64(UInt8(extension.data[0]))
    if (vectorLen == 0 || (vectorLen % 2) != 0 || vectorLen != extension.data.size - 1) {
        throw CryptoException(ParseError, "TLS1.3 supported_versions vector length is invalid")
    }

    let versions = ArrayList<Int64>()
    var offset = 1
    while (offset < extension.data.size) {
        versions.add(tls13InteropDecodeUInt16(extension.data, offset))
        offset += 2
    }
    versions.toArray()
}

private func tls13InteropParseSupportedGroupsExtension(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_INTEROP_EXT_SUPPORTED_GROUPS) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not supported_groups")
    }
    tls13InteropDecodeUInt16ListVector16(extension.data, "TLS1.3 supported_groups")
}

private func tls13InteropParseClientKeyShareGroupIds(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_INTEROP_EXT_KEY_SHARE) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not key_share")
    }
    let entries = tls13InteropDecodeVector16(extension.data, "TLS1.3 client key_share list")
    let groups = ArrayList<Int64>()
    var offset = 0
    while (offset < entries.size) {
        if (offset + 4 > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry is truncated")
        }
        let group = tls13InteropDecodeUInt16(entries, offset)
        offset += 2
        let keyLen = tls13InteropDecodeUInt16(entries, offset)
        offset += 2
        if (keyLen == 0 || offset + keyLen > entries.size) {
            throw CryptoException(ParseError, "TLS1.3 client key_share entry length is invalid")
        }
        groups.add(group)
        offset += keyLen
    }
    if (groups.size == 0) {
        throw CryptoException(ParseError, "TLS1.3 client key_share list is empty")
    }
    groups.toArray()
}

private func tls13InteropParseSignatureAlgorithmsExtension(extension: TlsExtension): Array<Int64> {
    if (extension.extType != TLS13_EXT_SIGNATURE_ALGORITHMS) {
        throw CryptoException(InvalidArgument, "TLS1.3 extension is not signature_algorithms")
    }
    let vector = tls13InteropDecodeVector16(extension.data, "TLS1.3 signature_algorithms")
    if (vector.size == 0 || (vector.size % 2) != 0) {
        throw CryptoException(ParseError, "TLS1.3 signature_algorithms vector length is invalid")
    }

    let schemes = ArrayList<Int64>()
    var offset = 0
    while (offset < vector.size) {
        schemes.add(tls13InteropDecodeUInt16(vector, offset))
        offset += 2
    }
    schemes.toArray()
}

private func tls13InteropDecodeUInt16ListVector16(data: Array<Byte>, label: String): Array<Int64> {
    let vector = tls13InteropDecodeVector16(data, label)
    if (vector.size == 0 || (vector.size % 2) != 0) {
        throw CryptoException(ParseError, "${label} vector length is invalid")
    }

    let values = ArrayList<Int64>()
    var offset = 0
    while (offset < vector.size) {
        values.add(tls13InteropDecodeUInt16(vector, offset))
        offset += 2
    }
    values.toArray()
}

private func tls13InteropDecodeVector16(data: Array<Byte>, label: String): Array<Byte> {
    if (data.size < 2) {
        throw CryptoException(ParseError, "${label} vector is truncated")
    }
    let len = tls13InteropDecodeUInt16(data, 0)
    if (len < 0 || 2 + len > data.size) {
        throw CryptoException(ParseError, "${label} vector length is invalid")
    }
    data[2..(2 + len)]
}

private func tls13InteropDecodeUInt16(bytes: Array<Byte>, offset: Int64): Int64 {
    if (offset < 0 || offset + 2 > bytes.size) {
        throw CryptoException(OutOfBounds, "TLS1.3 uint16 read out of bounds")
    }
    (Int64(UInt8(bytes[offset])) << 8) | Int64(UInt8(bytes[offset + 1]))
}

private func tls13InteropRequireAllInt64(
    missing: ArrayList<String>,
    actual: Array<Int64>,
    expected: Array<Int64>,
    label: String
): Unit {
    for (value in expected) {
        if (!tls13InteropContainsInt64(actual, value)) {
            missing.add("missing ${label} ${value}")
        }
    }
}

private func tls13InteropRequireAllStrings(
    missing: ArrayList<String>,
    actual: Array<String>,
    expected: Array<String>,
    label: String
): Unit {
    for (value in expected) {
        if (!tls13InteropContainsString(actual, value)) {
            missing.add("missing ${label} ${value}")
        }
    }
}

private func tls13InteropContainsInt64(values: Array<Int64>, target: Int64): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}

private func tls13InteropContainsString(values: Array<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    false
}
