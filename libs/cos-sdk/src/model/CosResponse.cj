package cos.model

import std.collection.HashMap

public class CosResponse {
    public let statusCode: Int64
    public let headers: HashMap<String, String>
    public let body: String
    public let requestId: String

    public init(
        statusCode: Int64,
        headers: HashMap<String, String>,
        body: String,
        requestId: String
    ) {
        this.statusCode = statusCode
        this.headers = headers
        this.body = body
        this.requestId = requestId
    }

    public func isSuccess(): Bool {
        return statusCode >= 200 && statusCode < 300
    }
}