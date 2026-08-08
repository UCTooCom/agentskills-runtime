package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractTlsPskTestSuite {
    @TestCase
    public func testContractPskIdentityEntryConstruction(): Unit {
        let entry = ContractTls13PskIdentityEntry(hexToBytes("010203"), 1000)
        @Assert(entry.identity.size, 3)
        @Assert(entry.obfuscatedTicketAge, 1000)
    }

    @TestCase
    public func testContractPskIdentityEntryEmptyIdentity(): Unit {
        let entry = ContractTls13PskIdentityEntry([], 0)
        @Assert(entry.identity.size, 0)
        @Assert(entry.obfuscatedTicketAge, 0)
    }

    @TestCase
    public func testContractNewSessionTicketMessageConstruction(): Unit {
        let msg = ContractTls13NewSessionTicketMessage(
            7200, 12345, hexToBytes("0a0b"), hexToBytes("01020304")
        )
        @Assert(msg.ticketLifetimeSeconds, 7200)
        @Assert(msg.ticketAgeAdd, 12345)
        @Assert(msg.ticketNonce.size, 2)
        @Assert(msg.ticket.size, 4)
    }

    @TestCase
    public func testContractNewSessionTicketMessageEmptyTicket(): Unit {
        let msg = ContractTls13NewSessionTicketMessage(0, 0, [], [])
        @Assert(msg.ticketLifetimeSeconds, 0)
        @Assert(msg.ticketAgeAdd, 0)
        @Assert(msg.ticketNonce.size, 0)
        @Assert(msg.ticket.size, 0)
    }

    @TestCase
    public func testContractPskDtosCloneArrayInputs(): Unit {
        let identity: Array<Byte> = [0x01, 0x02]
        let nonce: Array<Byte> = [0x03, 0x04]
        let ticket: Array<Byte> = [0x05, 0x06]
        let entry = ContractTls13PskIdentityEntry(identity, 7)
        let message = ContractTls13NewSessionTicketMessage(8, 9, nonce, ticket)

        identity[0] = 0xff
        nonce[0] = 0xff
        ticket[0] = 0xff

        @Assert(entry.identity[0], UInt8(0x01))
        @Assert(message.ticketNonce[0], UInt8(0x03))
        @Assert(message.ticket[0], UInt8(0x05))
    }

    @TestCase
    public func testContractTls13BuildClientHelloPskWithBinderEmptyInput(): Unit {
        try {
            _ = contractTls13BuildClientHelloPskWithBinder([], [])
            @Fail("empty PSK identity/key should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractTls13BuildServerHelloForPskInvalidInput(): Unit {
        try {
            _ = contractTls13BuildServerHelloForPskFromSessionTicket([])
            @Fail("empty client hello should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractTls13ExtractClientPskIdentifiesEmpty(): Unit {
        try {
            _ = contractTls13ExtractClientPskIdentities([])
            @Fail("empty client hello should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractTls13SelectPskIdentityReturnsMinusOneForEmpty(): Unit {
        let idx = contractTls13SelectPskIdentityFromSessionTickets([], nowUnixSeconds: 0)
        @Assert(idx, -1)
    }

    @TestCase
    public func testContractTls13VerifyClientPskBinderEmptyReturnsFalse(): Unit {
        let ok = contractTls13VerifyClientPskBinder([], [])
        @Assert(ok, false)
    }
}

private func hexToBytes(hex: String): Array<Byte> {
    let clean = hex.trimAscii().replace(" ", "").replace("\n", "").replace("\t", "")
    let out = Array<Byte>(clean.size / 2, repeat: 0)
    var i = 0
    while (i < clean.size) {
        let hi = hexNibble(clean[i])
        let lo = hexNibble(clean[i + 1])
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

private func hexNibble(ch: Byte): UInt8 {
    if (ch >= b'0' && ch <= b'9') {
        return UInt8(ch - b'0')
    }
    let lower = if (ch >= b'A' && ch <= b'F') { ch + 32 } else { ch }
    if (lower >= b'a' && lower <= b'f') {
        UInt8(lower - b'a' + 10)
    } else {
        throw Exception("invalid hex char: ${ch}")
    }
}
