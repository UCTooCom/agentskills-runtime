package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractMetadataTestSuite {
    @TestCase
    public func testContractFacadeInfoShape(): Unit {
        let info = contractFacadeInfo()
        @Assert(info.apiVersion, "1.0.0")
        @Assert(info.stabilityLevel, "L1")
        @Assert(info.freezeDate, "2026-03-24")
        @Assert(info.stableDomains.size > 0, true)
        @Assert(info.importRule.contains("jinguissl.contract.*"), true)
    }

    @TestCase
    public func testContractCapabilityInfoShape(): Unit {
        let info = contractCapabilityInfo()
        @Assert(info.stableDomains.size > 0, true)
        @Assert(info.httpTlsFeatures.contains("tls13-x25519"), true)
        @Assert(info.sshFeatures.contains("x25519-kex"), true)
        @Assert(info.x509Features.contains("certificate-chain-verify"), true)
        @Assert(info.directStdxTlsServerConfigBridge, false)
        @Assert(info.notes.size > 0, true)
    }

    @TestCase
    public func testContractFacadeInfoRejectsEmptyVersion(): Unit {
        try {
            _ = ContractFacadeInfo("", "L1", "2026-03-24", ["tls13"], "import jinguissl.contract.* only")
            @Fail("empty version should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractErrorAndIgniteCodesStayStable(): Unit {
        @Assert(ContractErrorCode.VerifyFailed.toString(), "VERIFY_FAILED")
        @Assert(ContractIgniteCryptoErrorCode.DecryptFailed.toString(), "DECRYPT_FAILED")
    }
}

// Supplemental tests added for enriched coverage
@Test
public class ContractSupplementaryTestSuite {
    @TestCase
    public func testContractMd5KnownVector(): Unit {
        let empty: Array<Byte> = []
        let digest = contractMd5(empty)
        @Assert(contractBytesToHexLower(digest), "d41d8cd98f00b204e9800998ecf8427e")
    }

    @TestCase
    public func testContractSha1KnownVector(): Unit {
        let empty: Array<Byte> = []
        let digest = contractSha1(empty)
        @Assert(contractBytesToHexLower(digest), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    @TestCase
    public func testContractChacha20Poly1305AlgorithmName(): Unit {
        let name = contractChacha20Poly1305AlgorithmName()
        @Assert(name, "CHACHA20-POLY1305")
    }

    @TestCase
    public func testContractMapToIgniteCryptoErrorCode(): Unit {
        @Assert(contractMapToIgniteCryptoErrorCode(ContractErrorCode.BadInput).toString(), "BAD_ENVELOPE")
    }

    @TestCase
    public func testContractHttpSshStartupProfilesCount(): Unit {
        let profiles = contractListHttpSshStartupProfiles()
        @Assert(profiles.size, 6)
    }

    @TestCase
    public func testContractSmCapability(): Unit {
        let info = contractSmCapability()
        @Assert(info.sm3DigestLen, 32)
    }

    @TestCase
    public func testContractKemProfile(): Unit {
        let profile = contractKemProfile()
        @Assert(profile.available, false)
    }

    @TestCase
    public func testContractEccCapability(): Unit {
        let info = contractEccCapability()
        @Assert(info.available, true)
    }

    @TestCase
    public func testContractEd25519SigningCapability(): Unit {
        let info = contractEd25519SigningCapability()
        @Assert(info.seedLen, 32)
    }

    @TestCase
   public func testContractRsaCapability(): Unit {
       let info = contractRsaCapability()
       @Assert(info.available, true)
   }

    @TestCase
    public func testContractBytesToHexLowerEdgeCases(): Unit {
        let empty: Array<Byte> = []
        @Assert(contractBytesToHexLower(empty), "")

        let single: Array<Byte> = [UInt8(0x00)]
        @Assert(contractBytesToHexLower(single), "00")

        let ff: Array<Byte> = [UInt8(0xff)]
        @Assert(contractBytesToHexLower(ff), "ff")

        let abc: Array<Byte> = [UInt8(0xab), UInt8(0xcd)]
        @Assert(contractBytesToHexLower(abc), "abcd")
    }

    @TestCase
    public func testContractSha256KnownVectors(): Unit {
        let empty: Array<Byte> = []
        let emptyDigest = contractSha256(empty)
        @Assert(contractBytesToHexLower(emptyDigest), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

        let abc = "abc".toArray()
        let abcDigest = contractSha256(abc)
        @Assert(contractBytesToHexLower(abcDigest), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @TestCase
    public func testContractSha512KnownVectors(): Unit {
        let empty: Array<Byte> = []
        let emptyDigest = contractSha512(empty)
        @Assert(contractBytesToHexLower(emptyDigest), "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e")

        let abc = "abc".toArray()
        let abcDigest = contractSha512(abc)
        @Assert(contractBytesToHexLower(abcDigest), "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
    }

    @TestCase
    public func testContractHkdfEdgeCases(): Unit {
        let ikm = Array<Byte>(22, repeat: 0x0b)
        let salt = Array<Byte>(32, repeat: 0x01)
        let info = Array<Byte>(10, repeat: 0xf0)

        // Zero-length output (not valid, should still not crash)
        let zero = contractHkdf(HashAlgorithm.SHA256, ikm, info, 0, salt: salt)
        @Assert(zero.size, 0)

        // Empty info
        let noInfo = Array<Byte>(0, repeat: 0)
        let okm = contractHkdf(HashAlgorithm.SHA256, ikm, noInfo, 16, salt: salt)
        @Assert(okm.size, 16)
    }

    @TestCase
    public func testContractHashEdgeCases(): Unit {
        let empty: Array<Byte> = []
        let sha384Empty = contractSha384(empty)
        @Assert(sha384Empty.size, 48)

        let genericSha384 = contractHash(HashAlgorithm.SHA384, empty)
        @Assert(genericSha384, sha384Empty)

        let genericSha256 = contractHash(HashAlgorithm.SHA256, empty)
        @Assert(genericSha256.size, 32)
    }
}
