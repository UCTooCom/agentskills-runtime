package magic.app.core.middleware

import magic.app.core.http.{HttpRequest, HttpResponse}
import std.collection.ArrayList

public interface Middleware {
    func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit
}

public class MiddlewareChain {
    private var middlewares: ArrayList<Middleware> = ArrayList<Middleware>()

    public init() {}

    public func use(middleware: Middleware): MiddlewareChain {
        middlewares.add(middleware)
        return this
    }

    public func execute(req: HttpRequest, res: HttpResponse, finalHandler: () -> Unit): Unit {
        eprintln("=== MiddlewareChain.execute: ${middlewares.size} middlewares ===")
        executeRecursive(req, res, finalHandler, 0)
    }

    private func executeRecursive(req: HttpRequest, res: HttpResponse, finalHandler: () -> Unit, index: Int64): Unit {
        eprintln("=== executeRecursive: index=${index}, size=${middlewares.size} ===")
        if (index >= middlewares.size) {
            eprintln("=== All middlewares done, calling finalHandler ===")
            finalHandler()
            return
        }

        let middleware = middlewares[index]
        eprintln("=== Calling middleware ${index} ===")
        let next = { => executeRecursive(req, res, finalHandler, index + 1) }
        middleware.handle(req, res, next)
        eprintln("=== Middleware ${index} returned ===")
    }
}
