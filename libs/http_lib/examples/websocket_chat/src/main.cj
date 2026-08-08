package sample_websocket_chat

import std.collection.HashMap
import http_lib.core.*
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig, ConnectionController, loggingMiddleware}

/**
 * WebSocket 升级演示服务器。
 *
 * 演示基于 HTTP Upgrade 的 WebSocket 握手。
 * 当客户端发送 Upgrade: websocket 请求时，服务器
 * 响应 101 Switching Protocols 并保持连接
 * 打开以进行双向通信。
 *
 * 特性：
 *   - WebSocket 升级检测
 *   - 带 JavaScript WebSocket API 的 HTML 聊天客户端
 *   - 回声服务器，回显所有接收到的帧
 *
 * 基于 WebSocket 协议升级模式（RFC 6455）。
 */

// ---- HTML 聊天页面 ----

func chatPageHandler(req: HttpRequest): HttpResponse {
    let html = "<!DOCTYPE html><html><head><title>WebSocket Chat Demo</title><style>body{font-family:monospace;max-width:600px;margin:50px auto;padding:20px;background:#1a1a2e;color:#eee}h1{color:#00d4ff}#chat{border:1px solid #333;height:300px;overflow-y:auto;padding:10px;margin:10px 0;background:#16213e;border-radius:8px}#chat div{margin:5px 0;padding:5px 10px;border-radius:4px}.sent{background:#0f3460;text-align:right}.received{background:#533483;text-align:left}#input{display:flex;gap:10px}#msg{flex:1;padding:10px;border:1px solid #333;border-radius:4px;background:#16213e;color:#eee}#send{padding:10px 20px;background:#00d4ff;color:#000;border:none;border-radius:4px;cursor:pointer;font-weight:bold}.status{color:#00ff88;font-size:12px}</style></head><body><h1>🔌 WebSocket Chat Demo</h1><div id='chat'></div><div id='input'><input id='msg' type='text' placeholder='Type a message...' onkeypress='if(event.key===\"Enter\")send()'><button id='send' onclick='send()'>Send</button></div><div class='status' id='status'>Connecting...</div><script>const ws=new WebSocket('ws://'+location.host+'/ws');const chat=document.getElementById('chat');const status=document.getElementById('status');ws.onopen=()=>{status.textContent='✓ Connected';status.style.color='#00ff88'};ws.onmessage=(e)=>{chat.innerHTML+='<div class=\"received\">'+e.data+'</div>';chat.scrollTop=chat.scrollHeight};ws.onclose=()=>{status.textContent='✗ Disconnected';status.style.color='#ff4444'};ws.onerror=()=>{status.textContent='✗ Error';status.style.color='#ff4444'};function send(){const input=document.getElementById('msg');const msg=input.value;if(msg){chat.innerHTML+='<div class=\"sent\">'+msg+'</div>';ws.send(msg);input.value='';chat.scrollTop=chat.scrollHeight}}</script></body></html>"
    HttpResponse.html(HttpStatus.OK, html)
}

func infoHandler(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK, "{\"server\":\"http_lib-websocket-demo\",\"upgrade\":\"websocket\",\"wsEndpoint\":\"/ws\"}")
}

/**
 * 使用 ConnectionController 模式的 WebSocket 升级处理器。
 *
 * 此处理器演示如何：
 *   1. 通过 req.connection 访问底层连接
 *   2. 执行 WebSocket 握手（101 Switching Protocols）
 *   3. 接管连接进行原始双向 I/O
 *   4. 通知服务器停止管理此连接
 *
 * 在生产实现中，原始 I/O 将被正确的 WebSocket 帧解析
 *（操作码、掩码、长度、载荷）取代。
 * 劫持器提供了构建此类库的基础。
 */
func wsHandler(req: HttpRequest): HttpResponse {
    // 访问服务器提供的底层连接
    let conn = match (req.connection) {
        case Some(c) => c
        case None =>
            return HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR,
                "hijacking not supported")
    }

    // 创建 ConnectionController 并执行 WebSocket 升级握手
    let h = ConnectionController(conn)
    try {
        h.upgradeToWebSocket(req)
    } catch (e: Exception) {
        return HttpResponse.text(HttpStatus.BAD_REQUEST, e.message)
    }

    // 连接已被劫持 — 服务器不会再触碰它。
    // 执行原始双向 I/O（示例回显循环）。
    // 实际实现：在此处解析 WebSocket 帧。
    let buf = Array<UInt8>(4096, repeat: 0)
    while (true) {
        let n = try {
            conn.read(buf)
        } catch (_: Exception) {
            break
        }
        if (n <= 0) { break }
        try {
            conn.write(buf[0..n])  // echo received bytes
        } catch (_: Exception) {
            break
        }
    }

    // 劫持后服务器会丢弃返回值
    HttpResponse.empty(HttpStatus.OK)
}

// ---- 主程序 ----

main(): Int64 {
    let router = Router()
        .get("/", chatPageHandler)
        .get("/info", infoHandler)
        .get("/ws", wsHandler)  // WebSocket upgrade endpoint

    let handler = router.handler()

    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    serverConfig.readTimeout = Duration.second * 300  // 5 min for WebSocket
    serverConfig.writeTimeout = Duration.second * 300
    serverConfig.serverName = "http_lib-ws-demo/0.1"

    let server = HttpServer(handler: handler, config: serverConfig)

    println("========================================")
    println("  WebSocket Chat Demo Server")
    println("  Listening on: http://127.0.0.1:8084")
    println("")
    println("  Open http://127.0.0.1:8084/ in a browser")
    println("  WebSocket endpoint: ws://127.0.0.1:8084/ws")
    println("")
    println("  Test with:")
    println("    curl -i -N -H 'Connection: Upgrade' -H 'Upgrade: websocket' \\")
    println("         -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \\")
    println("         -H 'Sec-WebSocket-Version: 13' http://127.0.0.1:8084/ws")
    println("========================================")

    server.listenAndServe("127.0.0.1", 8084)
    0
}
