package cos.model

public class ListObjectsRequest {
    public let bucket: String
    public let prefix: ?String
    public let marker: ?String
    public let maxKeys: ?Int64

    public init(
        bucket: String,
        prefix!: ?String = None,
        marker!: ?String = None,
        maxKeys!: ?Int64 = None
    ) {
        this.bucket = bucket
        this.prefix = prefix
        this.marker = marker
        this.maxKeys = maxKeys
    }
}