package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractSmCapabilityTestSuite {
    @TestCase
    public func testContractSmCapabilityShape(): Unit {
        let info = contractSmCapability()
        @Assert(info.sm3Available, true)
        @Assert(info.sm4Available, true)
        @Assert(info.detail.trimAscii().size > 0, true)
        @Assert(info.sm3DigestLen, 32)
        @Assert(info.sm4BlockLen, 16)
        @Assert(info.sm4KeyLen, 16)
    }

    @TestCase
    public func testContractTrySmCapabilitySuccess(): Unit {
        let outcome = contractTrySmCapability()
        @Assert(outcome.ok, true)
        @Assert(outcome.message, "OK")
        match (outcome.code) {
            case Some(_) =>
                @Fail("successful SM outcome should not carry error code")
            case None => ()
        }
        match (outcome.igniteCode) {
            case Some(_) =>
                @Fail("successful SM outcome should not carry ignite code")
            case None => ()
        }
        match (outcome.result) {
            case Some(result) =>
                @Assert(result.sm3Available, true)
                @Assert(result.sm4Available, true)
            case None =>
                @Fail("successful SM outcome must carry a result")
        }
    }

    @TestCase
    public func testContractRequireSmCapabilitySucceeds(): Unit {
        let capability = contractRequireSmCapability()
        @Assert(capability.sm3Available, true)
        @Assert(capability.sm4Available, true)
    }

    @TestCase
    public func testContractSmCapabilityRejectsEmptyDetail(): Unit {
        try {
            _ = ContractSmCapability(true, true, "", 32, 16, 16)
            @Fail("empty detail should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractSmCapabilityRejectsNonPositiveSm3DigestLen(): Unit {
        try {
            _ = ContractSmCapability(true, true, "detail", 0, 16, 16)
            @Fail("non-positive SM3 digest length should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractSmCapabilityRejectsNonPositiveSm4BlockLen(): Unit {
        try {
            _ = ContractSmCapability(true, true, "detail", 32, 0, 16)
            @Fail("non-positive SM4 block length should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractSmCapabilityRejectsNonPositiveSm4KeyLen(): Unit {
        try {
            _ = ContractSmCapability(true, true, "detail", 32, 16, 0)
            @Fail("non-positive SM4 key length should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractSmCapabilityOutcomeRejectsEmptyMessage(): Unit {
        try {
            _ = ContractSmCapabilityOutcome(true, "")
            @Fail("empty outcome message should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractSmCapabilityOutcomeOkRejectsErrorCode(): Unit {
        try {
            _ = ContractSmCapabilityOutcome(
                true, "OK",
                code: Some(ContractErrorCode.BadInput)
            )
            @Fail("ok outcome should reject error code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractSmCapabilityOutcomeNotOkNoErrorCodeConstraint(): Unit {
        // SM outcome does not enforce code presence on !ok — just verify it constructs cleanly.
        let outcome = ContractSmCapabilityOutcome(
            false, "failed",
            code: Some(ContractErrorCode.CryptoUnavailable),
            igniteCode: Some(ContractIgniteCryptoErrorCode.CryptoUnavailable)
        )
        @Assert(outcome.ok, false)
        @Assert(outcome.message, "failed")
        match (outcome.code) {
            case Some(c) => @Assert(c.toString(), "CRYPTO_UNAVAILABLE")
            case None => @Fail("code must be set")
        }
    }

    @TestCase
    public func testContractSmCapabilityOutcomeOkWithoutResultValid(): Unit {
        // SM outcome does not enforce result presence — just verify it constructs cleanly.
        let outcome = ContractSmCapabilityOutcome(true, "OK")
        @Assert(outcome.ok, true)
    }
}
