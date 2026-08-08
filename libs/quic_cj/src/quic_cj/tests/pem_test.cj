package quic_cj.tests

import quic_cj.tls.{decodePemBlock, parseEcPrivateKeyFromPem, parseRsaPrivateKeyFromPem}

@Test
public class PemTestSuite {
    @TestCase
    public func testDecodePemBlockSimple(): Unit {
        let pem = "-----BEGIN TEST-----\nAAECAwQFBgcICQoLDA0ODw==\n-----END TEST-----"
        let der = decodePemBlock(pem, "TEST")
        @Assert(der.size > 0, true)
        @Assert(der[0], 0x00u8)
        @Assert(der[1], 0x01u8)
    }

    @TestCase
    public func testDecodePemBlockMultiline(): Unit {
        let pem = "-----BEGIN MULTI-----\nAAECAwQFBgcI\nCQoLDA0ODw==\n-----END MULTI-----"
        let der = decodePemBlock(pem, "MULTI")
        @Assert(der.size, 16)
    }

    @TestCase
    public func testDecodePemBlockWrongType(): Unit {
        let pem = "-----BEGIN WRONG-----\nAAECAwQ=\n-----END WRONG-----"
        let der = decodePemBlock(pem, "OTHER")
        @Assert(der.size, 0)
    }

    @TestCase
    public func testDecodePemBlockMissingEnd(): Unit {
        let pem = "-----BEGIN X-----\nAAECAwQ=\n-----END Y-----"
        let der = decodePemBlock(pem, "X")
        @Assert(der.size, 0)
    }

    @TestCase
    public func testDecodePemBlockEmpty(): Unit {
        let der = decodePemBlock("", "TEST")
        @Assert(der.size, 0)
    }

    @TestCase
    public func testDecodePemBlockNestedBegin(): Unit {
        let pem = "-----BEGIN A-----\nAAECAwQ=\n-----BEGIN B-----\nBQYHCAk=\n-----END B-----\n-----END A-----"
        let der = decodePemBlock(pem, "A")
        @Assert(der.size, 0)
    }

    @TestCase
    public func testBase64EmptyBlock(): Unit {
        let pem = "-----BEGIN EMPTY-----\n-----END EMPTY-----"
        let der = decodePemBlock(pem, "EMPTY")
        @Assert(der.size, 0)
    }

    @TestCase
    public func testBase64Padded(): Unit {
        let pem = "-----BEGIN TEST-----\ndGVzdA==\n-----END TEST-----"
        let der = decodePemBlock(pem, "TEST")
        @Assert(der.size, 4)
    }

    @TestCase
    public func testBase64NoPadding(): Unit {
        let pem = "-----BEGIN ABC-----\nYWJj\n-----END ABC-----"
        let der = decodePemBlock(pem, "ABC")
        @Assert(der.size, 3)
    }

    @TestCase
    public func testBase64OneByte(): Unit {
        let pem = "-----BEGIN ONE-----\n/w==\n-----END ONE-----"
        let der = decodePemBlock(pem, "ONE")
        @Assert(der.size, 1)
        @Assert(der[0], 0xffu8)
    }

    @TestCase
    public func testParseEcPrivateKey(): Unit {
        let pem = "-----BEGIN EC PRIVATE KEY-----\n" +
            "MHcCAQEEIJX7sU1j4o2Z0tK0X0J6R+I8X3HMk6R5VgC5T2oG5G+6oAoGCCqG\n" +
            "SM49AwEHoUQDQgAE/8N7Pk0mOeC87LQcZBl+NdRy5R4TbmJh+Kq/HjFh0SUz\n" +
            "vYCoTttTps+gEfd8hPrVH/a9IfYgWSAoqBexCk0Ebg==\n" +
            "-----END EC PRIVATE KEY-----"
        let key = parseEcPrivateKeyFromPem(pem)
        let bytes = key.scalar.toBytesBE()
        @Assert(bytes.size > 0, true)
    }

    @TestCase
    public func testParseRsaPrivateKey(): Unit {
        let pem = "-----BEGIN RSA PRIVATE KEY-----\n" +
            "MIIEpAIBAAKCAQEA0gI5rFHhJ8RJFchW1ot7rXORpAOoQt/Ow5f+5kCpWBbB\n" +
            "-----END RSA PRIVATE KEY-----"
        let key = parseRsaPrivateKeyFromPem(pem)
        @Assert(key.publicKey.modulus.toBytesBE().size > 0, true)
    }
}
