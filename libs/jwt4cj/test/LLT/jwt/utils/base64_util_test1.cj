// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import jwt4cj.*

main() {
    let header = ###"
{
  "k1": "v1",
  "alg": "none",
  "typ": "JWT",
  "cty": "JWT"
}
"###
    let str2b64 = Base64Util.urlEncode(header)
    println(str2b64)
    
    let wrongJson2B64 = Base64Util.urlEncode(header+"}")
    println(wrongJson2B64)

    return 0
}
