/*
 * handlers.cj — yuanbao-policy 插件能力入口
 *
 * 注册名 "yuanbao-policy"，宿主经 stdio JSON-RPC invoke 转发。
 * 支持 action：
 *   search   —— 执行一次检索并输出带可信度标签的结果（含 excluded 数组）
 *   selftest —— 自检：连通性、服务档位、字段可用性、原文库状态
 *
 * 三条铁律：
 *   ① stdout 是 JSON-RPC 协议通道，诊断只能 eprintln；
 *   ② 失败不抛异常，一律返回结构化 {ok:false,error}（抛异常会被 cordis 包成 INVOKE-ERROR 丢原文）；
 *   ③ 判定规则与脚本轨 skills/yuanbao-search 保持一致。
 */
package skill_yuanbao_policy

import ystyle::cordis_plugin.PluginContext
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.time.DateTime

class YbDoc {
    var title: String = ""
    var url: String = ""
    var site: String = ""
    var date: String = ""
    var passage: String = ""
    var hasScore: Bool = false
    var score: Float64 = 0.0
    var hasAuthority: Bool = false
    var authority: Float64 = 0.0
    var vr: Bool = false
    var scoreNorm: Float64 = -1.0
}

public class YbHandlers {
    private static let GOV_HINTS: Array<String> = [".gov.cn", "gov.cn", ".gov.", "beijing.gov"]
    private static let PORTAL_HINTS: Array<String> = [
        "xinhuanet.com", "people.com.cn", "cctv.com", "cctv.cn", "chinadaily.com.cn",
        "chinanews.com.cn", "news.cn", "workercn.cn", "gmw.cn", "people.com",
        "163.com", "sina.com.cn", "sohu.com", "qq.com", "baidu.com", "zhihu.com",
    ]
    private static let SELFTEST_QUERY: String = "政策 申报"

    public static func register(ctx: PluginContext): Unit {
        ctx.registerHandler("yuanbao-policy", { method, args => YbHandlers.dispatch(method, args) })
    }

    private static func dispatch(method: String, args: Array<JsonValue>): JsonValue {
        if (args.size == 0) {
            return YbHandlers.err("missing args")
        }
        let req = args[0]
        let action = YbHandlers.fieldStr(req, "action")
        if (action == "selftest") {
            return YbHandlers.selftest()
        }
        if (action == "search" || action.size == 0) {
            return YbHandlers.search(req)
        }
        return YbHandlers.err("unknown action: ${action}")
    }

    // ── search ────────────────────────────────────────────────

    private static func search(req: JsonValue): JsonValue {
        let query = YbHandlers.fieldStr(req, "query")
        if (query.size == 0) {
            return YbHandlers.err("query 为必填项")
        }
        if (query.size > 200) {
            return YbHandlers.err("query 长度超过 200 字符")
        }
        let industryRaw = YbHandlers.fieldStr(req, "industry")
        let industry = if (industryRaw.size == 0) { "gov" } else { industryRaw }
        let cnt = YbHandlers.clampCnt(YbHandlers.fieldNum(req, "cnt"))
        let freshness = YbHandlers.fieldStr(req, "freshness")

        let (secretId, secretKey) = YbSign.credential()
        if (secretId.size == 0 || secretKey.size == 0) {
            return YbHandlers.err("未配置云 API 密钥（QCLOUD_COS_SECRET_ID / QCLOUD_COS_SECRET_KEY）")
        }

        // 默认不携带 Mode：实测 Mode=1 旗舰版仅召回 1 条且无 score（G4）
        let payload = HashMap<String, JsonValue>()
        payload.add("Query", JsonValue.String(query))
        payload.add("Industry", JsonValue.String(industry))
        payload.add("Cnt", JsonValue.Number(Float64(cnt)))
        if (freshness.size > 0) {
            payload.add("Freshness", JsonValue.String(freshness))
        }
        let body = JsonValue.Map(payload).stringify()
        let ts = YbSign.nowSeconds()
        let headers = YbSign.buildHeaders(body, secretId, secretKey, ts)

        let t0 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        let (respText, status) = YbHttp.post(YbSign.ENDPOINT, body, headers)
        let elapsedMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - t0

        if (respText.size == 0) {
            return YbHandlers.err("检索通道不可用（HTTP ${status}），已按降级处理")
        }

        var root: JsonValue
        try {
            root = JsonValue.parse(respText)
        } catch (_: Exception) {
            return YbHandlers.err("响应结构异常，按空结果处理")
        }

        var resp = root
        if (let Some(m0) <- root.asMap()) {
            // 注意：HashMap[key] 返回 V（键缺失抛 NoneValueException），安全取用必须 .get(key) → ?V
            // 而 JsonValue[key] 返回 ?JsonValue —— 两者不可混用
            if (let Some(r0) <- m0.get("Response")) {
                resp = r0
            }
        }
        if (let Some(rm) <- resp.asMap()) {
            if (let Some(e) <- rm.get("Error")) {
                let code = YbHandlers.fieldStr(e, "Code")
                return YbHandlers.err("API ${code}（不回显服务端原始消息）")
            }
        }

        let version = YbHandlers.fieldStr(resp, "Version")
        let requestId = YbHandlers.fieldStr(resp, "RequestId")

        // G6：Pages 每个元素是 JSON 字符串，必须二次 parse
        var rawPages = ArrayList<JsonValue>()
        if (let Some(rm2) <- resp.asMap()) {
            if (let Some(p) <- rm2.get("Pages")) {
                if (let Some(arr) <- p.asArray()) {
                    rawPages = arr
                }
            }
        }
        let docs = ArrayList<YbDoc>()
        var dropped: Int64 = 0
        for (p in rawPages) {
            var obj = p
            if (let Some(s) <- p.asString()) {
                try {
                    obj = JsonValue.parse(s)
                } catch (_: Exception) {
                    dropped = dropped + 1
                    continue
                }
            }
            let d = YbDoc()
            d.title = YbHandlers.fieldStr(obj, "title")
            d.url = YbHandlers.fieldStr(obj, "url")
            d.site = YbHandlers.fieldStr(obj, "site")
            d.date = YbHandlers.fieldStr(obj, "date")
            d.passage = YbHandlers.fieldStr(obj, "passage")
            let sv = YbHandlers.fieldNum(obj, "score")
            if (sv >= 0.0) {
                d.hasScore = true
                d.score = sv
            }
            let av = YbHandlers.fieldNum(obj, "authority_level")
            if (av >= 0.0) {
                d.hasAuthority = true
                d.authority = av
            }
            d.vr = YbHandlers.fieldBool(obj, "vr")
            // url 是溯源唯一依据，缺失即丢弃
            if (d.url.size == 0) {
                dropped = dropped + 1
                continue
            }
            docs.add(d)
        }

        // 批次内 min-max 归一化（G1：禁止跨批次比较、禁止写死阈值）
        var minS: Float64 = 0.0
        var maxS: Float64 = 0.0
        var hasAny: Bool = false
        for (d in docs) {
            if (d.hasScore) {
                if (!hasAny) {
                    minS = d.score
                    maxS = d.score
                    hasAny = true
                } else {
                    if (d.score < minS) { minS = d.score }
                    if (d.score > maxS) { maxS = d.score }
                }
            }
        }
        for (d in docs) {
            if (!d.hasScore) {
                d.scoreNorm = -1.0
            } else if (maxS == minS) {
                d.scoreNorm = 0.5
            } else {
                d.scoreNorm = (d.score - minS) / (maxS - minS)
            }
        }

        let kb = PolicyKb.load()
        if (!kb.ok) {
            eprintln("[yuanbao-policy] 政策原文库不可用：${kb.error}")
        }

        let items = ArrayList<JsonValue>()
        let excluded = ArrayList<JsonValue>()
        var authorityMissing: Int64 = 0
        let freshnessDays = YbHandlers.freshnessToDays(freshness)

        for (d in docs) {
            if (!d.hasAuthority) {
                authorityMissing = authorityMissing + 1
            }
            let (hit, policyNo, policyFile, evidence) = PolicyKb.matchPolicy(d.title, d.passage, kb)
            let kbHit = if (!kb.ok) { "库不可用" } else if (hit) { "已命中" } else { "未命中" }
            let item = YbHandlers.buildItem(d, freshnessDays, kbHit, policyNo, policyFile, evidence)
            let st = YbHandlers.fieldStr(item, "status")
            if (st == "可采信") {
                items.add(item)
            } else {
                excluded.add(item)
            }
        }

        if (version == "standard") {
            eprintln("[yuanbao-policy] 降级事件：本次服务档位为 standard")
        }
        if (docs.size > 0 && authorityMissing == docs.size) {
            eprintln("[yuanbao-policy] 降级事件：authority_level 整批缺失（${authorityMissing}/${docs.size}）")
        }
        if (dropped > 0) {
            eprintln("[yuanbao-policy] 丢弃 ${dropped} 条无效结果")
        }

        let out = HashMap<String, JsonValue>()
        out.add("ok", JsonValue.Boolean(true))
        out.add("requestId", JsonValue.String(requestId))
        out.add("version", JsonValue.String(version))
        out.add("elapsedMs", JsonValue.Number(Float64(elapsedMs)))
        out.add("degraded", JsonValue.Boolean(false))
        out.add("query", JsonValue.String(query))
        out.add("track", JsonValue.String("l3-process"))
        out.add("kb", JsonValue.Boolean(kb.ok))
        out.add("kbCount", JsonValue.Number(Float64(kb.count)))
        out.add("returned", JsonValue.Number(Float64(docs.size)))
        out.add("credible", JsonValue.Number(Float64(items.size)))
        out.add("excludedCount", JsonValue.Number(Float64(excluded.size)))
        out.add("items", JsonValue.Array(items))
        out.add("excluded", JsonValue.Array(excluded))
        return JsonValue.Map(out)
    }

    // ── selftest ──────────────────────────────────────────────

    private static func selftest(): JsonValue {
        let (secretId, secretKey) = YbSign.credential()
        let kb = PolicyKb.load()
        if (secretId.size == 0 || secretKey.size == 0) {
            let out = HashMap<String, JsonValue>()
            out.add("ok", JsonValue.Boolean(false))
            out.add("error", JsonValue.String("未配置云 API 密钥"))
            out.add("kb", JsonValue.Boolean(kb.ok))
            out.add("kbCount", JsonValue.Number(Float64(kb.count)))
            return JsonValue.Map(out)
        }
        let payload = HashMap<String, JsonValue>()
        payload.add("Query", JsonValue.String(YbHandlers.SELFTEST_QUERY))
        payload.add("Cnt", JsonValue.Number(10.0))
        let body = JsonValue.Map(payload).stringify()
        let headers = YbSign.buildHeaders(body, secretId, secretKey, YbSign.nowSeconds())
        let t0 = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        let (respText, status) = YbHttp.post(YbSign.ENDPOINT, body, headers)
        let elapsedMs = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - t0

        var version = ""
        var requestId = ""
        var pages: Int64 = 0
        if (respText.size > 0) {
            try {
                let root = JsonValue.parse(respText)
                var resp = root
                if (let Some(m0) <- root.asMap()) {
                    // 注意：HashMap[key] 返回 V（键缺失抛 NoneValueException），安全取用必须 .get(key) → ?V
            // 而 JsonValue[key] 返回 ?JsonValue —— 两者不可混用
            if (let Some(r0) <- m0.get("Response")) {
                        resp = r0
                    }
                }
                version = YbHandlers.fieldStr(resp, "Version")
                requestId = YbHandlers.fieldStr(resp, "RequestId")
                if (let Some(rm) <- resp.asMap()) {
                    if (let Some(p) <- rm.get("Pages")) {
                        if (let Some(arr) <- p.asArray()) {
                            pages = arr.size
                        }
                    }
                }
            } catch (_: Exception) {
                eprintln("[yuanbao-policy] 自检响应解析失败")
            }
        }

        eprintln("[yuanbao-policy] 自检：HTTP=${status} 档位=${version} 条数=${pages} 耗时=${elapsedMs}ms 原文库=${kb.ok}(${kb.count})")

        let out = HashMap<String, JsonValue>()
        out.add("ok", JsonValue.Boolean(respText.size > 0))
        out.add("status", JsonValue.String(status))
        out.add("version", JsonValue.String(version))
        out.add("requestId", JsonValue.String(requestId))
        out.add("pages", JsonValue.Number(Float64(pages)))
        out.add("elapsedMs", JsonValue.Number(Float64(elapsedMs)))
        out.add("kb", JsonValue.Boolean(kb.ok))
        out.add("kbCount", JsonValue.Number(Float64(kb.count)))
        out.add("track", JsonValue.String("l3-process"))
        return JsonValue.Map(out)
    }

    // ── 可信度四因子合成（与脚本轨同规则） ─────────────────────

    private static func buildItem(
        d: YbDoc,
        freshnessDays: Int64,
        kbHit: String,
        policyNo: String,
        policyFile: String,
        evidence: String
    ): JsonValue {
        // 权威度：≥4 高 / =3 中 / ≤2 低 / 缺失不可用
        var authority = "不可用"
        var authorityNote = "本次服务档位未提供"
        if (d.hasAuthority) {
            if (d.authority >= 4.0) {
                authority = "高"
                authorityNote = "${d.authority}(高)"
            } else if (d.authority >= 3.0) {
                authority = "中"
                authorityNote = "${d.authority}(中)"
            } else {
                authority = "低"
                authorityNote = "${d.authority}(低)"
            }
        }

        // 信源分级
        let hay = (d.site + " " + d.url).toAsciiLower()
        var sourceTier = "最低"
        var sourceNote = if (d.site.size == 0) { "site 为空（未知站点）" } else { "${d.site}（未知站点）" }
        var isGov = false
        for (h in YbHandlers.GOV_HINTS) {
            if (hay.contains(h)) {
                sourceTier = "最高"
                sourceNote = "${d.site}（政府信源）"
                isGov = true
                break
            }
        }
        if (!isGov) {
            for (h in YbHandlers.PORTAL_HINTS) {
                if (hay.contains(h)) {
                    sourceTier = "中间"
                    sourceNote = "${d.site}（门户/机构）"
                    break
                }
            }
        }

        // 时效：L3 轨按发布年份近似判定（脚本轨精确到日）
        var freshness = "未知"
        var freshnessNote = "无发布时间"
        let year = YbHandlers.extractYear(d.date)
        if (year > 0) {
            let nowYear = DateTime.nowUTC().year
            let windowYears = if (freshnessDays > 0) { freshnessDays / 365 + 1 } else { 1 }
            if (nowYear - year > windowYears) {
                freshness = "已过期"
                freshnessNote = "${d.date} 超出时效窗（按年份近似）"
            } else {
                freshness = "现行有效"
                freshnessNote = "${d.date} 在时效窗内（按年份近似）"
            }
        } else if (d.date.size > 0) {
            freshnessNote = "日期无法解析(${d.date})"
        }

        // 档位降级链
        var level = if (sourceTier == "最高") { "高" } else if (sourceTier == "中间") { "中" } else { "低" }
        if (freshness == "已过期" || freshness == "未知") {
            level = YbHandlers.downgrade(level)
        }
        if (authority == "低" || authority == "不可用") {
            level = YbHandlers.downgrade(level)
        }

        // 可核验出处门禁（v1.1）
        var status = "可采信"
        var gate = "具备可核验出处"
        if (sourceTier == "最低") {
            status = "待核实"
            gate = "信源不可核验（未知站点/自媒体）"
        }
        if (freshness == "已过期") {
            status = "待核实"
            gate = "已超出时效窗（过期政策不作申报依据）"
        }
        if (kbHit == "库不可用" && sourceTier != "最高") {
            status = "待核实"
            gate = "原文库不可用且非政府信源"
        }

        var kbNote = "库不可用"
        if (kbHit == "已命中") {
            kbNote = "已命中(policy_no=${policyNo}, ${evidence})"
        } else if (kbHit == "未命中") {
            kbNote = "未命中（未在本地政策原文库备案，需人工复核）"
        }
        var reason = "权威度=${authorityNote}；信源=${sourceTier}(${sourceNote})；时效=${freshness}(${freshnessNote})；原文库=${kbNote} → 结论状态：${status}（门禁：${gate}）"
        if (status == "待核实") {
            reason = reason + "，已排除出正式报告"
        }

        let cred = HashMap<String, JsonValue>()
        cred.add("authority", JsonValue.String(authority))
        cred.add("sourceTier", JsonValue.String(sourceTier))
        cred.add("freshness", JsonValue.String(freshness))
        cred.add("kbHit", JsonValue.String(kbHit))
        cred.add("policyNo", JsonValue.String(policyNo))
        cred.add("policyFile", JsonValue.String(policyFile))
        cred.add("status", JsonValue.String(status))
        cred.add("level", JsonValue.String(level))
        cred.add("reason", JsonValue.String(reason))

        let item = HashMap<String, JsonValue>()
        item.add("title", JsonValue.String(d.title))
        item.add("url", JsonValue.String(d.url))
        item.add("site", JsonValue.String(d.site))
        item.add("date", JsonValue.String(d.date))
        item.add("passage", JsonValue.String(d.passage))
        item.add("status", JsonValue.String(status))
        item.add("credibility", JsonValue.Map(cred))
        if (d.scoreNorm >= 0.0) {
            item.add("scoreNorm", JsonValue.Number(d.scoreNorm))
        }
        if (d.hasAuthority) {
            item.add("authorityLevel", JsonValue.Number(d.authority))
        }
        if (d.vr) {
            item.add("vr", JsonValue.Boolean(true))
        }
        if (policyNo.size > 0) {
            item.add("policyNo", JsonValue.String(policyNo))
        }
        return JsonValue.Map(item)
    }

    // ── 辅助 ──────────────────────────────────────────────────

    private static func downgrade(level: String): String {
        if (level == "高") {
            return "中"
        }
        if (level == "中") {
            return "低"
        }
        return "低"
    }

    private static func clampCnt(v: Float64): Int64 {
        let enums = [10, 20, 30, 40, 50]
        if (v <= 0.0) {
            return 50
        }
        var best: Int64 = 50
        var bestDiff: Float64 = 1000000.0
        for (e in enums) {
            let diff = if (v - Float64(e) >= 0.0) { v - Float64(e) } else { Float64(e) - v }
            if (diff < bestDiff) {
                bestDiff = diff
                best = e
            }
        }
        return best
    }

    /// freshness → 天数（用于时效窗近似）；无法识别返回 0（按 1 年兜底）
    private static func freshnessToDays(freshness: String): Int64 {
        if (freshness.size == 0) {
            return 0
        }
        if (freshness.startsWith("y")) {
            let n = YbHandlers.tailNumber(freshness)
            if (n > 0) {
                return n * 365
            }
        }
        if (freshness.startsWith("m")) {
            let n = YbHandlers.tailNumber(freshness)
            if (n > 0) {
                return n * 30
            }
        }
        if (freshness.startsWith("d")) {
            let n = YbHandlers.tailNumber(freshness)
            if (n > 0) {
                return n
            }
        }
        return 0
    }

    private static func tailNumber(s: String): Int64 {
        var v: Int64 = 0
        var any = false
        for (r in s.toRuneArray()) {
            if (r >= r'0' && r <= r'9') {
                v = v * 10 + YbHandlers.digitOf(r)
                any = true
            }
        }
        if (any) {
            return v
        }
        return 0
    }

    private static func digitOf(r: Rune): Int64 {
        if (r == r'0') { return 0 }
        if (r == r'1') { return 1 }
        if (r == r'2') { return 2 }
        if (r == r'3') { return 3 }
        if (r == r'4') { return 4 }
        if (r == r'5') { return 5 }
        if (r == r'6') { return 6 }
        if (r == r'7') { return 7 }
        if (r == r'8') { return 8 }
        return 9
    }

    /// 从日期串取年份（前 4 位数字）；取不到返回 -1
    private static func extractYear(s: String): Int64 {
        let runes = s.toRuneArray()
        if (runes.size < 4) {
            return -1
        }
        var v: Int64 = 0
        for (i in 0..4) {
            let r = runes[i]
            if (r < r'0' || r > r'9') {
                return -1
            }
            v = v * 10 + YbHandlers.digitOf(r)
        }
        return v
    }

    private static func fieldStr(v: JsonValue, key: String): String {
        if (let Some(m) <- v.asMap()) {
            if (let Some(x) <- m.get(key)) {
                return x.asString().getOrDefault({ => "" })
            }
        }
        return ""
    }

    /// 取数字字段；缺失或非数字返回 -1
    private static func fieldNum(v: JsonValue, key: String): Float64 {
        if (let Some(m) <- v.asMap()) {
            if (let Some(x) <- m.get(key)) {
                if (let Some(n) <- x.asNumber()) {
                    return n
                }
            }
        }
        return -1.0
    }

    private static func fieldBool(v: JsonValue, key: String): Bool {
        if (let Some(m) <- v.asMap()) {
            if (let Some(x) <- m.get(key)) {
                if (let Some(b) <- x.asBool()) {
                    return b
                }
            }
        }
        return false
    }

    private static func err(message: String): JsonValue {
        eprintln("[yuanbao-policy] 失败：${message}")
        let out = HashMap<String, JsonValue>()
        out.add("ok", JsonValue.Boolean(false))
        out.add("degraded", JsonValue.Boolean(true))
        out.add("error", JsonValue.String(message))
        out.add("items", JsonValue.Array(ArrayList<JsonValue>()))
        out.add("excluded", JsonValue.Array(ArrayList<JsonValue>()))
        return JsonValue.Map(out)
    }
}
