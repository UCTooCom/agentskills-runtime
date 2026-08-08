// EXEC: cjc %import-path %L %l %f
// EXEC: ./main
internal import std.collection.*
internal import std.time.*
internal import stdx.encoding.json.*

main(){
//     let headerJson = ###"{
//   "alg": "HS256",
//   "typ": "JWT",
//   "cty": "JWT",
//   "kid": "the key for signature validation",
//   "key1": "value1"
// }"###
//     let payloadJson = ###"{
//   "iss": "issuer1",
//   "sub": "Subject1",
//   "aud": ["Audience1"],
//   "exp": 1673835090,
//   "nbf": 1673830000,
//   "iat": 1673820000,
//   "jti": "jwtid1",
//   "key2": "value2"
// }"###

//     let parser = JWTParser()

//     let header = parser.parseHeader(headerJson)
//     if(header.getAlgorithm() != "HS256"){
//         return 1
//     }
//     if(header.getType() != "JWT"){
//         return 2
//     }
//     if(header.getContentType() != "JWT"){
//         return 3
//     }
//     if(header.getKeyId() != "the key for signature validation"){
//         return 4
//     }
//     if(header.getHeaderClaim("key1").asString() != "value1"){
//         return 5
//     }
//     if(!header.getHeaderClaim("mykey1").isMissing()){
//         return 6
//     }

//     let payload = parser.parsePayload(payloadJson)
//     if(payload.getIssuer() != "issuer1"){
//         return 7
//     }
//     if(payload.getSubject() != "Subject1"){
//         return 8
//     }
//     if(payload.getAudience() != ArrayList(["Audience1"])){
//         return 9
//     }
//     if(payload.getId() != "jwtid1"){
//         return 13
//     }
//     if(payload.getClaim("key2").asString() != "value2"){
//         return 14
//     }
//     if(!payload.getClaim("mykey1").isMissing()){
//         return 15
//     }

    0
}