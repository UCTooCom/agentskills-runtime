// DEPENDENCE: test_rsa_privateKey.pem
// DEPENDENCE: test_rsa_publicKey.pem
// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.fs.*
internal import std.posix.*
internal import jwt4cj.*

main() {

    let path: String = getcwd()
    // let pri_key: String = "${path}/test_rsa_privateKey.pem"
    let pub_key: String = "${path}/test_rsa_publicKey.pem"
    let token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.Q_CatS3ATEdvyR_T_jCFVDzVSJKWZpi5xYScdji3D6JBY335_AjanEzJFERNKO-d1KVs8Rx2xyNm6N_fI8y1Fg"
    let rsa = Algorithm.RSA256(RSAKeyProviderFileImpl(pub_key))
    var jd = JWTDecoder(token)
    rsa.verify(jd)
    println("verify success")
    return 0
}
