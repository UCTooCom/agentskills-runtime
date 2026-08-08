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
    let token = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.lJzdbO4vkmPmnHEwK061Uz7FxNKqrj4pQE86oTTmNNQKE3Pixq9VxiNWab43N9WNYMmSJWsNCNhVcvZ4nVminfy5UtBaXGfpUVcNrvIPkBEwIrEtRtYNCH3VlDKpWIQC16UuChyB7849CgWEl35jjYqQ-lb_RHMHgg9g28IVNV0"
    let rsa = Algorithm.RSA512(RSAKeyProviderFileImpl(pub_key))
    var jd = JWTDecoder(token)
    rsa.verify(jd)
    println("verify success")
    return 0
}
