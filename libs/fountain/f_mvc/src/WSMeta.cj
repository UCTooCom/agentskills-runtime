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

sealed abstract class WSFuncMeta<T> {
    WSFuncMeta(public let name: String, public let mediaType: String, public let responseFrameType: ?WebSocketFrameType){}
    let args = RequestArgMeta()
    var handle = {_: T, _: HttpContext, _: HttpRequestPathPatterns, _: WebSocket, _: Array<Byte> => Array<Byte>()}

    public func setHandle<R>(handle: (T, HttpContext, HttpRequestPathPatterns, WebSocket, Array<Byte>) -> R): Unit where R <: DataFields<R> {
        this.handle = {endpoint, ctx, pattern, ws, payload =>
            let r = handle(endpoint, ctx, pattern, ws, payload)
            if(mediaType.isEmpty()){
                match(r){
                    case x: Array<Byte> => x
                    case _ => []
                }
            }else{
                MediaTypes.parse(mediaType).fromDataFields<R>(r)
            }
        }
    }
    public func extract<T>(ctx: HttpContext, name: String, converter: ?AbstractDateTimeConverter, pattern: HttpRequestPathPatterns, ws: WebSocket, payload: Array<Byte>): ?T where T <: DataFields<T> {
        match(args[name]){
            case x: WSDataFrame => x.extract<T>(payload)
            case x => x.extract<T>(name, converter, ctx, pattern, DummyValidator.instance)
        }
    }
}
public class WSOpenMeta<T> <: WSFuncMeta<T> {
    init(name: String){
        super(name, '', None<WebSocketFrameType>)
    }
}
public class WSCloseMeta<T> <: WSFuncMeta<T> {
    init(name: String){
        super(name, '', WebSocketFrameType.CloseWebFrame)
    }
}
public class WSTextMeta<T> <: WSFuncMeta<T> {
    init(name: String, mediaType: String, responseFrameType: WebSocketFrameType){
        super(name, mediaType, responseFrameType)
    }
}
public class WSBinaryMeta<T> <: WSFuncMeta<T> {
    init(name: String, mediaType: String, responseFrameType: WebSocketFrameType){
        super(name, mediaType, responseFrameType)
    }
}
public class WSPingMeta<T> <: WSFuncMeta<T> {
    init(name: String, mediaType: String){
        super(name, mediaType, WebSocketFrameType.PongWebFrame)
    }
}
public class WSPongMeta<T> <: WSFuncMeta<T> {
    init(name: String, mediaType: String){
        super(name, mediaType, None<WebSocketFrameType>)
    }
}
public class WSPingFunc<T> <: WSFuncMeta<T> {
    var duration = Duration.Zero
    init(name: String, mediaType: String){
        super(name, mediaType, WebSocketFrameType.PingWebFrame)
    }
}

public class WSMeta<T> where T <: Object {
    private let log = LoggerFactory.getLogger<WSMeta<T>>()
    var pattern = None<HttpRequestPathPatterns>
    private var openMeta_ = None<WSOpenMeta<T>>
    private var closeMeta_ = None<WSCloseMeta<T>>
    private var textMeta_ = None<WSTextMeta<T>>
    private var binaryMeta_ = None<WSBinaryMeta<T>>
    private var pingMeta_ = None<WSPingMeta<T>>
    private var pongMeta_ = None<WSPongMeta<T>>
    private var pingFunc_ = None<WSPingFunc<T>>

    var handle = {_:T, _: HttpContext, _: HttpRequestPathPatterns => ()}

    public func setHandle(fn: (T, HttpContext, HttpRequestPathPatterns) -> Unit): Unit {
        handle = fn
    }

    public prop openMeta: ?WSOpenMeta<T> {
        get(){
            openMeta_
        }
    }
    public prop closeMeta: ?WSCloseMeta<T> {
        get(){
            closeMeta_
        }
    }
    public prop textMeta: ?WSTextMeta<T> {
        get(){
            textMeta_
        }
    }
    public prop binaryMeta: ?WSBinaryMeta<T> {
        get(){
            binaryMeta_
        }
    }
    public prop pingMeta: ?WSPingMeta<T> {
        get(){
            pingMeta_
        }
    }
    public prop pongMeta: ?WSPongMeta<T> {
        get(){
            pongMeta_
        }
    }
    public prop pingFunc: ?WSPingFunc<T> {
        get(){
            pingFunc_
        }
    }

    public func upgrade(ctx: HttpContext, 
                        subProtocols!: Array<String> = [],
                        origins!: Array<String> = [],
                        userFunc!: (HttpRequest) -> HttpHeaders = {_ => HttpHeaders()}): WebSocket{
        WebSocket.upgradeFromServer(ctx, 
                                    subProtocols: ArrayList<String>(subProtocols), 
                                    origins: ArrayList<String>(origins),
                                    userFunc: userFunc)
    }
    public static func writeText<T>(ws: WebSocket, data: T, mediaType!: String): Unit where T <: DataFields<T> {
        ws.write(TextWebFrame, MediaTypes.parse(mediaType).fromDataFields(data))
    }
    public static func writeText(ws: WebSocket, data: String, charset!: Charset): Unit {
        ws.write(TextWebFrame, charset.newEncoder().encode(data))
    }
    public static func writeBinary<T>(ws: WebSocket, data: T, mediaType!: String): Unit where T <: DataFields<T> {
        writeBinary(ws, MediaTypes.parse(mediaType).fromDataFields(data))
    }
    public static func close(ws: WebSocket, status!: ?UInt16 = None, reason!: String = ''): Unit {
        ws.writeCloseFrame(status: status, reason: reason)
        ws.closeConn()
    }
    public static func writeBinary(ws: WebSocket, data: Array<UInt8>): Unit {
        ws.write(BinaryWebFrame, data)
    }
    public func exec(endpoint: T, ctx: HttpContext, pattern: HttpRequestPathPatterns, ws: WebSocket): Unit {
        openMeta_?.handle(endpoint, ctx, pattern, ws, [])
        let pingTimer = if(let Some(f) <- pingFunc_) {
            let duration = f.duration
            let h = f.handle
            Timer.repeat(duration, duration, {=>
                ws.writePingFrame(h(endpoint, ctx, pattern, ws, []))
            })
        }else{
            None<Timer>
        }
        var bytes = ArrayList<Byte>()
        var frameType = None<WebSocketFrameType>
        func doExec(payload: Array<Byte>, fin: Bool, frameType: ?WebSocketFrameType, bytes: ArrayList<Byte>){
            if(let Some(ft) <- frameType){
                bytes.add(all: payload)
                if(fin){
                    func doExec<M>(meta: ?M, metaType: String) where M <: WSFuncMeta<T>  {
                        let m = meta.getOrThrow{WSException('${metaType} meta for ws is not specified')}
                        let resp = m.handle(endpoint, ctx, pattern, ws, bytes.unsafeData())
                        match(m.responseFrameType){
                            case Some(t) => match(t){
                                case TextWebFrame | BinaryWebFrame => ws.write(t, resp)
                                case _ => throw WSException('response of ${ctx.request.url} for ${m.name} must be TextWebFrame or BinaryWebFrame')
                            }
                            case _ => throw WSException('${ctx.request.url} for ${m.name} is not be specified frame type')
                        }
                    }
                    match(ft){
                        case TextWebFrame => doExec(textMeta_, "text")
                        case BinaryWebFrame => doExec(binaryMeta_, "binary")
                        case _ => return bytes
                    }
                    return ArrayList<Byte>()
                }
            }
            bytes
        }
        while(let frame <- ws.read()){
            try{
                match(frame.frameType){
                    case TextWebFrame | BinaryWebFrame =>
                        if(!bytes.isEmpty()){
                            throw WSException('current payload is not empty')
                        }
                        frameType = frame.frameType
                        bytes = doExec(frame.payload, frame.fin, frameType, bytes)
                    case ContinuationWebFrame =>
                        bytes = doExec(frame.payload, frame.fin, frameType, bytes)
                    case PingWebFrame => 
                        if(let Some(ping) <- pingMeta_){
                            let bytes = ping.handle(endpoint, ctx, pattern, ws, frame.payload)
                            ws.writePongFrame(bytes)
                        }else{
                            ws.writePongFrame(frame.payload)
                        }
                    case PongWebFrame =>
                        if(let Some(pong) <- pongMeta_){
                            pong.handle(endpoint, ctx, pattern, ws, frame.payload)
                        }
                    case CloseWebFrame =>
                        try{
                            if(let Some(c) <- closeMeta_){
                                let bytes = c.handle(endpoint, ctx, pattern, ws, frame.payload)
                                if(!bytes.isEmpty()){
                                    ws.write(CloseWebFrame, bytes)
                                }
                            }else{
                                ws.write(CloseWebFrame, frame.payload)
                            }
                        }catch(e: Exception){
                            log.error('error on handling close ${toBase64String(frame.payload)}', e)
                        }
                        pingTimer?.cancel()
                        ws.closeConn()
                        return
                    case _ => 
                        log.error('unsupport frame ${frame.frameType}')
                        ws.closeConn()
                }
            }catch(e: Exception){
                log.error('error on handling ${frame.frameType}; frame: ${toBase64String(frame.payload)}', e)
            }
        }
    }
    
    private func doExtractArgOption<P, M>(meta: ?M, ctx: HttpContext, name: String): ?P where P <: DataFields<P>, M <: WSFuncMeta<T> {
        let val = meta?.args.extract<P>(ctx, name, pattern)
        match(val){
            case Some(x) => x
            case _ => None<P>
        }
    }
    private func doExtractArg<P, M>(meta: ?M, ctx: HttpContext, name: String): P where P <: DataFields<P>, M <: WSFuncMeta<T> {
        doExtractArgOption<P, M>(meta, ctx, name).getOrThrow()
    }
    private func doExtractArg<P, M>(meta: ?M, ctx: HttpContext, name: String, default: P): P where P <: DataFields<P>, M <: WSFuncMeta<T> {
        doExtractArgOption<P, M>(meta, ctx, name) ?? default
    }

    public func extractOpenArg<T>(ctx: HttpContext, name: String): T where T <: DataFields<T> {
        doExtractArg(openMeta_, ctx, name)
    }
    public func extractOpenArg<T>(ctx: HttpContext, name: String, default: T): T where T <: DataFields<T> {
        doExtractArg(openMeta_, ctx, name, default)
    }
    public func extractCloseArg<T>(ctx: HttpContext, name: String): T where T <: DataFields<T> {
        doExtractArg(closeMeta_, ctx, name)
    }
    public func extractCloseArg<T>(ctx: HttpContext, name: String, default: T): T where T <: DataFields<T> {
        doExtractArg(closeMeta_, ctx, name, default)
    }
    public func extractTextArg<T>(ctx: HttpContext, name: String): T where T <: DataFields<T> {
        doExtractArg(textMeta_, ctx, name)
    }
    public func extractTextArg<T>(ctx: HttpContext, name: String, default: T): T where T <: DataFields<T> {
        doExtractArg(textMeta_, ctx, name, default)
    }
    public func extractBinaryArg<T>(ctx: HttpContext, name: String): T where T <: DataFields<T> {
        doExtractArg(binaryMeta_, ctx, name)
    }
    public func extractBinaryArg<T>(ctx: HttpContext, name: String, default: T): T where T <: DataFields<T> {
        doExtractArg(binaryMeta_, ctx, name, default)
    }
    public func extractPingArg<T>(ctx: HttpContext, name: String): T where T <: DataFields<T> {
        doExtractArg(pingMeta_, ctx, name)
    }
    public func extractPingArg<T>(ctx: HttpContext, name: String, default: T): T where T <: DataFields<T> {
        doExtractArg(pingMeta_, ctx, name, default)
    }
    public func extractPongArg<T>(ctx: HttpContext, name: String): T where T <: DataFields<T> {
        doExtractArg(pongMeta_, ctx, name)
    }
    public func extractPongArg<T>(ctx: HttpContext, name: String, default: T): T where T <: DataFields<T> {
        doExtractArg(pongMeta_, ctx, name, default)
    }

    public static func generate() : WSMeta<T> {
        let endpointClass = TypeInfo.of<T>()
        let meta = WSMeta<T>()
        for(function in endpointClass.instanceFunctions) {
            let funcName = function.name
            let funcMeta = 
            if(let Some(annotation) <- function.findAnnotation<OnWSOpen>()){
                let m = WSOpenMeta<T>(funcName)
                meta.openMeta_ = m
                m
            }else if(let Some(annotation) <- function.findAnnotation<OnWSClose>()){
                let m = WSCloseMeta<T>(funcName)
                meta.closeMeta_ = m
                m
            }else if(let Some(annotation) <- function.findAnnotation<OnWSBinary>()){
                let m = WSBinaryMeta<T>(funcName, annotation.mediaType, annotation.responseFrameType)
                meta.binaryMeta_ = m
                m
            }else if(let Some(annotation) <- function.findAnnotation<OnWSText>()){
                let m = WSTextMeta<T>(funcName, annotation.mediaType, annotation.responseFrameType)
                meta.textMeta_ = m
                m
            }else if(let Some(annotation) <- function.findAnnotation<OnWSPing>()){
                let m = WSPingMeta<T>(funcName, annotation.mediaType)
                meta.pingMeta_ = m
                m
            }else if(let Some(annotation) <- function.findAnnotation<OnWSPong>()){
                let m = WSPongMeta<T>(funcName, '')
                meta.pongMeta_ = m
                m
            }else if(let Some(annotation) <- function.findAnnotation<WSPing>()){
                let f = WSPingFunc<T>(funcName, annotation.mediaType)
                f.duration = Duration.parse(annotation.duration)
                meta.pingFunc_ = f
                f
            }else{
                continue
            }
            for (param in function.parameters) {
                let pname = param.name
                var toThrow = true
                for (annotation in param.annotations where annotation is ControllerFuncParam) {
                    funcMeta.args[pname] = (annotation as ControllerFuncParam).getOrThrow()
                    toThrow = false
                    break
                }
                if(toThrow){
                    throw WSException(
                        'parameter of controller function must be with one and only one Annotation as @RequestBody or @RequestParam or @RequestHeader or @PathVariable or @MultipartFormData')
                }
            }
        }
        meta
    }
}