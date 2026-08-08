/**
 * http_lib 的压力测试。
 *
 * 启动 HTTP 服务器，使用共享的 HttpClient 发起大量请求，
 * 验证所有响应。通过 spawn 使用并发工作者来
 * 模拟真实世界的负载。
 *
 * 用法：bash test/stress/run.sh
 */
package stress_test

import std.collection.ArrayList
import std.time.DateTime
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler}
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.client.{HttpClient, HttpRequestBuilder}

class StressResult {
    var totalRequests: Int64 = 0
    var successCount: Int64 = 0
    var failureCount: Int64 = 0
    var errors: ArrayList<String> = ArrayList<String>()
}

func rootHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "Hello from http_lib!")
}

func echoHandler(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    HttpResponse.text(HttpStatus.OK, body)
}

func routerHandler(req: HttpRequest, router: Router): HttpResponse {
    let result = router.find(req.method, req.url)
    match (result.handler) {
        case Some(h) => h(req)
        case None => HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
    }
}

/**
 * 为单个并发工作者运行请求。
 * 使用共享客户端进行连接池管理。
 */
func runWorker(id: Int64, client: HttpClient, baseUrl: String, numRequests: Int64, result: StressResult): Unit {
    var i: Int64 = 0
    while (i < numRequests) {
        try {
            // GET 请求
            let resp = client.get("${baseUrl}/")
            if (resp.status.code == 200) {
                let body = resp.bodyAsString()
                if (body == "Hello from http_lib!") {
                    result.successCount++
                } else {
                    result.failureCount++
                    synchronized(result) {
                        result.errors.add("Worker ${id}: GET ${i} unexpected body")
                    }
                }
            } else {
                result.failureCount++
                synchronized(result) {
                    result.errors.add("Worker ${id}: GET ${i} returned ${resp.status.code}")
                }
            }

            // POST 请求
            let echoResp = client.postJson("${baseUrl}/echo", "{\"worker\":${id},\"req\":${i}}")
            if (echoResp.status.code == 200) {
                result.successCount++
            } else {
                result.failureCount++
                synchronized(result) {
                    result.errors.add("Worker ${id}: POST ${i} returned ${echoResp.status.code}")
                }
            }
        } catch (e: Exception) {
            result.failureCount++
            synchronized(result) {
                result.errors.add("Worker ${id}: request ${i} error: ${e.message}")
            }
        }
        i++
    }
}

main(): Int64 {
    println("========================================")
    println("  http_lib Stress Test")
    println("========================================")
    println("")

    let router = Router()
        .get("/", rootHandler)
        .post("/echo", echoHandler)

    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    let server = HttpServer(handler: {req => routerHandler(req, router)}, config: serverConfig)

    spawn {
        try {
            server.listenAndServe("127.0.0.1", 9399)
        } catch (e: Exception) {
            println("Server stopped: ${e.message}")
        }
    }

    sleep(Duration.second * 2)
    println("Server started on port 9399")
    println("")

    // 配置
    let numWorkers: Int64 = 10
    let requestsPerWorker: Int64 = 100
    let totalRequests = numWorkers * requestsPerWorker
    println("Configuration: ${numWorkers} workers x ${requestsPerWorker} requests each = ${totalRequests} total")
    println("")

    // 创建单个共享的 HttpClient 用于连接池管理
    let client = HttpClient()
    let baseUrl = "http://127.0.0.1:9399"

    // 运行并发工作者
    println("Starting concurrent workers...")
    let startTime = DateTime.now()

    let result = StressResult()

    // 通过 spawn 并发启动工作者
    var workerIds = ArrayList<Int64>()
    var i: Int64 = 0
    while (i < numWorkers) {
        workerIds.add(i)
        i++
    }

    for (wid in workerIds) {
        spawn {
            runWorker(wid, client, baseUrl, requestsPerWorker, result)
        }
    }

    // 等待所有工作者完成（忙等待轮询）
    let expectedTotal = numWorkers * requestsPerWorker * 2  // GET + POST per request
    var waited: Int64 = 0
    while (result.successCount + result.failureCount < expectedTotal && waited < 300) {
        sleep(Duration.millisecond * 100)
        waited++
    }

    let endTime = DateTime.now()
    let elapsedMs = endTime - startTime
    let elapsedSec = Int64(elapsedMs) / 1000_000_000  // Convert nanoseconds to seconds (approximately)

    println("")
    println("Results:")
    println("  Successful: ${result.successCount}")
    println("  Failed: ${result.failureCount}")
    println("  Elapsed: ~${elapsedSec}s")
    if (elapsedMs > 0) {
        let totalDone = result.successCount + result.failureCount
        let opsPerSec = totalDone * 1000_000_000 / elapsedMs
        println("  Throughput: ~${opsPerSec} req/s")
    }

    if (result.errors.size > 0) {
        println("")
        println("Errors (first 10):")
        var errCount: Int64 = 0
        for (err in result.errors) {
            if (errCount >= 10) { break }
            println("  ${err}")
            errCount++
        }
    }

    println("")
    server.close()
    client.close()
    println("Server stopped.")

    if (result.failureCount > 0) {
        return 1
    }
    0
}
