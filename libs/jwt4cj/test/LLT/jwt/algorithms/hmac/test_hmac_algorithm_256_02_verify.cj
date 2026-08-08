// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import jwt4cj.*

main() {
    let hmac = Algorithm.HMAC256("pri_key")
    let token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.brtr31I4r5EjJOtSTx41_Jwby4ZcoxhGfm4KswEcWPA"
    let jd = JWTDecoder(token)
    hmac.verify(jd)
    println("verify success")
    0
}
