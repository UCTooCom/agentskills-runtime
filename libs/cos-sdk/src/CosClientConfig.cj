package cos

import std.collection.HashMap

public class CosClientConfig {
    public let secretId: String
    public let secretKey: String
    public let region: String
    public let bucket: ?String
    public let protocol: String
    public let timeout: Int64
    public let endpoint: ?String

    public init(
        secretId: String,
        secretKey: String,
        region: String,
        bucket!: ?String = None,
        protocol!: String = "https",
        timeout!: Int64 = 60,
        endpoint!: ?String = None
    ) {
        this.secretId = secretId
        this.secretKey = secretKey
        this.region = region
        this.bucket = bucket
        this.protocol = protocol
        this.timeout = timeout
        this.endpoint = endpoint
    }

    public func getEndpoint(): String {
        match (endpoint) {
            case Some(ep) => ep
            case None => "${protocol}://${region}.myqcloud.com"
        }
    }

    public func getBucketEndpoint(bucket: String): String {
        match (endpoint) {
            case Some(ep) => "${protocol}://${bucket}.${ep.replace("https://", "").replace("http://", "")}"
            case None => "${protocol}://${bucket}.cos.${region}.myqcloud.com"
        }
    }
}