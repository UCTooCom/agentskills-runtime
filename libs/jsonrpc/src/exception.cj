package ystyle::jsonrpc

public class JsonRpcException <: Exception {
    public let code: Int64

    public init(code: Int64, message: String) {
        super(message)
        this.code = code
    }
}

public enum Result<T> {
    | Ok(T)
    | Err(String)
}
