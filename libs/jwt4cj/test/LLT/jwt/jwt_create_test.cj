// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

let header = ###"
{
  "k1": "v1",
  "kid": "keyId",
  "alg": "none",
  "typ": "JWT"
}
"###

let payload = ###"
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

// let token = "ewogICJrMSI6ICJ2MSIsCiAgImtpZCI6ICJrZXlJZCIsCiAgImFsZyI6ICJIUzI1NiIsCiAgInR5cCI6ICJKV1QiCn0.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAzNjczODM1MDUwLAogICJuYmYiOiAxNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiZGRkIjogImRmZGRkZmYiLAogICJpbnQ2NCI6IDY0LAogICJmbG9hdDY0IjogMy4xNDAwMDAsCiAgIlN0cmluZyI6ICJhYmFhYmEiLAogICJ0aW1lIjogMTY3Mzg1MDAwMCwKICAibWFwIjogewogICAgIm1rMiI6ICJtdjIiCiAgfSwKICAibGlzdCI6IFsKICAgIDU2LjUxMDAwMCwKICAgIDQxLjk2MDAwMAogIF0sCiAgIm51bGwiOiBudWxsLAogICJhcnJheXN0cmluZyI6IFsKICAgICJhc3RyMSIsCiAgICAiYXN0cjIiCiAgXSwKICAiYXJyYXlpbnQiOiBbCiAgICA2ODQsCiAgICA2NAogIF0sCiAgInBrMSI6ICJwdjEiLAogICJwazIiOiAicHYyIgp9.V1UenPvLJGuM8-y7TSZXN5miDSLYXWsxwVQq7RRzY-w"
let token="ewogICJrMSI6ICJ2MSIsCiAgImtpZCI6ICJrZXlJZCIsCiAgImFsZyI6ICJIUzI1NiIsCiAgInR5cCI6ICJKV1QiCn0.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAzNjczODM1MDUwLAogICJuYmYiOiAxNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiZGRkIjogImRmZGRkZmYiLAogICJpbnQ2NCI6IDY0LAogICJmbG9hdDY0IjogMy4xNCwKICAiU3RyaW5nIjogImFiYWFiYSIsCiAgInRpbWUiOiAxNjczODUwMDAwLAogICJtYXAiOiB7CiAgICAibWsyIjogIm12MiIKICB9LAogICJsaXN0IjogWwogICAgNTYuNTEsCiAgICA0MS45NgogIF0sCiAgIm51bGwiOiBudWxsLAogICJhcnJheXN0cmluZyI6IFsKICAgICJhc3RyMSIsCiAgICAiYXN0cjIiCiAgXSwKICAiYXJyYXlpbnQiOiBbCiAgICA2ODQsCiAgICA2NAogIF0sCiAgInBrMSI6ICJwdjEiLAogICJwazIiOiAicHYyIgp9.RUKjRTPoqdQWf0tuoxyHy_sP3ftUEef-8xHPTjv5BZw"

main(){
    let jwtStr = JWT.create()
        .withHeader(HashMap<String, Any>([("k1","v1")]))
        .withKeyId("keyId")
        .withIssuer("issuer")
        .withSubject("subject")
        .withAudience(["aud1", "aud2"])
        .withExpiresAt(DateTime.ofEpoch(second: 3673835050, nanosecond: 0))
        .withNotBefore(DateTime.ofEpoch(second: 1673835050, nanosecond: 0))
        .withIssuedAt(DateTime.ofEpoch(second: 1673835000, nanosecond: 0))
        .withJWTId("jwtId")
        .withClaim("bool", true)
        .withClaim("ddd", "dfdddff")
        .withClaim("int64", 64)
        .withClaim("float64", 3.14)
        .withClaim("String", "abaaba")
        .withClaim("time", DateTime.ofEpoch(second: 1673850000, nanosecond: 0))
        .withClaim("map", HashMap<String, Any>([("mk2","mv2")]))
        .withClaim("list", ArrayList<Any>([56.51,41.96]))
        .withNullClaim("null")
        .withArrayClaim("arraystring", ["astr1","astr2"])
        .withArrayClaim("arrayint", [684,64])
        .withPayload(HashMap<String, Any>([("pk1","pv1"),("pk2","pv2")]))
        .sign(Algorithm.HMAC256("admin"))
    println(jwtStr)
    println(token)
    if(jwtStr != token){
        return 1
    }
    0
}
