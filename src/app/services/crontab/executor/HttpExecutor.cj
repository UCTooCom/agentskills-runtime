package magic.app.services.crontab.executor

import std.time.DateTime
import std.core.Duration
import std.io.StringReader
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult, durationMsBetween, triggerTypeToString}
import stdx.net.http.*

public class HttpExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "http" }
    }

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        let url = context.taskUri

        if (!validate(url)) {
            return ExecutionResult.failureResult("URL验证失败", 0, -1)
        }

        try {
            let clientBuilder = ClientBuilder()
            let timeoutSec = if (context.timeout > 0) { Int64(context.timeout) } else { Int64(30) }
            clientBuilder.readTimeout(Duration.second * timeoutSec)
            let client = clientBuilder.build()

            let requestBuilder = HttpRequestBuilder()
            requestBuilder.url(url)
            requestBuilder.post()
            requestBuilder.header("Content-Type", "application/json")
            requestBuilder.header("X-Crontab-Id", context.crontabId)
            requestBuilder.header("X-Crontab-Name", context.taskName)
            requestBuilder.header("X-Crontab-Trigger", triggerTypeToString(context.triggerType))
            if (!context.parameters.isEmpty() && context.parameters != "{}") {
                requestBuilder.body(context.parameters)
            }

            let request = requestBuilder.build()
            let response = client.send(request)

            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)

            let statusCode = Int64(response.status)
            let reader = StringReader(response.body)
            let responseBody = reader.readToEnd()
            let truncatedBody = if (responseBody.size > 2000) { responseBody[0..2000] } else { responseBody }

            if (statusCode >= 200 && statusCode < 300) {
                let summary = if (truncatedBody.size > 200) { truncatedBody[0..200] } else { truncatedBody }
                LogUtils.info("HttpExecutor", "HTTP回调成功: ${url}, status: ${statusCode}, 耗时: ${duration}ms")
                return ExecutionResult.successResult(truncatedBody, duration, summary)
            } else {
                LogUtils.error("HttpExecutor", "HTTP回调失败: ${url}, status: ${statusCode}")
                return ExecutionResult.failureResult("HTTP ${statusCode}: ${truncatedBody}", duration, Int32(statusCode))
            }
        } catch (e: Exception) {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            LogUtils.error("HttpExecutor", "HTTP回调异常: ${url}, ${e.message}")
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }

    public func validate(taskUri: String): Bool {
        if (!taskUri.startsWith("http://") && !taskUri.startsWith("https://")) {
            return false
        }
        if (isInternalIp(taskUri)) {
            LogUtils.error("HttpExecutor", "SSRF防护: 内网IP不允许: ${taskUri}")
            return false
        }
        return true
    }

    private func isInternalIp(url: String): Bool {
        let lower = url.toAsciiLower()
        if (lower.contains("127.0.0.1") || lower.contains("localhost")) { return true }
        if (lower.contains("10.") || lower.contains("192.168.") || lower.contains("172.16.") || lower.contains("172.17.") || lower.contains("172.18.") || lower.contains("172.19.") || lower.contains("172.20.") || lower.contains("172.21.") || lower.contains("172.22.") || lower.contains("172.23.") || lower.contains("172.24.") || lower.contains("172.25.") || lower.contains("172.26.") || lower.contains("172.27.") || lower.contains("172.28.") || lower.contains("172.29.") || lower.contains("172.30.") || lower.contains("172.31.")) { return true }
        if (lower.contains("0.0.0.0") || lower.contains("::1") || lower.contains("[::1]")) { return true }
        return false
    }
}
