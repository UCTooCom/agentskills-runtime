package jinguissl.tests

import jinguissl.contract.*

/**
 * TLS Cipher Suite 合约层包装测试。
 *
 * 验证每个 contractTls13CipherSuite* 函数正确路由到 core
 * 并返回预期的 AEAD 算法、密钥长度、哈希算法、哈希长度和 IV 长度。
 */
@Test
public class ContractTlsCipherSuiteTestSuite {
    @TestCase
    public func testContractCipherSuiteAeadAlgorithmAes128GcmSha256(): Unit {
        let alg = contractTls13CipherSuiteAeadAlgorithm(0x1301)
        @Assert(alg.toString(), "AES-GCM")
    }

    @TestCase
    public func testContractCipherSuiteAeadAlgorithmChaCha20Poly1305(): Unit {
        let alg = contractTls13CipherSuiteAeadAlgorithm(0x1303)
        @Assert(alg.toString(), "ChaCha20-Poly1305")
    }

    @TestCase
    public func testContractCipherSuiteKeyLenAes128GcmSha256(): Unit {
        let keyLen = contractTls13CipherSuiteKeyLen(0x1301)
        @Assert(keyLen, 16)
    }

    @TestCase
    public func testContractCipherSuiteKeyLenChaCha20Poly1305(): Unit {
        let keyLen = contractTls13CipherSuiteKeyLen(0x1303)
        @Assert(keyLen, 32)
    }

    @TestCase
    public func testContractCipherSuiteHashAlgorithmSha256(): Unit {
        let hashAlg = contractTls13CipherSuiteHashAlgorithm(0x1301)
        @Assert(hashAlg == HashAlgorithm.SHA256, true)
    }

    @TestCase
    public func testContractCipherSuiteHashAlgorithmSha384(): Unit {
        let hashAlg = contractTls13CipherSuiteHashAlgorithm(0x1302)
        @Assert(hashAlg == HashAlgorithm.SHA384, true)
    }

    @TestCase
    public func testContractCipherSuiteHashLenAes128GcmSha256(): Unit {
        let hashLen = contractTls13CipherSuiteHashLen(0x1301)
        @Assert(hashLen, 32)
    }

    @TestCase
    public func testContractCipherSuiteHashLenAes256GcmSha384(): Unit {
        let hashLen = contractTls13CipherSuiteHashLen(0x1302)
        @Assert(hashLen, 48)
    }

    @TestCase
    public func testContractCipherSuiteIvLenAes128GcmSha256(): Unit {
        let ivLen = contractTls13CipherSuiteIvLen(0x1301)
        @Assert(ivLen, 12)
    }

    @TestCase
    public func testContractCipherSuiteAeadAlgorithmToString(): Unit {
        let aes = ContractTlsAeadAlgorithm.AesGcm
        let chacha = ContractTlsAeadAlgorithm.ChaCha20Poly1305
        @Assert(aes.toString(), "AES-GCM")
        @Assert(chacha.toString(), "ChaCha20-Poly1305")
    }


    @TestCase
    public func testContractCipherSuiteAeadAlgorithmRejectsUnknown(): Unit {
        try {
            _ = contractTls13CipherSuiteAeadAlgorithm(0xFFFF)
            @Fail("unknown cipher suite should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testContractCipherSuiteKeyLenRejectsUnknown(): Unit {
        try {
            _ = contractTls13CipherSuiteKeyLen(0xFFFF)
            @Fail("unknown cipher suite should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }
}
