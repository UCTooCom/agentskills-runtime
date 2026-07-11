package cos.model

public class GetObjectResult {
    public let content: String
    public let contentType: String
    public let contentLength: Int64
    public let eTag: String
    public let lastModified: String

    public init(
        content: String,
        contentType: String,
        contentLength: Int64,
        eTag: String,
        lastModified: String
    ) {
        this.content = content
        this.contentType = contentType
        this.contentLength = contentLength
        this.eTag = eTag
        this.lastModified = lastModified
    }
}