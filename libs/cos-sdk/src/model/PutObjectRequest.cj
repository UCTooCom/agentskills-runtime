package cos.model

import std.collection.HashMap

public class PutObjectRequest {
    public let bucket: String
    public let key: String
    public let body: Array<Byte>
    public let contentType: ?String
    public let contentLength: ?Int64
    public let acl: ?String
    public let metadata: HashMap<String, String>

    public init(
        bucket: String,
        key: String,
        body: Array<Byte>,
        contentType!: ?String = None,
        contentLength!: ?Int64 = None,
        acl!: ?String = None,
        metadata!: HashMap<String, String> = HashMap<String, String>()
    ) {
        this.bucket = bucket
        this.key = key
        this.body = body
        this.contentType = contentType
        this.contentLength = contentLength
        this.acl = acl
        this.metadata = metadata
    }
}