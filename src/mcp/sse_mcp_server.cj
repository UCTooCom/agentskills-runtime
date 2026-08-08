package magic.mcp

import http_lib.server.{HttpServer, HttpServerConfig, ConnectionController}
import http_lib.router.{Router, Handler}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.{HttpStatus, HttpHeaders}
import http_lib.connection.Connection
import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import std.time.*
import magic.core.agent.Agent
import magic.tool.AgentAsTool
import magic.log.LogUtils
import magic.jsonable.*
import magic.core.tool.Tool
import magic.utils.{randomString}

public class SseMCPServer <: AbsMCPServer {
    var client_map = ConcurrentHashMap<String, Connection>()

    public init(tools: Array<Tool>) {
        super(tools)
    }

    public func start(host: String, port: UInt16): Unit {
        let router = Router()

        router.get("/sse", { req: HttpRequest =>
            match (req.connection) {
                case Some(conn) =>
                    let controller = ConnectionController(conn)
                    controller.write(unsafe { "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nTransfer-Encoding: chunked\r\n\r\n".rawData() })
                    req.takenOver = true

                    let uuid = randomString(size: 12)
                    controller.write(unsafe { "event: endpoint\ndata: /messages/?session_id=${uuid}\n\n".rawData() })
                    this.client_map.add(uuid, conn)

                    spawn {
                        while (true) {
                            sleep(Duration.second * 8)
                            try {
                                conn.write(unsafe { ": ping - ${DateTime.now()}\n\n".rawData() })
                                conn.flush()
                            } catch (e: Exception) {
                                LogUtils.error("Client: ${uuid} ${e.message}")
                                this.client_map.remove(uuid)
                                break
                            }
                        }
                    }
                    return HttpResponse.empty(HttpStatus.OK)
                case None =>
                    return HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "Connection hijack not supported")
            }
        })

        router.post("/messages/", { req: HttpRequest =>
            let bodyBytes = req.bodyAsBytes()
            let msg = String.fromUtf8(bodyBytes)

            let queryString = match (req.url.indexOf("?")) {
                case Some(idx) => req.url[idx + 1..]
                case None => ""
            }
            let params = queryString.split("&")
            var uuidVar = ""
            for (param in params) {
                let parts = param.split("=")
                if (parts.size == 2 && parts[0] == "session_id") {
                    uuidVar = parts[1]
                }
            }

            let uuid = uuidVar
            LogUtils.info("Recv: ${uuid}: ${msg}")

            spawn {
                this.loop(msg, uuid)
            }

            return HttpResponse.text(HttpStatus(202), "Accepted")
        })

        let config = HttpServerConfig()
        let server = HttpServer(handler: router.handler(), config: config)
        server.listenAndServe(host, port)
    }

    public func loop(msg: String, uuid: String): Unit {
        if (let Some(resp) <- this.handleRequestMessage(msg)) {
            this.send(resp, uuid)
        }
    }

    private func send(msg: String, uuid: String): Unit {
        LogUtils.info("Send: ${uuid}: ${msg}")
        match (client_map.get(uuid)) {
            case Some(conn) =>
                conn.write(unsafe { "event: message\ndata: ${msg}\n\n".rawData() })
                conn.flush()
            case None =>
                LogUtils.error("Client not found: ${uuid}")
        }
    }

    private func send<T>(response: T, uuid: String): Unit where T <: ToJsonValue {
        this.send(response.toJsonValue().toString(), uuid)
    }

    protected override func send(msg: String): Unit {
        throw Exception("Implementation")
    }

    protected override func recv(): Option<String> {
        throw Exception("Implementation")
    }

    public static func startWith(agents: Array<Agent>, host: String, port: UInt16): Unit {
        let allTools = ArrayList<Tool>()
        for (agent in agents) {
            allTools.add(all: agent.toolManager.tools)
            allTools.add(AgentAsTool(agent))
        }
        let server = SseMCPServer(allTools.toArray())
        server.start(host, port)
    }

    public static func startWith(tools: Array<Tool>, host: String, port: UInt16): Unit {
        let server = SseMCPServer(tools)
        server.start(host, port)
    }
}
