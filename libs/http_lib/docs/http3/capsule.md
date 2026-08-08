# HTTP/3 胶囊协议与 WebSocket 隧道（RFC 9297 / RFC 9220）

## 胶囊协议（Capsule Protocol）

胶囊协议（RFC 9297）用于在 HTTP/3 流上传输非 HTTP 数据，
如 UDP 数据报和 WebSocket 帧。在 HTTP/3 中，胶囊帧通过 DATA 帧传输。

### 胶囊格式

```
Capsule Type（QUIC varint）+ Capsule Length（QUIC varint）+ Capsule Data
```

### 胶囊类型

| 类型 | 值 | 说明 |
|------|-----|------|
| `DATA` | 0x00 | 数据流 |
| `DATAGRAM` | 0x01 | HTTP 数据报（RFC 9297 §5） |
| `DATAGRAM_WITH_CONTEXT` | 0x02 | 带上下文的 HTTP 数据报 |
| `CLOSE` | 0x03 | 关闭流 |

### 编码/解码

```cangjie
let capsule = H3Capsule(H3CapsuleType.DATAGRAM, datagramData)
let encoded = encodeH3Capsule(capsule)
let decoded = decodeH3Capsule(encoded)
```

## HTTP 数据报（HTTP Datagrams）

HTTP Datagram 使用 DATAGRAM 胶囊在 HTTP/3 连接上传输
UDP 数据报。这对于 WebRTC 数据通道、游戏协议等需要
低延迟数据传输的场景非常有用。

```cangjie
// 创建 DATAGRAM 胶囊
let capsule = buildDatagramCapsule(datagramData)
let encoded = encodeH3Capsule(capsule)
h3Conn.sendTunnelData(streamId, encoded)
```

## WebSocket over HTTP/3（RFC 9220）

WebSocket over HTTP/3 使用 Extended CONNECT 建立隧道，
通过胶囊协议传输 WebSocket 帧。

### 架构

```
客户端 ↔ H3Connection (Extended CONNECT) ↔ H3WebSocketTunnel
                                              ↕
                                      H3WebSocketConnection
                                              ↕
                                        WebSocket 处理器
```

### H3WebSocketTunnel

提供 WebSocket 数据的双向收发：

```cangjie
let tunnel = H3WebSocketTunnel(h3Conn, streamId)
tunnel.send(wsFrame)         // 发送数据
let (data, closed) = tunnel.recv()  // 接收数据
tunnel.close()               // 关闭隧道
```

### H3WebSocketConnection

将 H3WebSocketTunnel 适配为标准 Connection 接口，
使现有的 WebSocket 处理器（基于 ConnectionController）
可直接在 HTTP/3 隧道上工作：

```cangjie
let tunnel = H3WebSocketTunnel(h3Conn, streamId)
let wsConn = H3WebSocketConnection(tunnel)
wsConn.write(myData)         // 通过 DATAGRAM 胶囊发送
let data = wsConn.read(buf)  // 从胶囊解析中读取
```

## 相关文件

| 文件 | 说明 |
|------|------|
| `capsule.cj` | 胶囊类型定义、编解码、H3WebSocketTunnel、H3WebSocketConnection |
| `capsule_test.cj` | 胶囊协议单元测试 |

## 参考

- [RFC 9297 — HTTP Datagrams and the Capsule Protocol](https://www.rfc-editor.org/rfc/rfc9297)
- [RFC 9220 — Bootstrapping WebSockets with HTTP/3](https://www.rfc-editor.org/rfc/rfc9220)
- [RFC 9298 — Proxying UDP in HTTP](https://www.rfc-editor.org/rfc/rfc9298)
