// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

let header = ###"
{
  "k1": "v1",
  "kid": "algorithm.getSigningKeyId()",
  "alg": "none",
  "typ": "JWT",
  "cty": "JWT"
}
"###

let payload = 
    ###"
{
  "iss": "issuer",
  "sub": "subject",
  "aud": [
    "aud1",
    "aud2"
  ],
  "exp": 1673835090,
  "nbf": 1673835050,
  "iat": 1673835000,
  "jti": "jwtId",
  "bool": true,
  "int64": 64,
  "float64": 3.14,
  "String": "abaaba",
  "time": 1673850000,
  "map": {
    "mk2": "mv2"
  },
  "list": [
    56.51,
    41.96
  ],
  "null": null,
  "arraystring": [
    "astr1",
    "astr2"
  ],
  "arrayint": [
    684,
    64
  ],
  "pk1": "pv1",
  "pk2": "pv2"
}
"###

let token = 
    "CnsKICAiazEiOiAidjEiLAogICJraWQiOiAiYWxnb3JpdGhtLmdldFNpZ25pbmdLZXlJZCgpIiwKICAiYWxnIjogIm5vbmUiLAogICJ0eXAiOiAiSldUIiwKICAiY3R5IjogIkpXVCIKfQo.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAxNjczODM1MDkwLAogICJuYmYiOiAxNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiaW50NjQiOiA2NCwKICAiZmxvYXQ2NCI6IDMuMTQwMDAwLAogICJTdHJpbmciOiAiYWJhYWJhIiwKICAidGltZSI6IDE2NzM4NTAwMDAsCiAgIm1hcCI6IHsKICAgICJtazIiOiAibXYyIgogIH0sCiAgImxpc3QiOiBbCiAgICA1Ni41MTAwMDAsCiAgICA0MS45NjAwMDAKICBdLAogICJudWxsIjogbnVsbCwKICAiYXJyYXlzdHJpbmciOiBbCiAgICAiYXN0cjEiLAogICAgImFzdHIyIgogIF0sCiAgImFycmF5aW50IjogWwogICAgNjg0LAogICAgNjQKICBdLAogICJwazEiOiAicHYxIiwKICAicGsyIjogInB2MiIKfQ==."

main() {
    let decoder = JWT.decode(token)
    let arr = token.split(".")
    if (decoder.getHeader() != arr[0]) {
        println(decoder.getHeader())
        return 1
    }
    if (decoder.getPayload() != arr[1]) {
        println(decoder.getPayload())
        return 2
    }
    if (decoder.getSignature() != arr[2]) {
        println(decoder.getSignature())
        return 3
    }
    if (decoder.getAlgorithm() != "none") {
        return 4
    }
    if (decoder.getType() != "JWT") {
        return 5
    }
    if (decoder.getContentType() != "JWT") {
        return 6
    }
    if (decoder.getKeyId() != "algorithm.getSigningKeyId()") {
        return 7
    }
    if (decoder.getHeaderClaim("k1").asString() != "v1") {
        return 8
    }
    if (decoder.getIssuer() != "issuer") {
        return 9
    }
    if (decoder.getSubject() != "subject") {
        return 10
    }
    if (decoder.getAudience().size != 2) {
        return 11
    }
    if (decoder.getExpiresAt() != DateTime.ofEpoch(second: 1673835090, nanosecond: 0)) {
        return 12
    }
    if (decoder.getNotBefore() != DateTime.ofEpoch(second: 1673835050, nanosecond: 0)) {
        return 13
    }
    if (decoder.getIssuedAt() != DateTime.ofEpoch(second: 1673835000, nanosecond: 0)) {
        return 14
    }
    if (decoder.getId() != "jwtId") {
        return 15
    }
    if (decoder.getClaim("bool").asBool() != true) {
        return 16
    }
    if (decoder.getClaims().size != 19) {
        return 17
    }
    if (decoder.getToken() != token) {
        return 18
    }
    0
}
