package kaca_cookies

import std.collection.*

private func truncateAtNewline(text: String): String {
    let raw = unsafe { text.rawData() }
    var i = 0
    while (i < raw.size) {
        if (raw[i] == b'\r' || raw[i] == b'\n') {
            if (i == 0) {
                return ""
            }
            return text[0..i]
        }
        i += 1
    }
    text
}

private func parseCookieIntegerSign(text: String): ?Int64 {
    let trimmed = trimWsp(text)
    if (trimmed.isEmpty()) {
        return None
    }
    let raw = unsafe { trimmed.rawData() }
    var index = 0
    var sign = Int64(1)
    if (raw[0] == b'-') {
        sign = Int64(-1)
        index = 1
    } else if (raw[0] == b'+') {
        index = 1
    }
    if (index >= raw.size) {
        return None
    }
    var hasNonZero = false
    while (index < raw.size) {
        let ch = raw[index]
        if (ch < b'0' || ch > b'9') {
            return None
        }
        if (ch != b'0') {
            hasNonZero = true
        }
        index += 1
    }
    if (!hasNonZero) {
        return Some(0)
    }
    if (sign < 0) {
        return Some(-1)
    }
    Some(1)
}

private func parseExpiresYear(text: String): ?Int64 {
    let raw = unsafe { text.rawData() }
    var i = 0
    while (i + 3 < raw.size) {
        if (raw[i] >= b'0' && raw[i] <= b'9' &&
            raw[i + 1] >= b'0' && raw[i + 1] <= b'9' &&
            raw[i + 2] >= b'0' && raw[i + 2] <= b'9' &&
            raw[i + 3] >= b'0' && raw[i + 3] <= b'9') {
            let year = Int64((raw[i] - b'0').position()) * 1000 +
                Int64((raw[i + 1] - b'0').position()) * 100 +
                Int64((raw[i + 2] - b'0').position()) * 10 +
                Int64((raw[i + 3] - b'0').position())
            return Some(year)
        }
        i += 1
    }
    None
}

private func hasDisallowedCtl(text: String): Bool {
    let raw = unsafe { text.rawData() }
    for (ch in raw) {
        if (ch == b'\t') {
            continue
        }
        if (ch <= UInt8(0x1F) || ch == UInt8(0x7F)) {
            return true
        }
    }
    false
}

private func isAttributeValueTooLong(value: String): Bool {
    let raw = unsafe { value.rawData() }
    raw.size > 1024
}

private func isValidDomainAttributeValue(value: String): Bool {
    if (value.isEmpty() || value.startsWith(".") || value.endsWith(".")) {
        return false
    }
    if (value.indexOf(".").isNone()) {
        return false
    }
    if (value.indexOf("..").isSome()) {
        return false
    }
    let raw = unsafe { value.rawData() }
    for (ch in raw) {
        if (ch >= UInt8(0x80)) {
            return false
        }
        if (ch <= UInt8(0x20) || ch == b'"' || ch == b':' || ch == b'/' || ch == b'\\') {
            return false
        }
    }
    true
}

public class CookieJar {
    private let cookies = ArrayList<StoredCookie>()
    private var nextCreationIndex: Int64 = 0

    public init() {}

    public func clear(): Unit {
        cookies.clear()
    }

    public func setCookieString(
        cookieLine: String,
        requestHost!: String = "www.example.test",
        requestPath!: String = "/",
        isSecureContext!: Bool = false,
        isFromHttp!: Bool = true
    ): Bool {
        let host = trimWsp(requestHost).toAsciiLower()
        if (host.isEmpty()) {
            return false
        }
        let resolvedPath = if (requestPath.isEmpty()) { "/" } else { requestPath }

        let normalizedLine = trimWsp(truncateAtNewline(cookieLine))
        if (normalizedLine.isEmpty()) {
            return false
        }

        let segments = normalizedLine.split(";")
        if (segments.isEmpty()) {
            return false
        }
        let cookiePair = trimWsp(segments[0])
        if (cookiePair.isEmpty()) {
            return false
        }
        if (hasDisallowedCtl(cookiePair)) {
            return false
        }

        var name = ""
        var value = ""
        if (let Some(eqIndex) <- cookiePair.indexOf("=")) {
            if (eqIndex == 0) {
                name = ""
                value = if (cookiePair.size > 1) { trimWsp(cookiePair[1..cookiePair.size]) } else { "" }
            } else {
                name = trimWsp(cookiePair[0..eqIndex])
                value = if (eqIndex + 1 < cookiePair.size) {
                    trimWsp(cookiePair[(eqIndex + 1)..cookiePair.size])
                } else {
                    ""
                }
            }
        } else {
            name = ""
            value = cookiePair
        }

        if (name.isEmpty() && value.isEmpty()) {
            return false
        }
        if (hasDisallowedCtl(name) || hasDisallowedCtl(value)) {
            return false
        }
        if (name.size + value.size > 4096) {
            return false
        }

        var domain = host
        var path = defaultPath(resolvedPath)
        var secure = false
        var httpOnly = false
        var hasDomainAttribute = false
        var sawDomainAttribute = false
        var domainAttributeValid = true
        var hostOnly = true
        var maxAgeSign: ?Int64 = None
        var expiresYear: ?Int64 = None
        var sameSite: SameSite = SameSite.Lax

        var i = 1
        while (i < segments.size) {
            let rawAttributeSource = segments[i]
            if (hasDisallowedCtl(rawAttributeSource)) {
                return false
            }
            let rawAttribute = trimWsp(rawAttributeSource)
            if (!rawAttribute.isEmpty()) {
                var attributeName = ""
                var attributeValue = ""
                if (let Some(eqIndex) <- rawAttribute.indexOf("=")) {
                    attributeName = trimWsp(rawAttribute[0..eqIndex]).toAsciiLower()
                    attributeValue = if (eqIndex + 1 < rawAttribute.size) {
                        trimWsp(rawAttribute[(eqIndex + 1)..rawAttribute.size])
                    } else {
                        ""
                    }
                } else {
                    attributeName = rawAttribute.toAsciiLower()
                    attributeValue = ""
                }

                if (attributeName == "domain") {
                    sawDomainAttribute = true
                    if (attributeValue.isEmpty()) {
                        domain = host
                        hostOnly = true
                        domainAttributeValid = true
                    } else if (isAttributeValueTooLong(attributeValue)) {
                        // Ignore too-long domain attributes.
                    } else {
                        var candidateDomain = attributeValue.toAsciiLower()
                        if (candidateDomain.startsWith(".")) {
                            candidateDomain = if (candidateDomain.size > 1) {
                                candidateDomain[1..candidateDomain.size]
                            } else {
                                ""
                            }
                        }
                        if (isValidDomainAttributeValue(candidateDomain) && domainMatches(host, candidateDomain)) {
                            hasDomainAttribute = true
                            domainAttributeValid = true
                            domain = candidateDomain
                            hostOnly = false
                        } else {
                            domainAttributeValid = false
                        }
                    }
                } else if (attributeName == "path") {
                    if (isAttributeValueTooLong(attributeValue)) {
                        // Ignore too-long path attributes.
                    } else if (attributeValue.isEmpty() || !attributeValue.startsWith("/")) {
                        path = defaultPath(resolvedPath)
                    } else {
                        path = attributeValue
                    }
                } else if (attributeName == "secure") {
                    secure = true
                } else if (attributeName == "httponly") {
                    httpOnly = true
                } else if (attributeName == "samesite") {
                    let lowerValue = attributeValue.toAsciiLower()
                    if (lowerValue == "strict") {
                        sameSite = SameSite.Strict
                    } else if (lowerValue == "lax") {
                        sameSite = SameSite.Lax
                    } else if (lowerValue == "none") {
                        sameSite = SameSite.None
                    }
                } else if (attributeName == "max-age") {
                    if (!isAttributeValueTooLong(attributeValue)) {
                        if (let Some(sign) <- parseCookieIntegerSign(attributeValue)) {
                            maxAgeSign = Some(sign)
                        }
                    }
                } else if (attributeName == "expires") {
                    if (!isAttributeValueTooLong(attributeValue)) {
                        if (let Some(year) <- parseExpiresYear(attributeValue)) {
                            expiresYear = Some(year)
                        }
                    }
                }
            }
            i += 1
        }

        // Reject SameSite=None without Secure (RFC 6265bis requirement).
        if (match (sameSite) { case SameSite.None => true; case _ => false } && !secure) {
            return false
        }

        if (sawDomainAttribute && !domainAttributeValid) {
            return false
        }

        let lowerName = name.toAsciiLower()
        let lowerValue = value.toAsciiLower()
        if (name.isEmpty()) {
            if (lowerValue.startsWith("__secure-") || lowerValue.startsWith("__host-")) {
                return false
            }
        } else {
            if (lowerName.startsWith("__secure-") && (!secure || !isSecureContext)) {
                return false
            }
            if (lowerName.startsWith("__host-") && (!secure || !isSecureContext || hasDomainAttribute || path != "/")) {
                return false
            }
            if (lowerName.startsWith("__http-") && (!isFromHttp || !secure || !httpOnly || !isSecureContext)) {
                return false
            }
            if (lowerName.startsWith("__host-http-") &&
                (!isFromHttp || !secure || !httpOnly || !isSecureContext || hasDomainAttribute || path != "/")) {
                return false
            }
        }

        var existingIndex = -1
        var cursor = 0
        while (cursor < cookies.size) {
            let existing = cookies[cursor]
            if (existing.name == name && existing.domain == domain && existing.path == path) {
                existingIndex = cursor
                break
            }
            cursor += 1
        }

        var shouldExpire = false
        if (let Some(sign) <- maxAgeSign) {
            if (sign <= 0) {
                shouldExpire = true
            }
        } else if (let Some(year) <- expiresYear) {
            if (year < 2026) {
                shouldExpire = true
            }
        }

        if (shouldExpire) {
            if (existingIndex >= 0) {
                cookies.remove(at: existingIndex)
            }
            return true
        }

        if (existingIndex >= 0) {
            cookies.remove(at: existingIndex)
        }

        cookies.add(
            StoredCookie(
                name,
                value,
                domain,
                hostOnly,
                path,
                secure,
                httpOnly,
                sameSite,
                nextCreationIndex
            )
        )
        nextCreationIndex += 1
        true
    }

    public func setCookieStrings(
        cookieLines: Array<String>,
        requestHost!: String = "www.example.test",
        requestPath!: String = "/",
        isSecureContext!: Bool = false,
        isFromHttp!: Bool = true
    ): Unit {
        for (line in cookieLines) {
            _ = setCookieString(
                line,
                requestHost: requestHost,
                requestPath: requestPath,
                isSecureContext: isSecureContext,
                isFromHttp: isFromHttp
            )
        }
    }

    public func setCookieStringFromDom(
        cookieLine: String,
        requestHost!: String = "www.example.test",
        requestPath!: String = "/",
        isSecureContext!: Bool = false
    ): Bool {
        setCookieString(
            cookieLine,
            requestHost: requestHost,
            requestPath: requestPath,
            isSecureContext: isSecureContext,
            isFromHttp: false
        )
    }

    public func setCookieStringsFromDom(
        cookieLines: Array<String>,
        requestHost!: String = "www.example.test",
        requestPath!: String = "/",
        isSecureContext!: Bool = false
    ): Unit {
        for (line in cookieLines) {
            _ = setCookieStringFromDom(
                line,
                requestHost: requestHost,
                requestPath: requestPath,
                isSecureContext: isSecureContext
            )
        }
    }

    public func documentCookie(
        requestHost!: String = "www.example.test",
        requestPath!: String = "/",
        isSecureContext!: Bool = false
    ): String {
        if (cookies.isEmpty()) {
            return ""
        }
        let host = trimWsp(requestHost).toAsciiLower()
        let resolvedPath = if (requestPath.isEmpty()) { "/" } else { requestPath }
        let visible = ArrayList<StoredCookie>()
        for (cookie in cookies) {
            if (cookie.hostOnly) {
                if (host != cookie.domain) {
                    continue
                }
            } else {
                if (!domainMatches(host, cookie.domain)) {
                    continue
                }
            }
            if (!pathMatches(resolvedPath, cookie.path)) {
                continue
            }
            if (cookie.secure && !isSecureContext) {
                continue
            }
            if (cookie.httpOnly) {
                continue
            }
            visible.add(cookie)
        }
        if (visible.isEmpty()) {
            return ""
        }

        // RFC-style order: longer path first; for equal length, older cookie first.
        let ordered = ArrayList<StoredCookie>()
        let remaining = ArrayList<Int64>()
        var visibleIndex = 0
        while (visibleIndex < visible.size) {
            remaining.add(visibleIndex)
            visibleIndex += 1
        }
        while (!remaining.isEmpty()) {
            var bestPos = 0
            var cursor = 1
            while (cursor < remaining.size) {
                let candidate = visible[remaining[cursor]]
                let best = visible[remaining[bestPos]]
                if (candidate.path.size > best.path.size ||
                    (candidate.path.size == best.path.size && candidate.creationIndex < best.creationIndex)) {
                    bestPos = cursor
                }
                cursor += 1
            }
            let selected = remaining[bestPos]
            ordered.add(visible[selected])
            remaining.remove(at: bestPos)
        }

        let parts = ArrayList<String>()
        for (cookie in ordered) {
            parts.add(serializeCookieForDocument(cookie))
        }
        if (parts.isEmpty()) {
            return ""
        }
        let sb = StringBuilder()
        var i = 0
        while (i < parts.size) {
            if (i > 0) {
                sb.append("; ")
            }
            sb.append(parts[i])
            i += 1
        }
        sb.toString()
    }

    public func requestCookieHeader(
        requestHost!: String = "www.example.test",
        requestPath!: String = "/",
        isSecureContext!: Bool = false,
        requestIsSameSite!: Bool = true
    ): String {
        if (cookies.isEmpty()) {
            return ""
        }
        let host = trimWsp(requestHost).toAsciiLower()
        let resolvedPath = if (requestPath.isEmpty()) { "/" } else { requestPath }
        let visible = ArrayList<StoredCookie>()
        for (cookie in cookies) {
            if (cookie.hostOnly) {
                if (host != cookie.domain) {
                    continue
                }
            } else {
                if (!domainMatches(host, cookie.domain)) {
                    continue
                }
            }
            if (!pathMatches(resolvedPath, cookie.path)) {
                continue
            }
            if (cookie.secure && !isSecureContext) {
                continue
            }
            // SameSite enforcement: Lax/Strict cookies are not sent on cross-site requests.
            if (!requestIsSameSite && match (cookie.sameSite) { case SameSite.None => false; case _ => true }) {
                continue
            }
            visible.add(cookie)
        }
        if (visible.isEmpty()) {
            return ""
        }

        let ordered = ArrayList<StoredCookie>()
        let remaining = ArrayList<Int64>()
        var visibleIndex = 0
        while (visibleIndex < visible.size) {
            remaining.add(visibleIndex)
            visibleIndex += 1
        }
        while (!remaining.isEmpty()) {
            var bestPos = 0
            var cursor = 1
            while (cursor < remaining.size) {
                let candidate = visible[remaining[cursor]]
                let best = visible[remaining[bestPos]]
                if (candidate.path.size > best.path.size ||
                    (candidate.path.size == best.path.size && candidate.creationIndex < best.creationIndex)) {
                    bestPos = cursor
                }
                cursor += 1
            }
            let selected = remaining[bestPos]
            ordered.add(visible[selected])
            remaining.remove(at: bestPos)
        }

        let parts = ArrayList<String>()
        for (cookie in ordered) {
            parts.add(serializeCookieForDocument(cookie))
        }
        if (parts.isEmpty()) {
            return ""
        }
        let sb = StringBuilder()
        var i = 0
        while (i < parts.size) {
            if (i > 0) {
                sb.append("; ")
            }
            sb.append(parts[i])
            i += 1
        }
        sb.toString()
    }
}
