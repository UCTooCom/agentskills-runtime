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

import std.collection.{HashMap, Map}
import std.convert.Parsable
import std.time.DateTime
import stdx.crypto.digest.*
import stdx.crypto.keys.PadOption
import stdx.encoding.json.*
import stdx.encoding.hex.*
import stdx.encoding.base64.*
import stdx.crypto.keys.*
import f_data.{ObjectData, DataObject}
import f_exception.UnreadableException
import f_jwt.exception.JWTException

sealed abstract class JWT {
    let headers = HashMap<String, String>()
    let payload = HashMap<String, Any>()
    var signAlgo: SignAlgo = NoneSignAlgo.INSTANCE

    protected init() {}

    public func header(name: String, value: String): This {
        headers[name] = value
        this
    }
    private func HM5(): This {
        header("alg", "HM5")
    }
    public func hmacMD5(key: Array<Byte>): This {
        signAlgo = DigestSignAlgo(HMACDigest(key, HashType.MD5))
        HM5()
    }
    public func hmacMD5ByBase64Key(key: String): This {
        hmacMD5(fromBase64(key))
    }
    public func hmacMD5ByHexKey(key: String): This {
        hmacMD5(fromHex(key))
    }
    private func HS1(): This {
        header("alg", "HS1")
    }
    public func hmacSHA1(key: Array<Byte>): This {
        signAlgo = DigestSignAlgo(HMACDigest(key, HashType.SHA1))
        HS1()
    }
    public func hmacSHA1ByBase64Key(key: String): This {
        hmacSHA1(fromBase64(key))
    }
    public func hmacSHA1ByHexKey(key: String): This {
        hmacSHA1(fromHex(key))
    }
    private func HS224(): This {
        header("alg", "HS224")
    }
    public func hmacSHA224(key: Array<Byte>): This {
        signAlgo = DigestSignAlgo(HMACDigest(key, HashType.SHA224))
        HS224()
    }
    public func hmacSHA224ByBase64Key(key: String): This {
        hmacSHA224(fromBase64(key))
    }
    public func hmacSHA224ByHexKey(key: String): This {
        hmacSHA224(fromHex(key))
    }
    private func HS256(): This {
        header("alg", "HS256")
    }
    public func hmacSHA256(key: Array<Byte>): This {
        signAlgo = DigestSignAlgo(HMACDigest(key, HashType.SHA1))
        HS256()
    }
    public func hmacSHA256ByBase64Key(key: String): This {
        hmacSHA256(fromBase64(key))
    }
    public func hmacSHA256ByHexKey(key: String): This {
        hmacSHA256(fromHex(key))
    }
    private func HS384(): This {
        header("alg", "HS384")
    }
    public func hmacSHA384(key: Array<Byte>): This {
        signAlgo = DigestSignAlgo(HMACDigest(key, HashType.SHA1))
        HS384()
    }
    public func hmacSHA384ByBase64Key(key: String): This {
        hmacSHA384(fromBase64(key))
    }
    public func hmacSHA384ByHexKey(key: String): This {
        hmacSHA384(fromHex(key))
    }
    private func HS512(): This {
        header("alg", "HS512")
    }
    public func hmacSHA512(key: Array<Byte>): This {
        signAlgo = DigestSignAlgo(HMACDigest(key, HashType.SHA1))
        HS512()
    }
    public func hmacSHA512ByBase64Key(key: String): This {
        hmacSHA512(fromBase64(key))
    }
    public func hmacSHA512ByHexKey(key: String): This {
        hmacSHA512(fromHex(key))
    }
    private func ES224(): This {
        header("alg", "ES224")
    }
    public func ecdsa224(privateKeyPem!: ?String = None<String>, publicKeyPem!: ?String = None<String>): This {
        signAlgo = match ((privateKeyPem, publicKeyPem)) {
            case (Some(pri), Some(pub)) => ECDSASignAlgo(SHA224(), privateKey: ECDSAPrivateKey.decodeFromPem(pri),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case (Some(pri), Option<String>.None) => ECDSASignAlgo(SHA224(),
                privateKey: ECDSAPrivateKey.decodeFromPem(pri))
            case (Option<String>.None, Some(pub)) => ECDSASignAlgo(SHA224(),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case _ => throw JWTException("no key of ECDSA is been specified")
        }
        ES224()
    }
    private func ES256(): This {
        header("alg", "ES256")
    }

    public func ecdsa256(privateKeyPem!: ?String = None<String>, publicKeyPem!: ?String = None<String>): This {
        signAlgo = match ((privateKeyPem, publicKeyPem)) {
            case (Some(pri), Some(pub)) => ECDSASignAlgo(SHA256(), privateKey: ECDSAPrivateKey.decodeFromPem(pri),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case (Some(pri), Option<String>.None) => ECDSASignAlgo(SHA256(),
                privateKey: ECDSAPrivateKey.decodeFromPem(pri))
            case (Option<String>.None, Some(pub)) => ECDSASignAlgo(SHA256(),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case _ => throw JWTException("no key of ECDSA is been specified")
        }
        ES256()
    }
    private func ES384(): This {
        header("alg", "ES384")
    }
    public func ecdsa384(privateKeyPem!: ?String = None<String>, publicKeyPem!: ?String = None<String>): This {
        signAlgo = match ((privateKeyPem, publicKeyPem)) {
            case (Some(pri), Some(pub)) => ECDSASignAlgo(SHA384(), privateKey: ECDSAPrivateKey.decodeFromPem(pri),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case (Some(pri), Option<String>.None) => ECDSASignAlgo(SHA384(),
                privateKey: ECDSAPrivateKey.decodeFromPem(pri))
            case (Option<String>.None, Some(pub)) => ECDSASignAlgo(SHA384(),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case _ => throw JWTException("no key of ECDSA is been specified")
        }
        ES384()
    }
    private func ES512(): This {
        header("alg", "ES512")
    }
    public func ecdsa512(privateKeyPem!: ?String = None<String>, publicKeyPem!: ?String = None<String>): This {
        signAlgo = match ((privateKeyPem, publicKeyPem)) {
            case (Some(pri), Some(pub)) => ECDSASignAlgo(SHA512(), privateKey: ECDSAPrivateKey.decodeFromPem(pri),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case (Some(pri), Option<String>.None) => ECDSASignAlgo(SHA512(),
                privateKey: ECDSAPrivateKey.decodeFromPem(pri))
            case (Option<String>.None, Some(pub)) => ECDSASignAlgo(SHA512(),
                publicKey: ECDSAPublicKey.decodeFromPem(pub))
            case _ => throw JWTException("no key of ECDSA is been specified")
        }
        ES512()
    }
    private func RS256(): This {
        header("alg", "RS256")
    }
    public func rsa256(privateKeyPem!: ?String = None<String>, publicKeyPem!: ?String = None<String>,
        padType!: PadOption = PKCS1): This {
        signAlgo = match ((privateKeyPem, publicKeyPem)) {
            case (Some(pri), Some(pub)) => RSASignAlgo(SHA256(), privateKey: RSAPrivateKey.decodeFromPem(pri),
                publicKey: RSAPublicKey.decodeFromPem(pub), padType: padType)
            case (Some(pri), Option<String>.None) => RSASignAlgo(SHA256(), privateKey: RSAPrivateKey.decodeFromPem(pri),
                padType: padType)
            case (Option<String>.None, Some(pub)) => RSASignAlgo(
                SHA256(),
                publicKey: RSAPublicKey.decodeFromPem(pub),
                padType: padType
            )
            case _ => throw JWTException("no key of RSA is been specified")
        }
        RS256()
    }
    private func RS384(): This {
        header("alg", "RS384")
    }
    public func rsa384(privateKeyPem!: ?String = None<String>, publicKeyPem!: ?String = None<String>,
        padType!: PadOption = PKCS1): This {
        signAlgo = match ((privateKeyPem, publicKeyPem)) {
            case (Some(pri), Some(pub)) => RSASignAlgo(SHA384(), privateKey: RSAPrivateKey.decodeFromPem(pri),
                publicKey: RSAPublicKey.decodeFromPem(pub), padType: padType)
            case (Some(pri), Option<String>.None) => RSASignAlgo(SHA384(), privateKey: RSAPrivateKey.decodeFromPem(pri),
                padType: padType)
            case (Option<String>.None, Some(pub)) => RSASignAlgo(
                SHA384(),
                publicKey: RSAPublicKey.decodeFromPem(pub),
                padType: padType
            )
            case _ => throw JWTException("no key of RSA is been specified")
        }
        RS384()
    }
    private func RS512(): This {
        header("alg", "RS512")
    }
    public func rsa512(privateKeyPem!: ?String = None<String>, publicKeyPem!: ?String = None<String>,
        padType!: PadOption = PKCS1): This {
        signAlgo = match ((privateKeyPem, publicKeyPem)) {
            case (Some(pri), Some(pub)) => RSASignAlgo(SHA512(), privateKey: RSAPrivateKey.decodeFromPem(pri),
                publicKey: RSAPublicKey.decodeFromPem(pub), padType: padType)
            case (Some(pri), Option<String>.None) => RSASignAlgo(SHA512(), privateKey: RSAPrivateKey.decodeFromPem(pri),
                padType: padType)
            case (Option<String>.None, Some(pub)) => RSASignAlgo(
                SHA512(),
                publicKey: RSAPublicKey.decodeFromPem(pub),
                padType: padType
            )
            case _ => throw JWTException("no key of RSA is been specified")
        }
        RS512()
    }
    public func keyId(keyId: String): This {
        header("kid", keyId)
    }
    public func issuer(iss: String): This {
        addPayload('iss', iss)
    }
    public func subject(sub: String): This {
        addPayload('sub', sub)
    }
    public func audience(aud: String): This {
        addPayload('aud', aud)
    }
    public func expire(expire: Int64): This {
        this.expire(Duration.second * expire)
    }
    public func expire(duration: Duration): This {
        expireAt(DateTime.nowUTC() + duration)
    }
    public func expireAt(expireAt: DateTime): This {
        this.expireAt(expireAt.inUTC().toUnixTimeStamp())
    }
    public func expireAt(duration: Duration): This {
        this.expireAt(duration.toSeconds())
    }
    public func expireAt(expireAt: Int64): This {
        addPayload("exp", expireAt)
    }

    public func notBeforeAt(nbf: Int64): This {
        addPayload("nbf", nbf)
    }
    public func notBeforeAt(nbf: Duration): This {
        notBeforeAt(nbf.toSeconds())
    }
    public func notBeforeAt(nbf: DateTime): This {
        notBeforeAt(nbf.inUTC().toUnixTimeStamp())
    }
    public func issuedAt(iat: Int64): This {
        addPayload("iat", iat)
    }
    public func issuedAt(iat: Duration): This {
        addPayload("iat", iat.toSeconds())
    }
    public func issuedAt(iat: DateTime): This {
        addPayload("iat", iat.inUTC().toUnixTimeStamp())
    }
    public func jwtId<T>(jti: T, expire: Duration, cache: JwtIdCache<T>): This where T <: Equatable<T> & ToString {
        cache.put(jti, expire)
        addPayload("jti", jti)
    }
    public func jwtId<T>(jti: T, expireAt: DateTime, cache: JwtIdCache<T>): This where T <: Equatable<T> & ToString {
        cache.put(jti, expireAt.inUTC())
        addPayload("jti", jti)
    }

    public func addPayload<T>(name: String, value: T): This where T <: ToString {
        payload[name] = value
        this
    }
    public func addPayload<V, M>(map: M): This where V <: ToString, M <: Map<String, V> {
        for ((k, v) in map) {
            addPayload<V>(k, v)
        }
        this
    }
    public func addPayload<T>(data: T): This where T <: Object & ObjectData<T> {
        match (data.toData()) {
            case x: DataObject<T> => for ((k, v) in x) {
                addPayload(k, v)
            }
            case _ => throw UnreadableException()
        }
        this
    }

    public static func encoder(): JWTEncoder {
        JWTEncoder()
    }
    public static func verifier(data: String): JWTVerifier {
        JWTVerifier(data)
    }
}

public class JWTEncoder <: JWT {
    JWTEncoder() {}
    public func sign(): String {
        var json = JsonObject()
        for ((k, v) in headers) {
            json.put(k, JsonString(v))
        }
        let headerJson = json.toString()
        let headerBase64 = toBase64(headerJson)
        json = JsonObject()
        for ((k, v) in payload) {
            match (v) {
                case x: Bool => json.put(k, JsonBool(x))
                case x: Int64 => json.put(k, JsonInt(x))
                case x: UInt64 => json.put(k, JsonInt(Int64(x)))
                case x: Int32 => json.put(k, JsonInt(Int64(x)))
                case x: UInt32 => json.put(k, JsonInt(Int64(x)))
                case x: Int16 => json.put(k, JsonInt(Int64(x)))
                case x: UInt16 => json.put(k, JsonInt(Int64(x)))
                case x: Int8 => json.put(k, JsonInt(Int64(x)))
                case x: UInt8 => json.put(k, JsonInt(Int64(x)))
                case x: Float64 => json.put(k, JsonFloat(x))
                case x: Float32 => json.put(k, JsonFloat(Float64(x)))
                case x: Float16 => json.put(k, JsonFloat(Float64(x)))
                case x: String => json.put(k, JsonString(x))
                case x: Rune => json.put(k, JsonString(x.toString()))
                case x: JsonValue => json.put(k, x)
                case x: ToString => json.put(k, JsonString(x.toString()))
                case _ => throw JWTException("current value of key as ${k} does not support for payload")
            }
        }
        let payloadJson = json.toString()
        let payloadBase64 = toBase64(payloadJson)
        "${headerBase64}.${payloadBase64}.${signAlgo.signToBase64(bytesForSign(headerJson, payloadJson))}"
    }
}

public class JWTVerifier <: JWT {
    private let headerBytes: Array<Byte>
    private let payloadBytes: Array<Byte>
    private let signBytes: Array<Byte>
    JWTVerifier(private let data: String) {
        let firstDot = data.indexOf(".") ?? -1
        let lastDot = data.lastIndexOf(".", firstDot + 1) ?? -1
        headerBytes = fromBase64(data[0 .. firstDot])
        payloadBytes = fromBase64(data[firstDot + 1 .. lastDot])
        signBytes = fromBase64(data[lastDot + 1 ..])
        let headerJson = JsonValue.fromStr(String.fromUtf8(headerBytes))
        let payloadJson = JsonValue.fromStr(String.fromUtf8(payloadBytes))
        populate<String>(headerJson, headers)
        populate<Any>(payloadJson, payload)
    }
    private static func populate<T>(json: JsonValue, map: HashMap<String, T>) {
        match (json) {
            case x: JsonObject => for ((k, v) in x.getFields()) {
                map[k] = getJsonValue<T>(v)
            }
            case _ => ()
        }
    }
    private static func getJsonValue<T>(v: JsonValue): T {
        let r: Any = match (v) {
            case x: JsonBool => x.getValue()
            case x: JsonInt => x.getValue()
            case x: JsonString => x.getValue()
            case x: JsonFloat => x.getValue()
            case x: JsonArray => Array<Any>(x.size()) {
                i => if (let Some(jv) <- x.get(i)) {
                    getJsonValue<T>(jv)
                } else {
                    None<Any>
                }
            }
            case x: JsonObject =>
                let vm = HashMap<String, T>()
                populate<T>(x, vm)
                vm
            case _ => ()
        }
        (r as T).getOrThrow()
    }
    public func getPayload(name: String): ?Any {
        payload.get(name)
    }
    public func getHeader(name: String): ?String {
        headers.get(name)
    }
    public func getKeyId(): ?String {
        getHeader('kid')
    }
    public func getExpireAt(): ?DateTime {
        if (let Some(d) <- getExpireAtDuration()) {
            DateTime.UnixEpoch + d
        } else {
            None<DateTime>
        }
    }
    public func getExpireAtDuration(): ?Duration {
        if (let Some(d) <- getExpireAtSeconds()) {
            Duration.second * d
        } else {
            None<Duration>
        }
    }
    public func getExpireAtSeconds(): ?Int64 {
        getPayloadValue<Int64>('exp')
    }
    public func getNotBefore(): ?DateTime {
        if (let Some(d) <- getNotBeforeDuration()) {
            DateTime.UnixEpoch + d
        } else {
            None<DateTime>
        }
    }
    public func getNotBeforeDuration(): ?Duration {
        if (let Some(d) <- getNotBeforeSeconds()) {
            Duration.second * d
        } else {
            None<Duration>
        }
    }
    public func getNotBeforeSeconds(): ?Int64 {
        getPayloadValue<Int64>("nbf")
    }
    public func getPayloadValue<T>(name: String): ?T where T <: Parsable<T> {
        if (let Some(x) <- getPayload(name)) {
            match (x) {
                case v: T => v
                case v: String => tryParse<T>(v)
                case v: ToString => tryParse<T>(v.toString())
                case _ => None<T>
            }
        } else {
            None<T>
        }
    }
    public func getHeaderValue<T>(name: String): ?T where T <: Parsable<T> {
        tryParse<T>(getHeader(name))
    }
    private func tryParse<T>(value: ?String): ?T where T <: Parsable<T> {
        if (let Some(x) <- value) {
            T.tryParse(x)
        } else {
            None<T>
        }
    }
    public func isNotBefore(time!: DateTime = DateTime.nowUTC()): Bool {
        (this.getNotBefore() ?? time.inUTC()) <= time
    }
    public func isExpired(time!: DateTime = DateTime.nowUTC()): Bool {
        if (let Some(d) <- this.getExpireAt()) {
            d <= time.inUTC()
        } else {
            false
        }
    }
    public func verifySign(): Bool {
        signAlgo.verify(bytesForSign(headerBytes, payloadBytes), signBytes)
    }
    /**
     * 检查了exp nbf sign，如果没有指定exp 或nbf 就认为jwt在相应时间字段当前时间有效。
     */
    public func verify(): Bool {
        let now = DateTime.nowUTC()
        !isExpired(time: now) && isNotBefore(time: now) && verifySign()
    }
    public func verifyPayload<V>(name: String, value: V): Bool where V <: Equatable<V> {
        if (let Some(o) <- getPayload(name) && let v: Equatable<V> <- o) {
            v == value
        } else {
            false
        }
    }
    public func verifyIssuer<V>(issuer: V): Bool where V <: Equatable<V> {
        verifyPayload("iss", issuer)
    }
    public func verifySubject<V>(subject: V): Bool where V <: Equatable<V> {
        verifyPayload("sub", subject)
    }
    public func verifyAudience<V>(audience: V): Bool where V <: Equatable<V> {
        verifyPayload("aud", audience)
    }
    public func verifyIssueAt(issueAt: Int64): Bool {
        verifyPayload('iat', issueAt)
    }
    public func verifyIssueAt(issueAt: Duration): Bool {
        verifyIssueAt(issueAt.toSeconds())
    }
    public func verifyIssueAt(issueAt: DateTime): Bool {
        verifyIssueAt(issueAt.inUTC() - DateTime.UnixEpoch)
    }
    public func verifyId<T>(cache: JwtIdCache<T>): Bool where T <: Equatable<T> {
        match(getPayload('jti')) {
            case Some(jti: T) => cache.remove(jti)
            case _ => false
        }
    }
}
