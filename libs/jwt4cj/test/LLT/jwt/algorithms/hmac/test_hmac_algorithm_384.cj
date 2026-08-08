// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import stdx.encoding.hex.*
internal import jwt4cj.*

main() {
    var hmac1 = Algorithm.HMAC384("test1280".toArray())
    var arr2: Array<UInt8> = hmac1.sign("0123456789ABCDEF".toArray())
    if (toHexString(arr2) != "809f4653a5cc87ac82eaf3b95d7351406034198c13353b6c6cab8878c3ea2f1c607d5593b635e2d9718e95ba900f2939") {
        return -1
    }
    0
}
