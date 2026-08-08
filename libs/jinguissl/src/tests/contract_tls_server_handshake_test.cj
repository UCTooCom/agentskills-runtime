package jinguissl.tests

import jinguissl.contract.*

/**
 * TLS Server Handshake 合约层包装测试。
 *
 * 测试 EncryptedExtensions、Certificate 握手消息、ServerHello 创建
 * 及 X25519 密钥派生的合约包装。
 */
@Test
public class ContractTlsServerHandshakeTestSuite {
    @TestCase
    public func testContractBuildEncryptedExtensionsEmpty(): Unit {
        let ee = contractTls13BuildEncryptedExtensions()
        @Assert(ee.size > 0, true)
    }

    @TestCase
    public func testContractBuildEncryptedExtensionsWithAlpn(): Unit {
        let ee = contractTls13BuildEncryptedExtensions(selectedAlpn: "h2")
        @Assert(ee.size > 0, true)
    }

    @TestCase
    public func testContractBuildEncryptedExtensionsWithAcknowledge(): Unit {
        let ee = contractTls13BuildEncryptedExtensions(acknowledgeServerName: true)
        @Assert(ee.size > 0, true)
    }

    @TestCase
    public func testContractBuildCertificateHandshakeEmptyChainSucceeds(): Unit {
        let msg = contractTls13BuildCertificateHandshakeFromDerChain([])
        @Assert(msg.size > 4, true)
    }

    @TestCase
    public func testContractBuildServerHelloBadInput(): Unit {
        try {
            _ = contractTls13BuildServerHelloForX25519([], [])
            @Fail("empty client hello should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractDeriveSecretsFromX25519RequiresNonEmptyKeys(): Unit {
        try {
            _ = contractTls13DeriveSecretsFromX25519([], [], [], 0x1301)
            @Fail("empty keys should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractBuildEncryptedExtensionsWithAlpnAndAcknowledge(): Unit {
        let ee = contractTls13BuildEncryptedExtensions(selectedAlpn: "h2", acknowledgeServerName: true)
        @Assert(ee.size > 0, true)
        @Assert(ee[0], UInt8(8))
    }

    @TestCase
    public func testContractBuildEncryptedExtensionsWithHttp11Alpn(): Unit {
        let ee = contractTls13BuildEncryptedExtensions(selectedAlpn: "http/1.1")
        @Assert(ee.size > 0, true)
        @Assert(ee[0], UInt8(8))
    }

    @TestCase
    public func testContractBuildCertificateHandshakeWithSingleDerSucceeds(): Unit {
        let certDer: Array<Byte> = [0x30, 0x00]
        let msg = contractTls13BuildCertificateHandshakeFromDerChain([certDer])
        @Assert(msg.size > 4, true)
        @Assert(msg[0], UInt8(11))
    }
}
