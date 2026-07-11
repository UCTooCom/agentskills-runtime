package cos.model

public class CosObject {
    public let key: String
    public let lastModified: String
    public let eTag: String
    public let size: Int64
    public let storageClass: String

    public init(
        key: String,
        lastModified: String,
        eTag: String,
        size: Int64,
        storageClass: String
    ) {
        this.key = key
        this.lastModified = lastModified
        this.eTag = eTag
        this.size = size
        this.storageClass = storageClass
    }
}