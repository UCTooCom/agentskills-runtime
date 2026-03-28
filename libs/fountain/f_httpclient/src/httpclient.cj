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
package f_httpclient

public import std.io.{InputStream, ByteBuffer, copy}
public import std.net.{SocketAddress, StreamingSocket}
public import stdx.net.tls.*
public import stdx.encoding.url.*
public import stdx.log.Logger
public import stdx.net.http.*
public import f_data.*
import f_http.*
import f_http.exception.MediaTypeException

public class HttpClient <: Resource {
    private static var readTimeout_ = None<Duration>
    private static var writeTimeout_ = None<Duration>
    public static func globalReadTimeout(readTimeout: Duration): Unit {
        readTimeout_ = readTimeout
    }
    public static func globalWriteTimeout(writeTimeout: Duration): Unit {
        writeTimeout_ = writeTimeout
    }
    private let builder = ClientBuilder()
    private let request = HttpRequestBuilder()
    private var client = None<Client>

    public HttpClient(var url: String){
        if(let Some(x) <- readTimeout_){
            readTimeout(x)
        }
        if(let Some(x) <- writeTimeout_){
            writeTimeout(x)
        }
    }

    public func autoRedirect(auto: Bool): This {
        builder.autoRedirect(auto)
        this
    }
    public func connector(c: (SocketAddress) -> StreamingSocket): This {
        builder.connector(c)
        this
    }
    public func cookieJar(cookieJar: ?CookieJar): This {
        builder.cookieJar(cookieJar)
        this
    }
    public func enablePush(enable: Bool): This {
        builder.enablePush(enable)
        this
    }
    public func headerTableSize(size: UInt32): This {
        builder.headerTableSize(size)
        this
    }
    public func httpProxy(addr: String): This {
        builder.httpProxy(addr)
        this
    }
    public func httpsProxy(addr: String): This {
        builder.httpsProxy(addr)
        this
    }
    public func initialWindowSize(size: UInt32): This {
        builder.initialWindowSize(size)
        this
    }
    public func logger(logger: Logger): This {
        builder.logger(logger)
        this
    }
    public func maxConcurrentStreams(size: UInt32): This {
        builder.maxConcurrentStreams(size)
        this
    }
    public func maxFrameSize(size: UInt32): This {
        builder.maxFrameSize(size)
        this
    }
    public func maxHeaderListSize(size: UInt32): This {
        builder.maxHeaderListSize(size)
        this
    }
    public func noProxy(): This {
        builder.noProxy()
        this
    }
    public func poolSize(size: Int64): This {
        builder.poolSize(size)
        this
    }
    public func readTimeout(timeout: Duration): This {
        builder.readTimeout(timeout)
        this
    }
    public func tlsConfig(config: TlsClientConfig): This {
        builder.tlsConfig(config)
        this
    }
    public func writeTimeout(timeout: Duration): This {
        builder.writeTimeout(timeout)
        this
    }
    public func header(key: String, value: String): This {
        request.header(key, value)
        this
    }
    public func header<T>(key: String, value: T): This where T <: ToString {
        header(key, value.toString())
    }
    private var closed = false
    public func isClosed(): Bool {
        closed
    }
    public func close(): Unit {
        client?.close()
        closed = true
    }
    private func send(method: String): HttpResponse {
        request.method(method).url(url)
        client = builder.build()
        (client?.send(request.build())).getOrThrow()
    }
    public func get(): HttpResponse {
        send('GET')
    }
    public func delete(): HttpResponse {
        send('DELETE')
    }
    public func put(): HttpResponse {
        send('PUT')
    }
    public func post(): HttpResponse {
        send('POST')
    }
    public func put(body: String): HttpResponse {
        request.body(body)
        put()
    }
    public func post(body: String): HttpResponse {
        request.body(body)
        post()
    }
    public func put(body: InputStream): HttpResponse {
        request.body(body)
        put()
    }
    public func post(body: InputStream): HttpResponse {
        request.body(body)
        post()
    }
    public func put(body: Array<Byte>): HttpResponse {
        request.body(body)
        put()
    }
    public func post(body: Array<Byte>): HttpResponse {
        request.body(body)
        post()
    }
    private func body<T>(contentType: String, body: T): This where T <: DataFields<T> {
        let bytes = MediaTypes.tryParse(contentType).getOrThrow{
            MediaTypeException('${contentType} is not a valid media type')
        }.fromDataFields<T>(body)
        request.body(bytes)
        this
    }
    public func put<T>(contentType: String, body: T): HttpResponse where T <: DataFields<T> {
        header('Content-Type', contentType)
        this.body<T>(contentType, body).put()
    }
    public func post<T>(contentType: String, body: T): HttpResponse where T <: DataFields<T> {
        header('Content-Type', contentType)
        this.body<T>(contentType, body).post()
    }

    public func form(): FormBuilder {
        FormBuilder(this)
    }
    public func multipartFormdata(): MultipartFormDataBuilder {
        MultipartFormDataBuilder(this)
    }
}
public class FormBuilder {
    FormBuilder(private let client: HttpClient){}
    private let form = Form()
    public func add(key: String, value: String): This {
        form.add(key, value)
        this
    }
    public func set(key: String, value: String): This {
        form.set(key, value)
        this
    }
    public func remove(key: String): This {
        form.remove(key)
        this
    }
    private func build(): HttpClient {
        client.url = '${client.url}?${form.toEncodeString()}'
        client
    }
    public func get(): HttpResponse {
        return build().get()
    }
    public func delete(): HttpResponse {
        return build().delete()
    }
    public func put(): HttpResponse {
        return client.put(form.toEncodeString())
    }
    public func post(): HttpResponse {
        return client.post(form.toEncodeString())
    }
}
public interface ExtendHttpResponse {
    func convert<T>(): ?T where T <: DataFields<T>
}
extend HttpResponse <: ExtendHttpResponse {
    public func convert<T>(): ?T where T <: DataFields<T> {
        let contentType = this.headers.getFirst('Content-Type') ?? 'application/json'
        if(let Some(s) <- this.bodySize){
            MediaTypes.tryParse(contentType).getOrThrow{
                MediaTypeException('${contentType} is not a valid media type')
            }.toDataFields<T>(this.body)
        }else{
            None<T>
        }
    }
}
public class MultipartFormDataBuilder {
    private let data = MultipartFormData()
    MultipartFormDataBuilder(private let client: HttpClient){
        client.header('Content-Type', 'multipart/form-data, boundary=${data.boundary}')
    }
    public func newPart(): MultipartFileBuilder{
        data.newPart()
    }
    public func put(){
        client.put(data.input())
    }
    public func post(){
        client.post(data.input())
    }
}