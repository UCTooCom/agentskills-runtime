# JinguiSSL Core - Usage Samples

This directory contains standalone sample projects demonstrating how to use
the JinguiSSL Core library for various cryptographic operations.

Each subdirectory is an independent CangJie project with a `main()` entry point
that showcases a specific module's capabilities. Build and run any sample with:

```bash
cd sample/<scenario>
cjpm build && cjpm run
```

## Available Samples

| Sample | Module | Description |
|--------|--------|-------------|
| [ed25519](ed25519/) | `crypto/ed25519` | Ed25519 key generation, signing, and verification |
| [aes](aes/) | `crypto/aes` | AES encryption in ECB, CBC, and GCM modes |
| [digest](digest/) | `crypto/digest` | Hash functions (MD5, SHA-1/256/384/512), HMAC, HKDF |
| [x25519](x25519/) | `crypto/x25519` | X25519 ECDH key agreement |
| [chacha20](chacha20/) | `crypto/chacha20` | ChaCha20 stream cipher and ChaCha20-Poly1305 AEAD |
| [rsa](rsa/) | `crypto/rsa` | RSA key generation, PKCS1v1.5 and PSS signatures |
| [sm3](sm3/) | `crypto/sm3` | SM3 cryptographic hash (GM/T 0004-2012) |
| [sm4](sm4/) | `crypto/sm4` | SM4 block cipher (GM/T 0002-2012) |
| [ecc](ecc/) | `crypto/ecc` | ECDSA signatures and ECDH key exchange |
| [x509](x509/) | `crypto/x509` | X.509 certificate parsing and chain verification |
| [kem](kem/) | `crypto/kem` | RSA-KEM and ECDH-KEM encapsulation |
| [compliance](compliance/) | `crypto/compliance` | FIPS 140 compliance profiles |
| [utils](utils/) | `crypto/utils` | Utility functions (endian, constant-time, CSPRNG) |
| [bignum](bignum/) | `crypto/bignum` | BigNum arithmetic, modular exponentiation, and GCD |
| [ssh](ssh/) | `crypto/ssh` | SSH host key fingerprints and version banner |
| [tls](tls/) | `crypto/tls` | TLS session ticket creation, encoding, and decoding |

## Prerequisites

CangJie SDK with `cjpm` build tool. The samples reference `jinguissl_core`
as a path dependency pointing to the parent directory.
