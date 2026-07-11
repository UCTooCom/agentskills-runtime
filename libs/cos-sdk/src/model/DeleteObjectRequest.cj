package cos.model

public class DeleteObjectRequest {
    public let bucket: String
    public let key: String

    public init(
        bucket: String,
        key: String
    ) {
        this.bucket = bucket
        this.key = key
    }
}