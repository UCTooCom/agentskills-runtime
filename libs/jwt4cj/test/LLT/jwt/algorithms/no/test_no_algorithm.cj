// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import jwt4cj.*

main() {
    var noa = Algorithm.none()
    noa.sign("0123456789".toArray(), "ABCDEF".toArray())
    let token = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.MEUCIDyeCSbxc2rZ8qWg01aIEVxgIAoKFTj3kZOL4rRonuHxAiEAscdWHtaNHFu5GlWmkY0HQruaxyCJSFi4wJGsftUM0LI"
    var jd = JWTDecoder(token)
    try {
        noa.verify(jd)
    } catch (e: SignatureVerificationException) {
        return 0
    }
    return 1
}
