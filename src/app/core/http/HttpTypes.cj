package magic.app.core.http

import std.collection.ArrayList
import std.collection.HashMap

public enum HttpMethod {
    | GET
    | POST
    | PUT
    | DELETE
    | PATCH
    | HEAD
    | OPTIONS
    
    public func level(): Int32 {
        match (this) {
            case GET => 0
            case POST => 1
            case PUT => 2
            case DELETE => 3
            case PATCH => 4
            case HEAD => 5
            case OPTIONS => 6
        }
    }
}

public class HttpUrl {
    public var scheme: String = "http"
    public var host: String = ""
    public var port: Int32 = 80
    public var path: String = "/"
    public var query: String = ""
    public var fragment: String = ""
    
    public init() {}
    
    public func toString(): String {
        var url = "${scheme}://${host}"
        if ((scheme == "http" && port != 80) || (scheme == "https" && port != 443)) {
            url = url + ":${port}"
        }
        url = url + path
        if (query != "") {
            url = url + "?${query}"
        }
        if (fragment != "") {
            url = url + "#${fragment}"
        }
        return url
    }
}

public class HttpHeader {
    public var name: String = ""
    public var value: String = ""
    
    public init() {}
    
    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

public class HttpRequest {
    public var method: HttpMethod = HttpMethod.GET
    public var uri: HttpUrl = HttpUrl()
    public var headers: ArrayList<HttpHeader> = ArrayList<HttpHeader>()
    public var body: String = ""
    public var pathParams: HashMap<String, String> = HashMap<String, String>()
    public var queryParams: HashMap<String, String> = HashMap<String, String>()
    public var locals: HashMap<String, Any> = HashMap<String, Any>()
    
    private var bodyCache: ?String = None<String>
    
    public init() {}
    
    public func header(name: String): ?String {
        for (h in headers) {
            if (h.name == name) {
                return h.value
            }
        }
        return None<String>
    }
    
    public func pathParam(name: String): ?String {
        return pathParams.get(name)
    }
    
    public func queryParam(name: String): ?String {
        return queryParams.get(name)
    }
    
    public func json(): ?String {
        if (bodyCache == None<String>) {
            bodyCache = body
        }
        return bodyCache
    }
    
    public func getLocals(key: String): ?Any {
        return locals.get(key)
    }
    
    public func setLocals(key: String, value: Any) {
        locals[key] = value
    }
}

public class HttpResponse {
    private var statusCode: Int32 = 200
    private var headers: HashMap<String, String> = HashMap<String, String>()
    private var bodyContent: String = ""
    
    public init() {}
    
    public func status(code: Int32): HttpResponse {
        this.statusCode = code
        return this
    }
    
    public func header(name: String, value: String): HttpResponse {
        headers[name] = value
        return this
    }
    
    public func json(data: String): HttpResponse {
        headers["Content-Type"] = "application/json; charset=utf-8"
        bodyContent = data
        return this
    }
    
    public func send(text: String): HttpResponse {
        headers["Content-Type"] = "text/plain; charset=utf-8"
        bodyContent = text
        return this
    }
    
    public func getStatusCode(): Int32 {
        return statusCode
    }
    
    public func getHeaders(): HashMap<String, String> {
        return headers
    }
    
    public func getBody(): String {
        return bodyContent
    }
}
