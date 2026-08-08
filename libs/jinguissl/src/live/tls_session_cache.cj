package jinguissl.live

import std.collection.ArrayList
import jinguissl_core.crypto.error.*
import jinguissl_core.crypto.tls.{
    TLS_SESSION_DEFAULT_TTL_SECONDS,
    TlsSessionCache,
    TlsSessionCacheStats,
    TlsSessionIdentity,
    TlsSessionTicket,
    tlsCreateSessionTicket,
    tlsDecodeSessionTicket,
    tlsEncodeSessionTicket,
    tlsIsSessionTicketExpired
}

public class ContractTlsSessionIdentity {
    public let version: ContractTlsVersion
    public let resumptionId: Array<Byte>
    public let serverName: String
    public let alpnProtocol: String

    public init(
        version: ContractTlsVersion,
        resumptionId: Array<Byte>,
        serverName!: String = "",
        alpnProtocol!: String = ""
    ) {
        if (resumptionId.size == 0 || resumptionId.size > 65535) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session resumption id length is invalid")
        }
        this.version = version
        this.resumptionId = resumptionId.clone()
        this.serverName = serverName.trimAscii().toAsciiLower()
        this.alpnProtocol = alpnProtocol.trimAscii().toAsciiLower()
    }
}

public class ContractTlsSessionTicket {
    public let version: Int64
    public let identity: ContractTlsSessionIdentity
    public let secret: Array<Byte>
    public let nonce: Array<Byte>
    public let issuedAtUnixSeconds: Int64
    public let expiresAtUnixSeconds: Int64

    public init(
        version: Int64,
        identity: ContractTlsSessionIdentity,
        secret: Array<Byte>,
        nonce: Array<Byte>,
        issuedAtUnixSeconds: Int64,
        expiresAtUnixSeconds: Int64
    ) {
        if (version <= 0 || version > 255) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session ticket version is invalid")
        }
        if (secret.size == 0 || secret.size > 65535) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session ticket secret length is invalid")
        }
        if (issuedAtUnixSeconds <= 0 || expiresAtUnixSeconds <= issuedAtUnixSeconds) {
            throw ContractException(ContractErrorCode.BadInput, "TLS session ticket validity window is invalid")
        }
        this.version = version
        this.identity = identity
        this.secret = secret.clone()
        this.nonce = nonce.clone()
        this.issuedAtUnixSeconds = issuedAtUnixSeconds
        this.expiresAtUnixSeconds = expiresAtUnixSeconds
    }
}

public class ContractTls13SessionTicketPolicy {
    public let minRemainingTtlSeconds: Int64
    public let renewBeforeExpirySeconds: Int64
    public let requiredServerName: String
    public let requiredAlpnProtocol: String

    public init(
        minRemainingTtlSeconds!: Int64 = 1,
        renewBeforeExpirySeconds!: Int64 = 300,
        requiredServerName!: String = "",
        requiredAlpnProtocol!: String = ""
    ) {
        if (minRemainingTtlSeconds < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 ticket min remaining ttl must be >= 0"
            )
        }
        if (renewBeforeExpirySeconds < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 ticket renew-before-expiry seconds must be >= 0"
            )
        }
        this.minRemainingTtlSeconds = minRemainingTtlSeconds
        this.renewBeforeExpirySeconds = renewBeforeExpirySeconds
        this.requiredServerName = requiredServerName.trimAscii().toAsciiLower()
        this.requiredAlpnProtocol = requiredAlpnProtocol.trimAscii().toAsciiLower()
    }
}

public class ContractTls13SessionTicketLifecycleResult {
    public let usable: Bool
    public let shouldRenew: Bool
    public let reason: String
    public let nowUnixSeconds: Int64
    public let remainingTtlSeconds: Int64

    public init(
        usable: Bool,
        shouldRenew: Bool,
        reason: String,
        nowUnixSeconds: Int64,
        remainingTtlSeconds: Int64
    ) {
        if (reason.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 ticket lifecycle reason must not be empty")
        }
        if (nowUnixSeconds <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 ticket lifecycle nowUnixSeconds must be > 0")
        }
        this.usable = usable
        this.shouldRenew = shouldRenew
        this.reason = reason.trimAscii()
        this.nowUnixSeconds = nowUnixSeconds
        this.remainingTtlSeconds = remainingTtlSeconds
    }
}

public class ContractTls13NewSessionTicketRequest {
    public let ticket: ContractTlsSessionTicket
    public let ticketAgeAdd: Int64

    public init(
        ticket: ContractTlsSessionTicket,
        ticketAgeAdd!: Int64 = 0
    ) {
        this.ticket = ticket
        this.ticketAgeAdd = ticketAgeAdd
    }
}

public class ContractTls13StoreNewSessionTicketRequest {
    public let cache: ContractTlsSessionCache
    public let encodedNewSessionTicket: Array<Byte>

    public init(
        cache: ContractTlsSessionCache,
        encodedNewSessionTicket: Array<Byte>
    ) {
        if (encodedNewSessionTicket.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 store NewSessionTicket request payload must not be empty"
            )
        }
        this.cache = cache
        this.encodedNewSessionTicket = encodedNewSessionTicket.clone()
    }
}

public class ContractTls13SessionTicketLifecycleRequest {
    public let ticket: ContractTlsSessionTicket
    public let policy: ContractTls13SessionTicketPolicy
    public let nowUnixSeconds: Int64

    public init(
        ticket: ContractTlsSessionTicket,
        policy!: ContractTls13SessionTicketPolicy = ContractTls13SessionTicketPolicy(),
        nowUnixSeconds!: Int64 = 0
    ) {
        this.ticket = ticket
        this.policy = ContractTls13SessionTicketPolicy(
            minRemainingTtlSeconds: policy.minRemainingTtlSeconds,
            renewBeforeExpirySeconds: policy.renewBeforeExpirySeconds,
            requiredServerName: policy.requiredServerName,
            requiredAlpnProtocol: policy.requiredAlpnProtocol
        )
        this.nowUnixSeconds = nowUnixSeconds
    }
}

public class ContractTlsSessionCacheStats {
    public let size: Int64
    public let hits: Int64
    public let misses: Int64
    public let evictions: Int64
    public let expiredRemovals: Int64

    public init(size: Int64, hits: Int64, misses: Int64, evictions: Int64, expiredRemovals: Int64) {
        this.size = size
        this.hits = hits
        this.misses = misses
        this.evictions = evictions
        this.expiredRemovals = expiredRemovals
    }
}

public class ContractTlsSessionCache {
    let _inner: TlsSessionCache

    public init(maxEntries!: Int64 = 1024, defaultTtlSeconds!: Int64 = TLS_SESSION_DEFAULT_TTL_SECONDS) {
        try {
            this._inner = TlsSessionCache(maxEntries: maxEntries, defaultTtlSeconds: defaultTtlSeconds)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session cache initialization failed: ${e.message}"
            )
        }
    }

    public prop size: Int64 {
        get() {
            _inner.size
        }
    }

    public func stats(): ContractTlsSessionCacheStats {
        contractFromTlsSessionCacheStats(_inner.stats())
    }

    public func store(ticket: ContractTlsSessionTicket): ContractTlsSessionTicket {
        try {
            let stored = _inner.store(contractToTlsSessionTicket(ticket))
            contractFromTlsSessionTicket(stored)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket store failed: ${e.message}"
            )
        }
    }

    public func storeFromSecret(
        identity: ContractTlsSessionIdentity,
        secret: Array<Byte>,
        nonce!: Array<Byte> = [],
        nowUnixSeconds!: Int64 = 0,
        ttlSeconds!: Int64 = 0
    ): ContractTlsSessionTicket {
        try {
            let stored = _inner.storeFromSecret(
                contractToTlsSessionIdentity(identity),
                secret,
                nonce: nonce,
                nowUnixSeconds: nowUnixSeconds,
                ttlSeconds: ttlSeconds
            )
            contractFromTlsSessionTicket(stored)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket store-from-secret failed: ${e.message}"
            )
        }
    }

    public func load(
        identity: ContractTlsSessionIdentity,
        nowUnixSeconds!: Int64 = 0
    ): ?ContractTlsSessionTicket {
        try {
            let loaded = _inner.load(
                contractToTlsSessionIdentity(identity),
                nowUnixSeconds: nowUnixSeconds
            )
            if (let Some(ticket) <- loaded) {
                return Some(contractFromTlsSessionTicket(ticket))
            }
            None
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket load failed: ${e.message}"
            )
        }
    }

    public func remove(identity: ContractTlsSessionIdentity): Bool {
        try {
            _inner.remove(contractToTlsSessionIdentity(identity))
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session ticket remove failed: ${e.message}"
            )
        }
    }

    public func purgeExpired(nowUnixSeconds!: Int64 = 0): Int64 {
        try {
            _inner.purgeExpired(nowUnixSeconds: nowUnixSeconds)
        } catch (e: CryptoException) {
            throw ContractException(
                mapCryptoErrorForOperation(e, "tls"),
                "TLS session cache purge failed: ${e.message}"
            )
        }
    }

    public func clear(): Unit {
        _inner.clear()
    }
}

public class ContractTls13EarlyDataReplayStats {
    public let size: Int64
    public let hits: Int64
    public let misses: Int64
    public let evictions: Int64
    public let expiredRemovals: Int64
    public let rejects: Int64

    public init(
        size: Int64,
        hits: Int64,
        misses: Int64,
        evictions: Int64,
        expiredRemovals: Int64,
        rejects: Int64
    ) {
        this.size = size
        this.hits = hits
        this.misses = misses
        this.evictions = evictions
        this.expiredRemovals = expiredRemovals
        this.rejects = rejects
    }
}

public class ContractTls13EarlyDataReplayCache {
    let _maxEntries: Int64
    let _defaultWindowSeconds: Int64
    let _entries = ArrayList<ContractTls13EarlyDataReplayEntry>()

    var _hits: Int64 = 0
    var _misses: Int64 = 0
    var _evictions: Int64 = 0
    var _expiredRemovals: Int64 = 0
    var _rejects: Int64 = 0

    public init(maxEntries!: Int64 = 2048, defaultWindowSeconds!: Int64 = 600) {
        if (maxEntries <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 early data replay cache maxEntries must be positive"
            )
        }
        if (defaultWindowSeconds <= 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 early data replay cache default window must be positive"
            )
        }
        this._maxEntries = maxEntries
        this._defaultWindowSeconds = defaultWindowSeconds
    }

    public prop size: Int64 {
        get() {
            _entries.size
        }
    }

    public func stats(): ContractTls13EarlyDataReplayStats {
        ContractTls13EarlyDataReplayStats(
            _entries.size,
            _hits,
            _misses,
            _evictions,
            _expiredRemovals,
            _rejects
        )
    }

    public func contains(replayKey: String, nowUnixSeconds!: Int64 = 0): Bool {
        let normalizedKey = contractNormalizeReplayKey(replayKey)
        let now = contractResolveReplayUnixSeconds(nowUnixSeconds)
        purgeExpiredInternal(now)
        let (index, found) = findEntryByKey(normalizedKey)
        if (index < 0) {
            _misses += 1
            return false
        }
        match (found) {
            case Some(entry) =>
                if (entry.isExpired(now)) {
                    _entries.remove(at: index)
                    _expiredRemovals += 1
                    _misses += 1
                    return false
                }
                _hits += 1
                true
            case None =>
                _misses += 1
                false
        }
    }

    public func remember(
        replayKey: String,
        nowUnixSeconds!: Int64 = 0,
        ttlSeconds!: Int64 = 0
    ): Bool {
        let normalizedKey = contractNormalizeReplayKey(replayKey)
        let now = contractResolveReplayUnixSeconds(nowUnixSeconds)
        purgeExpiredInternal(now)
        let (index, found) = findEntryByKey(normalizedKey)
        if (index >= 0) {
            match (found) {
                case Some(entry) =>
                    if (!entry.isExpired(now)) {
                        _hits += 1
                        _rejects += 1
                        return false
                    }
                    _entries.remove(at: index)
                    _expiredRemovals += 1
                case None =>
                    ()
            }
        }

        let effectiveTtl = if (ttlSeconds > 0) {
            ttlSeconds
        } else {
            _defaultWindowSeconds
        }
        let expiresAt = now + effectiveTtl
        _entries.add(
            ContractTls13EarlyDataReplayEntry(
                normalizedKey,
                now,
                expiresAt
            )
        )
        trimToCapacity()
        _misses += 1
        true
    }

    public func purgeExpired(nowUnixSeconds!: Int64 = 0): Int64 {
        let now = contractResolveReplayUnixSeconds(nowUnixSeconds)
        purgeExpiredInternal(now)
    }

    public func clear(): Unit {
        while (_entries.size > 0) {
            _entries.remove(at: _entries.size - 1)
        }
    }

    private func purgeExpiredInternal(nowUnixSeconds: Int64): Int64 {
        var removed: Int64 = 0
        var i = _entries.size - 1
        while (i >= 0) {
            if (_entries[i].isExpired(nowUnixSeconds)) {
                _entries.remove(at: i)
                removed += 1
            }
            i -= 1
        }
        _expiredRemovals += removed
        removed
    }

    private func trimToCapacity(): Unit {
        while (_entries.size > _maxEntries) {
            _entries.remove(at: 0)
            _evictions += 1
        }
    }

    private func findEntryByKey(replayKey: String): (Int64, ?ContractTls13EarlyDataReplayEntry) {
        var idx: Int64 = 0
        for (entry in _entries) {
            if (entry.replayKey == replayKey) {
                return (idx, Some(entry))
            }
            idx += 1
        }
        (-1, None)
    }
}

class ContractTls13EarlyDataReplayEntry {
    public let replayKey: String
    public let acceptedAtUnixSeconds: Int64
    public let expiresAtUnixSeconds: Int64

    public init(replayKey: String, acceptedAtUnixSeconds: Int64, expiresAtUnixSeconds: Int64) {
        if (replayKey.size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS1.3 early data replay key must not be empty")
        }
        if (acceptedAtUnixSeconds <= 0 || expiresAtUnixSeconds <= acceptedAtUnixSeconds) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 early data replay entry lifetime is invalid"
            )
        }
        this.replayKey = replayKey
        this.acceptedAtUnixSeconds = acceptedAtUnixSeconds
        this.expiresAtUnixSeconds = expiresAtUnixSeconds
    }

    public func isExpired(nowUnixSeconds: Int64): Bool {
        nowUnixSeconds >= expiresAtUnixSeconds
    }
}

private func contractNormalizeReplayKey(replayKey: String): String {
    let normalized = replayKey.trimAscii()
    if (normalized.size == 0) {
        throw ContractException(ContractErrorCode.BadInput, "TLS1.3 early data replay key must not be empty")
    }
    normalized
}

private func contractResolveReplayUnixSeconds(nowUnixSeconds: Int64): Int64 {
    if (nowUnixSeconds > 0) {
        return nowUnixSeconds
    }
    1
}

public func contractTlsCreateSessionTicket(
    identity: ContractTlsSessionIdentity,
    secret: Array<Byte>,
    nonce!: Array<Byte> = [],
    nowUnixSeconds!: Int64 = 0,
    ttlSeconds!: Int64 = TLS_SESSION_DEFAULT_TTL_SECONDS
): ContractTlsSessionTicket {
    try {
        let ticket = tlsCreateSessionTicket(
            contractToTlsSessionIdentity(identity),
            secret,
            nonce: nonce,
            nowUnixSeconds: nowUnixSeconds,
            ttlSeconds: ttlSeconds
        )
        contractFromTlsSessionTicket(ticket)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket creation failed: ${e.message}"
        )
    }
}

public func contractTlsEncodeSessionTicket(ticket: ContractTlsSessionTicket): Array<Byte> {
    try {
        tlsEncodeSessionTicket(contractToTlsSessionTicket(ticket))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket encoding failed: ${e.message}"
        )
    }
}

public func contractTlsDecodeSessionTicket(encoded: Array<Byte>): ContractTlsSessionTicket {
    try {
        contractFromTlsSessionTicket(tlsDecodeSessionTicket(encoded))
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket decoding failed: ${e.message}"
        )
    }
}

public func contractTlsIsSessionTicketExpired(
    ticket: ContractTlsSessionTicket,
    nowUnixSeconds!: Int64 = 0
): Bool {
    try {
        tlsIsSessionTicketExpired(contractToTlsSessionTicket(ticket), nowUnixSeconds: nowUnixSeconds)
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS session ticket expiry check failed: ${e.message}"
        )
    }
}

func contractToTlsSessionIdentity(identity: ContractTlsSessionIdentity): TlsSessionIdentity {
    TlsSessionIdentity(
        contractToTlsVersion(identity.version),
        identity.resumptionId,
        serverName: identity.serverName,
        alpnProtocol: identity.alpnProtocol
    )
}

func contractFromTlsSessionIdentity(identity: TlsSessionIdentity): ContractTlsSessionIdentity {
    ContractTlsSessionIdentity(
        contractFromTlsVersion(identity.version),
        identity.resumptionId,
        serverName: identity.serverName,
        alpnProtocol: identity.alpnProtocol
    )
}

func contractToTlsSessionTicket(ticket: ContractTlsSessionTicket): TlsSessionTicket {
    TlsSessionTicket(
        contractToTlsSessionIdentity(ticket.identity),
        ticket.secret,
        ticket.nonce,
        ticket.issuedAtUnixSeconds,
        ticket.expiresAtUnixSeconds,
        version: ticket.version
    )
}

func contractFromTlsSessionTicket(ticket: TlsSessionTicket): ContractTlsSessionTicket {
    ContractTlsSessionTicket(
        ticket.version,
        contractFromTlsSessionIdentity(ticket.identity),
        ticket.secret,
        ticket.nonce,
        ticket.issuedAtUnixSeconds,
        ticket.expiresAtUnixSeconds
    )
}

func contractFromTlsSessionCacheStats(stats: TlsSessionCacheStats): ContractTlsSessionCacheStats {
    ContractTlsSessionCacheStats(
        stats.size,
        stats.hits,
        stats.misses,
        stats.evictions,
        stats.expiredRemovals
    )
}
