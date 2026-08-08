// DEPENDENCE: ../algorithms/rsa/test_rsa_privateKey_02.pem
// DEPENDENCE: ../algorithms/rsa/test_rsa_privateKey.pem
// DEPENDENCE: ../algorithms/rsa/test_rsa_publicKey_02.pem
// DEPENDENCE: ../algorithms/ecdsa/test_ecdsa_privateKey.pem
// DEPENDENCE: ../algorithms/ecdsa/test_ecdsa_publicKey.pem
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*
internal import stdx.encoding.json.*
internal import std.collection.*
internal import std.time.*
internal import std.fs.*
internal import stdx.crypto.keys.*

main() {
    println(JsonNodeClaim(JsonValue.fromStr("null")).isNull())
    println(JsonNodeClaim(JsonValue.fromStr("1")).asInt())
    println(JsonNodeClaim(JsonValue.fromStr("1.1")).asFloat())
    println(JsonNodeClaim(JsonValue.fromStr(##"["a0"]"##)).asArray()[0])
    println(JsonNodeClaim(JsonValue.fromStr(##"["l0"]"##)).asList()[0])
    println(JsonNodeClaim(JsonValue.fromStr(##"{"k":"v"}"##)).asMap().get("k").toString())
    println(JsonNodeClaim(JsonValue.fromStr("123")).getValue())

    println(asIntList(JsonNodeClaim(JsonValue.fromStr(##"[1,2,4]"##))).size)
    println(asStringList(JsonNodeClaim(JsonValue.fromStr(##"["a","b"]"##))).size)

    println(Algorithm.none().getName())

    let rsaKey = RSAKeyProviderFileImpl("test_rsa_privateKey_02.pem", "test_rsa_publicKey_02.pem")
    println("rsaKey.getPrivateKey().toString() : ${rsaKey.getPrivateKey().toString()}")
    println("rsaKey.getPrivateKey().toString() : ${rsaKey.getPrivateKey().toString()}")

    let rsaPublicKey: ?RSAPublicKey = try {
        let textpub = String.fromUtf8(File.readFrom("test_rsa_publicKey_02.pem"))
        println(textpub)
        RSAPublicKey.decodeFromPem(textpub)
    } catch (e: Exception) {
        e.printStackTrace()
        None
    }
    println(rsaPublicKey?.toString())

    var rsaPri = RSAPrivateKey(1024)
    var rsaPub = RSAPublicKey(rsaKey.getPrivateKey())
    let pemEntry = rsaPub.encodeToPem()
    println(pemEntry.toString())
    println(pemEntry.label)
    for (kv in pemEntry.headers) {
        println("${kv[0]},${kv[1]}")
    }
    println(pemEntry.encode())

    println("rsaKey.getPublicKey().toString() : ${rsaPub.toString()}")

    let ecKey = ECDSAKeyProviderFileImpl("test_ecdsa_privateKey.pem", "test_ecdsa_publicKey.pem")
    println(ecKey.getPrivateKey().toString())
    println(ecKey.getPublicKey().toString())

    try {
        let ecPrivateKey = ECDSAPrivateKey.decodeFromPem("test_ecdsa_privateKey.pem")
        let ecPublicKey = ECDSAPublicKey.decodeFromPem("test_ecdsa_publicKey.pem")
    } catch (e: Exception) {
        e.printStackTrace()
    }
    
    let ecPrivateKey = ECDSAPrivateKey(P224)
    let ecPublicKey = ECDSAPublicKey(ecPrivateKey)
    let ecKey1 = ECDSAKeyProviderImpl(ecPrivateKey, ecPublicKey)
    println(ecKey1.getPrivateKey().toString())
    println(ecKey1.getPublicKey().toString())

    var rsapri = RSAPrivateKey(1024)
    var rsapub = RSAPublicKey(rsapri)
    File.writeTo("rsa_private.pem", rsapri.encodeToPem().encode().toArray())
    File.writeTo("rsa_public.pem", rsapub.encodeToPem().encode().toArray())
    var ecdsapri = ECDSAPrivateKey(P224)
    var ecdsapub = ECDSAPublicKey(ecdsapri)
    File.writeTo("ecdsa_private.pem", ecdsapri.encodeToPem().encode().toArray())
    File.writeTo("ecdsa_public.pem", ecdsapub.encodeToPem().encode().toArray())

    println(RSAPublicKey(RSAKeyProviderFileImpl("test_rsa_privateKey.pem").getPrivateKey()).encodeToPem().encode())
    println(ECDSAPublicKey(ECDSAKeyProviderFileImpl("test_ecdsa_privateKey.pem").getPrivateKey()).encodeToPem().encode())
    0
}
