package tls_sample

import jinguissl_core.crypto.compliance.{TlsVersion, TLS_VERSION_1_2, TLS_VERSION_1_3}
import jinguissl_core.crypto.tls.{TlsSessionIdentity, TlsSessionTicket, tlsCreateSessionTicket, tlsIsSessionTicketExpired, tlsEncodeSessionTicket, tlsDecodeSessionTicket, TLS_SESSION_TICKET_VERSION, TLS_SESSION_DEFAULT_TTL_SECONDS}
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - TLS Sample =====")

    // 1. Session Identity
    println("--- TLS Session Identity ---")
    let identity = TlsSessionIdentity(
        TLS_VERSION_1_3,
        [0x01, 0x02, 0x03, 0x04],
        serverName: "example.com",
        alpnProtocol: "h2"
    )
    println("TLS version: ${identity.version.toString()}")
    println("Server: ${identity.serverName}")
    println("ALPN: ${identity.alpnProtocol}")
    println("Resumption ID: ${bytesToHexLower(identity.resumptionId)}")
    if (identity.serverName != "example.com") { throw Exception("Identity mismatch") }

    // 2. Session Ticket
    println("\n--- TLS Session Ticket ---")
    let ticket = tlsCreateSessionTicket(
        identity,
        [0x10, 0x20, 0x30, 0x40, 0x50],
        nonce: [0xaa, 0xbb],
        nowUnixSeconds: 1000000,
        ttlSeconds: 3600
    )
    println("Ticket version: ${ticket.version}")
    println("Secret size: ${ticket.secret.size}")
    println("Nonce size: ${ticket.nonce.size}")
    if (ticket.version != TLS_SESSION_TICKET_VERSION) {
        throw Exception("Unexpected ticket version")
    }

    // 3. Ticket Expiry
    println("\n--- Ticket Expiry ---")
    let notExpired = tlsIsSessionTicketExpired(ticket, nowUnixSeconds: 1000000)
    println("Expired at issue time: ${notExpired}")  // false
    if (notExpired) { throw Exception("Ticket should not be expired at issue time") }

    let expired = tlsIsSessionTicketExpired(ticket, nowUnixSeconds: 1005000)
    println("Expired after 5000 seconds: ${expired}")  // true
    if (!expired) { throw Exception("Ticket should be expired after TTL") }

    // 4. Encode/Decode Session Ticket
    println("\n--- Encode/Decode Session Ticket ---")
    let encoded = tlsEncodeSessionTicket(ticket)
    println("Encoded ticket size: ${encoded.size} bytes")

    let decoded = tlsDecodeSessionTicket(encoded)
    println("Decoded server: ${decoded.identity.serverName}")
    println("Decoded ALPN: ${decoded.identity.alpnProtocol}")
    println("Decoded version: ${decoded.identity.version.toString()}")
    if (decoded.identity.serverName != "example.com" || decoded.identity.alpnProtocol != "h2") {
        throw Exception("Decode mismatch: server=${decoded.identity.serverName}, alpn=${decoded.identity.alpnProtocol}")
    }

    // 5. Constants
    println("\n--- TLS Constants ---")
    println("Session ticket version: ${TLS_SESSION_TICKET_VERSION}")
    println("Default TTL: ${TLS_SESSION_DEFAULT_TTL_SECONDS}s")

    // 6. Multiple identities
    println("\n--- Multiple Session Identities ---")
    let id2 = TlsSessionIdentity(
        TLS_VERSION_1_2,
        [0x05, 0x06, 0x07, 0x08],
        serverName: "secure.example.org",
        alpnProtocol: "http/1.1"
    )
    let ticket2 = tlsCreateSessionTicket(
        id2,
        [0x60, 0x70, 0x80],
        nonce: [0xcc],
        nowUnixSeconds: 2000000,
        ttlSeconds: 7200
    )
    let enc2 = tlsEncodeSessionTicket(ticket2)
    let dec2 = tlsDecodeSessionTicket(enc2)
    println("Ticket 2 server: ${dec2.identity.serverName}")
    println("Ticket 2 ALPN: ${dec2.identity.alpnProtocol}")
    println("Ticket 2 version: ${dec2.identity.version.toString()}")
    if (dec2.identity.serverName != "secure.example.org") {
        throw Exception("Second ticket decode mismatch")
    }

    println("=== TLS sample passed ===")
}
