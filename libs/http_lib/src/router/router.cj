package http_lib.router

import std.collection.{HashMap, ArrayList}
import std.sync.ReadWriteLock
import http_lib.core.{HttpMethod, HttpStatus, ProtocolException}
import http_lib.message.{HttpRequest, HttpResponse, StreamingHandler, ResponseBuilder, wrapHandler}

/**
 * 用于处理 HTTP 请求的处理器函数类型。
 */
public type Handler = (HttpRequest) -> HttpResponse

/**
 * 中间件函数类型：通过前置/后置处理包装 Handler。
 */
public type Middleware = (Handler) -> Handler

/**
 * 基于基数树的 HTTP 路由器，支持路径参数。
 *
 * 基数树路由器，支持所有标准 HTTP 方法。
 * 路径模式：
 *   - /static/path    精确匹配
 *   - /users/:id      命名参数（匹配 /users/123）
 *   - /files/=path   通配参数（匹配 /files/a/b/c）
 *
 * 线程安全：所有公开方法均受互斥锁保护。
 *
 * 用法：
 *   let router = Router()
 *   router.use(loggingMiddleware)
 *   router.get("/users/:id", userHandler)
 *   let server = HttpServer(handler: router.handler())
 */
public class Router {
    private var trees: HashMap<HttpMethod, Node>
    public var middlewareChain: MiddlewareChain
    // 基于主机的路由：将主机名映射到子路由器
    private var hostRouters: HashMap<String, Router>
    // 路由组（带前缀的嵌套路由器）
    private var groups: ArrayList<Router>
    private var groupPrefix: String
    // 读写锁，用于线程安全的路由操作。
    // 路由查找（读）远多于注册（写），
    // 因此读写锁允许并发读取和互斥写入。
    private var rwLock: ReadWriteLock

    public init() {
        this.trees = HashMap<HttpMethod, Node>()
        this.middlewareChain = MiddlewareChain()
        this.hostRouters = HashMap<String, Router>()
        this.groups = ArrayList<Router>()
        this.groupPrefix = ""
        this.rwLock = ReadWriteLock()
    }

    /**
     * 注册中间件函数。
     */
    public func use(m: Middleware): Router {
        middlewareChain.use(m)
        this
    }

    /**
     * 创建主机特定的子路由器（虚拟主机路由）。
     * 在返回的子路由器上注册的路由ed router only match when
     * 请求的 Host 头匹配给定主机名时，才路由到此子路由器。
     *
     * 用法：
     *   router.host("api.example.com").get("/v1/users", apiHandler)
     *   router.host("admin.example.com").get("/dashboard", adminHandler)
     */
    public func host(hostname: String): Router {
        synchronized(rwLock.writeLock) {
            match (hostRouters.get(hostname)) {
                case Some(r) => r
                case None =>
                    let subRouter = Router()
                    hostRouters[hostname] = subRouter
                    subRouter
            }
        }
    }

    /**
     * 创建具有公共路径前缀的路由组。
     * 在返回的路由器上注册的所有路由ter are
     * 会自动添加给定路径前缀。
     *
     * 用法：
     *   let api = router.group("/api/v1")
     *   api.get("/users", listUsers)       // 匹配 /api/v1/users
     *   api.post("/users", createUser)     // 匹配 /api/v1/users
     */
    public func group(prefix: String): Router {
        synchronized(rwLock.writeLock) {
            let subRouter = Router()
            subRouter.groupPrefix = prefix
            groups.add(subRouter)
            subRouter
        }
    }

    /**
     * 注册 GET 请求处理器 at the given path.
     */
    public func get(path: String, handler: Handler): Router {
        handle(HttpMethod.GET, path, handler)
        this
    }

    /**
     * 注册 POST 请求处理器 at the given path.
     */
    public func post(path: String, handler: Handler): Router {
        handle(HttpMethod.POST, path, handler)
        this
    }

    /**
     * 为给定路径注册 PUT 请求处理器。
     */
    public func put(path: String, handler: Handler): Router {
        handle(HttpMethod.PUT, path, handler)
        this
    }

    /**
     * 为给定路径注册 DELETE 请求处理器。
     */
    public func delete(path: String, handler: Handler): Router {
        handle(HttpMethod.DELETE, path, handler)
        this
    }

    /**
     * 为给定路径注册 PATCH 请求处理器。
     */
    public func patch(path: String, handler: Handler): Router {
        handle(HttpMethod.PATCH, path, handler)
        this
    }

    /**
     * 为给定路径注册 HEAD 请求处理器。
     */
    public func head(path: String, handler: Handler): Router {
        handle(HttpMethod.HEAD, path, handler)
        this
    }

    /**
     * 为给定路径注册 OPTIONS 请求处理器。
     */
    public func options(path: String, handler: Handler): Router {
        handle(HttpMethod.OPTIONS, path, handler)
        this
    }

    /**
     * 为给定路径注册 CONNECT 请求处理器。
     */
    public func connect(path: String, handler: Handler): Router {
        handle(HttpMethod.CONNECT, path, handler)
        this
    }

    /**
     * 为给定路径注册 TRACE 请求处理器。
     */
    public func trace(path: String, handler: Handler): Router {
        handle(HttpMethod.TRACE, path, handler)
        this
    }

    /**
     * 为给定路径注册任意方法的处理器。
     * 同时支持 :param 语法（如 /users/:id) and {param} syntax
     * （如 /users/{id}）。{param} 语法被转换为 :param
     * 以向后兼容已有路由。
     */
    public func handle(method: HttpMethod, path: String, handler: Handler): Router {
        synchronized(rwLock.writeLock) {
            // 若为组子路由器则应用组前缀
            let fullPath = if (groupPrefix.size > 0) { "${groupPrefix}${path}" } else { path }
            // 将 {param} 语法转换为内部基数树的 :param 格式
            let normalizedPath = translateBraceParams(fullPath)
            if (!trees.contains(method)) {
                trees[method] = Node()
            }
            trees[method].addRoute(normalizedPath, handler)
            // 诊断日志：对关键路由输出
            if (path.contains("hello") || path.contains("health") || path.contains("tasks/public/home-stats")) {
                eprintln("[Router.handle] method=${method}, path='${path}', normalized='${normalizedPath}', root.path='${trees[method].path}', root.indices='${trees[method].indices}', children=${trees[method].children.size}")
            }
        }
        this
    }

    /**
     * 为给定的方法、路径和可选的主机头查找处理器。
     * 检查顺序：主机专用路由器优先，然后是本地树，最后是分组。
     *
     * 返回包含匹配的处理器、路径参数以及
     * 是否应发出尾部斜杠重定向的 HandlerResult。
     */
    public func find(method: HttpMethod, path: String): HandlerResult {
        synchronized(rwLock.readLock) { findLocked(method, path) }
    }

    private func findLocked(method: HttpMethod, path: String): HandlerResult {
        // 诊断日志：记录查找过程
        let diagFind = path.contains("health") || path.contains("tasks") || path.contains("webmcp")
        match (trees.get(method)) {
            case Some(root) =>
                if (diagFind) {
                    eprintln("[findLocked] method=${method}, path='${path}', root.path='${root.path}', root.indices='${root.indices}', children=${root.children.size}, maxParams=${root.maxParams}, wildChild=${root.wildChild}")
                }
                // 根据树的参数深度决定是否延迟分配 ParamMap：
                // maxParams == 0 表示此 HTTP 方法树下全是静态路由，
                // 不会匹配到任何路径参数，因此完全跳过 ParamMap
                // 分配和 valueSetter lambda，避免无谓的 HashMap 创建。
                if (root.maxParams > 0) {
                    let pm = ParamMap()
                    let setParam = {key, value => pm.set(key, value)}
                    let (handler, tsr) = root.findRoute(path, Some(setParam))
                    let params = pm.build()
                    if (diagFind) {
                        eprintln("[findLocked] findRoute result: handler=${handler.isSome()}, tsr=${tsr}")
                    }
                    if (handler.isSome()) {
                        return HandlerResult(handler: handler, params: params, tsr: tsr)
                    }
                    if (tsr) {
                        return HandlerResult(handler: None, params: params, tsr: true)
                    }
                } else {
                    // 全静态路由树 —— 无需 ParamMap
                    let (handler, tsr) = root.findRoute(path, None)
                    if (diagFind) {
                        eprintln("[findLocked] findRoute result: handler=${handler.isSome()}, tsr=${tsr}")
                    }
                    if (handler.isSome()) {
                        return HandlerResult(handler: handler, params: HashMap<String, String>(), tsr: tsr)
                    }
                    if (tsr) {
                        return HandlerResult(handler: None, params: HashMap<String, String>(), tsr: true)
                    }
                }
            case None =>
                if (diagFind) {
                    eprintln("[findLocked] method=${method} NOT in trees! trees.size=${trees.size}")
                }
                ()
        }
        // 检查组子路由器
        for (group in groups) {
            let result = group.findLocked(method, path)
            if (result.handler.isSome() || result.tsr) {
                return result
            }
        }
        HandlerResult(handler: None, params: HashMap<String, String>(), tsr: false)
    }

    /**
     * 在主机专用路由器中查找处理器。
     * 使用请求的 Host 头调用此方法以启用虚拟主机路由。
     *
     * 用法：
     *   let host = match (req.headers.get("host")) { case Some(h) => h case None => "" }
     *   let result = router.findByHost(method, path, host)
     */
    public func findByHost(method: HttpMethod, path: String, host: String): HandlerResult {
        synchronized(rwLock.readLock) {
            // 诊断：检查虚拟主机路由
            let diag = path.contains("tasks") || path.contains("webmcp") || path.contains("health")
            // 先检查主机专用路由器
            match (hostRouters.get(host)) {
                case Some(hostRouter) =>
                    if (diag) {
                        eprintln("[findByHost] hostRouter found for '${host}', delegating...")
                    }
                    let result = hostRouter.findLocked(method, path)
                    if (result.handler.isSome() || result.tsr) {
                        return result
                    }
                case None =>
                    if (diag) {
                        eprintln("[findByHost] no hostRouter for '${host}', falling back to default")
                    }
            }
            // 回退到默认路由 + 分组
            findLocked(method, path)
        }
    }

    /**
     * 获取给定主机名的主机专用子路由器。
     * 若未注册主机专用路由则返回 None。
     */
    public func getHostRouter(hostname: String): ?Router {
        synchronized(rwLock.readLock) { hostRouters.get(hostname) }
    }

    /**
     * 获取路径的 Allow 头值（所有已注册的方法）。
     */
    public func allowedMethodsForPath(path: String): String {
        synchronized(rwLock.readLock) { allowedMethodsForPathLocked(path) }
    }

    private func allowedMethodsForPathLocked(path: String): String {
        var methods = ArrayList<String>()
        let methodList = [
            HttpMethod.GET, HttpMethod.POST, HttpMethod.PUT, HttpMethod.DELETE,
            HttpMethod.PATCH, HttpMethod.HEAD, HttpMethod.OPTIONS, HttpMethod.CONNECT, HttpMethod.TRACE
        ]
        for (m in methodList) {
            match (trees.get(m)) {
                case Some(root) =>
                    let (h, _) = root.findRoute(path, None)
                    if (h.isSome()) {
                        methods.add(m.toString())
                    }
                case None => ()
            }
        }
        // 也检查组子路由器
        for (group in groups) {
            let groupMethods = group.allowedMethodsForPathLocked(path)
            if (groupMethods.size > 0) {
                for (gm in groupMethods.split(",")) {
                    let trimmed = gm.trimAscii()
                    if (trimmed.size > 0) {
                        var found = false
                        for (m in methods) {
                            if (m == trimmed) { found = true; break }
                        }
                        if (!found) { methods.add(trimmed) }
                    }
                }
            }
        }
        var result = ""
        var first = true
        for (m in methods) {
            if (first) { first = false } else { result += ", " }
            result += m
        }
        if (result.size == 0) { return "" }
        result
    }

    /**
     * 返回一个通过此路由器派发请求的 Handler，
     * 应用所有已注册的中间件。
     *
     * 这是将路由器与 HttpServer 集成的推荐方式：
     *   let server = HttpServer(handler: router.handler())
     *
     * 处理器：
     * 1. 提取 Host 头部用于虚拟主机路由
     * 2. 查找匹配的路由并提取路径参数
     * 3. 将参数存储在 req.pathParams 中供处理器访问
     * 4. 在适当时发出尾部斜杠重定向（301）
     * 5. 对不支持的方法返回 405 并带 Allow 头部
     * 6. 没有路由匹配时返回 404
     */
    public func handler(): Handler {
        let dispatchHandler: Handler = { req: HttpRequest =>
            let host = match (req.headers.get("host")) {
                case Some(h) => h
                case None => ""
            }
            let result = this.findByHost(req.method, req.path, host)

            // 诊断日志：路由匹配结果
            if (result.handler.isNone()) {
                eprintln("[Router] No route found: method=${req.method}, path=${req.path}, host=${host}")
            }

            // 尾部斜杠重定向
            if (result.tsr && result.handler.isNone()) {
                if (req.method == HttpMethod.GET || req.method == HttpMethod.HEAD) {
                    let redirectPath = if (req.path.endsWith("/")) {
                        req.path[..req.path.size - 1]
                    } else {
                        "${req.path}/"
                    }
                    let querySuffix = match (req.url.indexOf("?")) {
                        case Some(idx) => req.url[idx..]
                        case None => ""
                    }
                    return HttpResponse.redirect("${redirectPath}${querySuffix}", status: HttpStatus.MOVED_PERMANENTLY)
                }
            }

            match (result.handler) {
                case Some(h) =>
                    // 将路径参数存储在请求中供处理器访问
                    req.pathParams = result.params
                    h(req)
                case None =>
                    // 检查是否允许此路径的任何其他方法
                    let allow = this.allowedMethodsForPath(req.path)
                    if (allow.size > 0) {
                        let resp = HttpResponse.text(HttpStatus.METHOD_NOT_ALLOWED, "Method Not Allowed")
                        resp.headers.set("Allow", allow)
                        resp
                    } else {
                        HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
                    }
            }
        }
        this.middlewareChain.apply(dispatchHandler)
    }

    /**
     * 返回通过此路由器分发请求的 StreamingHandler。
     *
     * 这是 handler() 的流式版本。处理器接收
     * ResponseBuilder 进行增量写入，而不是返回 HttpResponse。
     * 标准 (HttpRequest)->HttpResponse 处理器通过 wrapHandler 自动适配。
     *
     * 处理器：
     * 1. 提取 Host 头部用于虚拟主机路由
     * 2. 查找匹配的路由并提取路径参数
     * 3. 将参数存储在 req.pathParams 中供处理器访问
     * 4. 在适当时发出尾部斜杠重定向（301）
     * 5. 对不支持的方法返回 405 并带 Allow 头部
     * 6. 没有路由匹配时返回 404
     */
    public func handlerStream(): StreamingHandler {
        let dispatchHandler: Handler = { req: HttpRequest =>
            let host = match (req.headers.get("host")) {
                case Some(h) => h
                case None => ""
            }
            let result = this.findByHost(req.method, req.path, host)

            // 尾部斜杠重定向
            if (result.tsr && result.handler.isNone()) {
                if (req.method == HttpMethod.GET || req.method == HttpMethod.HEAD) {
                    let redirectPath = if (req.path.endsWith("/")) {
                        req.path[..req.path.size - 1]
                    } else {
                        "${req.path}/"
                    }
                    let querySuffix = match (req.url.indexOf("?")) {
                        case Some(idx) => req.url[idx..]
                        case None => ""
                    }
                    return HttpResponse.redirect("${redirectPath}${querySuffix}", status: HttpStatus.MOVED_PERMANENTLY)
                }
            }

            match (result.handler) {
                case Some(h) =>
                    req.pathParams = result.params
                    h(req)
                case None =>
                    let allow = this.allowedMethodsForPath(req.path)
                    if (allow.size > 0) {
                        let resp = HttpResponse.text(HttpStatus.METHOD_NOT_ALLOWED, "Method Not Allowed")
                        resp.headers.set("Allow", allow)
                        resp
                    } else {
                        HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
                    }
            }
        }
        let wrappedHandler = this.middlewareChain.apply(dispatchHandler)
        wrapHandler(wrappedHandler)
    }
}

/**
 * 路由查找的结果。
 */
public class HandlerResult {
    public let handler: ?Handler
    public let params: HashMap<String, String>
    public let tsr: Bool  // 需要尾随斜杠重定向

    public init(handler!: ?Handler, params!: HashMap<String, String>, tsr!: Bool = false) {
        this.handler = handler
        this.params = params
        this.tsr = tsr
    }
}

// ---------- Radix 树节点 ----------

internal class Node {
    var path: String = ""
    var wildChild: Bool = false
    var nodeType: NodeType = NodeType.Static
    var maxParams: Int64 = 0
    var indices: String = ""
    var children: Array<Node> = []
    var handler: ?Handler = None
    var priority: Int64 = 0

    public init() {}

    /**
     * 添加带有给定处理器的路由。
     */
    public func addRoute(path: String, handler: Handler): Unit {
        let fullPath = path
        var n: Node = this
        var p = path
        n.priority++
        var numParams = countParams(p)

        if (n.path.size > 0 || n.children.size > 0) {
            while (true) {
                // 更新 maxParams
                if (numParams > n.maxParams) { n.maxParams = numParams }

                // 查找最长公共前缀
                var i: Int64 = 0
                let maxLen = if (p.size < n.path.size) { p.size } else { n.path.size }
                while (i < maxLen && p[i] == n.path[i]) { i++ }

                // 必要时分割边
                if (i < n.path.size) {
                    let child = Node()
                    child.path = n.path[i..]
                    child.wildChild = n.wildChild
                    child.nodeType = n.nodeType
                    child.children = n.children
                    child.indices = n.indices
                    child.handler = n.handler
                    child.priority = n.priority - 1

                    for (c in child.children) {
                        if (c.maxParams > child.maxParams) { child.maxParams = c.maxParams }
                    }

                    n.children = [child]
                    n.indices = String.fromUtf8([n.path[i]])
                    n.path = p[..i]
                    n.handler = None
                    n.wildChild = false
                }

                // 使新节点成为子节点
                if (i < p.size) {
                    p = p[i..]
                    // 分割后重新计算剩余路径的参数数量。
                    // 公共前缀可能包含 ':' 字符（例如 ':limit' 和 ':id' 的公共前缀是 ':'），
                    // 导致剩余路径 p 丢失了参数前缀，但 numParams 仍包含已消耗的参数计数。
                    // 不重新计算会导致 insertChild 中 np > 0 但路径无参数，引发越界错误。
                    numParams = countParams(p)

                    if (n.wildChild) {
                        // 遍历所有通配符子节点（Param/CatchAll），找到第一个匹配的。
                        // 支持同一位置存在多个不同名称的 Param 子节点
                        // （如 :limit/:page 和 :id 共存）。
                        // 不能假设通配符子节点在 children[0]，
                        // 因为 incrementChildPrio 可能已将静态子节点移到前面。
                        var wcMatched = false
                        for (ci in 0..n.children.size) {
                            let wc = n.children[ci]
                            if (wc.nodeType != NodeType.Param && wc.nodeType != NodeType.CatchAll) {
                                continue
                            }
                            if (p.size >= wc.path.size && wc.path == p[..wc.path.size] &&
                                (wc.path.size >= p.size || p[wc.path.size] == b'/')) {
                                // 匹配通配符子节点，进入它继续处理
                                n = wc
                                n.priority++
                                if (numParams > n.maxParams) { n.maxParams = numParams }
                                numParams--
                                wcMatched = true
                                break
                            }
                        }
                        if (wcMatched) { continue }
                        // 没有通配符子节点匹配，允许共存：
                        // 不修改 n，继续走下面的静态子节点添加逻辑。
                        // insertChild 会创建新的通配符子节点。
                    }

                    let c = p[0]

                    // 参数后的斜杠
                    if (n.nodeType == NodeType.Param && c == b'/' && n.children.size == 1) {
                        n = n.children[0]
                        n.priority++
                        continue
                    }

                    // 检查是否存在具有下一个路径字节的静态子节点。
                    // 直接遍历 children 数组而非 indices 字符串，
                    // 因为 indices 可能与 children 不同步（参数路由插入时不更新 indices）。
                    // 重要：跳过 Param/CatchAll 子节点，因为通配符子节点通过
                    // wildChild 逻辑处理。若不跳过，c=':' 会错误匹配 Param 节点
                    // （其 path 以 ':' 开头），导致 Param 节点被公共前缀分割而损坏。
                    var found = false
                    for (i2 in 0..n.children.size) {
                        let child2 = n.children[i2]
                        if (child2.nodeType == NodeType.Param || child2.nodeType == NodeType.CatchAll) {
                            continue
                        }
                        if (child2.path.size > 0 && child2.path[0] == c) {
                            n = n.children[incrementChildPrio(n, i2)]
                            found = true
                            break
                        }
                    }
                    if (found) { continue }

                    // 否则插入
                    if (c != b':' && c != b'*') {
                        let parent = n
                        let child = Node()
                        child.maxParams = numParams
                        // 注意：必须直接赋值给 n.children，不能使用成员变量 children 赋值。
                        // 因为 addRoute 是在根节点上调用，this.children 是根节点的 children，
                        // 而 n 可能已下移到子节点。若用 children = ... 会覆盖根节点的 children，
                        // 导致根节点丢失其他子节点，引发大面积 404 错误。
                        n.children = insertChildNode(n.children, child)
                        n = child
                        insertChild(n, numParams, p, fullPath, handler)
                        // insertChild 已设置 child.path，现在同步父节点索引
                        // 仅包含静态子节点的首字节，排除 Param/CatchAll 子节点，
                        // 因为通配符子节点通过 wildChild 标志处理，不参与 indices 查找。
                        var syncedIndices = ""
                        for (cn in parent.children) {
                            if (cn.path.size > 0 && cn.nodeType != NodeType.Param && cn.nodeType != NodeType.CatchAll) {
                                syncedIndices += String.fromUtf8([cn.path[0]])
                            }
                        }
                        parent.indices = syncedIndices
                        break
                    }
                    insertChild(n, numParams, p, fullPath, handler)
                    break
                } else if (i == p.size) {
                    // 使节点成为叶子
                    if (n.handler.isSome()) {
                        throw Exception("a handler is already registered for path '${fullPath}'")
                    }
                    n.handler = handler
                    break
                }
                break
            }
        } else {
            // 空树
            insertChild(n, numParams, p, fullPath, handler)
            if (numParams > n.maxParams) { n.maxParams = numParams }
            n.nodeType = NodeType.Root
        }
        // 确保每次插入后索引和子节点保持同步。
        // 仅统计静态子节点数量，因为 indices 不包含 Param/CatchAll 子节点。
        var staticChildCount = 0
        for (c in n.children) {
            if (c.nodeType != NodeType.Param && c.nodeType != NodeType.CatchAll) {
                staticChildCount++
            }
        }
        if (n.indices.size != staticChildCount) {
            var newIndices = ""
            for (c in n.children) {
                if (c.path.size > 0 && c.nodeType != NodeType.Param && c.nodeType != NodeType.CatchAll) {
                    newIndices += String.fromUtf8([c.path[0]])
                }
            }
            n.indices = newIndices
        }
    }

    /**
     * 查找给定路径的路由。
     *
     * 支持同一位置多个 Param 子节点的回溯匹配
     * （如 :limit/:page 和 :id 共存时，先尝试 :limit 子树，
     * 失败后回溯尝试 :id）。
     *
     * 路径参数仅在匹配成功后通过 valueSetter 应用，
     * 避免回溯时残留无效参数。
     */
    public func findRoute(path: String, valueSetter: ?(String, String) -> Unit): (?Handler, Bool) {
        let capacity = if (this.maxParams > 0) { this.maxParams } else { 1 }
        let buffer = ParamBuffer(capacity)
        let result = findRouteRec(this, path, buffer)
        let (matchedHandler, _) = result
        if (matchedHandler.isSome()) {
            if (let Some(fn) <- valueSetter) {
                for (i in 0..buffer.count) {
                    fn(buffer.names[i], buffer.values[i])
                }
            }
        }
        result
    }

    /**
     * 递归查找路由的内部辅助方法。
     *
     * 当通配符子节点匹配失败时，自动回溯尝试下一个通配符子节点。
     * 路径参数收集到 buffer 中，仅在成功时保留；
     * 回溯时通过恢复计数器移除已添加的参数。
     */
    private func findRouteRec(node: Node, p: String, buffer: ParamBuffer): (?Handler, Bool) {
        let n = node

        // 情况1：路径与节点路径完全匹配
        if (p == n.path) {
            if (n.handler.isSome()) {
                return (n.handler, false)
            }
            // 检查尾部斜杠重定向 (TSR)
            if (p == "/" && n.wildChild && n.nodeType != NodeType.Root) {
                return (None, true)
            }
            for (ci in 0..n.children.size) {
                let child = n.children[ci]
                if (child.nodeType != NodeType.Param && child.nodeType != NodeType.CatchAll &&
                    child.path.size > 0 && child.path[0] == b'/' &&
                    child.path.size == 1 && child.handler.isSome()) {
                    return (None, true)
                }
            }
            return (None, false)
        }

        // 情况2：路径比节点路径短 — 检查 TSR
        if (p.size < n.path.size) {
            let tsr = (p == "/") || (n.path.size == p.size + 1 && n.path[p.size] == b'/' &&
                        p == n.path[..p.size] && n.handler.isSome())
            return (None, tsr)
        }

        // 情况3：路径比节点路径长 — 检查前缀匹配
        if (!p.startsWith(n.path)) {
            return (None, false)
        }

        let remaining = p[n.path.size..]

        // 先尝试静态子节点匹配
        if (remaining.size > 0) {
            let c = remaining[0]
            for (i in 0..n.children.size) {
                let child = n.children[i]
                // 跳过通配符子节点，由后面的 wildChild 逻辑处理
                if (child.nodeType == NodeType.Param || child.nodeType == NodeType.CatchAll) {
                    continue
                }
                if (child.path.size > 0 && child.path[0] == c) {
                    let result = findRouteRec(child, remaining, buffer)
                    let (resHandler, resTsr) = result
                    if (resHandler.isSome() || resTsr) {
                        return result
                    }
                    // 静态子节点匹配失败，跳出循环继续尝试通配符
                    break
                }
            }
        }

        // 尝试通配符子节点（支持多个 Param 子节点回溯）
        if (n.wildChild) {
            var tsrCandidate = false
            for (ci in 0..n.children.size) {
                let wc = n.children[ci]
                if (wc.nodeType != NodeType.Param && wc.nodeType != NodeType.CatchAll) {
                    continue
                }

                if (wc.nodeType == NodeType.CatchAll) {
                    // CatchAll：匹配剩余全部路径
                    if (wc.children.size > 0) {
                        let catchAllNode = wc.children[0]
                        let paramName = if (catchAllNode.path.size > 2) {
                            catchAllNode.path[2..]
                        } else {
                            catchAllNode.path
                        }
                        buffer.add(paramName, remaining)
                        return (catchAllNode.handler, false)
                    }
                    continue
                }

                // Param 节点：匹配到下一个 '/' 或路径末尾
                var end: Int64 = 0
                while (end < remaining.size && remaining[end] != b'/') { end++ }

                if (end < remaining.size) {
                    // 还有剩余路径，需要在 Param 子节点的子树中继续匹配
                    if (wc.children.size > 0) {
                        let saved = buffer.add(wc.path[1..], remaining[..end])
                        let result = findRouteRec(wc.children[0], remaining[end..], buffer)
                        let (subHandler, _) = result
                        if (subHandler.isSome()) {
                            return result
                        }
                        // 回溯：恢复计数器，移除已添加的参数
                        buffer.restore(saved)
                    }
                    continue  // 尝试下一个 Param 子节点
                }

                // Param 消耗了全部剩余路径
                if (wc.handler.isSome()) {
                    buffer.add(wc.path[1..], remaining)
                    return (wc.handler, false)
                }

                // 无处理器，检查 TSR
                if (wc.children.size > 0) {
                    let tsrChild = wc.children[0]
                    if (tsrChild.path == "/" && tsrChild.handler.isSome()) {
                        // 记录 TSR 可能性，继续尝试其他 Param 子节点寻找完全匹配
                        tsrCandidate = true
                    }
                }
                continue
            }
            if (tsrCandidate) {
                return (None, true)
            }
            return (None, false)
        }

        return (None, false)
    }
}

/**
 * 路径参数缓冲区，使用固定大小数组避免 ArrayList.removeAt 不可用的问题。
 * 通过计数器实现回溯：add 返回旧计数，restore 恢复到指定计数。
 */
internal class ParamBuffer {
    var names: Array<String>
    var values: Array<String>
    var count: Int64 = 0

    public init(capacity: Int64) {
        names = Array<String>(capacity, repeat: "")
        values = Array<String>(capacity, repeat: "")
    }

    public func add(name: String, value: String): Int64 {
        let oldCount = count
        if (count < names.size) {
            names[count] = name
            values[count] = value
            count++
        }
        oldCount
    }

    public func restore(saved: Int64): Unit {
        count = saved
    }
}

internal enum NodeType {
    | Static
    | Root
    | Param
    | CatchAll

    public operator func ==(that: NodeType): Bool {
        match ((this, that)) {
            case (Static, Static) => true
            case (Root, Root) => true
            case (Param, Param) => true
            case (CatchAll, CatchAll) => true
            case _ => false
        }
    }

    public operator func !=(that: NodeType): Bool {
        !(this == that)
    }
}

private func countParams(path: String): Int64 {
    var count: Int64 = 0
    var i: Int64 = 0
    while (i < path.size) {
        if (path[i] == b':' || path[i] == b'*') {
            count++
        }
        i++
    }
    count
}

private func incrementChildPrio(n: Node, pos: Int64): Int64 {
    // 边界检查
    if (pos < 0 || pos >= n.children.size) {
        return 0
    }
    n.children[pos].priority++
    let prio = n.children[pos].priority

    var newPos = pos
    while (newPos > 0 && n.children[newPos - 1].priority < prio) {
        let tmp = n.children[newPos - 1]
        n.children[newPos - 1] = n.children[newPos]
        n.children[newPos] = tmp
        newPos--
    }

    // 重排后重建 indices 以保持同步
    // 仅包含静态子节点，排除 Param/CatchAll 子节点
    if (newPos != pos) {
        var newIndices = ""
        for (c in n.children) {
            if (c.path.size > 0 && c.nodeType != NodeType.Param && c.nodeType != NodeType.CatchAll) {
                newIndices += String.fromUtf8([c.path[0]])
            }
        }
        n.indices = newIndices
    }

    newPos
}

private func insertChildNode(children: Array<Node>, child: Node): Array<Node> {
    // 使用循环逐个复制，避免 copyTo 在不同仓颉版本中的语义差异。
    // 先用占位符创建数组，再逐个赋值，确保每个旧子节点都被正确复制。
    let newSize = children.size + 1
    let newChildren = Array<Node>(newSize, repeat: child)
    var i: Int64 = 0
    while (i < children.size) {
        newChildren[i] = children[i]
        i++
    }
    // 最后一个位置保留新 child（已在 repeat 中初始化）
    newChildren
}

private func insertChild(n: Node, numParams: Int64, path: String, fullPath: String, handler: Handler): Unit {
    var offset: Int64 = 0
    var node = n
    var np = numParams
    var i: Int64 = 0
    let max = path.size

    while (np > 0 && i < max) {
        let c = path[i]
        if (c != b':' && c != b'*') {
            i++
            continue
        }

        var end = i + 1
        while (end < max && path[end] != b'/') {
            match (path[end]) {
                case ':' | '*' =>
                    throw Exception("only one wildcard per path segment is allowed, has: '${path[i..]}' in path '${fullPath}'")
                case _ => end++
            }
        }

        if (node.children.size > 0 && !node.wildChild) {
            // 允许通配符与静态子节点共存：将现有静态子节点保留，添加通配符子节点
            // wildChild 标记为 true，findRoute 会先匹配静态再 fallback 通配符
        }

        if (end - i < 2) {
            throw Exception("wildcards must be named with a non-empty name in path '${fullPath}'")
        }

        if (c == b':') {
            // 参数
            if (i > 0) {
                node.path = path[offset..i]
                offset = i
            }

            var child = Node()
            child.nodeType = NodeType.Param
            child.maxParams = np

            // 追加通配符子节点，保留已有静态子节点
            node.children = insertChildNode(node.children, child)
            node.wildChild = true
            node = child
            node.priority++
            np--

            if (end < max) {
                node.path = path[offset..end]
                offset = end

                child = Node()
                child.maxParams = np
                child.priority = 1

                node.children = [child]
                node = child
            }
            i = end
        } else {
            // 全匹配路由
            if (end != max || np > 1) {
                throw Exception("catch-all routes are only allowed at the end of the path in path '${fullPath}'")
            }

            if (node.path.size > 0 && node.path[node.path.size - 1] == b'/') {
                throw Exception("catch-all conflicts with existing handler for the path segment root in path '${fullPath}'")
            }

            i--
            if (path[i] != b'/') {
                throw Exception("no / before catch-all in path '${fullPath}'")
            }

            node.path = path[offset..i]

            var child = Node()
            child.wildChild = true
            child.nodeType = NodeType.CatchAll
            child.maxParams = 1

            node.children = [child]
            node.indices = String.fromUtf8([path[i]])
            node = child
            node.priority++

            child = Node()
            child.path = path[i..]
            child.nodeType = NodeType.CatchAll
            child.maxParams = 1
            child.handler = handler
            child.priority = 1

            node.children = [child]
            return
        }
    }

    // 插入剩余路径和处理器
    node.path = path[offset..]
    node.handler = handler
}

/**
 * 将 {param} 和 {param:pattern} 语法转换为 radix 树的 :param 格式。
 * 例如：
 *   /users/{id}        → /users/:id
 *   /files/{name:.+}   → /files/:name
 *
 * 支持与现有 :param 语法并存的通配符模式。
 */
private func translateBraceParams(path: String): String {
    let runes = path.toRuneArray()
    var result = ArrayList<Rune>()
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'{') {
            // 查找闭合括号
            var j = i + 1
            while (j < runes.size && runes[j] != r'}') { j += 1 }
            if (j < runes.size) {
                // 提取参数名称（去掉 :pattern，如果存在）
                let inner = String(runes[i + 1..j])
                let colonIdx = inner.indexOf(":")
                let paramName = match (colonIdx) {
                    case Some(ci) => inner[..ci]
                    case None => inner
                }
                result.add(r':')
                let nameRunes = paramName.toRuneArray()
                for (r in nameRunes) { result.add(r) }
                i = j + 1
            } else {
                // 未闭合的括号 — 保持原样
                result.add(runes[i])
                i += 1
            }
        } else {
            result.add(runes[i])
            i += 1
        }
    }
    String(result.toArray())
}

/**
 * findLocked() 使用的延迟分配参数映射。
 *
 * 路径参数的 HashMap<String, String> 仅在
 * 设置第一个参数键值对时分配。对于没有参数
 * 的静态路由，这避免了不必要的分配。
 *
 * 此封装还解决了仓颉的 lambda 限制，即
 * 传递给其他函数的 lambda 无法捕获可变 (var) 变量。
 */
internal class ParamMap {
    private var inner: ?HashMap<String, String> = None

    public func set(key: String, value: String): Unit {
        match (inner) {
            case Some(map) =>
                map[key] = value
            case None =>
                let newMap = HashMap<String, String>()
                newMap[key] = value
                inner = Some(newMap)
        }
    }

    public func build(): HashMap<String, String> {
        match (inner) {
            case Some(m) => m
            case None => HashMap<String, String>()
        }
    }
}
