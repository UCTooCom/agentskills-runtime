package cos.model

import std.collection.HashMap

public class ObjectMetadata {
    public let headers: HashMap<String, String>

    public init(headers!: HashMap<String, String> = HashMap<String, String>()) {
        this.headers = headers
    }

    public func setContentType(contentType: String): Unit {
        headers.add("Content-Type", contentType)
    }

    public func getContentType(): ?String {
        headers.get("Content-Type")
    }

    public func setContentLength(length: Int64): Unit {
        headers.add("Content-Length", length.toString())
    }

    public func addMetadata(key: String, value: String): Unit {
        headers.add("x-cos-meta-${key}", value)
    }

    public func getMetadata(key: String): ?String {
        headers.get("x-cos-meta-${key}")
    }
}