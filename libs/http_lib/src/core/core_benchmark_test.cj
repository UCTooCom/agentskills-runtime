package http_lib.core


/**
 * 核心类型、Headers、Method、Status 性能基准测试。
 */
@Test public class MethodBench {
    @Bench
    public func methodParse(): Unit {
        let _ = HttpMethod.parse("GET")
    }

    @Bench
    public func methodEquality(): Unit {
        let _ = HttpMethod.GET == HttpMethod.GET
        let _ = HttpMethod.GET.hashCode()
    }
}

@Test public class StatusBench {
    @Bench
    public func statusCategoryChecks(): Unit {
        let s = HttpStatus.OK
        let _ = s.isSuccess()
        let _ = s.isClientError()
        let _ = s.isServerError()
        let _ = s.isInformational()
        let _ = s.isRedirection()
    }
}

@Test public class HeadersBench {
    @Bench
    public func headersSet(): Unit {
        let h = HttpHeaders()
        h.set("Content-Type", "application/json")
        h.set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        h.set("Authorization", "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
        h.set("Cache-Control", "no-cache, no-store, must-revalidate")
        h.set("X-Request-ID", "550e8400-e29b-41d4-a716-446655440000")
    }

    @Bench
    public func headersToBytes(): Unit {
        let h = HttpHeaders()
        h.set("Content-Type", "application/json")
        h.set("Content-Length", "42")
        h.set("Server", "http_lib")
        h.set("Date", "Mon, 01 Jan 2026 00:00:00 GMT")
        let _ = h.toBytes()
    }

    @Bench
    public func headersCaseInsensitive(): Unit {
        let h = HttpHeaders()
        h.set("CONTENT-TYPE", "application/json")
        h.set("content-type", "text/html")
        h.set("Content-Type", "text/plain")
        let _ = h.get("CONTENT-TYPE")
        let _ = h.get("content-type")
        let _ = h.get("Content-Type")
    }

    @Bench
    public func headersMultiValue(): Unit {
        let h = HttpHeaders()
        h.add("Set-Cookie", "session=abc123; Path=/")
        h.add("Set-Cookie", "theme=dark; Path=/")
        h.add("Set-Cookie", "lang=en; Path=/")
        let _ = h.getAll("set-cookie")
        let _ = h.get("Set-Cookie")
    }

    @Bench
    public func benchCurrentHttpDate(): Unit {
        let _ = currentHttpDate()
    }

    @Bench
    public func parseContentLength(): Unit {
        let _ = parseContentLength("1048576")
    }
}
