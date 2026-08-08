// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import stdx.encoding.json.*
internal import jwt4cj.*

main() {
    try {
        MISSING_CLAIM.toString()
    } catch (e: MissingClaimException) {
        return 0
    }
    1
}
