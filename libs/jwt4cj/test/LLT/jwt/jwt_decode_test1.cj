// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

let token = 
    "ewogICJrMSI6ICJ2MSIsCiAgImtpZCI6ICJhbGdvcml0aG0uZ2V0U2lnbmluZ0tleUlkKCkiLAogICJhbGciOiAibm9uZSIsCiAgInR5cCI6ICJKV1QiCn0.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAxNjczODM1MDkwLAogICJuYmYiOiAxNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiaW50NjQiOiA2NCwKICAiZmxvYXQ2NCI6IDMuMTQwMDAwLAogICJTdHJpbmciOiAiYWJhYWJhIiwKICAidGltZSI6IDE2NzM4NTAwMDAsCiAgIm1hcCI6IHsKICAgICJtazIiOiAibXYyIgogIH0sCiAgImxpc3QiOiBbCiAgICA1Ni41MTAwMDAsCiAgICA0MS45NjAwMDAKICBdLAogICJudWxsIjogbnVsbCwKICAiYXJyYXlzdHJpbmciOiBbCiAgICAiYXN0cjEiLAogICAgImFzdHIyIgogIF0sCiAgImFycmF5aW50IjogWwogICAgNjg0LAogICAgNjQKICBdLAogICJwazEiOiAicHYxIiwKICAicGsyIjogInB2MiIKfQ"

main() {
    try {
        JWT.decode(token)
    } catch (e: JWTDecodeException) {
        if (e.message == "The token was expected to have 3 parts, but got 2.") {
            return 0
        }
    }
    1
}
