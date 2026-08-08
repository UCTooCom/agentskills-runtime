package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractEccCapabilityTestSuite {
    @TestCase
    public func testContractEccCapabilityShape(): Unit {
        let info = contractEccCapability()
        @Assert(info.available, true)
        @Assert(info.detail.trimAscii().size > 0, true)
        @Assert(info.supportedCurves.size > 0, true)
        @Assert(info.ecdsaAllowed, true)
    }

    @TestCase
    public func testContractEccCapabilitySupportedCurvesP256(): Unit {
        let info = contractEccCapability()
        var found = false
        for (curve in info.supportedCurves) {
            if (curve == "P-256") { found = true }
        }
        @Assert(found, true)
    }

    @TestCase
    public func testContractEccCapabilitySupportedCurvesP384(): Unit {
        let info = contractEccCapability()
        var found = false
        for (curve in info.supportedCurves) {
            if (curve == "P-384") { found = true }
        }
        @Assert(found, true)
    }

    @TestCase
    public func testContractEccCapabilitySupportedCurvesP521(): Unit {
        let info = contractEccCapability()
        var found = false
        for (curve in info.supportedCurves) {
            if (curve == "P-521") { found = true }
        }
        @Assert(found, true)
    }

    @TestCase
    public func testContractTryEccCapabilitySuccess(): Unit {
        let outcome = contractTryEccCapability()
        @Assert(outcome.ok, true)
        @Assert(outcome.message, "OK")
        match (outcome.code) {
            case Some(_) =>
                @Fail("successful ECC outcome should not carry error code")
            case None => ()
        }
        match (outcome.igniteCode) {
            case Some(_) =>
                @Fail("successful ECC outcome should not carry ignite code")
            case None => ()
        }
        match (outcome.result) {
            case Some(result) =>
                @Assert(result.available, true)
                @Assert(result.supportedCurves.size > 0, true)
            case None =>
                @Fail("successful ECC outcome must carry a result")
        }
    }

    @TestCase
    public func testContractRequireEccCapabilitySucceeds(): Unit {
        let capability = contractRequireEccCapability()
        @Assert(capability.available, true)
        @Assert(capability.ecdsaAllowed, true)
        @Assert(capability.ecdhAllowed, true)
    }

    @TestCase
    public func testContractEccCapabilityRejectsEmptyDetail(): Unit {
        try {
            _ = ContractEccCapability(true, "", [], [], true, true)
            @Fail("empty detail should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEccCapabilityOutcomeRejectsEmptyMessage(): Unit {
        try {
            _ = ContractEccCapabilityOutcome(true, "")
            @Fail("empty outcome message should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEccCapabilityOutcomeOkRejectsErrorCode(): Unit {
        try {
            _ = ContractEccCapabilityOutcome(
                true, "OK",
                code: Some(ContractErrorCode.BadInput)
            )
            @Fail("ok outcome should reject error code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEccCapabilityOutcomeNotOkRequiresCode(): Unit {
        try {
            _ = ContractEccCapabilityOutcome(false, "failed")
            @Fail("not-ok outcome should require code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractEccCapabilityOutcomeNotOkRequiresIgniteCode(): Unit {
        try {
            _ = ContractEccCapabilityOutcome(
                false, "failed",
                code: Some(ContractErrorCode.CryptoUnavailable)
            )
            @Fail("not-ok outcome should require ignite code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }
}
