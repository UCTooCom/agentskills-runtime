# jwt库

## jwt入口

### 介绍

    jwt开放api入口

### 主要接口

#### class JWT

```cangjie
public class JWT {
    /*
    * 构造函数
    */
    public init()
    /*
    * jwt解码
    * @param token jwt
    * @return DecodedJWT 解码后的jwt
    */
    public func decodeJwt(token: String): DecodedJWT
    /*
    * jwt解码
    * @param token jwt
    * @return DecodedJWT 解码后的jwt
    */
    public static func decode(token: String): DecodedJWT
    /*
    * 创建校验器
    * @param algorithm 算法对象
    * @return Verification
    */
    public static func require(algorithm: Algorithm): Verification

    /*
    * 创建构造器
    * @return Builder
    */
    public static func create(): Builder
}
```

## jwt构建

### 介绍

构造jwt字符串

### 主要接口

#### class Builder

```
/*
 * 构造header/payload内容
 * value支持String/Bool/Time/Int64/Float64/JsonValue/Array<String>/Array<Int64>/Map<String,Any>/ArrayList<Any>
 * 可嵌套 Any只支持以上类型
 */
public class Builder{
    /*
    * 批量添加值到header
    * @param headerClaims 
    * @return Builder
    */
    public func withHeader(headerClaims: Map<String, Any>): Builder

    /*
    * 添加keyid到Header
    * @param keyId value
    * @return Builder
    */
    public func withKeyId(keyId: String): Builder

    /*
    * 添加发布者到Payload
    * @param issuer Issuer value
    * @return Builder
    */
    public func withIssuer(issuer: String): Builder

    /*
    * 添加主题到Payload
    * @param subject Subject value
    * @return Builder
    */
    public func withSubject(subject: String): Builder

    /*
    * 添加接受者到Payload
    * @param audience Audience value
    * @return Builder
    */
    public func withAudience(audience: Array<String>): Builder

    /*
    * 添加超时到payload
    * @param expiresAt the Expires At value
    * @return Builder
    */
    public func withExpiresAt(expiresAt: DateTime): Builder

    /*
    * 添加Not Before ("nbf") claim到Payload
    * @param notBefore the Not Before value
    * @return Builder
    */
    public func withNotBefore(notBefore: DateTime): Builder

    /*
    * 添加发布时间到Payload
    * @param issuedAt the Issued At value
    * @return Builder
    */
    public func withIssuedAt(issuedAt: DateTime): Builder

    /*
    * 添加JWT Id ("jti") claim到Payload
    * @param jwtId the Token Id value
    * @return Builder
    */
    public func withJWTId(jwtId: String): Builder

    /*
    * 添加自定义Bool值到Payload
    * @param name  the Claim's name
    * @param value the Claim's value
    * @return Builder
    */
    public func withClaim(name: String, value: Bool): Builder

    /*
    * 添加自定义Int64值到Payload
    * @param name  the Claim's name
    * @param value the Claim's value
    * @return Builder
    */
    public func withClaim(name: String, value: Int64): Builder

    /*
    * 添加自定义Float64值到Payload
    * @param name  the Claim's name
    * @param value the Claim's value
    * @return Builder
    */
    public func withClaim(name: String, value: Float64): Builder

    /*
    * 添加自定义String值到Payload
    * @param name  the Claim's name
    * @param value the Claim's value
    * @return Builder
    */
    public func withClaim(name: String, value: String): Builder

    /*
    * 添加自定义Time值到Payload
    * @param name  the Claim's name
    * @param value the Claim's value
    * @return Builder
    */
    public func withClaim(name: String, value: DateTime): Builder

    /*
    * 添加自定义Map值到Payload
    * @param name the Claim's name
    * @param map  the Claim's key-values
    * @return Builder
    * @throw IllegalArgumentException 参数类型不支持
    */
    public func withClaim(name: String, map: Map<String, Any>): Builder

    /*
    * 添加自定义ArrayList值到Payload
    * @param name the Claim's name
    * @param list the Claim's list of values
    * @return Builder
    * @throw IllegalArgumentException 参数类型不支持
    */
    public func withClaim(name: String, list: ArrayList<Any>): Builder

    /*
    * 添加自定义null值到Payload
    * @param name the Claim's name
    * @return Builder
    */
    public func withNullClaim(name: String): Builder

    /*
    * 添加自定义Array值到Payload
    * @param name  the Claim's name
    * @param items the Claim's value
    * @return Builder
    */
    public func withArrayClaim(name: String, items: Array<String>): Builder

    /*
    * 添加自定义Array值到Payload
    * @param name  the Claim's name
    * @param items the Claim's value
    * @return Builder
    */
    public func withArrayClaim(name: String, items: Array<Int64>): Builder

    /*
    * 批量添加值到Payload
    * @param payloadClaims the values to use as Claims in the token's payload
    * @return Builder
    * @throw IllegalArgumentException 参数类型不支持
    */
    public func withPayload(payloadClaims: Map<String, Any>): Builder

    /*
    * 签名
    * @param algorithm used to sign the JWT
    * @return a  JWT token
    * @throw SignatureGenerationException 签名失败
    */
    public func sign(algorithm: Algorithm): String
}
```

### 示例

```cangjie
from std import collection.*
from std import time.*
from encoding import json.*
from jwt import jwt.algorithms.*
from jwt import jwt.impl.*
from jwt import jwt.*

main(){
    let jwtStr = JWT.create()
        .withHeader(HashMap<String, Any>([("k1","v1")]))
        .withKeyId("keyId")
        .withIssuer("issuer")
        .withSubject("subject")
        .withAudience(["aud1", "aud2"])
        .withExpiresAt(DateTime.ofEpoch(second: 3673835050, nanosecond: 0))
        .withNotBefore(DateTime.ofEpoch(second: 1673835050, nanosecond: 0))
        .withIssuedAt(DateTime.ofEpoch(second: 1673835050, nanosecond: 0))
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
    0
}
```

```
ewogICJrMSI6ICJ2MSIsCiAgImtpZCI6ICJrZXlJZCIsCiAgImFsZyI6ICJIUzI1NiIsCiAgInR5cCI6ICJKV1QiCn0.ewogICJpc3MiOiAiaXNzdWVyIiwKICAic3ViIjogInN1YmplY3QiLAogICJhdWQiOiBbCiAgICAiYXVkMSIsCiAgICAiYXVkMiIKICBdLAogICJleHAiOiAzNjczODM1MDUwLAogICJuYmYiOiAxNjczODM1MDUwLAogICJpYXQiOiAxNjczODM1MDAwLAogICJqdGkiOiAiand0SWQiLAogICJib29sIjogdHJ1ZSwKICAiZGRkIjogImRmZGRkZmYiLAogICJpbnQ2NCI6IDY0LAogICJmbG9hdDY0IjogMy4xNDAwMDAsCiAgIlN0cmluZyI6ICJhYmFhYmEiLAogICJ0aW1lIjogMTY3Mzg1MDAwMCwKICAibWFwIjogewogICAgIm1rMiI6ICJtdjIiCiAgfSwKICAibGlzdCI6IFsKICAgIDU2LjUxMDAwMCwKICAgIDQxLjk2MDAwMAogIF0sCiAgIm51bGwiOiBudWxsLAogICJhcnJheXN0cmluZyI6IFsKICAgICJhc3RyMSIsCiAgICAiYXN0cjIiCiAgXSwKICAiYXJyYXlpbnQiOiBbCiAgICA2ODQsCiAgICA2NAogIF0sCiAgInBrMSI6ICJwdjEiLAogICJwazIiOiAicHYyIgp9.V1UenPvLJGuM8-y7TSZXN5miDSLYXWsxwVQq7RRzY-w
```

## jwt解码

### 介绍

jwt解码

### 主要接口

#### class JWTDecoder

```cangjie
public class JWTDecoder <: DecodedJWT {
    /*
    * 构造函数
    * @param jwt
    * @throw JWTDecodeException 解码失败
    */
    public init(jwt: String)

    /*
    * get未解码jwt
    * @return String
    */
    public func getToken(): String

    /*
    * get未解码header
    * @return String
    */
    public func getHeader(): String

    /*
    * get未解码payload
    * @return String
    */
    public func getPayload(): String

    /*
    * get未解码签名
    * @return String
    */
    public func getSignature(): String

    /*
    * get header.alg
    * @return String
    */
    public func getAlgorithm(): String

    /*
    * get header.typ
    * @return String
    */
    public func getType(): String

    /*
    * get header.cty
    * @return String
    */
    public func getContentType(): String

    /*
    * get header.kid
    * @return String
    */
    public func getKeyId(): String

    /*
    * get claim from header
    * @param name claim key
    * @return Claim value
    */
    public func getHeaderClaim(name: String): Claim

    /*
    * get payload.iss
    * @return String
    */
    public func getIssuer(): String

    /*
    * get payload.sub
    * @return String
    */
    public func getSubject(): String

    /*
    * get payload.aud
    * @return ArrayList<String>
    */
    public func getAudience(): ArrayList<String>

    /*
    * get payload.exp
    * @return DateTime
    */
    public func getExpiresAt(): DateTime

    /*
    * get payload.nbf
    * @return DateTime
    */
    public func getNotBefore(): DateTime

    /*
    * get payload.iat
    * @return DateTime
    */
    public func getIssuedAt(): DateTime

    /*
    * get payload.jti
    * @return String
    */
    public func getId(): String

    /*
    * get payload claim
    * @param name claim key
    * @return Claim value
    */
    public func getClaim(name: String): Claim

    /*
    * get all payload claims
    * @return Map<String, Claim>
    */
    public func getClaims(): Map<String, Claim>
}
```

### 示例

```cangjie
from jwt import jwt.impl.*
from jwt import jwt.*

main() {
    let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ."
    let decoder = JWT.decode(token)
    let header = decoder.getHeader() // eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
    println(header)
    let myclaim = decoder.getClaim("name").asString() // John Doe
    println(myclaim)
}
```

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
John Doe
```

## jwt校验

### 介绍

    jwt完整性
    payload业务校验

### 主要接口

#### class BaseJWTVerifier

```cangjie
/*
 * 基础校验类，校验方法的入口
 *
 */
public class BaseJWTVerifier <: JWTVerifier {
    /*
    * 校验
    * @param token jwt string
    * @return DecodedJWT
    */
    public func verify(token: String): DecodedJWT
    /*
    * 校验
    * @param jwt DecodedJWT
    * @return DecodedJWT
    * @throw AlgorithmMismatchException 算法不匹配
    * @throw IncorrectClaimException claim不匹配
    */
    public func verify(jwt: DecodedJWT): DecodedJWT
}
```

#### class BaseVerification

```cangjie
/*
 * 具体各种校验方法的实现类，负责主要的功能
 * 
 */
public class BaseVerification <: Verification {
    /*
     * 校验部分接受者 Audience官方字段
     * @param audience 接受者名字
     * @return Verification
     * @throw IncorrectClaimException claim不匹配
     */
    public func withAnyOfAudience(audience: Array<String>): Verification
    /*
     * verify claim String Array
     * @param Claim name
     * @param Claim value
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withArrayClaim(name: String, items: Array<String>): Verification
    /*
     * 校验全部接受者 Audience官方字段
     * @param audience 接受者名字
     * @return Verification
     * @throw IncorrectClaimException claim不匹配
     */
    public func withAudience(audience: Array<String>): Verification
    /*
     * verify claim Int64 Array
     * @param Claim name
     * @param Claim value 
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withArrayClaim(name: String, items: Array<Int64>): Verification 
    /*
     * verify Issuer Array
     * @param 发布者名字
     * @return Verification
     * @throw IncorrectClaimException claim不匹配
     */
    public func withIssuer(issuer: Array<String>): Verification 
    /*
     * verify Issuer String
     * @param 发布者名字
     * @return Verification
     * @throw IncorrectClaimException claim不匹配
     */
    public func withIssuer(issuer: String): Verification 
    /*
     * verify Subject String
     * @param Subject name 通用
     * @return Verification
     * @throw IncorrectClaimException claim不匹配
     */
    public func withSubject(subject: String): Verification 
    /*
     * 校验全部接受者 Audience官方字段
     * @param audience 接受者名字
     * @return Verification
     * @throw IncorrectClaimException claim不匹配
     */
    public func withAudience(audience: ArrayList<String>): Verification
    /*
     * 校验部分接受者 Audience官方字段
     * @param audience 接受者名字
     * @return Verification
     * @throw IncorrectClaimException claim不匹配
     */
    public func withAnyOfAudience(audience: ArrayList<String>): Verification 
    /*
     * 修改默认的时间间隔
     * @param 时间间隔
     * @return Verification
     * @throw IllegalArgumentException 时间不能为负值异常
     */
    public func acceptLeeway(leeway: Int64): Verification
    /*
     * 设置超时的时间间隔 "exp"
     * @param 时间间隔
     * @return Verification
     * @throw IllegalArgumentException 时间不能为负值异常
     */
    public func acceptExpiresAt(leeway: Int64): Verification 
    /*
     * 设置不能超过的时间间隔 "nbf" 
     * @param 时间间隔
     * @return Verification
     * @throw IllegalArgumentException 时间不能为负值异常
     */
    public func acceptNotBefore(leeway: Int64): Verification 
    /*
     * 设置发布的时间间隔 "iss"
     * @param 时间间隔
     * @throw IllegalArgumentException 时间不能为负值异常
     * @return Verification
     */
    public func acceptIssuedAt(leeway: Int64): Verification 
    /*
     * 设置是否进行发布时间的校验
     * @return Verification
     */
    public func ignoreIssuedAt(): Verification 
    /*
     * verify jwtId
     * @param jwtId jwt标识
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withJWTId(jwtId: String): Verification 
    /*
     * verify ClaimPresence (always true)
     * @param name 
     * @return Verification
     */
    public func withClaimPresence(name: String): Verification
    /*
     * 判断claim是否为null
     * @param name
     * @return Verification
     */
    public func withNullClaim(name: String): Verification 
    /*
     * verify Claim bool
     * @param Claim name
     * @param Claim value
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withClaim(name: String, value: Bool): Verification 
    /*
     * verify Claim Int64 
     * @param Claim name
     * @param Claim value
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withClaim(name: String, value: Int64): Verification 
    /*
     * verify Claim Float64 
     * @param Claim name
     * @param Claim value
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withClaim(name: String, value: Float64): Verification 
    /*
     * verify Claim String
     * @param Claim name
     * @param Claim value
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withClaim(name: String, value: String): Verification
    /*
     * verify Claim DateTime
     * @param Claim name
     * @param Claim value
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withClaim(name: String, value: DateTime): Verification
    /*
     * 自定义校验规则
     * @param Claim name
     * @param predicate 比较器 
     * @return Verification
     */
    public func withClaim(name: String, predicate: (Claim, DecodedJWT)->Bool): Verification 
    /*
     * verify Claim String ArrayList
     * @param Claim name
     * @param Claim value 
     * @return Verification
     * @throw MissingClaimException claim不存在异常
     */
    public func withArrayClaim(name: String, items: ArrayList<String>): Verification 
    /*
     * verify Claim Int64 ArrayList
     * @param Claim name
     * @param Claim value 
     * @return Verification
     */
    public func withArrayClaim(name: String, items: ArrayList<Int64>): Verification 
    /*
     * 创建校验器
     * @return JWTVerifier
     */
    public func build(): JWTVerifier 
    
}
```

### 示例

```cangjie
from std import collection.*
from std import time.*
from encoding import json.*
from jwt import jwt.algorithms.*
from jwt import jwt.impl.*
from jwt import jwt.exception.*
from jwt import jwt.interfaces.*
from jwt import jwt.*

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
   0
}
```

## 签名算法

### 介绍

    以 crypto4cj 三方库的 hmac、rsa、ecdsa 算法逻辑为基础，提供 jwt 的抽象入口类 algorithm ，使其能用于调用其他具体的算法

### 主要接口

#### class Algorithm

```cangjie
public abstract class Algorithm {

    /*
     * 通过 KeyProvider 实现类创建 RSA256 算法对象
     * @param keyProvider
     * @return Algorithm 实例
     */    
    public static func RSA256(keyProvider: KeyProvider<KeyType, KeyType>): Algorithm
    
    /*
     * 通过 KeyProvider 实现类创建 RSA384 算法对象
     * @param keyProvider
     * @return Algorithm 实例
     */    
    public static func RSA384(keyProvider: KeyProvider<KeyType, KeyType>): Algorithm
    
    /*
     * 通过 KeyProvider 实现类创建 RSA512 算法对象
     * @param keyProvider
     * @return Algorithm 实例
     */    
    public static func RSA512(keyProvider: KeyProvider<KeyType, KeyType>): Algorithm
    
    /*
     * 通过秘钥创建 HMAC256 算法对象
     * @param secret 秘钥
     * @return Algorithm 实例
     */    
    public static func HMAC256(secret: String): Algorithm

    /*
     * 通过秘钥内容创建 HMAC256 算法对象
     * @param secret 秘钥
     * @return Algorithm 实例
     */    
    public static func HMAC256(secret: Array<UInt8>): Algorithm 
    
    /*
     * 通过秘钥创建 HMAC384 算法对象
     * @param secret 秘钥
     * @return Algorithm 实例
     */    
    public static func HMAC384(secret: String): Algorithm

    /*
     * 通过秘钥内容创建 HMAC384 算法对象
     * @param secret 秘钥
     * @return Algorithm 实例
     */    
    public static func HMAC384(secret: Array<UInt8>): Algorithm
    
    /*
     * 通过秘钥创建 HMAC512 算法对象
     * @param secret 秘钥
     * @return Algorithm 实例
     */    
    public static func HMAC512(secret: String): Algorithm

    /*
     * 通过秘钥内容创建 HMAC512 算法对象
     * @param secret 秘钥
     * @return Algorithm 实例
     */    
    public static func HMAC512(secret: Array<UInt8>): Algorithm

    /*
     * 通过 ECDSAKeyProviderFileImpl 实现类创建 ECDSA256 算法对象
     * @param keyProvider
     * @return Algorithm 实例
     */    
    public static func ECDSA256(keyProvider: ECDSAKeyProviderFileImpl): Algorithm
    
    /*
     * 通过 ECDSAKeyProviderFileImpl 实现类创建 ECDSA384 算法对象
     * @param keyProvider
     * @return Algorithm 实例
     */    
    public static func ECDSA384(keyProvider: ECDSAKeyProviderFileImpl): Algorithm
    
    /*
     * 通过 ECDSAKeyProviderFileImpl 实现类创建 ECDSA512 算法对象
     * @param keyProvider
     * @return Algorithm 实例
     */    
    public static func ECDSA512(keyProvider: ECDSAKeyProviderFileImpl): Algorithm
    
    /*
     * 创建 none 算法对象
     * @param 
     * @return Algorithm 
     */
    public static func none(): Algorithm
}

```

### 示例

#### Hmac256 算法签名示例

```cangjie
from std import collection.*
from jwt import jwt.algorithms.*
from jwt import jwt.utils.*
from crypto4cj import hmaccj.*

main() {
    let hmac1 = Algorithm.HMAC256("pri_key")
    let hmac2 = Algorithm.HMAC384("")
    let hmac3 = Algorithm.HMAC512("pri")
    let header: Array<UInt8> = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9".toUtf8Array()
    let payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ".toUtf8Array()
    var ret: Array<UInt8> = hmac1.sign(header, payload)
    hmac2.sign(header, payload)
    hmac3.sign(header, payload)
    println(Base64Util.urlEncode(ret))
    0
}
```

```cangjie
iUZfpck062AL-KPiKW7IxZZ1mE9eKQsdHfRf0wgPyI8
```

#### Hmac256 算法验签示例

```cangjie
from std import collection.*
from jwt import jwt.algorithms.*
from jwt import jwt.utils.*
from jwt import jwt.interfaces.*
from jwt import jwt.*
from crypto4cj import hmaccj.*

main() {
    let hmac = Algorithm.HMAC256("pri_key")
    let token = "eyJrMSI6InYxIiwia2lkIjoia2V5SWQiLCJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJpc3N1ZXIiLCJzdWIiOiJzdWJqZWN0IiwiYXVkIjpbImF1ZDEiLCJhdWQyIl0sImV4cCI6MzY3MzgzNTA1MCwibmJmIjoxNjczODM1MDUwLCJpYXQiOjE2NzM4MzUwMDAsImp0aSI6Imp3dElkIiwiYm9vbCI6dHJ1ZSwiZGRkIjoiZGZkZGRmZiIsImludDY0Ijo2NCwiZmxvYXQ2NCI6My4xNCwiU3RyaW5nIjoiYWJhYWJhIiwidGltZSI6MTY3Mzg1MDAwMCwibWFwIjp7Im1rMiI6Im12MiJ9LCJsaXN0IjpbNTYuNTEsNDEuOTZdLCJudWxsIjpudWxsLCJhcnJheXN0cmluZyI6WyJhc3RyMSIsImFzdHIyIl0sImFycmF5aW50IjpbNjg0LDY0XSwicGsxIjoicHYxIiwicGsyIjoicHYyIn0.6PjJHq98jIlmEFroRHh-E2BeGPH6QRPs6sBvNPx3JTw"
    let jd = JWTDecoder(token)
    hmac.verify(jd)
    println("verify success")
    0
}
```

```cangjie
verify success
```

#### Rsa384 算法签名示例

```cangjie
from jwt import jwt.algorithms.*
from jwt import jwt.interfaces.*
from jwt import jwt.impl.*
from jwt import jwt.*
from jwt import jwt.utils.*
from crypto4cj import rsacj.*
from std import os.posix.*
from std import fs.*

main() {

    let src: Array<UInt8> = "eyJhbGciOiJSUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toUtf8Array()
    let src_header: Array<UInt8> = "eyJhbGciOiJSUzM4NCIsInR5cCI6IkpXVCJ9".toUtf8Array()
    let src_payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toUtf8Array()
    var path: String = getcwd()
    let pri_key: String = "${path}/test_rsa_privateKey_02.pem"
    let pub_key: String = "${path}/test_rsa_publicKey_02.pem"
    var rsa = Algorithm.RSA384(RSAKeyProviderFileImpl(pri_key))
    var rsa2 = Algorithm.RSA384(RSAKeyProviderFileImpl(pri_key, pub_key))
    let ret = rsa.sign(src)
    let ret2 = rsa2.sign(src_header, src_payload)
    if (Base64Util.urlEncode(ret) == Base64Util.urlEncode(ret2)) {
        println("签名后的值为:" + "${Base64Util.urlEncode(ret)}")
        println("两种方式的签名结果是一致的..")
        return 0
    }
    return 1
}
```

```cangjie
签名后的值为:Rypv9wnvE1-mDBkogHAwRZR1V2fHzOQZUyOrT5IgyrknUyK5kEs8gHBvIA5RqJkmsoUJAn8CQi5rC0dTaLU7pf_bDYUdsGc1GIDNAhEGAT6RCsZWCwkRxofHHVNet116Pv5gO9pBztLJWJfLy1a6k4Dfn-72EM0uLtRTXizWzT8

两种方式的签名结果是一致的..
```

#### Rsa384 算法验签示例

```cangjie
from std import fs.*
from std import os.posix.*
from crypto4cj import rsacj.*
from crypto4cj import sha256cj.*
from jwt import jwt.algorithms.*
from jwt import jwt.impl.*
from jwt import jwt.interfaces.*
from jwt import jwt.utils.*
from jwt import jwt.*

main() {

    let path: String = getcwd()
    let pri_key: String = "${path}/test_rsa_privateKey_02.pem"
    let pub_key: String = "${path}/test_rsa_publicKey_02.pem"
    let token = "eyJhbGciOiJSUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.Rypv9wnvE1-mDBkogHAwRZR1V2fHzOQZUyOrT5IgyrknUyK5kEs8gHBvIA5RqJkmsoUJAn8CQi5rC0dTaLU7pf_bDYUdsGc1GIDNAhEGAT6RCsZWCwkRxofHHVNet116Pv5gO9pBztLJWJfLy1a6k4Dfn-72EM0uLtRTXizWzT8"
    let rsa = Algorithm.RSA384(RSAKeyProviderFileImpl(pub_key))
    var jd = JWTDecoder(token)
    rsa.verify(jd)
    println("verify success")
    return 0
}
```

```cangjie
verify success
```

#### Ecdsa512 算法签名验签示例

```cangjie
from crypto4cj import eccj.*
from std import os.posix.*
from jwt import jwt.algorithms.*
from jwt import jwt.interfaces.*
from jwt import jwt.impl.*
from jwt import jwt.*
from jwt import jwt.utils.*

main() {  
    var path: String = getcwd()
    let pri_key: String = "${path}/test_ecdsa_privateKey.pem"
    let pub_key: String = "${path}/test_ecdsa_publicKey.pem"
    var s: Array<UInt8> = "eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toUtf8Array()
    let header: Array<UInt8> = "eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9".toUtf8Array()
    let payload: Array<UInt8> = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0".toUtf8Array()
    let ecdsa = Algorithm.ECDSA512(ECDSAKeyProviderFileImpl(pri_key))
    let ec = Algorithm.ECDSA512(ECDSAKeyProviderFileImpl(pri_key, pub_key))
    println("*****************************************************************************")
    println("签名开始前，传入的原文数组内容是:" + "${s}")
    let ret = ecdsa.sign(s)
    let ret2 = ecdsa.sign(header, payload)
    println("*****************************************************************************")
    var str = Base64Util.urlEncode(ret)
    println("打印生成的签名值使用Base64加密后是:" + "${str}")
    let token = "eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0." + str
    let ecdsa2 = Algorithm.ECDSA512(ECDSAKeyProviderFileImpl(pub_key))
    var jd = JWTDecoder(token)
    ecdsa2.verify(jd)
    return 0
}
```

```cangjie
签名开始前，传入的原文数组内容是:[101, 121, 74, 104, 98, 71, 99, 105, 79, 105, 74, 70, 85, 122, 85, 120, 77, 105, 73, 115, 73, 110, 82, 53, 99, 67, 73, 54, 73, 107, 112, 88, 86, 67, 74, 57, 46, 101, 121, 74, 122, 100, 87, 73, 105, 79, 105, 73, 120, 77, 106, 77, 48, 78, 84, 89, 51, 79, 68, 107, 119, 73, 105, 119, 105, 98, 109, 70, 116, 90, 83, 73, 54, 73, 107, 112, 118, 97, 71, 52, 103, 82, 71, 57, 108, 73, 105, 119, 105, 89, 87, 82, 116, 97, 87, 52, 105, 79, 110, 82, 121, 100, 87, 85, 115, 73, 109, 108, 104, 100, 67, 73, 54, 77, 84, 85, 120, 78, 106, 73, 122, 79, 84, 65, 121, 77, 110, 48]

打印生成的签名值使用Base64加密后是:MEYCIQDoY5tGvdbOWlQZOhX9NJ6RQpZ8K02maIhardMxOn5owQIhAIyZAIM_Y0o-qdLYe2ZHpb6eWw9-HfvCSMy3sgwATHXJ

Verify success!
```

## 通用接口

### 介绍

主要API间数据流转的接口, 一般为开放API的`参数类型`或`返回值类型`.
    
### 主要接口

#### Claim

```cangjie
/*
 * 包装值 可转成其他类型
 */
public interface Claim <: ToString {
    /*
     * 是否null
     * @return true是 false否
     */
    func isNull(): Bool
    /*
     * 是否存在
     * @return true是 false否
     */
    func isMissing(): Bool
    /*
     * 转成Bool
     * @return Bool
     */
    func asBool(): Bool
    /*
     * 转成Int64
     * @return Int64
     */
    func asInt(): Int64
    /*
     * 转成Float64
     * @return Float64
     */
    func asFloat(): Float64
    /*
     * 转成String
     * @return String
     */
    func asString(): String
    /*
     * DateTime
     * @return DateTime
     */
    func asTime(): DateTime
    /*
     * 转成Array
     * @return Array<NodeType>
     */
    func asArray(): Array<NodeType>
    /*
     * 转成List
     * @return ArrayList<NodeType>
     */
    func asList(): ArrayList<NodeType>
    /*
     * 转成Map
     * @return Map<String, NodeType>
     */
    func asMap(): Map<String, NodeType>
    /*
     * 获取值
     * @return NodeType
     */
    func getValue(): NodeType
}
```

#### NodeType
    NodeType是标准库JsonValue的别名
    Claim使用JsonValue作为其内部value, 依靠JsonValue转成其他类型输出.
```cangjie
public type NodeType = JsonValue
```

## 其他接口

### 介绍

    这些接口在内部流程中使用, 无需调用者操作, 也有可能随迭代修改其实现，请按需谨慎使用。

### 接口

#### Base64Util

```cangjie
/*
 * base64urlsafe转换
 */
public class Base64Util {
    /*
     * 转成base64
     * @param content 原文字节
     * @return String base64
     */
    public static func urlEncode(content: Array<UInt8>): String
    /*
     * 转成base64
     * @param content 原文
     * @return String base64
     */
    public static func urlEncode(content: String): String
    /*
     * 转成原文字节
     * @param content base64
     * @return String 原文字节
     */
    public static func urlDecode2Byte(content: String): Array<UInt8>
    /*
     * 转成原文
     * @param content base64
     * @return String 原文
     */
    public static func urlDecode(content: String): String
}
```

#### Algorithm

```cangjie

public abstract class Algorithm {
    /*
     * 获取签名键的id
     * @param 
     * @return String 字符串
     */
    public open func getSigningKeyId(): String

    /*
     * 获取 name
     * @param 
     * @return String 字符串
     */
    public func getName(): String

    /*
     * toString 方法
     * @param 
     * @return String 字符串
     */
    public func toString(): String

    /*
     * 抽象类的抽象验证方法
     * @param 传入一个 jwt 解析器
     * @return
     */
    public func verify(jwt: DecodedJWT): Unit

    /*
     * 抽象类的抽象签名方法
     * @param 传入header部分与payload部分
     * @return 签名值
     */
    public open func sign(headerBytes: Array<UInt8>, payloadBytes: Array<UInt8>): Array<UInt8>

    /*
     * 抽象类的抽象签名方法
     * @param 传入明文部分
     * @return 签名值
     */
    public func sign(contentBytes: Array<UInt8>): Array<UInt8>
}
```

#### AlgorithmMismatchException

```cangjie

public class AlgorithmMismatchException {

    /*
     * AlgorithmMismatchException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### AlgorithmMismatchException

```cangjie

public class IncorrectClaimException {

    /*
     * IncorrectClaimException 的有参构造
     * @param message String 类型字符串
     * @param claimName String 类型字符串
     * @param claim Claim 类对象
     */
    public init(message: String, claimName: String, claim: Claim)

    /*
     * 获取 getClaimName
     * @return String 类型字符串
     */
    public func getClaimName(): String

    /*
     * 获取 getClaimValue
     * @return Claim 类型
     */
    public func getClaimValue(): Claim
}
```

#### InvalidClaimException

```cangjie

public class InvalidClaimException {

    /*
     * InvalidClaimException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### JWTCreationException

```cangjie

public class JWTCreationException {

    /*
     * JWTCreationException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### JWTDecodeException

```cangjie

public class JWTDecodeException {

    /*
     * JWTDecodeException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### JWTValidationException

```cangjie

public class JWTValidationException {

    /*
     * JWTValidationException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### JWTVerificationException

```cangjie

public class JWTVerificationException {

    /*
     * JWTVerificationException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### MissingClaimException

```cangjie

public class MissingClaimException {

    /*
     * MissingClaimException 的无参构造
     */
    public init()

    /*
     * MissingClaimException 的有参构造
     * @param claimName String 类型字符串
     */
    public init(claimName: String)

    /*
     * 获取 getClaimName
     * @return String 类型字符串
     */
    public func getClaimName(): String
}
```

#### SignatureGenerationException

```cangjie

public class SignatureGenerationException {

    /*
     * SignatureGenerationException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### SignatureVerificationException

```cangjie

public class SignatureVerificationException {

    /*
     * SignatureVerificationException 的有参构造
     * @param message String 类型字符串
     */
    public init(message: String)
}
```

#### TokenExpiredException

```cangjie

public class TokenExpiredException {

    /*
     * TokenExpiredException 的有参构造
     * @param message String 类型字符串
     * @param time DateTime 类对象
     */
    public init(message: String, time: DateTime)

    /*
     * getExpiredOn 方法
     * @return DateTime 类对象
     */
    public func getExpiredOn(): DateTime
}
```

#### Header

```cangjie
/*
 * jwt解码时构建header
 */
public interface Header {
    /*
     * 获取算法
     * @return String
     */
    func getAlgorithm(): String
    /*
     * 获取type
     * @return String
     */
    func getType(): String
    /*
     * 获取 Content Type
     * @return String
     */
    func getContentType(): String
    /*
     * 获取keyid
     * @return String
     */
    func getKeyId(): String
    /*
     * 获取指定字段
     * @param name 字段名
     * @return Claim
     */
    func getHeaderClaim(name: String): Claim
}
```

#### Payload

```cangjie
/*
 * jwt解码时构建Payload
 */
public interface Payload {
    /*
     * 获取发布者
     * @return String
     */
    func getIssuer(): String
    /*
     * 获取主题
     * @return String
     */
    func getSubject(): String
    /*
     * 获取接收者
     * @return ArrayList<String>
     */
    func getAudience(): ArrayList<String>
    /*
     * 获取超时
     * @return DateTime
     */
    func getExpiresAt(): DateTime
    /*
     * 获取Not Before
     * @return DateTime
     */
    func getNotBefore(): DateTime
    /*
     * 获取发布时间
     * @return DateTime
     */
    func getIssuedAt(): DateTime
    /*
     * 获取jwtid
     * @return String
     */
    func getId(): String
    /*
     * 获取指定字段
     * @param name 字段名
     * @return Claim
     */
    func getClaim(name: String): Claim
    /*
     * 获取所有字段
     * @return Map<String, Claim>
     */
    func getClaims(): Map<String, Claim>
}
```

#### JWTParser

```cangjie
/*
 * header/payload解析
 */
public class JWTParser <: JWTPartsParser {
    /*
     * 构造函数
     */
    public init() {}
    /*
     * 解析header
     * @param jsons 未解码header
     * @return Header
     */
    public override func parseHeader(jsons: String): Header
    /*
     * 解析Payload
     * @param jsons 未解码Payload
     * @return Payload
     */
    public override func parsePayload(jsons: String): Payload
}
```

#### HeaderClaimsHolder

```cangjie
/*
 * header容器 用以编码
 * @param 
 * @return 
 */
public class HeaderClaimsHolder <: ClaimsHolder {
    /*
     * 构造函数
     * @param claims header内容
     */
    public init(claims: Map<String, Any>)
}
```

#### PayloadClaimsHolder

```cangjie
/*
 * payload容器 用以编码
 * @param 
 * @return 
 */
public class PayloadClaimsHolder <: ClaimsHolder {
    /*
     * 构造函数
     * @param claims header内容
     */
    public init(claims: Map<String, Any>)
}
```

#### ClaimsSerializer

```cangjie
/*
 * claims序列化
 * @param 
 * @return 
 */
public open class ClaimsSerializer <: Serializer {
    /*
     * json序列化holder中的值
     * @param holder 值容器
     * @return jsonString
     */
    public func serialize(holder: ClaimsHolder): String
}
```

#### Serializer

```cangjie
/*
 * json序列化
 * @param 
 * @return 
 */
public open class Serializer <: ToString {
    /*
     * 获取json
     * @return json String
     */
    public func toString(): String
}
```

#### 反序列化工具方法

```cangjie
/*
 * claim转ArrayList<Int64>
 * @param claim
 * @return ArrayList<Int64>
 */
public func asIntList(claim: Claim): ArrayList<Int64>
/*
 * claim转ArrayList<String>
 * @param claim
 * @return ArrayList<String>
 */
public func asStringList(claim: Claim): ArrayList<String>
```

#### ExpectedCheckHolderImpl

```cangjie
/*
 * lambda校验规则包装
 */
public class ExpectedCheckHolderImpl <: ExpectedCheckHolder {
    /**
     * 构造函数
     * @param climeName 待校验claim名
     * @param predicate 校验方法
     */
    public init(climeName: String, predicate: (Claim, DecodedJWT)->Bool)
    /**
     * 获取校验值名称
     * @return String
     */
    func getClaimName(): String
    /**
     * 校验
     * @param claim 待校验claim
     * @param decodedJWT 已解码jwt
     * @return true校验成功 false校验失败
     */
    func verify(claim: Claim, decodedJWT: DecodedJWT): Bool
}
```

#### RSAKeyProviderFileImpl

```cangjie
public class RSAKeyProviderFileImpl <: RSAKeyProvider<String, String> {
    /*
     * 构造函数
     * @param file 密钥文件路径
     */
    public init(file: String)
    /*
     * 构造函数
     * @param privateKeyFile 私钥文件路径
     * @param publicKeyFile 公钥文件路径
     */
    public init(privateKeyFile: String, publicKeyFile: String)
    /*
     * 获取公钥
     * @return 公钥文件路径
     */
    public func getPublicKey(): String
    /*
     * 获取私钥
     * @return 私钥文件路径
     */
    public func getPrivateKey(): String
}
```

#### ECDSAKeyProviderFileImpl

```cangjie
public class ECDSAKeyProviderFileImpl <: ECDSAKeyProvider<String, String> {
    /*
     * 构造函数
     * @param file 密钥文件路径
     */
    public init(file: String)
    /*
     * 构造函数
     * @param privateKeyFile 私钥文件路径
     * @param publicKeyFile 公钥文件路径
     */
    public init(privateKeyFile: String, publicKeyFile: String)
    /*
     * 获取公钥
     * @return 公钥文件路径
     */
    public func getPublicKey(): String
    /*
     * 获取私钥
     * @return 私钥文件路径
     */
    public func getPrivateKey(): String
}
```
