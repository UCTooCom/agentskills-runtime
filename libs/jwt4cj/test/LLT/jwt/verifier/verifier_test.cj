// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

let token = "ewogICJrMSI6ICJ2MSIsCiAgImtpZCI6ICJrZXlJZCIsCiAgImFsZyI6ICJub25lIiwKICAidHlwIjogIkpXVCIKfQ.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAzNjczODM1MDUwLAogICJuYmYiOiAxNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiZGRkIjogImRmZGRkZmYiLAogICJpbnQ2NCI6IDY0LAogICJmbG9hdDY0IjogMy4xNDAwMDAsCiAgIlN0cmluZyI6ICJhYmFhYmEiLAogICJ0aW1lIjogMTY3Mzg1MDAwMCwKICAibWFwIjogewogICAgIm1rMiI6ICJtdjIiCiAgfSwKICAibGlzdCI6IFsKICAgIDU2LjUxMDAwMCwKICAgIDQxLjk2MDAwMAogIF0sCiAgIm51bGwiOiBudWxsLAogICJhcnJheXN0cmluZyI6IFsKICAgICJhc3RyMSIsCiAgICAiYXN0cjIiCiAgXSwKICAiYXJyYXlpbnQiOiBbCiAgICA2ODQsCiAgICA2NAogIF0sCiAgInBrMSI6ICJwdjEiLAogICJwazIiOiAicHYyIgp9."

main() {
   
  let require = JWT.require(Algorithm.none());
  try {
    require.withClaim("String","abaaba")
           .withArrayClaim("arraystring",["astr1","astr2"])
           .withArrayClaim("arrayint", [684,64])
    require.withClaim("time", DateTime.ofEpoch(second: 1673850000, nanosecond: 0))
        .withClaim("bool", true)
        .withClaim("int64", 64)
        .withClaim("float64", 3.14)
        .withIssuer("issuer") // 签发对象
        .withAudience(["aud1"]) // 接收全部对象   // ["aud1", "aud3"] false
        .withAnyOfAudience(["aud1", "aud3"]) //接收部分对象
        .withSubject("subject")
        .withJWTId("jwtId")
        .withClaimPresence("ddd")


    require.acceptExpiresAt(111111)
    require.acceptLeeway(111111) // 设置默认时间


    let builder: JWTVerifier = require.build()
    builder.verify(token)
    return 0
  } catch (e: TokenExpiredException){
    println(e.message)
    return 2
  }
   catch(e: Exception) {
    return 3
  }
}