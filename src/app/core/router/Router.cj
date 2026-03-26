package magic.app.core.router

import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.core.middleware.Middleware
import std.collection.HashMap
import std.collection.ArrayList

public class Route {
    public var method: HttpMethod = HttpMethod.GET
    public var path: String = ""
    public var handler: (HttpRequest, HttpResponse) -> Unit
    public var middlewares: ArrayList<Middleware> = ArrayList<Middleware>()
    
    public init() {
        handler = { req, res => res.status(404).send("Not Found") }
    }
    
    public init(
        method: HttpMethod,
        path: String,
        handler: (HttpRequest, HttpResponse) -> Unit
    ) {
        this.method = method
        this.path = path
        this.handler = handler
    }
    
    public func use(middleware: Middleware): Route {
        middlewares.add(middleware)
        return this
    }
}

public class Router {
    private var routes: ArrayList<Route> = ArrayList<Route>()
    private var middlewareChain: ArrayList<Middleware> = ArrayList<Middleware>()
    
    public init() {}
    
    public func use(middleware: Middleware): Router {
        middlewareChain.add(middleware)
        return this
    }
    
    public func get(path: String, handler: (HttpRequest, HttpResponse) -> Unit): Router {
        routes.add(Route(HttpMethod.GET, path, handler))
        return this
    }
    
    public func post(path: String, handler: (HttpRequest, HttpResponse) -> Unit): Router {
        routes.add(Route(HttpMethod.POST, path, handler))
        return this
    }
    
    public func put(path: String, handler: (HttpRequest, HttpResponse) -> Unit): Router {
        routes.add(Route(HttpMethod.PUT, path, handler))
        return this
    }
    
    public func delete(path: String, handler: (HttpRequest, HttpResponse) -> Unit): Router {
        routes.add(Route(HttpMethod.DELETE, path, handler))
        return this
    }
    
    public func `match`(req: HttpRequest): ?Route {
        for (route in routes) {
            if (matchRoute(route, req)) {
                return route
            }
        }
        return None<Route>
    }
    
    public func findRoute(method: HttpMethod, path: String): ?Route {
        for (route in routes) {
            if (isSameMethod(route.method, method) && route.path == path) {
                return route
            }
        }
        return None<Route>
    }

    private func isSameMethod(a: HttpMethod, b: HttpMethod): Bool {
        return a.level() == b.level()
    }

    private func matchRoute(route: Route, req: HttpRequest): Bool {
        if (!isSameMethod(route.method, req.method)) {
            return false
        }

        return matchPath(route.path, req.uri.path, req)
    }

    private func matchPath(pattern: String, path: String, req: HttpRequest): Bool {
        let patternParts = pattern.split("/")
        let pathParts = path.split("/")

        if (patternParts.size != pathParts.size) {
            return false
        }

        for (i in 0..patternParts.size) {
            let patternPart = patternParts[i]
            let pathPart = pathParts[i]

            if (patternPart.startsWith(":")) {
                let paramName = patternPart[1..]
                req.pathParams[paramName] = pathPart
            } else if (patternPart != pathPart) {
                return false
            }
        }

        return true
    }
    
    public func getMiddlewareChain(): ArrayList<Middleware> {
        return middlewareChain
    }
    
    public func getRoutes(): ArrayList<Route> {
        return routes
    }
}
