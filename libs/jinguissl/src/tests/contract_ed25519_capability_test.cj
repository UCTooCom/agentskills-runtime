package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractEd25519CapabilityTestSuite {
    @TestCase
    public func testContractEd25519SigningCapabilityShape(): Unit {
        let info = contractEd25519SigningCapability()
        @Assert(info.available, true)
        @Assert(info.detail.trimAscii().size > 0, true)
        @Assert(info.seedLen, 32)
        @Assert(info.pubKeyLen, 32)
        @Assert(info.sigLen, 64)
    }

    @TestCase
    public func testContractTryEd25519SigningCapabilitySuccess(): Unit {
        let outcome = contractTryEd25519SigningCapability()
        @Assert(outcome.ok, true)
        @Assert(outcome.message, "OK")
        match (outcome.code) {
            case Some(_) =>
                @Fail("successful Ed25519 outcome should not carry error code")
            case None => ()
        }
        match (outcome.igniteCode) {
            case Some(_) =>
                @Fail("successful Ed25519 outcome should not carry ignite code")
            case None => ()
        }
        match (outcome.result) {
            case Some(result) =>
                @Assert(result.seedLen, 32)
                @Assert(result.pubKeyLen, 32)
                @Assert(result.sigLen, 64)
            case None =>
                @Fail("successful Ed25519 outcome must carry a result")
        }
    }

    @TestCase
    public func testContractRequireEd25519SigningCapabilitySucceeds(): Unit {
        let capability = contractRequireEd25519SigningCapability()
        @Assert(capability.available, true)
        @Assert(capability.seedLen, 32)
    }

    @TestCase
    public func testContractEd25519SigningCapabilityRejectsEmptyDetail(): Unit {
        try {
            _ = ContractEd25519SigningCapability(true, "", 32, 32, 64)
            @Fail("empty detail should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEd25519SigningCapabilityRejectsNonPositiveSeedLen(): Unit {
        try {
            _ = ContractEd25519SigningCapability(true, "detail", 0, 32, 64)
            @Fail("non-positive seed length should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEd25519SigningCapabilityRejectsNonPositivePubKeyLen(): Unit {
        try {
            _ = ContractEd25519SigningCapability(true, "detail", 32, 0, 64)
            @Fail("non-positive pubkey length should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEd25519SigningCapabilityRejectsNonPositiveSigLen(): Unit {
        try {
            _ = ContractEd25519SigningCapability(true, "detail", 32, 32, 0)
            @Fail("non-positive sig length should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEd25519CapabilityOutcomeRejectsEmptyMessage(): Unit {
        try {
            _ = ContractEd25519SigningCapabilityOutcome(true, "")
            @Fail("empty outcome message should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEd25519CapabilityOutcomeOkRejectsErrorCode(): Unit {
        try {
            _ = ContractEd25519SigningCapabilityOutcome(
                true, "OK",
                code: Some(ContractErrorCode.BadInput)
            )
            @Fail("ok outcome should reject error code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEd25519CapabilityOutcomeNotOkRequiresCode(): Unit {
        try {
            _ = ContractEd25519SigningCapabilityOutcome(false, "failed")
            @Fail("not-ok outcome should require code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEd25519CapabilityOutcomeNotOkRequiresIgniteCode(): Unit {
        try {
            _ = ContractEd25519SigningCapabilityOutcome(
                false, "failed",
                code: Some(ContractErrorCode.CryptoUnavailable)
            )
            @Fail("not-ok outcome should require ignite code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }
}
