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

public class MultiRequestMethodHandler <: HttpRequestHandler {
    private static let log = LoggerFactory.getLogger<MultiRequestMethodHandler>()
    static let NOT_ACCEPTABLE = HttpStatusOnlyHandler(HttpStatus.NOT_ACCEPTABLE)
    private static let METHOD_NOT_ALLOWED = HttpStatusOnlyHandler(HttpStatus.METHOD_NOT_ALLOWED)
    private static let UNSUPPORTED_MEDIA_TYPE = HttpStatusOnlyHandler(HttpStatus.UNSUPPORTED_MEDIA_TYPE)
    private static let NOT_IMPLEMENTED = HttpStatusOnlyHandler(HttpStatus.NOT_IMPLEMENTED)
    static let INTERNAL_SERVER_ERROR = HttpStatusOnlyHandler(
        HttpStatus.INTERNAL_SERVER_ERROR, 
        message: MVCConfig.getInternalServerErrorMessage(),
        kind: MVCConfig.getInternalServerErrorMessageKind())

    private static let accessControlAllowHeaders: String = MVCConfig.accessControlAllowHeaders
    private static let accessControlAllowOrigin: String = MVCConfig.accessControlAllowOrigin
    private static let accessControlMaxAge: Int64 = MVCConfig.accessControlMaxAge

    MultiRequestMethodHandler(private let patterns: HttpRequestPathPatterns) {}

    private let metas = HashMap<RequestMethod, HashMap<String, RequestMeta>>() //注册时已使用Mutex同步，不必使用ConcurrentHashMap
    private static let mutex = Mutex()
    func register(meta: RequestMeta): Unit {
        synchronized(mutex) {
            meta.pattern = patterns
            log.debug{'MVC.register meta:${meta}; methodRegistered:${metas.contains(meta.method)}'}
            let map = metas.computeIfAbsent(meta.method){HashMap<String, RequestMeta>()}
            meta.iterateConsumes {
                c => 
                log.debug{'MVC.register meta:${meta}; methodRegistered:${metas.contains(meta.method)}; consumesRegistered:${c},${map.contains(c)}'}
                if (let Some(m) <- map.addIfAbsent(c, meta)) {
                    let msg = 'duplicate RequestMeta, method: ${meta.method}, path: ${meta.path}, consumes: ${c}, registered: ${m}'
                    log.warn(msg)
                    throw MVCException(msg)
                } else {
                    log.debug{'RequestMeta registered: ${c} ${meta}'}
                }
            }
        }
    }

    public func handle(ctx: HttpContext): Unit {
        let request = ctx.request
        let headers = request.headers
        let consumes = headers.getFirst('Content-Type') ?? ''
        let method = RequestMethod.parse(request.method)
        func check(meta: RequestMeta): HttpRequestHandler {
            if (!meta.checkProduces(ctx)) {
                NOT_ACCEPTABLE
            } else if (!meta.check(ctx)) {
                NOT_IMPLEMENTED
            } else {
                meta
            }
        }
        func check(metas: HashMap<String, RequestMeta>): HttpRequestHandler {
            if (let Some(m) <- metas.get(consumes) && let h <- check(m)) {
                h
            } else {
                UNSUPPORTED_MEDIA_TYPE
            }
        }
        func handle(ms: HashMap<String, RequestMeta>): Unit {
            check(ms).handle(ctx)
        }
        log.debug{'fountain mvc ${request.method}: ${request.url}'}
        match ((metas.get(method), method)) {
            case (Some(ms), OPTIONS) => check(ms).handle(ctx)
            case (_, OPTIONS) =>
                let allow = StringGenerator()
                allow.append(method)
                let last = metas.size
                for ((method, _) in metas) {
                    allow.append(", ")
                    allow.append(method)
                }
                let allows = allow.toString()
                let resp = ctx.responseBuilder
                resp.header("Access-Control-Allow-Method", allows).header("Allow", allows)
                if (!accessControlAllowHeaders.isEmpty()) {
                    resp.header("Access-Control-Allow-Headers", accessControlAllowHeaders)
                }
                if (!accessControlAllowOrigin.isEmpty()) {
                    resp.header("Access-Control-Allow-Origin", accessControlAllowOrigin)
                }
                if (accessControlMaxAge > 0) {
                    resp.header("Access-Control-Max-Age", accessControlMaxAge.toString())
                }
            case (Some(m), HEAD) => match (metas.get(RequestMethod.GET)) {
                case Some(ms) => handle(ms)
                case _ => METHOD_NOT_ALLOWED.handle(ctx)
            }
            case (Some(ms), _) => handle(ms)
            case _ => METHOD_NOT_ALLOWED.handle(ctx)
        }
    }
}

class HttpStatusOnlyHandler <: HttpRequestHandler {
    HttpStatusOnlyHandler(private let status: HttpStatus, private let message!: String = '', private let kind!: FailureMessageKind = Text) {}
    
    public func handle(ctx: HttpContext): Unit {
        handle(ctx, None<Exception>)
    }
    public func handle(ctx: HttpContext, ex: ?Exception): Unit {
        func setStatus(){
            let b = ctx.responseBuilder.status(status.value)
            RequestMeta.setResponseStatus(status)
            if(let Some(accept) <- ctx.request.headers.getFirst("Accept")) {
                b.header("Content-Type", accept)
            }
            b
        }
        match(kind){
            case Bean => if(message.size > 0 && let Some(x) <- BeanFactory.instance.getFirst<ErrorHttpRequestHandler>(cond: Exactly(message))){
                let (status, resp) = x.handle(ctx, ex)
                if(resp is Unit){
                    return
                }
                RequestMeta.setResponseStatus(status)
                let b = ctx.responseBuilder.status(status.value)
                var accept = ''
                if(let Some(acc) <- ctx.request.headers.getFirst('Accept')) {
                    b.header("Content-Type", acc)
                    accept = acc
                }
                match(resp){
                    case x: String => b.body(x)
                    case x: ToString => b.body(x.toString())
                    case x: InputStream => b.body(x)
                    case x: Array<Byte> => b.body(x)
                    case x: ToData where accept.size > 0 => 
                        if(accept.isEmpty() || accept.contains('*/*')){
                            b.body(MediaTypes.parse('application/json').fromData(x.toData()))
                        }else if(accept.indexOf(',').isSome()){
                            let queue = AcceptQueue(accept)
                            while(let Some((_, _, accept)) <- queue.remove()){
                                if(let Some(mt) <- MediaTypes.tryParse(accept)){
                                    b.body(mt.fromData(x.toData()))
                                    return
                                }
                            }
                            b.body(x.toData().toString())
                        }else if (let Some(mt) <- MediaTypes.tryParse(accept)){
                            b.body(mt.fromData(x.toData()))
                        }else{
                            b.body(MediaTypes.parse('application/json').fromData(x.toData()))
                        }
                    case _ => b.body(status.reasonPhrase)
                }
            } else {
                setStatus().body(status.reasonPhrase)
            }
            case Text => setStatus().body(if (message.isEmpty()) {
                status.reasonPhrase
            } else {
                message
            })
            case Base64Binary => if(message.size > 0 && let Some(x) <- fromBase64String(message)){
                setStatus().body(x)
            }else{
                setStatus().body(status.reasonPhrase)
            }
        }
    }
}
