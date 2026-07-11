package cos.http

import stdx.net.http.*
import stdx.net.tls.{TlsClientConfig, CertificateVerifyMode}
import std.core.Duration
import std.collection.{HashMap, ArrayList}
import std.io.StringReader
import std.net.{SocketAddress, TcpSocket}
import cos.sign.CosSigner
import cos.model.CosResponse

public class CosHttpClient {
    private let client: Client
    private let signer: CosSigner
    private let region: String
    private let defaultBucket: ?String
    private let protocol: String

    public init(
        signer: CosSigner,
        region: String,
        defaultBucket!: ?String = None,
        protocol!: String = "https",
        timeout!: Int64 = 60
    ) {
        this.signer = signer
        this.region = region
        this.defaultBucket = defaultBucket
        this.protocol = protocol

        let cb = ClientBuilder()
        cb.readTimeout(Duration.second * timeout)
        cb.writeTimeout(Duration.second * timeout)
        cb.autoRedirect(true)

        if (protocol == "https") {
            var tlsConfig = TlsClientConfig()
            let bucketDomain = match (defaultBucket) {
                case Some(b) => b
                case None => ""
            }
            tlsConfig.domain = "${bucketDomain}.cos.${region}.myqcloud.com"
            tlsConfig.verifyMode = TrustAll
            cb.tlsConfig(tlsConfig)
        }

        this.client = cb.build()
    }

    public func get(
        bucket: String,
        key: String,
        headers!: HashMap<String, String> = HashMap<String, String>()
    ): CosResponse {
        let url = buildUrl(bucket, key)
        let pathname = buildPathname(key)
        let request = createRequest("GET", url, pathname, headers, bucket, None)
        return execute(request)
    }

    public func put(
        bucket: String,
        key: String,
        body: Array<Byte>,
        headers!: HashMap<String, String> = HashMap<String, String>()
    ): CosResponse {
        let url = buildUrl(bucket, key)
        let pathname = buildPathname(key)
        let request = createRequest("PUT", url, pathname, headers, bucket, body)
        return execute(request)
    }

    public func delete(
        bucket: String,
        key: String,
        headers!: HashMap<String, String> = HashMap<String, String>()
    ): CosResponse {
        let url = buildUrl(bucket, key)
        let pathname = buildPathname(key)
        let request = createRequest("DELETE", url, pathname, headers, bucket, None)
        return execute(request)
    }

    public func head(
        bucket: String,
        key: String,
        headers!: HashMap<String, String> = HashMap<String, String>()
    ): CosResponse {
        let url = buildUrl(bucket, key)
        let pathname = buildPathname(key)
        let request = createRequest("HEAD", url, pathname, headers, bucket, None)
        return execute(request)
    }

    public func listObjects(
        bucket: String,
        prefix!: ?String = None,
        delimiter!: ?String = None,
        marker!: ?String = None,
        maxKeys!: ?Int64 = None
    ): CosResponse {
        let url = buildListUrl(bucket, prefix, delimiter, marker, maxKeys)
        let pathname = "/"
        let headers = HashMap<String, String>()
        let request = createRequest("GET", url, pathname, headers, bucket, None)
        return execute(request)
    }

    private func buildUrl(bucket: String, key: String): String {
        let endpoint = "${bucket}.cos.${region}.myqcloud.com"
        let encodedKey = encodeKey(key)
        return "${protocol}://${endpoint}/${encodedKey}"
    }

    private func buildListUrl(
        bucket: String,
        prefix: ?String,
        delimiter: ?String,
        marker: ?String,
        maxKeys: ?Int64
    ): String {
        let endpoint = "${bucket}.cos.${region}.myqcloud.com"
        var url = "${protocol}://${endpoint}/"
        var params = ArrayList<String>()

        if (prefix.isSome()) {
            params.add("prefix=${encodeKey(prefix.getOrThrow())}")
        }
        if (delimiter.isSome()) {
            params.add("delimiter=${encodeKey(delimiter.getOrThrow())}")
        }
        if (marker.isSome()) {
            params.add("marker=${encodeKey(marker.getOrThrow())}")
        }
        if (maxKeys.isSome()) {
            params.add("max-keys=${maxKeys.getOrThrow()}")
        }

        if (params.size > 0) {
            url = "${url}?"
            for (i in 0..params.size) {
                if (i > 0) {
                    url = "${url}&"
                }
                url = "${url}${params[i]}"
            }
        }
        return url
    }

    private func buildPathname(key: String): String {
        if (key.startsWith("/")) {
            return key
        }
        return "/${key}"
    }

    private func encodeKey(key: String): String {
        var encoded = ""
        let bytes = key.toArray()
        for (b in bytes) {
            let byteVal: UInt8 = b
            if ((byteVal >= 65 && byteVal <= 90) || (byteVal >= 97 && byteVal <= 122) || 
                (byteVal >= 48 && byteVal <= 57) || byteVal == 45 || byteVal == 46 || 
                byteVal == 95 || byteVal == 126) {
                encoded = encoded + String.fromUtf8(Array<UInt8>(1, repeat: byteVal))
            } else {
                encoded = "${encoded}%${toHex(byteVal >> 4)}${toHex(byteVal & 0x0F)}"
            }
        }
        return encoded
    }

    private func toHex(val: UInt8): String {
        let chars = "0123456789ABCDEF"
        return chars[Int64(val)..Int64(val + 1)]
    }

    private func createRequest(
        method: String,
        url: String,
        pathname: String,
        headers: HashMap<String, String>,
        bucket: String,
        body: ?Array<Byte>
    ): HttpRequest {
        let signedHeaders = signer.getAuthorization(
            method,
            pathname,
            HashMap<String, String>(),
            headers,
            bucket,
            region
        )

        let rb = HttpRequestBuilder().url(url)
        
        if (method == "GET") {
            rb.get()
        } else if (method == "PUT") {
            rb.put()
        } else if (method == "DELETE") {
            rb.delete()
        } else if (method == "HEAD") {
            rb.head()
        }
        
        rb.header("Authorization", signedHeaders)
        
        if (!headers.contains("Host") && !headers.contains("host")) {
            rb.header("Host", "${bucket}.cos.${region}.myqcloud.com")
        }
        
        for (key in headers.keys()) {
            let optVal = headers.get(key)
            if (optVal.isSome()) {
                rb.header(key, optVal.getOrThrow())
            }
        }

        if (body.isSome()) {
            if (!headers.contains("Content-Type") && !headers.contains("content-type")) {
                rb.header("Content-Type", "application/octet-stream")
            }
            rb.body(body.getOrThrow())
        }

        return rb.build()
    }

    private func execute(request: HttpRequest): CosResponse {
        let response = client.send(request)
        let status = Int64(response.status)
        let reader = StringReader(response.body)
        let bodyStr = reader.readToEnd()
        let respHeaders = HashMap<String, String>()
        return CosResponse(status, respHeaders, bodyStr, "")
    }
}
