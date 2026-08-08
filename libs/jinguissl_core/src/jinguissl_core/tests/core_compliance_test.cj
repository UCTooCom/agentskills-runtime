package jinguissl_core.tests

import jinguissl_core.crypto.compliance.{FipsProfile, TlsVersion, TLS_VERSION_1_2, TLS_VERSION_1_3}
import jinguissl_core.crypto.error.CryptoException

@Test
public class CoreComplianceTestSuite {

    // ========== FipsProfile construction ==========

    @TestCase
    public func testPhase1DefaultProfileNotEmpty(): Unit {
        let profile = FipsProfile.phase1Default()
        let allowed = profile.allowedAlgorithms()
        @Assert(allowed.size > 0, true)
    }

    @TestCase
    public func testPhase1DefaultAllowsSha256(): Unit {
        let profile = FipsProfile.phase1Default()
        @Assert(profile.isAllowed("SHA-256"), true)
        profile.requireAllowed("SHA-256")
    }

    @TestCase
    public func testPhase1DefaultAllowsAesGcm(): Unit {
        let profile = FipsProfile.phase1Default()
        @Assert(profile.isAllowed("AES-GCM"), true)
    }

    @TestCase
    public func testPhase1DefaultRejectsSm4(): Unit {
        let profile = FipsProfile.phase1Default()
        @Assert(profile.isAllowed("SM4"), false)
        try {
            profile.requireAllowed("SM4")
            @Fail("SM4 should not be in default FIPS profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }

    @TestCase
    public func testPhase1DefaultRejectsChaCha20(): Unit {
        let profile = FipsProfile.phase1Default()
        @Assert(profile.isAllowed("ChaCha20"), false)
    }

    // ========== fromText parsing ==========

    @TestCase
    public func testFromTextSingleAlgorithm(): Unit {
        let profile = FipsProfile.fromText("SHA-256")
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("SHA-384"), false)
    }

    @TestCase
    public func testFromTextMultipleLines(): Unit {
        let text = "SHA-256\nSHA-384\nAES-GCM"
        let profile = FipsProfile.fromText(text)
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("SHA-384"), true)
        @Assert(profile.isAllowed("AES-GCM"), true)
        @Assert(profile.isAllowed("RSA"), false)
    }

    @TestCase
    public func testFromTextWithComments(): Unit {
        let text = "SHA-256\n# This is a comment\nAES-GCM\n  # indented comment"
        let profile = FipsProfile.fromText(text)
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("AES-GCM"), true)
    }

    @TestCase
    public func testFromTextWithEmptyLines(): Unit {
        let text = "SHA-256\n\n\nAES-GCM\n  "
        let profile = FipsProfile.fromText(text)
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("AES-GCM"), true)
    }

    @TestCase
    public func testFromTextCaseInsensitive(): Unit {
        let profile = FipsProfile.fromText("sha-256")
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("sha-256"), true)
    }

    @TestCase
    public func testFromTextWithCommas(): Unit {
        let text = "SHA-256, SHA-384, AES-GCM"
        let profile = FipsProfile.fromText(text)
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("SHA-384"), true)
        @Assert(profile.isAllowed("AES-GCM"), true)
    }

    @TestCase
    public func testFromTextCommaAndNewlineMixed(): Unit {
        let text = "SHA-256, SHA-384\nAES-GCM"
        let profile = FipsProfile.fromText(text)
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("SHA-384"), true)
        @Assert(profile.isAllowed("AES-GCM"), true)
    }

    // ========== Empty profile rejection ==========

    @TestCase
    public func testEmptyArrayRejected(): Unit {
        try {
            _ = FipsProfile([])
            @Fail("FipsProfile with empty array should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testFromTextOnlyCommentsRejected(): Unit {
        try {
            _ = FipsProfile.fromText("# just a comment\n\n # another")
            @Fail("FipsProfile.fromText with only comments should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testFromTextOnlyWhitespaceRejected(): Unit {
        try {
            _ = FipsProfile.fromText("  \n\n  ")
            @Fail("FipsProfile.fromText with only whitespace should throw")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    // ========== isAllowed/requireAllowed ==========

    @TestCase
    public func testIsAllowedVariants(): Unit {
        let profile = FipsProfile.phase1Default()
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("sha-256"), true)
        @Assert(profile.isAllowed("SHA256"), false)
    }

    @TestCase
    public func testRequireAllowedThrowsForBlocked(): Unit {
        let profile = FipsProfile.phase1Default()
        try {
            profile.requireAllowed("MD5")
            @Fail("MD5 should be blocked by default FIPS profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }

    @TestCase
    public func testRequireAllowedPassesForAllowed(): Unit {
        let profile = FipsProfile.phase1Default()
        profile.requireAllowed("AES-CBC")
        profile.requireAllowed("RSA")
        profile.requireAllowed("ECDSA")
        profile.requireAllowed("ECDH")
        profile.requireAllowed("TLS1.3")
    }

    // ========== TlsVersion ==========

    @TestCase
    public func testTlsVersionConstants(): Unit {
        @Assert(TLS_VERSION_1_2.toString(), "TLS1.2")
        @Assert(TLS_VERSION_1_3.toString(), "TLS1.3")
        @Assert(TLS_VERSION_1_2 != TLS_VERSION_1_3, true)
    }

    @TestCase
    public func testTlsVersionOrdinalValues(): Unit {
        @Assert(TLS_VERSION_1_2.ordinalValue(), 0)
        @Assert(TLS_VERSION_1_3.ordinalValue(), 1)
    }

    @TestCase
    public func testTlsVersionEquality(): Unit {
        @Assert(TLS_VERSION_1_2 == TLS_VERSION_1_2, true)
        @Assert(TLS_VERSION_1_3 == TLS_VERSION_1_3, true)
        @Assert(TLS_VERSION_1_2 == TLS_VERSION_1_3, false)
        @Assert(TLS_VERSION_1_3 == TLS_VERSION_1_2, false)
    }

    // ========== allowedAlgorithms() returns expected content ==========

    @TestCase
    public func testAllowedAlgorithmsContainsExpected(): Unit {
        let profile = FipsProfile.phase1Default()
        let all = profile.allowedAlgorithms()
        var foundSha256 = false
        var foundRsa = false
        for (alg in all) {
            if (alg == "SHA-256") { foundSha256 = true }
            if (alg == "RSA") { foundRsa = true }
        }
        @Assert(foundSha256, true)
        @Assert(foundRsa, true)
    }

    @TestCase
    public func testCustomProfileRoundTrip(): Unit {
        let algorithms: Array<String> = ["SHA-256", "AES-GCM", "RSA"]
        let profile = FipsProfile(algorithms)
        let all = profile.allowedAlgorithms()
        var count = 0
        for (_ in all) { count += 1 }
        @Assert(count == 3, true)
        @Assert(profile.isAllowed("SHA-256"), true)
        @Assert(profile.isAllowed("AES-GCM"), true)
        @Assert(profile.isAllowed("RSA"), true)
        @Assert(profile.isAllowed("MD5"), false)
    }
}
