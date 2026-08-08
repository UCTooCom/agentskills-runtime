package kaca_cookies

public func trimWsp(text: String): String {
    let raw = unsafe { text.rawData() }
    var start = 0
    var end = raw.size
    while (start < end && (raw[start] == b' ' || raw[start] == b'\t' || raw[start] <= UInt8(0x1F))) {
        start += 1
    }
    while (end > start && (raw[end - 1] == b' ' || raw[end - 1] == b'\t' || raw[end - 1] <= UInt8(0x1F))) {
        end -= 1
    }
    if (start == 0 && end == raw.size) {
        return text
    }
    if (start >= end) {
        return ""
    }
    text[start..end]
}

public func defaultPath(requestPath: String): String {
    if (requestPath.isEmpty() || !requestPath.startsWith("/")) {
        return "/"
    }
    if (requestPath == "/") {
        return "/"
    }
    let raw = unsafe { requestPath.rawData() }
    var i = raw.size - 1
    while (i >= 0) {
        if (raw[i] == b'/') {
            if (i <= 0) {
                return "/"
            }
            return requestPath[0..i]
        }
        i -= 1
    }
    "/"
}

public func domainMatches(requestHost: String, cookieDomain: String): Bool {
    let host = trimWsp(requestHost).toAsciiLower()
    let domain = trimWsp(cookieDomain).toAsciiLower()
    if (host.isEmpty() || domain.isEmpty()) {
        return false
    }
    if (host == domain) {
        return true
    }
    host.endsWith("." + domain)
}

public func pathMatches(requestPath: String, cookiePath: String): Bool {
    let targetPath = if (requestPath.isEmpty() || !requestPath.startsWith("/")) { "/" } else { requestPath }
    let candidate = if (cookiePath.isEmpty() || !cookiePath.startsWith("/")) { "/" } else { cookiePath }
    if (targetPath == candidate) {
        return true
    }
    if (!targetPath.startsWith(candidate)) {
        return false
    }
    if (candidate.endsWith("/")) {
        return true
    }
    let raw = unsafe { targetPath.rawData() }
    if (candidate.size >= raw.size) {
        return false
    }
    raw[candidate.size] == b'/'
}

public func serializeCookieForDocument(cookie: StoredCookie): String {
    if (cookie.name.isEmpty()) {
        return cookie.value
    }
    cookie.name + "=" + cookie.value
}
