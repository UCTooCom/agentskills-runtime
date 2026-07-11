package cos.model

public class PutObjectResult {
    public let eTag: String
    public let location: String
    public let versionId: ?String

    public init(
        eTag: String,
        location: String,
        versionId!: ?String = None
    ) {
        this.eTag = eTag
        this.location = location
        this.versionId = versionId
    }
}