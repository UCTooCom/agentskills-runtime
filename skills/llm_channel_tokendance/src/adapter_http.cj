/*
 * HTTP 客户端（curl 后端）—— 适配器插件的出网通道
 *
 * 为什么用 curl 而不是 std.net / http_lib：
 * - `http_lib` 是宿主包（magic.utils.http），插件是独立 cjpm 工程，不依赖宿主编译图；
 * - `std.net` 在本仓颉版本上没有稳定的 HTTPS 客户端 API，且 stdx 的 OpenSSL DLL
 *   有已知的 libcrypto-3-x64.dll 命名坑（见项目 MEMORY「stdx OpenSSL DLL」条）；
 * - curl.exe 是 Windows 10+ 自带、Linux/macOS 也 ubiquitous，零依赖零 DLL 风险。
 *   对标：宿主 src/utils/http/http_curl.cj 的 HttpUtilsImpl(http == "curl") 分支。
 *
 * 关键约束：
 * - **请求体写临时文件再用 @file 传**：Process.start 的命令行长度有限，
 *   长 prompt 必然超限（对标 http_curl.cj:54 `saveTempFile` + `args.add("@${tempPath}")`）。
 * - **状态码与响应体分离**：用 `-w "\n%{http_code}"` 让 curl 在响应体末尾追加状态码，
 *   这样一次调用就能同时拿到「业务错误原文」（非 200 时的响应体）与状态码，
 *   满足契约 §3.4「*_detail 必须是原始错误原文」。
 */
package skill_llm_channel_tokendance

import std.process.{executeWithOutput, ProcessRedirect}
import std.env.getVariables
import std.collection.{ArrayList, HashMap}
import std.fs.{File, Path, OpenMode, exists, remove}
import std.time.DateTime
import std.convert.Parsable
import jsonvalue.*

public class AdapterHttp {
    /// 单次 HTTP 调用超时（秒）。探测走同一条路径，超时不宜过大——
    /// 探测是三枪前台行为，60s 足够覆盖正常网络抖动。
    private static let TIMEOUT_SEC: Int64 = 60

    /**
     * 发起一次 JSON POST。
     *
     * @param url     完整 URL
     * @param headers 请求头（已含鉴权）
     * @param body    请求体 JSON 文本
     * @return (httpCode, responseBodyText)
     * @throws Exception curl 不可用 / 超时等进程级失败（原文上抛，不吞）
     */
    public static func postJson(
        url: String,
        headers: HashMap<String, String>,
        body: String
    ): (Int64, String) {
        let bodyPath = AdapterHttp.writeTempBody(body)
        let args = ArrayList<String>()
        args.add("-s")            // 静默进度条
        args.add("-S")            // 但保留错误信息到 stderr
        args.add("-X")
        args.add("POST")
        args.add("--max-time")
        args.add(AdapterHttp.TIMEOUT_SEC.toString())
        args.add("-w")
        args.add("\n%{http_code}") // 响应体末尾追加状态码
        for ((k, v) in headers) {
            args.add("-H")
            args.add("${k}: ${v}")
        }
        args.add("--data-binary")
        args.add("@${bodyPath}")
        args.add(url)

        try {
            let (_, stdout, stderr) = executeWithOutput(
                "curl",
                args.toArray(),
                environment: AdapterHttp.childEnv(),
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )
            return AdapterHttp.splitStatus(String.fromUtf8(stdout), String.fromUtf8(stderr))
        } finally {
            AdapterHttp.cleanupTemp(bodyPath)
        }
    }

    /**
     * 发起一次流式 POST（SSE / chunked），把响应体逐行回调出去。
     *
     * 当前宿主侧 PluginChatModel.asyncCreate 明确抛异常（core 侧未开放流帧工厂），
     * 所以本方法**只用于 probe 的 stream 枪**——那一枪只需要知道
     * 「能否收到首帧 + 是否有 done 帧」，不需要把帧交给上层。
     * 用 `--no-buffer` 关闭 curl 缓冲，否则首帧会被拖到响应结束才吐出来，
     * 导致「能不能流式」这个探测结论完全失真。
     *
     * @param onLine 每收到一行回调一次（已去掉行尾 \r）
     * @return (httpCode, stderr)
     */
    public static func postStream(
        url: String,
        headers: HashMap<String, String>,
        body: String,
        onLine: (String) -> Unit
    ): (Int64, String) {
        let bodyPath = AdapterHttp.writeTempBody(body)
        let args = ArrayList<String>()
        args.add("-s")
        args.add("-S")
        args.add("-X")
        args.add("POST")
        args.add("--no-buffer")   // 关键：否则首帧延迟到结束，探测结论失真
        args.add("--max-time")
        args.add(AdapterHttp.TIMEOUT_SEC.toString())
        args.add("-w")
        args.add("\n%{http_code}")
        for ((k, v) in headers) {
            args.add("-H")
            args.add("${k}: ${v}")
        }
        args.add("--data-binary")
        args.add("@${bodyPath}")
        args.add(url)

        try {
            let (_, stdout, stderr) = executeWithOutput(
                "curl",
                args.toArray(),
                environment: AdapterHttp.childEnv(),
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )
            // 逐行回调；最后一个纯数字行是 curl 追加的状态码，不作为内容行
            let lines = AdapterHttp.splitLines(String.fromUtf8(stdout))
            for (line in lines) {
                if (AdapterHttp.isNumeric(line)) {
                    continue
                }
                onLine(line)
            }
            let status = AdapterHttp.trailingStatus(String.fromUtf8(stdout))
            return (status, String.fromUtf8(stderr))
        } finally {
            AdapterHttp.cleanupTemp(bodyPath)
        }
    }

    // ── 内部工具 ──────────────────────────────────────────────────────

    /// 拆出末尾 curl 追加的 http_code，剩余部分是响应体
    private static func splitStatus(stdout: String, stderr: String): (Int64, String) {
        let code = AdapterHttp.trailingStatus(stdout)
        let body = AdapterHttp.stripTrailingCode(stdout)
        if (code == 0 && !stderr.trimAscii().isEmpty()) {
            // curl 自身失败（DNS/连接/超时）：状态码 000 或缺失
            throw Exception("curl 调用失败：${stderr.trimAscii()}")
        }
        (code, body)
    }

    /// 末行是纯数字（curl -w 追加的 http_code）时返回它，否则 0
    private static func trailingStatus(stdout: String): Int64 {
        let lines = AdapterHttp.splitLines(stdout)
        if (lines.isEmpty()) {
            return 0
        }
        let last = lines[lines.size - 1]
        if (AdapterHttp.isNumeric(last)) {
            return Int64.parse(last.trimAscii())
        }
        0
    }

    /// 去掉末尾 curl 追加的状态码行，返回纯响应体
    private static func stripTrailingCode(stdout: String): String {
        let lines = AdapterHttp.splitLines(stdout)
        if (lines.isEmpty()) {
            return ""
        }
        let last = lines[lines.size - 1]
        if (!AdapterHttp.isNumeric(last)) {
            // 没有状态码行：整体都是响应体（curl 未输出 -w 内容）
            return stdout
        }
        if (lines.size == 1) {
            // 只有状态码：响应体为空
            return ""
        }
        // 重新拼回「除末行外」的所有行，保留原始换行结构
        let kept = ArrayList<String>()
        for (i in 0..(lines.size - 1)) {
            kept.add(lines[i])
        }
        AdapterHttp.joinLines(kept)
    }

    private static func joinLines(lines: ArrayList<String>): String {
        var out = ""
        for (i in 0..lines.size) {
            if (i > 0) {
                out += "\n"
            }
            out += lines[i]
        }
        out
    }

    /**
     * 按 \n 切行并去掉行尾 \r。
     *
     * 用 Rune 数组而不是 String 字节下标：仓颉 String 的 `s[a..b]` 按**字节**切，
     * 响应体里的中文/emoji 会把一行切成乱码（半个 UTF-8 序列）。
     */
    private static func splitLines(text: String): ArrayList<String> {
        let out = ArrayList<String>()
        if (text.isEmpty()) {
            return out
        }
        let runes = text.toRuneArray()
        var buf = ""
        for (r in runes) {
            if (r == r'\n') {
                out.add(AdapterHttp.trimCR(buf))
                buf = ""
            } else {
                buf += r.toString()
            }
        }
        if (!buf.isEmpty()) {
            out.add(AdapterHttp.trimCR(buf))
        }
        out
    }

    private static func trimCR(s: String): String {
        if (s.isEmpty()) {
            return s
        }
        let runes = s.toRuneArray()
        let last = runes[runes.size - 1]
        if (last == r'\r') {
            return String(runes[0..(runes.size - 1)])
        }
        return s
    }

    private static func isNumeric(s: String): Bool {
        if (s.isEmpty()) {
            return false
        }
        for (r in s.toRuneArray()) {
            if (r < r'0' || r > r'9') {
                return false
            }
        }
        true
    }

    /// 请求体写临时文件：命令行长度有限，长 prompt 必然超限
    private static func writeTempBody(body: String): String {
        let dir = AdapterHttp.tempDir()
        let ts = DateTime.now().toUnixTimeStamp().toSeconds()
        let path = "${dir}/llm_channel_tokendance_body_${ts}.json"
        try (f = File(Path(path), OpenMode.Write)) {
            f.write(body.toArray())
        }
        path
    }

    private static func cleanupTemp(path: String): Unit {
        try {
            if (exists(Path(path))) {
                remove(Path(path))
            }
        } catch (_: Exception) {
            // 临时文件删不掉不该影响主流程（最坏是留个垃圾文件）
        }
    }

    private static func tempDir(): String {
        let candidates = ["./log/tmp", "./target/tmp", "."]
        for (d in candidates) {
            if (exists(Path(d))) {
                return d
            }
        }
        return "."
    }

    /**
     * 子进程环境。
     *
     * 必须手工带 getVariables()：executeWithOutput 的 environment 形参是
     * **整体替换**而非合并，只塞自定义键会丢掉 PATH，导致找不到 curl。
     * （与 app/services/crontab/executor/ScriptExecutor.childEnv 同款理由）
     */
    private static func childEnv(): HashMap<String, String> {
        let env = HashMap<String, String>(getVariables())
        // 显式声明不代理，避免内网网关被 HTTP_PROXY 环境变量带偏
        env["NO_PROXY"] = "localhost,127.0.0.1"
        env
    }
}
