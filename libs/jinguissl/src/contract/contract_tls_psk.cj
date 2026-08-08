 package jinguissl.contract

 import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
 import jinguissl_core.crypto.tls.{
     Tls13NewSessionTicketMessage,
     Tls13PskIdentityEntry,
     TlsSessionTicket,
     tls13BuildClientHelloPskFromSessionTicket,
     tls13BuildClientHelloPskFromSessionTickets,
     tls13BuildClientHelloPskWithBinder,
     tls13BuildServerHelloForPskFromSessionTicket,
     tls13ExtractClientPskIdentities,
     tls13SelectPskIdentityFromSessionTickets,
     tls13VerifyClientPskBinder
 }

 /// 合约层面的 PSK 身份条目。
 public class ContractTls13PskIdentityEntry {
     public let identity: Array<Byte>
     public let obfuscatedTicketAge: Int64

     public init(identity: Array<Byte>, obfuscatedTicketAge: Int64) {
         this.identity = identity.clone()
         this.obfuscatedTicketAge = obfuscatedTicketAge
     }
 }

 /// 合约层面的 NewSessionTicket 消息内容。
 public class ContractTls13NewSessionTicketMessage {
     public let ticketLifetimeSeconds: Int64
     public let ticketAgeAdd: Int64
     public let ticketNonce: Array<Byte>
     public let ticket: Array<Byte>

     public init(
         ticketLifetimeSeconds: Int64,
         ticketAgeAdd: Int64,
         ticketNonce: Array<Byte>,
         ticket: Array<Byte>
     ) {
         this.ticketLifetimeSeconds = ticketLifetimeSeconds
         this.ticketAgeAdd = ticketAgeAdd
         this.ticketNonce = ticketNonce.clone()
         this.ticket = ticket.clone()
     }
 }

 /// 从 session ticket 构建 PSK ClientHello。
 public func contractTls13BuildClientHelloPskFromSessionTicket(
     ticket: TlsSessionTicket,
     sessionId!: Array<Byte> = []
 ): Array<Byte> {
     try {
         tls13BuildClientHelloPskFromSessionTicket(ticket, sessionId: sessionId)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building PSK client hello from session ticket failed: ${e.message}"
         )
     }
 }

 /// 从多个 session ticket 构建 PSK ClientHello。
 public func contractTls13BuildClientHelloPskFromSessionTickets(
     tickets: Array<TlsSessionTicket>,
     sessionId!: Array<Byte> = []
 ): Array<Byte> {
     try {
         tls13BuildClientHelloPskFromSessionTickets(tickets, sessionId: sessionId)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building PSK client hello from session tickets failed: ${e.message}"
         )
     }
 }

 /// 使用原始 PSK 身份和密钥构建 PSK ClientHello。
 public func contractTls13BuildClientHelloPskWithBinder(
     pskIdentity: Array<Byte>,
     psk: Array<Byte>,
     sessionId!: Array<Byte> = []
 ): Array<Byte> {
     try {
         tls13BuildClientHelloPskWithBinder(pskIdentity, psk, sessionId: sessionId)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building PSK client hello with binder failed: ${e.message}"
         )
     }
 }

 /// 构建对 PSK 握手响应的服务端 ServerHello。
 public func contractTls13BuildServerHelloForPskFromSessionTicket(
     encodedClientHello: Array<Byte>,
     selectedIdentityIndex!: Int64 = 0,
     nowUnixSeconds!: Int64 = 0
 ): Array<Byte> {
     try {
         tls13BuildServerHelloForPskFromSessionTicket(
             encodedClientHello,
             selectedIdentityIndex: selectedIdentityIndex,
             nowUnixSeconds: nowUnixSeconds
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building PSK server hello failed: ${e.message}"
         )
     }
 }

 /// 验证客户端的 PSK binder 值。
 public func contractTls13VerifyClientPskBinder(
     encodedClientHello: Array<Byte>,
     psk: Array<Byte>,
     selectedIdentityIndex!: Int64 = 0
 ): Bool {
     try {
         tls13VerifyClientPskBinder(encodedClientHello, psk, selectedIdentityIndex: selectedIdentityIndex)
     } catch (e: CryptoException) {
         return false
     }
 }

 /// 从 ClientHello 提取 PSK 身份列表。
 public func contractTls13ExtractClientPskIdentities(
     encodedClientHello: Array<Byte>
 ): Array<ContractTls13PskIdentityEntry> {
     try {
         let identities = tls13ExtractClientPskIdentities(encodedClientHello)
         var result: Array<ContractTls13PskIdentityEntry> = []
         var i: Int64 = 0
         while (i < identities.size) {
             let entry = identities[i]
             let n = result.size
             let out = Array<ContractTls13PskIdentityEntry>(n + 1, repeat: ContractTls13PskIdentityEntry([], 0))
             var j: Int64 = 0
             while (j < n) { out[j] = result[j]; j += 1 }
             out[n] = ContractTls13PskIdentityEntry(entry.identity, entry.obfuscatedTicketAge)
             result = out
             i += 1
         }
         result
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 extracting PSK identities from client hello failed: ${e.message}"
         )
     }
 }

 /// 从 ClientHello 选择匹配的 PSK 身份索引。
 /// 返回: 选中的 PSK 身份索引，或 -1（未找到）
 public func contractTls13SelectPskIdentityFromSessionTickets(
     encodedClientHello: Array<Byte>,
     nowUnixSeconds!: Int64 = 0
 ): Int64 {
     try {
         tls13SelectPskIdentityFromSessionTickets(encodedClientHello, nowUnixSeconds: nowUnixSeconds)
     } catch (e: CryptoException) {
         return -1
     }
 }

 private func mapCryptoErrorForOperation(e: CryptoException, operation: String): ContractErrorCode {
     match (e.code) {
         case CryptoErrorCode.InvalidArgument => ContractErrorCode.BadInput
         case CryptoErrorCode.OutOfBounds => ContractErrorCode.BadInput
         case CryptoErrorCode.DivideByZero => ContractErrorCode.BadInput
         case CryptoErrorCode.NoModInverse => ContractErrorCode.BadInput
         case CryptoErrorCode.ParseError => ContractErrorCode.BadInput
         case CryptoErrorCode.ComplianceRejected => ContractErrorCode.ComplianceRejected
         case CryptoErrorCode.Unsupported => ContractErrorCode.Unsupported
         case CryptoErrorCode.InternalError => ContractErrorCode.InternalError
         case _ => ContractErrorCode.InternalError
     }
 }
