/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_jwt

import std.unittest.*
import std.unittest.testmacro.*
import std.time.DateTime
import std.collection.HashMap
import stdx.encoding.hex.*
import stdx.encoding.base64.*

@Test
public class JWTTest {
    
    /**
     * 测试基本的HMAC SHA1签名和验证功能
     * 验证JWT的基本工作流程：创建、签名、验证
     */
    @TestCase
    public func testBasicHmacSHA1() {
        let jwt = JWT.encoder().hmacSHA1('1234567890'.toArray())
        let sign = jwt.keyId('1234567890').expire(Duration.minute).addPayload('name', 'Bob').sign()
        println(sign)
        @Expect(JWT.verifier(sign).verify(), true)
    }

    /**
     * 测试hmacMD5ByHexKey方法
     * 验证使用十六进制密钥的MD5 HMAC签名功能
     */
    @TestCase
    public func testHmacMD5ByHexKey() {
        let hexKey = "48656c6c6f576f726c64" // "HelloWorld" in hex
        let jwt = JWT.encoder().hmacMD5ByHexKey(hexKey)
        let token = jwt.addPayload("user", "testUser").sign()
        
        // 验证token可以被正确验证
        let verifier = JWT.verifier(token)
        @Expect(verifier.verifySign(), true)
        
        // 验证header中包含正确的算法
        @Expect(verifier.getHeader("alg"), Some("HM5"))
        
        // 验证payload中包含正确的数据
        @Expect(verifier.getPayload("user"), Some("testUser"))
    }

    /**
     * 测试hmacMD5ByHexKey方法的边界情况
     * 验证空密钥和无效十六进制字符串的处理
     */
    @TestCase
    public func testHmacMD5ByHexKeyEdgeCases() {
        // 测试空十六进制字符串
        let jwt1 = JWT.encoder().hmacMD5ByHexKey("")
        let token1 = jwt1.addPayload("test", "value").sign()
        @Expect(JWT.verifier(token1).verifySign(), true)
        
        // 测试单个字符的十六进制
        let jwt2 = JWT.encoder().hmacMD5ByHexKey("41") // "A" in hex
        let token2 = jwt2.addPayload("test", "value").sign()
        @Expect(JWT.verifier(token2).verifySign(), true)
        
        // 测试长十六进制密钥
        let longHexKey = "0123456789abcdef" * 8 // 128个字符
        let jwt3 = JWT.encoder().hmacMD5ByHexKey(longHexKey)
        let token3 = jwt3.addPayload("test", "value").sign()
        @Expect(JWT.verifier(token3).verifySign(), true)
    }

    /**
     * 测试hmacMD5ByBase64Key方法
     * 验证使用Base64编码密钥的MD5 HMAC签名功能
     */
    @TestCase
    public func testHmacMD5ByBase64Key() {
        let base64Key = toBase64String("HelloWorld".toArray())
        let jwt = JWT.encoder().hmacMD5ByBase64Key(base64Key)
        let token = jwt.addPayload("user", "testUser").sign()
        
        // 验证token可以被正确验证
        let verifier = JWT.verifier(token)
        @Expect(verifier.verifySign(), true)
        
        // 验证header中包含正确的算法
        @Expect(verifier.getHeader("alg"), Some("HM5"))
    }

    /**
     * 测试所有HMAC算法的一致性
     * 验证不同HMAC算法都能正确工作
     */
    @TestCase
    public func testAllHmacAlgorithms() {
        let key = "testKey123".toArray()
        let payload = HashMap<String, String>()
        payload["user"] = "testUser"
        payload["role"] = "admin"
        
        // 测试HMAC MD5
        let jwtMD5 = JWT.encoder().hmacMD5(key)
        jwtMD5.addPayload(payload)
        let tokenMD5 = jwtMD5.sign()
        @Expect(JWT.verifier(tokenMD5).verifySign(), true)
        @Expect(JWT.verifier(tokenMD5).getHeader("alg"), Some("HM5"))
        
        // 测试HMAC SHA1
        let jwtSHA1 = JWT.encoder().hmacSHA1(key)
        jwtSHA1.addPayload(payload)
        let tokenSHA1 = jwtSHA1.sign()
        @Expect(JWT.verifier(tokenSHA1).verifySign(), true)
        @Expect(JWT.verifier(tokenSHA1).getHeader("alg"), Some("HS1"))
        
        // 测试HMAC SHA224
        let jwtSHA224 = JWT.encoder().hmacSHA224(key)
        jwtSHA224.addPayload(payload)
        let tokenSHA224 = jwtSHA224.sign()
        @Expect(JWT.verifier(tokenSHA224).verifySign(), true)
        @Expect(JWT.verifier(tokenSHA224).getHeader("alg"), Some("HS224"))
        
        // 测试HMAC SHA256
        let jwtSHA256 = JWT.encoder().hmacSHA256(key)
        jwtSHA256.addPayload(payload)
        let tokenSHA256 = jwtSHA256.sign()
        @Expect(JWT.verifier(tokenSHA256).verifySign(), true)
        @Expect(JWT.verifier(tokenSHA256).getHeader("alg"), Some("HS256"))
        
        // 测试HMAC SHA384
        let jwtSHA384 = JWT.encoder().hmacSHA384(key)
        jwtSHA384.addPayload(payload)
        let tokenSHA384 = jwtSHA384.sign()
        @Expect(JWT.verifier(tokenSHA384).verifySign(), true)
        @Expect(JWT.verifier(tokenSHA384).getHeader("alg"), Some("HS384"))
        
        // 测试HMAC SHA512
        let jwtSHA512 = JWT.encoder().hmacSHA512(key)
        jwtSHA512.addPayload(payload)
        let tokenSHA512 = jwtSHA512.sign()
        @Expect(JWT.verifier(tokenSHA512).verifySign(), true)
        @Expect(JWT.verifier(tokenSHA512).getHeader("alg"), Some("HS512"))
    }

    /**
     * 测试JWT头部设置功能
     * 验证自定义头部字段的设置和获取
     */
    @TestCase
    public func testHeaderFunctionality() {
        let jwt = JWT.encoder().hmacSHA256("secret".toArray())
        jwt.header("typ", "JWT")
        jwt.header("custom", "value")
        jwt.keyId("key123")
        
        let token = jwt.addPayload("test", "data").sign()
        let verifier = JWT.verifier(token)
        
        @Expect(verifier.getHeader("typ"), Some("JWT"))
        @Expect(verifier.getHeader("custom"), Some("value"))
        @Expect(verifier.getHeader("kid"), Some("key123"))
        @Expect(verifier.getHeader("alg"), Some("HS256"))
        @Expect(verifier.getHeader("nonexistent"), None<String>)
    }

    /**
     * 测试JWT载荷设置功能
     * 验证各种类型的载荷数据设置和获取
     */
    @TestCase
    public func testPayloadFunctionality() {
        let jwt = JWT.encoder().hmacSHA256("secret".toArray())
        
        // 测试标准声明
        jwt.issuer("testIssuer")
        jwt.subject("testSubject")
        jwt.audience("testAudience")
        jwt.issuedAt(DateTime.now())
        jwt.expireAt(DateTime.now() + Duration.hour)
        jwt.notBeforeAt(DateTime.now())
        
        // 测试自定义载荷
        jwt.addPayload("stringValue", "test")
        jwt.addPayload("intValue", 123)
        jwt.addPayload("boolValue", true)
        
        let token = jwt.sign()
        let verifier = JWT.verifier(token)
        
        @Expect(verifier.getPayload("iss"), Some("testIssuer"))
        @Expect(verifier.getPayload("sub"), Some("testSubject"))
        @Expect(verifier.getPayload("aud"), Some("testAudience"))
        @Expect(verifier.getPayload("stringValue"), Some("test"))
        @Expect(verifier.getPayload("intValue"), Some(123))
        @Expect(verifier.getPayload("boolValue"), Some(true))
        @Expect(verifier.getPayload("nonexistent"), None<Any>)
    }

    /**
     * 测试JWT时间相关功能
     * 验证过期时间、生效时间等时间相关功能
     */
    @TestCase
    public func testTimeFunctionality() {
        let jwt = JWT.encoder().hmacSHA256("secret".toArray())
        let now = DateTime.now()
        let futureTime = now + Duration.hour
        let pastTime = now - Duration.hour
        
        // 测试过期时间设置
        jwt.expireAt(futureTime)
        jwt.notBeforeAt(pastTime)
        jwt.issuedAt(now)
        
        let token = jwt.addPayload("test", "data").sign()
        let verifier = JWT.verifier(token)
        
        // 验证时间相关方法
        @Expect(verifier.isExpired(time: now), false) // 未过期
        @Expect(verifier.isNotBefore(time: now), true) // 已生效
        
        // 测试过期时间获取
        let expireAt = verifier.getExpireAt()
        @Expect(expireAt.isSome(), true)
        
        // 测试生效时间获取
        let notBefore = verifier.getNotBefore()
        @Expect(notBefore.isSome(), true)
    }

    /**
     * 测试JWT验证功能
     * 验证各种验证场景，包括签名验证、载荷验证等
     */
    @TestCase
    public func testVerificationFunctionality() {
        let jwt = JWT.encoder().hmacSHA256("secret".toArray())
        jwt.issuer("testIssuer")
        jwt.subject("testSubject")
        jwt.audience("testAudience")
        jwt.expireAt(DateTime.now() + Duration.hour)
        
        let token = jwt.sign()
        let verifier = JWT.verifier(token)
        
        // 测试整体验证
        @Expect(verifier.verify(), true)
        
        // 测试签名验证
        @Expect(verifier.verifySign(), true)
        
        // 测试载荷验证
        @Expect(verifier.verifyIssuer("testIssuer"), true)
        @Expect(verifier.verifyIssuer("wrongIssuer"), false)
        @Expect(verifier.verifySubject("testSubject"), true)
        @Expect(verifier.verifySubject("wrongSubject"), false)
        @Expect(verifier.verifyAudience("testAudience"), true)
        @Expect(verifier.verifyAudience("wrongAudience"), false)
        
        // 测试自定义载荷验证
        @Expect(verifier.verifyPayload("iss", "testIssuer"), true)
        @Expect(verifier.verifyPayload("iss", "wrongIssuer"), false)
    }

    /**
     * 测试错误情况处理
     * 验证各种错误情况的处理，如无效token、错误密钥等
     */
    @TestCase
    public func testErrorHandling() {
        let jwt = JWT.encoder().hmacSHA256("secret".toArray())
        let token = jwt.addPayload("test", "data").sign()
        
        // 测试错误密钥验证
        let wrongJwt = JWT.encoder().hmacSHA256("wrongSecret".toArray())
        let wrongVerifier = JWT.verifier(token)
        @Expect(wrongVerifier.verifySign(), false)
        
        // 测试过期token
        let expiredJwt = JWT.encoder().hmacSHA256("secret".toArray())
        expiredJwt.expireAt(DateTime.now() - Duration.hour) // 已过期
        let expiredToken = expiredJwt.addPayload("test", "data").sign()
        let expiredVerifier = JWT.verifier(expiredToken)
        @Expect(expiredVerifier.isExpired(), true)
        
        // 测试未生效token
        let notYetValidJwt = JWT.encoder().hmacSHA256("secret".toArray())
        notYetValidJwt.notBeforeAt(DateTime.now() + Duration.hour) // 未来时间
        let notYetValidToken = notYetValidJwt.addPayload("test", "data").sign()
        let notYetValidVerifier = JWT.verifier(notYetValidToken)
        @Expect(notYetValidVerifier.isNotBefore(), false)
    }

    /**
     * 测试链式调用功能
     * 验证JWT构建器模式的链式调用
     */
    @TestCase
    public func testChainedCalls() {
        let jwt = JWT.encoder()
            .hmacSHA256("secret".toArray())
            .header("typ", "JWT")
            .keyId("key123")
            .issuer("testIssuer")
            .subject("testSubject")
            .audience("testAudience")
            .expire(Duration.hour)
            .addPayload("custom", "value")
        
        let token = jwt.sign()
        let verifier = JWT.verifier(token)
        
        @Expect(verifier.verifySign(), true)
        @Expect(verifier.getHeader("typ"), Some("JWT"))
        @Expect(verifier.getHeader("kid"), Some("key123"))
        @Expect(verifier.getPayload("iss"), Some("testIssuer"))
        @Expect(verifier.getPayload("sub"), Some("testSubject"))
        @Expect(verifier.getPayload("aud"), Some("testAudience"))
        @Expect(verifier.getPayload("custom"), Some("value"))
    }

    /**
     * 测试不同密钥格式的兼容性
     * 验证十六进制和Base64密钥格式的正确处理
     */
    @TestCase
    public func testKeyFormatCompatibility() {
        let originalKey = "HelloWorld123"
        let hexKey = toHexString(originalKey.toArray())
        let base64Key = toBase64String(originalKey.toArray())
        
        // 使用原始字节数组
        let jwt1 = JWT.encoder().hmacSHA256(originalKey.toArray())
        let token1 = jwt1.addPayload("test", "value").sign()
        
        // 使用十六进制密钥
        let jwt2 = JWT.encoder().hmacSHA256ByHexKey(hexKey)
        let token2 = jwt2.addPayload("test", "value").sign()
        
        // 使用Base64密钥
        let jwt3 = JWT.encoder().hmacSHA256ByBase64Key(base64Key)
        let token3 = jwt3.addPayload("test", "value").sign()
        
        // 所有三种方式应该产生相同的结果
        @Expect(JWT.verifier(token1).verifySign(), true)
        @Expect(JWT.verifier(token2).verifySign(), true)
        @Expect(JWT.verifier(token3).verifySign(), true)
        
        // 交叉验证应该成功
        @Expect(JWT.verifier(token2).verifySign(), true)
        @Expect(JWT.verifier(token3).verifySign(), true)
        @Expect(JWT.verifier(token1).verifySign(), true)
        @Expect(JWT.verifier(token3).verifySign(), true)
        @Expect(JWT.verifier(token1).verifySign(), true)
        @Expect(JWT.verifier(token2).verifySign(), true)
    }

    /**
     * 测试大量数据处理
     * 验证JWT在处理大量载荷数据时的性能和正确性
     */
    @TestCase
    public func testLargePayload() {
        let jwt = JWT.encoder().hmacSHA256("secret".toArray())
        
        // 添加大量载荷数据
        for (i in 0..100) {
            jwt.addPayload("key${i}", "value${i}")
        }
        
        let token = jwt.sign()
        let verifier = JWT.verifier(token)
        
        @Expect(verifier.verifySign(), true)
        
        // 验证所有数据都正确存储
        for (i in 0..100) {
            @Expect(verifier.getPayload("key${i}"), Some("value${i}"))
        }
    }

    /**
     * 测试空值和边界值处理
     * 验证各种边界情况的处理
     */
    @TestCase
    public func testBoundaryValues() {
        let jwt = JWT.encoder().hmacSHA256("secret".toArray())
        
        // 测试空字符串
        jwt.addPayload("empty", "")
        jwt.addPayload("space", " ")
        jwt.addPayload("newline", "\n")
        jwt.addPayload("tab", "\t")
        
        // 测试特殊字符
        jwt.addPayload("special", "!@#$%^&*()_+-=[]{}|;':\",./<>?")
        jwt.addPayload("unicode", "你好世界🌍")
        
        let token = jwt.sign()
        let verifier = JWT.verifier(token)
        
        @Expect(verifier.verifySign(), true)
        @Expect(verifier.getPayload("empty"), Some(""))
        @Expect(verifier.getPayload("space"), Some(" "))
        @Expect(verifier.getPayload("newline"), Some("\n"))
        @Expect(verifier.getPayload("tab"), Some("\t"))
        @Expect(verifier.getPayload("special"), Some("!@#$%^&*()_+-=[]{}|;':\",./<>?"))
        @Expect(verifier.getPayload("unicode"), Some("你好世界🌍"))
    }
}
