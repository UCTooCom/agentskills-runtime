// EXEC: cjc %import-path %L %l %f
// EXEC: ./main

import yaml4cj.yaml.*

main() {
    // 2023年2月27日 不再提供外部能力

    // let res1 = EncodingT.EncodingT_ANY_ENCODING
    // let res2 = EncodingT.EncodingT_UTF8_ENCODING
    // let res3 = EncodingT.EncodingT_UTF16LE_ENCODING
    // let res4 = EncodingT.EncodingT_UTF16BE_ENCODING

    // if(
    //     ((res1.toString() != "EncodingT_ANY_ENCODING") && (res1.hashCode() != 0)) ||
    //     ((res2.toString() != "EncodingT_UTF8_ENCODING") && (res2.hashCode() != 1)) ||
    //     ((res3.toString() != "EncodingT_UTF16LE_ENCODING") && (res3.hashCode() != 2)) ||
    //     ((res4.toString() != "EncodingT_UTF16BE_ENCODING") && (res4.hashCode() != 3)) ||
    //     (res1 != res2) != true ||
    //     (res1 == res2) != false
    // ) {
    //     return -1
    // }

    return 0
}
