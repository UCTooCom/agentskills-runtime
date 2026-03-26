package magic.app.core.response

public class APIResponse<T> {
    public var data: T
    public var currentPage: Int32 = 0
    public var totalCount: Int64 = 0
    public var totalPage: Int32 = 0
    
    public init(data: T) {
        this.data = data
    }
    
    public init(
        data: T,
        currentPage: Int32,
        totalCount: Int64,
        totalPage: Int32
    ) {
        this.data = data
        this.currentPage = currentPage
        this.totalCount = totalCount
        this.totalPage = totalPage
    }
}

public class APIError {
    public var errno: String = ""
    public var errmsg: String = ""
    
    public init(errno: String, errmsg: String) {
        this.errno = errno
        this.errmsg = errmsg
    }
    
    public func toJson(): String {
        return "{\"errno\":\"${errno}\",\"errmsg\":\"${errmsg}\"}"
    }
}

public class APIResult<T> {
    public var success: Bool = true
    public var data: ?T = None<T>
    public var reason: ?String = None<String>
    
    public init() {}
    
    public init(data: T) {
        this.success = true
        this.data = data
    }
    
    public init(success: Bool, reason: String) {
        this.success = success
        this.reason = reason
    }
}
