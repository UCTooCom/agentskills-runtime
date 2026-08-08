package kaca_cookies

public enum SameSite {
    | None
    | Lax
    | Strict
}

public class StoredCookie {
    public var name: String
    public var value: String
    public var domain: String
    public var hostOnly: Bool
    public var path: String
    public var secure: Bool
    public var httpOnly: Bool
    public var sameSite: SameSite
    public var creationIndex: Int64

    public init(
        name: String,
        value: String,
        domain: String,
        hostOnly: Bool,
        path: String,
        secure: Bool,
        httpOnly: Bool,
        sameSite: SameSite,
        creationIndex: Int64
    ) {
        this.name = name
        this.value = value
        this.domain = domain
        this.hostOnly = hostOnly
        this.path = path
        this.secure = secure
        this.httpOnly = httpOnly
        this.sameSite = sameSite
        this.creationIndex = creationIndex
    }
}
