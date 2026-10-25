/*
 * transport.cj — 出网（curl 子进程）
 *
 * 插件工程引不到宿主的 http_lib，且 std.net 在本仓颉版本无稳定 HTTPS 客户端，
 * 故按既有约定用 curl.exe：零依赖、零 DLL 风险，与宿主 src/utils/http/http_curl.cj 同款。
 *
 * 请求体写临时文件后以 @file 传入，避免命令行长度限制与中文参数编码问题；
 * 用 -w 在响应体末尾追加状态码，一次调用同时拿到响应体与 HTTP 状态。
 */
package skill_yuanbao_policy

import std.collection.{HashMap, ArrayList}
import std.fs.File
import std.process.{executeWithOutput, ProcessRedirect}

public class YbHttp {
    public static let BODY_FILE: String = "./.yuanbao_policy_request.json"

    /// 返回 (响应体, HTTP 状态码字符串)
    public static func post(url: String, body: String, headers: HashMap<String, String>): (String, String) {
        try {
            File.writeTo(YbHttp.BODY_FILE, body.toArray())
        } catch (e: Exception) {
            eprintln("[yuanbao-policy] 请求体写临时文件失败: ${e.message}")
            return ("", "0")
        }

        let args = ArrayList<String>()
        args.add("-s")
        args.add("-X")
        args.add("POST")
        args.add(url)
        for ((k, v) in headers) {
            args.add("-H")
            args.add("${k}: ${v}")
        }
        args.add("--data-binary")
        args.add("@${YbHttp.BODY_FILE}")
        args.add("-w")
        args.add("\n%{http_code}")

        try {
            let (code, out, err) = executeWithOutput(
                "curl",
                args.toArray(),
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )
            if (code != 0 && out.size == 0) {
                eprintln("[yuanbao-policy] curl 退出码 ${code}")
            }
            return YbHttp.splitStatus(String.fromUtf8(out))
        } catch (e: Exception) {
            eprintln("[yuanbao-policy] curl 调用失败: ${e.message}")
            return ("", "0")
        }
    }

    /// 按最后一个换行切分响应体与追加的状态码
    ///
    /// 两处坑（都在同一个 API 上）：
    ///   ① String.lastIndexOf 返回 Option<Int64>，不是 Int64（工程先例 AttachmentsService.cj:1060）；
    ///   ② 即使解包出来也是「字节下标」，响应体含中文时把它当 Rune 下标会切出乱码。
    /// 故改为在 Rune 序列里直接定位最后一个换行符（中文安全）。
    ///
    /// 第三处坑（闭包）：Array<Rune>(n, { i => ... }) 的初始化 lambda **不能捕获 var**
    /// （编译器报 "lambda capturing mutable variables needs to be called directly"）。
    /// 故定位用的 `at` 是 var，进 lambda 前必须固化成不可变副本 `atFixed`。
    private static func splitStatus(text: String): (String, String) {
        let runes = text.toRuneArray()
        var at: Int64 = -1
        for (i in 0..runes.size) {
            if (runes[i] == r'\n') {
                at = i
            }
        }
        if (at < 0) {
            return (text, "")
        }
        let atFixed: Int64 = at
        let head = String(Array<Rune>(atFixed, { i => runes[i] }))
        let tailLen = runes.size - atFixed - 1
        let tail = String(Array<Rune>(tailLen, { i => runes[atFixed + 1 + i] }))
        return (head, tail.trimAscii())
    }
}
