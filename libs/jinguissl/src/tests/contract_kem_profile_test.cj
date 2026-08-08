package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractKemProfileTestSuite {
    @TestCase
    public func testContractKemProfileShape(): Unit {
        let info = contractKemProfile()
        @Assert(info.algoHint.trimAscii().size > 0, true)
        @Assert(info.detail.trimAscii().size > 0, true)
    }

    @TestCase
    public func testContractTryKemProfileSuccess(): Unit {
        let outcome = contractTryKemProfile()
        @Assert(outcome.ok, true)
        @Assert(outcome.message, "OK")
        match (outcome.code) {
            case Some(_) =>
                @Fail("successful KEM outcome should not carry error code")
            case None => ()
        }
        match (outcome.igniteCode) {
            case Some(_) =>
                @Fail("successful KEM outcome should not carry ignite code")
            case None => ()
        }
        match (outcome.result) {
            case Some(result) =>
                @Assert(result.algoHint.trimAscii().size > 0, true)
            case None =>
                @Fail("successful KEM outcome must carry a result")
        }
    }

    @TestCase
    public func testContractKemProfileRejectsEmptyAlgoHint(): Unit {
        try {
            _ = ContractKemProfile(true, "", "detail")
            @Fail("empty algo hint should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractKemProfileRejectsEmptyDetail(): Unit {
        try {
            _ = ContractKemProfile(true, "ml-kem", "")
            @Fail("empty detail should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractKemProfileOutcomeRejectsEmptyMessage(): Unit {
        try {
            _ = ContractKemProfileOutcome(true, "")
            @Fail("empty outcome message should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractKemProfileOutcomeOkRejectsErrorCode(): Unit {
        try {
            _ = ContractKemProfileOutcome(
                true, "OK",
                code: Some(ContractErrorCode.BadInput)
            )
            @Fail("ok outcome should reject error code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractKemProfileOutcomeOkRejectsIgniteCode(): Unit {
        try {
            _ = ContractKemProfileOutcome(
                true, "OK",
                igniteCode: Some(ContractIgniteCryptoErrorCode.CryptoUnavailable)
            )
            @Fail("ok outcome should reject ignite code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractKemProfileOutcomeOkRequiresResult(): Unit {
        try {
            _ = ContractKemProfileOutcome(true, "OK")
            @Fail("ok outcome must carry a result")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractKemProfileOutcomeNotOkRequiresCode(): Unit {
        try {
            _ = ContractKemProfileOutcome(false, "failed")
            @Fail("not-ok outcome should require code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractKemProfileOutcomeNotOkRequiresIgniteCode(): Unit {
        try {
            _ = ContractKemProfileOutcome(
                false, "failed",
                code: Some(ContractErrorCode.CryptoUnavailable)
            )
            @Fail("not-ok outcome should require ignite code")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }
}
