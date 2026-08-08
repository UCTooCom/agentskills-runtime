package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractRsaCapabilityTestSuite {
    @TestCase
    public func testContractRsaCapabilityShape(): Unit {
        let info = contractRsaCapability()
        @Assert(info.available, true)
        @Assert(info.detail.trimAscii().size > 0, true)
        @Assert(info.supportedKeySizes.size > 0, true)
        @Assert(info.supportedSchemes.size > 0, true)
        @Assert(info.supportedHashAlgorithms.size > 0, true)
        @Assert(info.rsaAllowed, true)
    }

    @TestCase
    public func testContractRsaCapabilitySupportedKeySizes(): Unit {
        let info = contractRsaCapability()
        @Assert(info.supportedKeySizes.size > 0, true)
        @Assert(info.supportedSchemes.size > 0, true)
        @Assert(info.supportedHashAlgorithms.size > 0, true)
        var found2048 = false
        for (size in info.supportedKeySizes) {
            if (size == 2048) { found2048 = true }
        }
        @Assert(found2048, true)
    }

    @TestCase
    public func testContractTryRsaCapabilitySuccess(): Unit {
        let outcome = contractTryRsaCapability()
        @Assert(outcome.ok, true)
        @Assert(outcome.message, "OK")
        match (outcome.code) {
            case Some(_) =>
                @Fail("successful RSA outcome should not carry error code")
            case None => ()
        }
        match (outcome.igniteCode) {
            case Some(_) =>
                @Fail("successful RSA outcome should not carry ignite code")
            case None => ()
        }
        match (outcome.result) {
            case Some(result) =>
                @Assert(result.available, true)
                @Assert(result.supportedKeySizes.size > 0, true)
            case None =>
                @Fail("successful RSA outcome must carry a result")
        }
    }

    @TestCase
    public func testContractRequireRsaCapabilitySucceeds(): Unit {
        let capability = contractRequireRsaCapability()
        @Assert(capability.available, true)
        @Assert(capability.rsaAllowed, true)
    }

    @TestCase
    public func testContractRsaCapabilityRejectsEmptyDetail(): Unit {
        try {
            _ = ContractRsaCapability(true, "", [2048], ["rsassa-pkcs1-v1_5"], ["sha256"], true)
            @Fail("empty detail should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractRsaCapabilityRejectsEmptyKeySizes(): Unit {
        try {
            _ = ContractRsaCapability(true, "detail", [], ["rsassa-pkcs1-v1_5"], ["sha256"], true)
            @Fail("empty key sizes should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractRsaCapabilityRejectsEmptySchemes(): Unit {
        try {
            _ = ContractRsaCapability(true, "detail", [2048], [], ["sha256"], true)
            @Fail("empty schemes should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractRsaCapabilityRejectsEmptyHashAlgorithms(): Unit {
        try {
            _ = ContractRsaCapability(true, "detail", [2048], ["rsassa-pkcs1-v1_5"], [], true)
            @Fail("empty hash algorithms should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractRsaCapabilityOutcomeRejectsEmptyMessage(): Unit {
        try {
            _ = ContractRsaCapabilityOutcome(true, "")
            @Fail("empty outcome message should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractRsaCapabilityOutcomeOkRejectsErrorCode(): Unit {
        try {
            _ = ContractRsaCapabilityOutcome(
                true, "OK",
                code: Some(ContractErrorCode.BadInput)
            )
            @Fail("ok outcome should reject error code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractRsaCapabilityOutcomeNotOkRequiresCode(): Unit {
        try {
            _ = ContractRsaCapabilityOutcome(false, "failed")
            @Fail("not-ok outcome should require code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractRsaCapabilityOutcomeNotOkRequiresIgniteCode(): Unit {
        try {
            _ = ContractRsaCapabilityOutcome(
                false, "failed",
                code: Some(ContractErrorCode.CryptoUnavailable)
            )
            @Fail("not-ok outcome should require ignite code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }
}
