package quic_cj.tests

import quic_cj.{
    QError, CryptoError, StreamError, DatagramTooLargeError,
    newProtocolViolation, newFlowControlError, newFinalSizeError,
    newTransportError, newApplicationError, newCryptoError,
    newTransportErrorWithCode, ApplicationError,
}
import quic_cj.util.{
    PROTOCOL_VIOLATION, FLOW_CONTROL_ERROR, FINAL_SIZE_ERROR,
}

@Test
public class ErrorTestSuite {
    @TestCase
    public func testCryptoErrorCreation(): Unit {
        let err = CryptoError(20u8, "bad certificate")
        @Assert(err.alert, 20u8)
        @Assert(err.message, "bad certificate")
    }

    @TestCase
    public func testNewCryptoError(): Unit {
        let err = newCryptoError(10u8, "unexpected message")
        @Assert(err.alert, 10u8)
        @Assert(err.message, "unexpected message")
    }

    @TestCase
    public func testProtocolViolation(): Unit {
        let err = newProtocolViolation("invalid frame")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, PROTOCOL_VIOLATION)
        @Assert(err.errorMessage, "invalid frame")
    }

    @TestCase
    public func testFlowControlError(): Unit {
        let err = newFlowControlError("data overflow")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, FLOW_CONTROL_ERROR)
        @Assert(err.errorMessage, "data overflow")
    }

    @TestCase
    public func testFinalSizeError(): Unit {
        let err = newFinalSizeError("size mismatch")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, FINAL_SIZE_ERROR)
        @Assert(err.errorMessage, "size mismatch")
    }

    @TestCase
    public func testNewTransportError(): Unit {
        let err = newTransportError(0x0au64, "transport violation")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, 0x0au64)
        @Assert(err.errorMessage, "transport violation")
    }

    @TestCase
    public func testNewApplicationError(): Unit {
        let err = newApplicationError(0x01u64, "app error")
        @Assert(err.isTransport, false)
        @Assert(err.appCode, 0x01u64)
    }

    @TestCase
    public func testStreamErrorCreation(): Unit {
        let err = StreamError(4, 0x02u64, true)
        @Assert(err.streamId, 4)
        @Assert(err.errorCode, 0x02u64)
        @Assert(err.remote, true)
    }

    @TestCase
    public func testDatagramTooLargeError(): Unit {
        let err = DatagramTooLargeError(1200)
        @Assert(err.maxDatagramPayloadSize, 1200)
    }

    @TestCase
    public func testApplicationErrorCreation(): Unit {
        let err = ApplicationError(0x100u64, "app protocol error")
        @Assert(err.errorCode, 0x100u64)
        @Assert(err.reason, "app protocol error")
    }

    @TestCase
    public func testApplicationErrorDefault(): Unit {
        let err = ApplicationError(0u64, "")
        @Assert(err.errorCode, 0u64)
        @Assert(err.reason, "")
    }

    @TestCase
    public func testNewTransportErrorWithCode(): Unit {
        let err = newTransportErrorWithCode(0x0au64, "transport code error")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, 0x0au64)
        @Assert(err.errorMessage, "transport code error")
    }

    @TestCase
    public func testNewTransportErrorWithCodeDefaultMsg(): Unit {
        let err = newTransportErrorWithCode(0x01u64, "")
        @Assert(err.isTransport, true)
        @Assert(err.transportCode, 0x01u64)
        @Assert(err.errorMessage, "")
    }

    @TestCase
    public func testQErrorTransportInitialState(): Unit {
        let err = newTransportError(0x01u64, "")
        @Assert(err.isTransport, true)
        @Assert(err.appCode, 0u64)
    }

    @TestCase
    public func testQErrorApplicationInitialState(): Unit {
        let err = newApplicationError(0x100u64, "")
        @Assert(err.isTransport, false)
        @Assert(err.appCode, 0x100u64)
        @Assert(err.transportCode, 0u64)
    }

    @TestCase
    public func testStreamErrorDefaults(): Unit {
        let err = StreamError(0, 0u64, false)
        @Assert(err.streamId, 0)
        @Assert(err.errorCode, 0u64)
        @Assert(err.remote, false)
    }

    @TestCase
    public func testStreamErrorLargeValues(): Unit {
        let err = StreamError(999999, 0xFFFFFFFFu64, true)
        @Assert(err.streamId, 999999)
        @Assert(err.errorCode, 0xFFFFFFFFu64)
        @Assert(err.remote, true)
    }
}
