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

public class RequestMeta <: HttpRequestHandler & ToString & Comparable<RequestMeta> {
    private static let log = LoggerFactory.getLogger<RequestMeta>()
    static let currentResponseStatus = ThreadLocal<UInt16>()
    static func setResponseStatus(status: HttpStatus) {
        currentResponseStatus.set(status.value)
    }
    private static func getResponseStatus(): UInt16 {
        match (currentResponseStatus.get()) {
            case Some(c) => c
            case _ => HttpStatus.OK.value
        }
    }
    private var ignoreAuth_ = false
    private var ignorePrivilege_ = false

    private let produces = HashSet<String>()
    private let consumes = HashSet<String>()

    private let args = RequestArgMeta()

    var pattern = None<HttpRequestPathPatterns>

    RequestMeta(
        public let path: String,
        public let method: RequestMethod,
        private let params!: RequestCondition = DummyRequestCondition.instance,
        private let headers!: RequestCondition = DummyRequestCondition.instance
    ) {}

    public func compare(other: RequestMeta): Ordering {
        var cmp = path.compare(other.path)
        if (cmp == Ordering.EQ) {
            cmp = method.compare(other.method)
        }
        if (cmp == Ordering.EQ) {
            let tree1 = TreeSet<String>(consumes).iterator()
            let tree2 = TreeSet<String>(other.consumes).iterator()
            while (cmp == Ordering.EQ && let Some(c1) <- tree1.next() && let Some(c2) <- tree2.next()) {
                cmp = c1.compare(c2)
            }
        }
        if (cmp == Ordering.EQ) {
            cmp = consumes.size.compare(other.consumes.size)
        }
        return cmp
    }
    public func toString(): String {
        'path: ${path}; method: ${method}; consumes: ${consumes}; consumesSize: ${consumes.size}'
    }

    private var handle_: (HttpContext) -> Unit = {
        ctx: HttpContext => throw MVCException('Request was not handled')
    }

    public func handle(ctx: HttpContext): Unit {
        handle_(ctx)
    }

    private func populateResponseContentType(ctx: HttpContext) {
        let accept = if (let Some(accept) <- ctx.request.headers.getFirst('Accept')) {
            accept
        } else {
            '*/*'
        }
        ctx.responseBuilder.header('Content-Type', accept)
    }
    public prop ignoreAuth: Bool {
        get() {
            ignoreAuth_
        }
    }
    public prop ignorePrivilege: Bool {
        get() {
            ignorePrivilege_
        }
    }
    internal func iterateConsumes(fn: (String) -> Unit): Unit {
        for (c in consumes) {
            fn(c)
        }
    }
    private func checkHeader(ctx: HttpContext, headers: HashSet<String>, name: String): Bool {
        headers.isEmpty() || headers.contains(ctx.request.headers.getFirst(name) ?? '') || headers.contains('*/*') ||
            headers.contains("*") || headers.contains('')
    }
    public func checkProduces(ctx: HttpContext) {
        if (let Some(accept) <- ctx.request.headers.getFirst('Accept')) {
            accept.isEmpty() || accept == '*' || accept == '*/*' || produces.contains(accept) || if (accept
                .indexOf(',')
                .isSome()) {
                let priority = AcceptQueue(accept)
                while (let Some((q, idx, c)) <- priority.remove()) {
                    log.debug {'RequestMeta.checkProduces.MultiAccept:${q};${idx};${c}'}
                    if (c.startsWith('*/*') || produces.contains(c)) {
                        ctx.request.headers.set('Accept', c)
                        return true
                    }
                }
                false
            } else {
                false
            }
        } else {
            true
        }
    }

    public func check(ctx: HttpContext): Bool {
        let request = ctx.request
        this.headers.check(request.headers) && this.params.check(request.form, request.url)
    }
    public func setHandle<T>(fn: (T, HttpContext, HttpRequestPathPatterns) -> Any): Unit where T <: Object {
        let pattern = this.pattern.getOrThrow()
        this.handle_ = {
            ctx =>
                let result = try {
                    CurrentHttpContext.set(ctx)
                    fn(BeanFactory.instance.getFirst<T>().getOrThrow(), ctx, pattern)
                } finally {
                    CurrentHttpContext.clear()
                }
                match (result) {
                    case x: JsonValue => respond(x, ctx)
                    case x: InputStream => respond(x, ctx)
                    case x: Array<Byte> => respond(x, ctx)
                    case _: Unit => ()
                    case x: ToData => respond(x, ctx)
                    case _ =>
                        let request = ctx.request
                        log.warn {'fountain.mvc.handle ${request.method}:${request.url};${TypeInfo.of(result)}'}
                        MultiRequestMethodHandler.NOT_ACCEPTABLE.handle(ctx)
                }
        }
    }
    public func checkAuth(ctx: HttpContext, args: ArrayList<Any>): Bool {
        let checked = if (ignoreAuth && ignorePrivilege) {
            return true
        } else {
            AuthHandlerProxy.instance.check(AuthParam(ctx, path, args, ignoreAuth, ignorePrivilege))
        }
        let (check, status, resp) = match (checked) {
            case OK => return true
            case SessionNotFound(status, resp) => ('SessionNotFound', status, resp)
            case SessionNotFound(resp) => ('SessionNotFound', HttpStatus.OK, resp)
            case InvalidSession(status, resp) => ('InvalidSession', status, resp)
            case InvalidSession(resp) => ('InvalidSession', HttpStatus.OK, resp)
            case SessionError(status, resp) => ('SessionError', status, resp)
            case SessionError(resp) => ('SessionError', HttpStatus.OK, resp)
            case PrivilegeError(status, resp) => ('PrivilegeError', status, resp)
            case PrivilegeError(resp) => ('PrivilegeError', HttpStatus.OK, resp)
            case NoPrivilege(status, resp) => ('NoPrivilege', status, resp)
            case NoPrivilege(resp) => ('NoPrivilege', HttpStatus.OK, resp)
        }
        setResponseStatus(status)
        let accept = ctx.request.headers.getFirst('Accept') ?? '*/*'
        let builder = ctx.responseBuilder.status(status.value).header('Content-Type', accept)
        func respondStatusReasonPhrase() {
            builder.body(if (status == HttpStatus.OK) {
                HttpStatus.UNAUTHORIZED.reasonPhrase
            } else {
                status.reasonPhrase
            })
        }
        log.warn {
            'fountain.mvc.check ${this}; accept: ${accept}; status: ${status.value}; CheckHandler returns ${TypeInfo.of(resp)}; checked: ${check}'
        }
        match (resp) {
            case x: String => builder.body(x)
            case x: Array<Byte> => builder.body(x)
            case x: InputStream => builder.body(x)
            case x: ToString => builder.body(x.toString())
            case x: ToData where accept != '*/*' => match (MediaTypes.tryParse(accept)) {
                case Some(mt) => builder.body(mt.fromData(x.toData()))
                case _ => respondStatusReasonPhrase()
            }
            case _ => respondStatusReasonPhrase()
        }
        false
    }
    func setHandle<T>(wsmeta: WSMeta<T>) where T <: Object {
        this.handle_ = {
            ctx => wsmeta.handle(BeanFactory.instance.getFirst<T>().getOrThrow(), ctx, pattern.getOrThrow())
        }
        produces.add('*')
        consumes.add('*')
    }
    private func respond(method: String, fn: () -> Unit): Unit {
        try {
            fn()
        } finally {
            OverallStopwatch.elapsed(method)
        }
    }
    private func respond<R>(result: R, ctx: HttpContext): Unit where R <: ToData {
        respond(ctx.request.method) {
            let accept = ctx.request.headers.getFirst('Accept')
            if (!(result is Unit) && let Some(accept) <- accept) {
                if (let Some(mediaType) <- MediaTypes.tryParse(accept)) {
                    let bytes = mediaType.fromData(result.toData())
                    ctx.responseBuilder.header('Content-Type', accept).body(bytes)
                } else if (accept == '*/*') {
                    let acc = this.produces.iterator().next() ?? 'application/json'
                    let mt = MediaTypes.parse(acc)
                    let bytes = mt.fromData(result.toData())
                    ctx.responseBuilder.header('Content-Type', acc).body(bytes)
                } else {
                    if (let r: Resource <- result) {
                        try {
                            r.close()
                        } catch (e: Exception) {
                            log.warn(e){'Error occurred on closing ${TypeInfo.of(result)}; path: ${path}; accept: ${accept}'}
                        }
                    }
                    MultiRequestMethodHandler.NOT_ACCEPTABLE.handle(ctx)
                }
            } else if ((result is Unit) && let Some(accept) <- accept && accept == '*/*') {
                ctx.responseBuilder.header('Content-Type', accept).body('')
            } else if ((result is Unit) && accept.isNone()) {
                ctx.responseBuilder.body('')
            } else {
                MultiRequestMethodHandler.NOT_ACCEPTABLE.handle(ctx)
            }
        }
    }
    private func respond(response: JsonValue, ctx: HttpContext): Unit {
        respond(ctx.request.method) {
            if (let Some(accept) <- ctx.request.headers.getFirst('Accept')) {
                if (let Some(mediaType) <- MediaTypes.tryParse(accept) && let jmt: JsonMediaType <- mediaType) {
                    let bytes = jmt.fromData(response)
                    ctx.responseBuilder.header('Content-Type', accept).body(bytes)
                } else if (accept == '*/*') {
                    ctx.responseBuilder.header('Content-Type', 'application/json').body(response.toString())
                } else {
                    MultiRequestMethodHandler.NOT_ACCEPTABLE.handle(ctx)
                }
            } else {
                ctx.responseBuilder.header('Content-Type', 'application/json').body(response.toString())
            }
        }
    }
    private func respond(response: InputStream, ctx: HttpContext): Unit {
        respond(ctx.request.method) {
            populateResponseContentType(ctx)
            ctx.responseBuilder.body(response)
        }
    }
    private func respond(response: Array<Byte>, ctx: HttpContext): Unit {
        respond(ctx.request.method) {
            populateResponseContentType(ctx)
            ctx.responseBuilder.body(response)
        }
    }
    private func respond(response: String, ctx: HttpContext): Unit {
        respond(ctx.request.method) {
            populateResponseContentType(ctx)
            ctx.responseBuilder.body(response.unsafeBytes())
        }
    }
    public func isMultipart(name: String) {
        args[name] is MultipartFormData
    }

    public func extract<T, P>(ctx: HttpContext, name: String, default: ?P): T where P <: DataFields<P> {
        match (default) {
            case _: ?HttpContext => (ctx as T).getOrThrow()
            case _: ?HttpRequest => (ctx.request as T).getOrThrow()
            case _: ?HttpHeaders => (ctx.request.headers as T).getOrThrow()
            case _: ?HttpResponseBuilder => (ctx.responseBuilder as T).getOrThrow()
            case _: ?Array<Byte> => (this.extractBytes(ctx) as T).getOrThrow()
            case _: ?Form => (ctx.request.form as T).getOrThrow()
            case _ => match (default) {
                case Some(d: P) =>
                    let val = args.extract<P>(ctx, name, d, pattern)
                    if (let x: T <- val) {
                        x
                    } else if (let x: T <- Some(val)) {
                        x
                    } else {
                        throw UnreachableException()
                    }
                case _ =>
                    let val = args.extract<P>(ctx, name, pattern)
                    match (val) {
                        case x: T => x
                        case Some(x: T) => x
                        case _ => throw HttpRequestException(
                            'NO param for controller func, which request param name is ${name}')
                    }
            }
        }
    }

    public func extractBytes(ctx: HttpContext): Array<Byte> {
        let buf = ByteBuffer()
        copy(ctx.request.body, to: buf)
        buf.bytes()
    }
    private func addMediaTypes(set: HashSet<String>, types: Array<String>, allowAny: Bool, allowEmpty: Bool): Unit {
        if (types.isEmpty()) {
            if (!allowEmpty) {
                throw IllegalArgumentException('mime type must not be empty string')
            }
            set.add('')
            return
        }
        for (t in types) {
            match (t.trimAscii()) {
                case '*' | '*/*' where !allowAny => throw IllegalArgumentException(
                    "Invalid mime type: ${t} in ${types.toString().replace(', ', '|').replace('[', '').replace(']', '')}")
                case '*' | '*/*' =>
                    set.add('*')
                    set.add('*/*')
                case '' where !allowEmpty => throw IllegalArgumentException(
                    "mime type must not be empty string in ${types.toString().replace(', ', '|').replace('[', '').replace(']', '')}")
                case x => set.add(x)
            }
        }
    }
    private func addMediaTypes(set: HashSet<String>, types: String, allowAny: Bool, allowEmpty: Bool): Unit {
        addMediaTypes(set, types.split("|"), allowAny, allowEmpty)
    }
    private func addProduces(types: String) {
        addMediaTypes(produces, types, true, false)
    }
    private func addConsumes(types: String) {
        addMediaTypes(consumes, types, false, true)
    }
    public static func generate<T>(fnName: String, argTypes: Array<TypeInfo>): ArrayList<RequestMeta> where T <: Object {
        let typeInfo = TypeInfo.of<T>()
        let metas = ArrayList<RequestMeta>()
        let function = typeInfo.getInstanceFunction(fnName, argTypes)
        let functionParamMap = HashMap<String, ParameterInfo>()
        for (param in function.parameters) {
            functionParamMap[param.name] = param
        }
        let args = HashMap<String, (ControllerFuncParam, Validator, ?AbstractDateTimeConverter)>()
        let zero = unsafeZeroValue<ControllerFuncParam>()
        for (param in function.parameters) {
            let pname = param.name
            var toThrow = true
            for (annotation in param.annotations) {
                match (annotation) {
                    case x: ControllerFuncParam => match (args.get(pname)) {
                        case Some((p, v, c)) where refEq(p, zero) =>
                            args[pname] = (x, v, c)
                            toThrow = false
                            break
                        case None =>
                            args[pname] = (x, DummyValidator.instance, None<AbstractDateTimeConverter>)
                            toThrow = false
                        case _ => throw UnreachableException()
                    }
                    case x: Validator => match (args.get(pname)) {
                        case Some((p, v, c)) where v is DummyValidator =>
                            args[pname] = (p, x, c)
                            toThrow = false
                            break
                        case None => args[pname] = (zero, x, None<AbstractDateTimeConverter>)
                        case _ => throw UnreachableException()
                    }
                    case x: AbstractDateTimeConverter => match (args.get(pname)) {
                        case Some((p, v, c)) where c.isNone() =>
                            args[pname] = (p, v, x)
                            toThrow = false
                            break
                        case None => args[pname] = (zero, DummyValidator.instance, x)
                        case _ => throw UnreachableException()
                    }
                    case _ => continue
                }
            }
            if (toThrow) {
                throw MVCException(
                    'parameter of controller function must be with one and only one Annotation as @RequestBody or @RequestParam or @RequestHeader or @PathVariable or @MultipartFormData')
            }
        }
        let ignoreSecurity = function.findAnnotation<IgnoreSecurity>().isSome()
        let ignoreAuthGlobal = ignoreSecurity || function.findAnnotation<IgnoreAuth>().isSome()
        let ignorePrivilegeGlobal = ignoreSecurity || function.findAnnotation<IgnorePrivilege>().isSome()
        for (annotation in function.annotations) {
            if (let a: RequestMapping <- annotation) {
                let method = a.method
                let ignoreAuth = a.ignoreAuth || ignoreAuthGlobal
                let ignorePrivilege = a.ignorePrivilege || ignorePrivilegeGlobal
                let params = RequestCondition.compile(a.params)
                let headers = RequestCondition.compile(a.headers)
                for (path in a.path.split('|')) {
                    let meta = RequestMeta(path, method, params: params, headers: headers)
                    meta.addProduces(a.produces)
                    meta.addConsumes(a.consumes)
                    meta.ignoreAuth_ = ignoreAuth
                    meta.ignorePrivilege_ = ignorePrivilege
                    meta.args.add(all: args)
                    RequestMetas.instance.add(meta)
                    metas.add(meta)
                }
            }
        }
        metas
    }
    public func accessLog<T>(start: MonoTime, ctx: HttpContext, args: ArrayList<Any>, returned: ?Any, e: ?Exception) where T <: Object {
        func anyToString(any: Any) {
            let arg = match (any) {
                case x: HttpContext => x
                case x: HttpRequest => x
                case x: HttpHeaders => x
                case x: HttpResponseBuilder => x
                case x: Form => return x.toEncodeString()
                case x: String => return x
                case x: ToString => return x.toString()
                case x: Array<Byte> => return toBase64String(x)
                case x: ToData => return JsonValue.tryFromData(x.toData()).toString()
                case x => x
            }
            TypeInfo.of(arg).toString()
        }
        let request = ctx.request
        let argGen = StringGenerator().append('[')
        for (arg in args) {
            if (argGen.size > 1) {
                argGen.append(',')
            }
            let s = anyToString(arg)
            argGen.append(s)
        }
        argGen.append(']')
        let result = match (returned) {
            case Some(x) => anyToString(x)
            case _ => 'None'
        }
        let log = LoggerFactory.getLogger<T>()
        func logContent(){
            'MVC.accessLog:${request.method}:${request.url}?${request.form.toEncodeString()}; consumes:${request.headers.getFirst('Content-Type')}; params:${argGen}; returned:${result}; status:${getResponseStatus()}; elapsed:${MonoTime.now() - start}'
        }
        if (let Some(ex) <- e) {
            let exce = try {
                MultiRequestMethodHandler.INTERNAL_SERVER_ERROR.handle(ctx, ex)
                ex
            } catch (e: Exception) {
                let status = HttpStatus.INTERNAL_SERVER_ERROR
                let b = ctx.responseBuilder
                b.status(status.value)
                b.body(status.reasonPhrase)
                setResponseStatus(status)
                let mvcex = MVCException(e)
                mvcex.addSuppressed(ex)
                mvcex
            }
            log.error(exce, logContent)
        } else {
            log.info(logContent)
        }
    }
}
