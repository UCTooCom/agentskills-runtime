/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.utils.http

import magic.log.LogUtils
import magic.utils.getEnv
import magic.config.Config

import std.collection.{HashMap, contains}
import std.io.StringReader

import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.connection.TlsConfig
import stdx.encoding.json.*
import stdx.encoding.url.URL

private func buildHttpClient(url: String, verify: Bool): HttpClient {
    let config = HttpClientConfig()
    // 大模型 API 调用超时：5 分钟。
    // 前端 MCP 客户端默认 10 分钟超时（AgentModelProvider timeout:600000），
    // runtime 侧需早于前端返回错误，否则前端先 abort 丢弃后到的响应 → loading 永驻。
    config.readTimeout = Duration.minute * 5
    // 禁用 HTTP/2 升级：http_lib 的 tryUpgradeToHttp2 不检查 TLS ALPN 协商结果，
    // 会盲目发送 HTTP/2 preface。若服务器未协商 "h2"（如 DeepSeek 官方 API 对
    // 部分 TLS 1.2 客户端协商为 http/1.1），服务器解析 preface 失败后会强制关闭
    // 连接，导致 "Failed to write data 10054" 错误。
    // OpenAI 兼容 API（含 DeepSeek 官方、StepFun、OpenRouter 等）均完整支持 HTTP/1.1，
    // 强制使用 HTTP/1.1 可避免该问题。
    config.enableHttp2 = false
    if (url.startsWith("https")) {
        if (!verify) {
            config.tlsConfig = TlsConfig.insecure()
        }
    }
    return HttpClient(config: config)
}

private func prepareHttpRequest(method: String,
                                url: String,
                                header: HashMap<String, String>,
                                body: Option<JsonObject>): HttpRequest {
    let rb = HttpRequestBuilder().withUrl(url)
    if (let Some(b) <- body) {
        rb.withJson(b.toJsonString())
    }
    if (method == "POST") {
        rb.post()
    } else if (method == "GET") {
        rb.get()
    }
    for ((k, v) in header) {
        rb.withHeader(k, v)
    }
    return rb.build()
}

private func sendHttp(method: String,
                      url: String,
                      header: HashMap<String, String>,
                      body: Option<JsonObject>,
                      verify: Bool): (HttpClient, HttpResponse) {
    let client = buildHttpClient(url, verify)
    let req = prepareHttpRequest(method, url, header, body)
    try {
        let response = client.send(req)
        if (response.status.code != 200 && response.status.code != 202) {
            let content = readHttpBody(response).trimAscii()
            let msg = if (content.isEmpty()) {
                "Http status: ${response.status.code}"
            } else {
                "Http status: ${response.status.code}\nHttp response: ${content}"
            }
            LogUtils.error("Http ${url} with data: ${(body ?? JsonObject()).toJsonString()} failed")
            LogUtils.error(msg)
            throw HttpException(msg)
        }
        return (client, response)
    } catch (ex: Exception) {
 //       LogUtils.error("Http ${url} with data: ${(body ?? JsonObject(())).toJsonString()} failed")
        LogUtils.debug(ex)
        throw HttpException(ex.message)
    }
}

private func readHttpBody(resp: HttpResponse): String {
    return resp.bodyAsString()
}

//=====================================================================================

@When[ohos != "true" && http != "curl"]
protected struct HttpUtilsImpl {
    static protected func send(method: String,
                               url: String,
                               header: HashMap<String, String>,
                               body: Option<JsonObject>,
                               verify!: Bool): Option<String> {
        logHttpInfo(method, url, header, body, async: false)
        let (client, resp) = sendHttp(method, url, header, body, verify)
        return processJson(client, resp)
    }

    static private func processJson(client: HttpClient, response: HttpResponse): String {
        return readHttpBody(response)
    }

    static protected func asyncSend(method: String,
                                    url: String,
                                    header: HashMap<String, String>,
                                    body: Option<JsonObject>,
                                    verify!: Bool): HttpStream {
        logHttpInfo(method, url, header, body, async: true)
        let (client, resp) = sendHttp(method, url, header, body, verify)
        let httpStream = HttpStream()
        spawn {
            processStream(client, resp, httpStream)
        }
        return httpStream
    }

    static private func processStream(client: HttpClient, response: HttpResponse, httpStream: HttpStream): Unit {
        let bodyBytes = response.bodyAsBytes()
        if (bodyBytes.size > 0) {
            httpStream.put(bodyBytes)
        }
        LogUtils.trace("End http stream. Status: ${response.status.code}")
        httpStream.markEOF()
    }

    static protected func hybridSend(method: String,
                                     url: String,
                                     header: HashMap<String, String>,
                                     body: Option<JsonObject>,
                                     verify!: Bool): HttpResult {
        logHttpInfo(method, url, header, body, async: false)
        let (client, resp) = sendHttp(method, url, header, body, verify)
        let contentType = match (resp.headers.get("content-type")) {
            case Some(v) => v
            case None => ""
        }
        if (contentType.contains("text/event-stream")) {
            let httpStream = HttpStream()
            spawn {
                processStream(client, resp, httpStream)
            }
            return HttpResult(
                status: Int64(resp.status.code),
                header: resp.headers,
                value: HttpResultOption.Stream(httpStream)
            )
        } else {
            return HttpResult(
                status: Int64(resp.status.code),
                header: resp.headers,
                value: HttpResultOption.Json(processJson(client, resp))
            )
        }
    }
}
