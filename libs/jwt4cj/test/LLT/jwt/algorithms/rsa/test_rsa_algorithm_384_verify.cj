// DEPENDENCE: test_rsa_privateKey_02.pem
// DEPENDENCE: test_rsa_publicKey_02.pem
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.fs.*
internal import std.posix.*
internal import jwt4cj.*

main() {

    let path: String = getcwd()
    // let pri_key: String = "${path}/test_rsa_privateKey_02.pem"
    let pub_key: String = "${path}/test_rsa_publicKey_02.pem"
    let token = "eyJhbGciOiJSUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.Rypv9wnvE1-mDBkogHAwRZR1V2fHzOQZUyOrT5IgyrknUyK5kEs8gHBvIA5RqJkmsoUJAn8CQi5rC0dTaLU7pf_bDYUdsGc1GIDNAhEGAT6RCsZWCwkRxofHHVNet116Pv5gO9pBztLJWJfLy1a6k4Dfn-72EM0uLtRTXizWzT8"
    let rsa = Algorithm.RSA384(RSAKeyProviderFileImpl(pub_key))
    var jd = JWTDecoder(token)
    rsa.verify(jd)
    println("verify success")
    return 0
}
