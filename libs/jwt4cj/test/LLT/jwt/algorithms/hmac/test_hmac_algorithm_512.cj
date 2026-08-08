// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import stdx.encoding.hex.*
internal import jwt4cj.*

main() {
    var hmac1 = Algorithm.HMAC512("test1280".toArray())
    var arr2: Array<UInt8> = hmac1.sign("0123456789ABCDEF".toArray())
    if (toHexString(arr2) != "44f986af4ca102bfa133e7135994173e120399078e4fdbf2363c4ac975cc3ff67cbe235c7e3667a6120827118dc3ac8e54c949d7f6fdacc704cdf86b1c13a530") {
        return -1
    }
    0
}
