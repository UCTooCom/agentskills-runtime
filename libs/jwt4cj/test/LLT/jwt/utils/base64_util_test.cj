// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import jwt4cj.*

main() {
    let str = "as?0"
    let bytes = str.toArray()
    let urlsafe_b64 = "YXM_MA"

    let str2b64 = Base64Util.urlEncode(str)
    if (str2b64 != urlsafe_b64) {
        println("str2b64 fail")
        return -1
    }

    let byte2b64 = Base64Util.urlEncode(bytes)
    if (byte2b64 != urlsafe_b64) {
        println("byte2b64 fail")
        return -1
    }

    let b642str = Base64Util.urlDecode(urlsafe_b64)
    if (b642str != str) {
        return -1
    }

    let b642byte = Base64Util.urlDecode2Byte(urlsafe_b64)
    if (String.fromUtf8(b642byte) != str) {
        println("b642byte fail")
        return -1
    }

    return 0
}
