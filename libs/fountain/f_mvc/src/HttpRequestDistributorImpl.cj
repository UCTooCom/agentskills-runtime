/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_mvc

abstract sealed class HttpRequestPathPatterns <: HttpRequestDistributor {
    private let patterns = PathPattern()

    public func extract(path: String, name: String): ?String {
        patterns.extractVariableInPath(path, name)
    }
    private func register(meta: RequestMeta): Unit {
        patterns.compileIfAbsent<MultiRequestMethodHandler>(meta.path) {
            MultiRequestMethodHandler(this)
        }.register(meta)
    }
    func register(metas: ArrayList<RequestMeta>) {
        for (meta in metas) {
            register(meta)
        }
        metas
    }
    func register<T>(path: String, meta: WSMeta<T>): WSMeta<T> where T <: Object {
        let requestMeta = RequestMeta(path, RequestMethod.WS)
        requestMeta.pattern = this
        requestMeta.setHandle(meta)
        register(requestMeta)
        meta
    }
    func getHandler(path: String) {
        patterns.data<HttpRequestHandler>(path)
    }
}
class HttpRequestDistributorImpl <: HttpRequestPathPatterns {
    static let instance = HttpRequestDistributorImpl()
    private static let NOT_FOUND = NotFoundHandler()
    private init() {}
    public func register(path: String, handler: HttpRequestHandler): Unit {
        throw MVCException("func register(String, HttpRequestHandler): Unit is not implemented")
    }
    public func register(path: String, handler: (HttpContext) -> Unit): Unit {
        throw MVCException("func register(String, (HttpContext) -> Unit): Unit is not implemented")
    }

    public func distribute(path: String): HttpRequestHandler {
        OverallStopwatch.doStart(path)
        let handler = getHandler(path)
        match (handler) {
            case Some(h) => h
            case _ => NOT_FOUND
        }
    }

    func generateAndRegister<T>(fnName: String, argTypes: Array<TypeInfo>): ArrayList<RequestMeta> where T <: Object {
        let metas = RequestMeta.generate<T>(fnName, argTypes)
        register(metas)
    }
    func generateAndRegisterWSEndPoint<T>(path: String): WSMeta<T> where T <: Object {
        let meta = WSMeta<T>.generate()
        register<T>(path, meta)
    }
}
