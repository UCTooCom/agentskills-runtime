package cos.sign

import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import stdx.crypto.digest.{SHA1, HMAC, HashType}

public class CosSigner {
    private let secretId: String
    private let secretKey: String

    public init(secretId: String, secretKey: String) {
        this.secretId = secretId
        this.secretKey = secretKey
    }

    public func getAuthorization(
        method: String,
        pathname: String,
        queryParams: HashMap<String, String>,
        headers: HashMap<String, String>,
        bucket: ?String,
        region: ?String,
        expires!: Int64 = 900
    ): String {
        let now = (DateTime.now() - DateTime.UnixEpoch).toSeconds() - 1
        let exp = now + expires

        let qSignAlgorithm = "sha1"
        let qAk = secretId
        let qSignTime = "${now};${exp}"
        let qKeyTime = qSignTime

        let signHeaders = getSignHeaderObj(headers, bucket, region)
        let headerKeys = getObjectKeys(signHeaders, true)
        let qHeaderList = toLower(joinStrings(headerKeys, ";"))
        let paramKeys = getObjectKeys(queryParams, true)
        let qUrlParamList = toLower(joinStrings(paramKeys, ";"))

        let signKey = hmacSha1Hex(secretKey, qKeyTime)

        let formatStringParts = ArrayList<String>()
        formatStringParts.add(toLower(method))
        formatStringParts.add(normalizePath(pathname))
        formatStringParts.add(obj2str(queryParams, true))
        formatStringParts.add(obj2str(signHeaders, true))
        formatStringParts.add("")
        let formatStringJoined = joinStrings(formatStringParts, "\n")

        let formatStringHash = sha1Hex(formatStringJoined)
        let stringToSignParts = ArrayList<String>()
        stringToSignParts.add(qSignAlgorithm)
        stringToSignParts.add(qSignTime)
        stringToSignParts.add(formatStringHash)
        stringToSignParts.add("")
        let stringToSign = joinStrings(stringToSignParts, "\n")

        let qSignature = hmacSha1Hex(signKey, stringToSign)

        let resultParts = ArrayList<String>()
        resultParts.add("q-sign-algorithm=${qSignAlgorithm}")
        resultParts.add("q-ak=${qAk}")
        resultParts.add("q-sign-time=${qSignTime}")
        resultParts.add("q-key-time=${qKeyTime}")
        resultParts.add("q-header-list=${qHeaderList}")
        resultParts.add("q-url-param-list=${qUrlParamList}")
        resultParts.add("q-signature=${qSignature}")
        return joinStrings(resultParts, "&")
    }

    private func getSignHeaderObj(
        headers: HashMap<String, String>,
        bucket: ?String,
        region: ?String
    ): HashMap<String, String> {
        let signHeaders = HashMap<String, String>()
        let allowedHeaders = ArrayList<String>()
        allowedHeaders.add("cache-control")
        allowedHeaders.add("content-disposition")
        allowedHeaders.add("content-encoding")
        allowedHeaders.add("content-length")
        allowedHeaders.add("content-md5")
        allowedHeaders.add("content-type")
        allowedHeaders.add("expect")
        allowedHeaders.add("expires")
        allowedHeaders.add("host")
        allowedHeaders.add("if-match")
        allowedHeaders.add("if-modified-since")
        allowedHeaders.add("if-none-match")
        allowedHeaders.add("if-unmodified-since")
        allowedHeaders.add("origin")
        allowedHeaders.add("range")
        allowedHeaders.add("transfer-encoding")
        allowedHeaders.add("pic-operations")

        for (key in headers.keys()) {
            let lowerKey = toLower(key)
            if (lowerKey.startsWith("x-cos-") || lowerKey.startsWith("x-ci-") || arrayContains(allowedHeaders, lowerKey)) {
                let valOpt = headers.get(key)
                if (valOpt.isSome()) {
                    signHeaders[key] = valOpt.getOrThrow()
                }
            }
        }

        if (bucket.isSome() && region.isSome() && !signHeaders.contains("Host") && !signHeaders.contains("host")) {
            signHeaders["Host"] = "${bucket.getOrThrow()}.cos.${region.getOrThrow()}.myqcloud.com"
        }

        return signHeaders
    }

    private func arrayContains(arr: ArrayList<String>, item: String): Bool {
        for (s in arr) {
            if (s == item) {
                return true
            }
        }
        return false
    }

    private func toLower(str: String): String {
        let asciiA: UInt8 = 65
        let asciiZ: UInt8 = 90
        let asciiOffset: UInt8 = 32
        var result = ""
        let bytes = str.toArray()
        for (b in bytes) {
            if (b >= asciiA && b <= asciiZ) {
                result = result + String.fromUtf8(Array<UInt8>(1, repeat: b + asciiOffset))
            } else {
                result = result + String.fromUtf8(Array<UInt8>(1, repeat: b))
            }
        }
        return result
    }

    private func getObjectKeys(map: HashMap<String, String>, forKey: Bool): ArrayList<String> {
        var keys = ArrayList<String>()
        for (key in map.keys()) {
            keys.add(key)
        }
        keys = sortArrayIgnoreCase(keys)
        if (forKey) {
            let encoded = ArrayList<String>()
            for (k in keys) {
                encoded.add(toLower(camSafeUrlEncode(k)))
            }
            return encoded
        }
        return keys
    }

    private func sortArrayIgnoreCase(arr: ArrayList<String>): ArrayList<String> {
        var result = ArrayList<String>()
        for (item in arr) {
            result.add(item)
        }
        let len = result.size
        for (i in 0..len) {
            for (j in 0..(len - i - 1)) {
                if (toLower(result[j]) > toLower(result[j + 1])) {
                    let temp = result[j]
                    result[j] = result[j + 1]
                    result[j + 1] = temp
                }
            }
        }
        return result
    }

    private func joinStrings(arr: ArrayList<String>, delimiter: String): String {
        if (arr.size == 0) {
            return ""
        }
        var result = arr[0]
        for (i in 1..arr.size) {
            result = "${result}${delimiter}${arr[i]}"
        }
        return result
    }

    private func camSafeUrlEncode(str: String): String {
        let encoded = urlEncode(str)
        return encoded
            .replace("!", "%21")
            .replace("'", "%27")
            .replace("(", "%28")
            .replace(")", "%29")
            .replace("*", "%2A")
    }

    private func urlEncode(str: String): String {
        let hexChars = "0123456789ABCDEF"
        var result = ""
        let bytes = str.toArray()
        for (b in bytes) {
            let byteVal: UInt8 = b
            if ((byteVal >= 65 && byteVal <= 90) || (byteVal >= 97 && byteVal <= 122) || 
                (byteVal >= 48 && byteVal <= 57) || byteVal == 45 || byteVal == 46 || 
                byteVal == 95 || byteVal == 126) {
                result = result + String.fromUtf8(Array<UInt8>(1, repeat: byteVal))
            } else {
                result = "${result}%"
                let highNibble: UInt8 = (byteVal >> 4) & 0x0F
                let lowNibble: UInt8 = byteVal & 0x0F
                result = "${result}${hexChars[Int64(highNibble)..Int64(highNibble+1)]}"
                result = "${result}${hexChars[Int64(lowNibble)..Int64(lowNibble+1)]}"
            }
        }
        return result.replace(" ", "%20")
    }

    private func obj2str(obj: HashMap<String, String>, lowerCaseKey: Bool): String {
        let list = ArrayList<String>()
        let keyList = getObjectKeys(obj, false)

        for (key in keyList) {
            let optVal = obj.get(key)
            let val = match (optVal) {
                case Some(v) => v
                case None => ""
            }
            let encodedKey = if (lowerCaseKey) { toLower(camSafeUrlEncode(key)) } else { camSafeUrlEncode(key) }
            let encodedVal = camSafeUrlEncode(val)
            list.add("${encodedKey}=${encodedVal}")
        }

        return joinStrings(list, "&")
    }

    private func normalizePath(path: String): String {
        if (path.startsWith("/")) {
            return path
        }
        return "/${path}"
    }

    private func hmacSha1Hex(key: String, data: String): String {
        let keyBytes = stringToBytes(key)
        let dataBytes = stringToBytes(data)
        let digest = hmacSha1(keyBytes, dataBytes)
        return bytesToHex(digest)
    }

    private func sha1Hex(data: String): String {
        let dataBytes = stringToBytes(data)
        let digest = sha1(dataBytes)
        return bytesToHex(digest)
    }

    private func stringToBytes(str: String): Array<Byte> {
        let bytes = str.toArray()
        var result = Array<Byte>(bytes.size, repeat: 0)
        for (i in 0..bytes.size) {
            result[i] = bytes[i]
        }
        return result
    }

    private func bytesToHex(bytes: Array<Byte>): String {
        let hexChars = "0123456789abcdef"
        var result = ""
        for (b in bytes) {
            let byteVal: UInt8 = b
            let high: UInt8 = (byteVal >> 4) & 0x0F
            let low: UInt8 = byteVal & 0x0F
            result = "${result}${hexChars[Int64(high)..Int64(high+1)]}"
            result = "${result}${hexChars[Int64(low)..Int64(low+1)]}"
        }
        return result
    }

    private func sha1(data: Array<Byte>): Array<Byte> {
        let sha1 = SHA1()
        sha1.write(data)
        return sha1.finish()
    }

    private func hmacSha1(key: Array<Byte>, data: Array<Byte>): Array<Byte> {
        let hmac = HMAC(key, HashType.SHA1)
        hmac.write(data)
        return hmac.finish()
    }
}
