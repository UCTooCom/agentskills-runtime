# Digest / HMAC / HKDF API 参考

## 摘要函数

### contractMd5(data: Array<Byte>): Array<Byte>
MD5 摘要。已弃用，仅用于兼容旧系统。

### contractSha1(data: Array<Byte>): Array<Byte>
SHA-1 摘要。已弃用，建议使用 SHA-256 或更高。

### contractSha256(data: Array<Byte>): Array<Byte>
SHA-256 摘要。

### contractSha384(data: Array<Byte>): Array<Byte>
SHA-384 摘要。

### contractSha512(data: Array<Byte>): Array<Byte>
SHA-512 摘要。

### contractHash(algorithm: HashAlgorithm, data: Array<Byte>): Array<Byte>
通用哈希分发器。通过 `HashAlgorithm` 枚举选择算法：
`MD5`, `SHA1`, `SHA256`, `SHA384`, `SHA512`

### contractBytesToHexLower(bytes: Array<Byte>): String
字节数组转小写十六进制字符串。

## HMAC

### contractHmac(algorithm: HashAlgorithm, key: Array<Byte>, data: Array<Byte>): Array<Byte>
计算 HMAC。算法可选 MD5/SHA1/SHA256/SHA384/SHA512。

## HKDF

### contractHkdfExtract(algorithm, salt: Array<Byte>, ikm: Array<Byte>): Array<Byte>
HKDF Extract 步骤，返回 PRK。

### contractHkdfExpand(algorithm, prk: Array<Byte>, info: Array<Byte>, outputLen: Int64): Array<Byte>
HKDF Expand 步骤，从 PRK 派生指定长度 OKM。

### contractHkdf(algorithm, ikm, info, outputLen, salt?: Array<Byte>): Array<Byte>
一步完成 HKDF（Extract + Expand）。

## 示例

```cangjie
import jinguissl.contract.*

main() {
    // SHA-256
    let empty: Array<Byte> = []
    println(contractBytesToHexLower(contractSha256(empty)))
    // e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

    // HMAC-SHA256
    let key = "secret".toArray()
    let data = "message".toArray()
    let hmac = contractHmac(HashAlgorithm.SHA256, key, data)

    // HKDF
    let okm = contractHkdf(HashAlgorithm.SHA256, data, "info".toArray(), 32, salt: "salt".toArray())
}
```
