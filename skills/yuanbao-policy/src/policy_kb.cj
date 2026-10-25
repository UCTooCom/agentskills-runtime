/*
 * policy_kb.cj — 政策原文库交叉验证器（与脚本轨 policy_kb.ts / .py 同规则）
 *
 * 三级证据：
 *   1. title    ：标题级 2-gram Jaccard ≥ 0.6，或包含覆盖 ≥ 80%
 *   2. core     ：核心名重叠系数 ≥ 0.75（长通知标题里嵌着短政策名时 Jaccard 会被摊薄）
 *   3. fulltext ：政策全名（≥8 字）出现在「标题 + 摘要」归一化文本中
 *
 * 索引不可解析 → ok=false → 调用方按门禁把「非政府信源」结论置待核实（G14 v1.1）。
 */
package skill_yuanbao_policy

import std.collection.{HashMap, ArrayList}
import std.fs.File
import jsonvalue.*

public class PolicyEntry {
    public let policyNo: String
    public let title: String
    public let file: String

    public init(policyNo: String, title: String, file: String) {
        this.policyNo = policyNo
        this.title = title
        this.file = file
    }
}

public class PolicyKb {
    public let ok: Bool
    public let count: Int64
    public let indexPath: String
    public let error: String
    public let entries: ArrayList<PolicyEntry>
    public let norms: ArrayList<String>
    public let grams: ArrayList<HashMap<String, Bool>>

    public init() {
        this.ok = false
        this.count = 0
        this.indexPath = ""
        this.error = ""
        this.entries = ArrayList<PolicyEntry>()
        this.norms = ArrayList<String>()
        this.grams = ArrayList<HashMap<String, Bool>>()
    }

    public init(indexPath: String, entries: ArrayList<PolicyEntry>, error: String) {
        this.indexPath = indexPath
        this.entries = entries
        this.error = error
        this.ok = error.size == 0 && entries.size > 0
        this.count = entries.size
        this.norms = ArrayList<String>()
        this.grams = ArrayList<HashMap<String, Bool>>()
        for (e in entries) {
            let n = PolicyKb.normalize(e.title)
            this.norms.add(n)
            this.grams.add(PolicyKb.bigrams(n))
        }
    }

    /// 默认索引位置：../beichen-policy-assistant/knowledge/policy-index.json
    /// 逐个尝试候选路径（进程工作目录由宿主决定）
    public static func load(): PolicyKb {
        let candidates = [
            "./skills/beichen-policy-assistant/knowledge/policy-index.json",
            "../skills/beichen-policy-assistant/knowledge/policy-index.json",
            "../../skills/beichen-policy-assistant/knowledge/policy-index.json",
            "../../../skills/beichen-policy-assistant/knowledge/policy-index.json",
            "../../../../skills/beichen-policy-assistant/knowledge/policy-index.json",
        ]
        for (p in candidates) {
            let kb = PolicyKb.loadFrom(p)
            if (kb.ok) {
                return kb
            }
        }
        return PolicyKb()
    }

    public static func loadFrom(path: String): PolicyKb {
        var text = ""
        try {
            text = String.fromUtf8(File.readFrom(path))
        } catch (_: Exception) {
            return PolicyKb(path, ArrayList<PolicyEntry>(), "政策索引读取失败")
        }
        if (text.size == 0) {
            return PolicyKb(path, ArrayList<PolicyEntry>(), "政策索引为空")
        }
        var root: JsonValue
        try {
            root = JsonValue.parse(text)
        } catch (_: Exception) {
            return PolicyKb(path, ArrayList<PolicyEntry>(), "政策索引解析失败")
        }
        var items = ArrayList<JsonValue>()
        if (let Some(arr) <- root.asArray()) {
            items = arr
        } else if (let Some(m) <- root.asMap()) {
            // HashMap[key] 返回 V（键缺失抛 NoneValueException），安全取用必须 .get(key) → ?V
            if (let Some(p) <- m.get("policies")) {
                if (let Some(arr2) <- p.asArray()) {
                    items = arr2
                }
            }
        }
        if (items.size == 0) {
            return PolicyKb(path, ArrayList<PolicyEntry>(), "未找到 policies 数组")
        }
        let entries = ArrayList<PolicyEntry>()
        for (it in items) {
            if (let Some(m2) <- it.asMap()) {
                let no = PolicyKb.strOf(m2, "policy_no")
                let title = PolicyKb.strOf(m2, "title")
                let file = PolicyKb.strOf(m2, "file")
                if (title.size > 0) {
                    entries.add(PolicyEntry(no, title, file))
                }
            }
        }
        if (entries.size == 0) {
            return PolicyKb(path, entries, "政策索引为空")
        }
        return PolicyKb(path, entries, "")
    }

    /// 归一化：去空白 + 去标点（按 Rune 处理，中文安全）
    public static func normalize(s: String): String {
        let runes = s.toRuneArray()
        let out = ArrayList<Rune>()
        for (r in runes) {
            if (PolicyKb.isSkippable(r)) {
                continue
            }
            out.add(r)
        }
        return String(out.toArray())
    }

    public static func bigrams(s: String): HashMap<String, Bool> {
        let m = HashMap<String, Bool>()
        let runes = s.toRuneArray()
        if (runes.size == 0) {
            return m
        }
        if (runes.size == 1) {
            m.add(String(Array<Rune>(1, { _ => runes[0] })), true)
            return m
        }
        for (i in 0..runes.size - 1) {
            let idx = i
            m.add(String(Array<Rune>(2, { k => runes[idx + k] })), true)
        }
        return m
    }

    public static func jaccard(a: HashMap<String, Bool>, b: HashMap<String, Bool>): Float64 {
        let inter = PolicyKb.intersectSize(a, b)
        let union = Float64(a.size + b.size) - inter
        if (union <= 0.0) {
            return 0.0
        }
        return inter / union
    }

    /// 重叠系数 |A∩B| / min(|A|,|B|)
    public static func overlap(a: HashMap<String, Bool>, b: HashMap<String, Bool>): Float64 {
        let small = if (a.size <= b.size) { a.size } else { b.size }
        if (small <= 0) {
            return 0.0
        }
        return PolicyKb.intersectSize(a, b) / Float64(small)
    }

    public static func intersectSize(a: HashMap<String, Bool>, b: HashMap<String, Bool>): Float64 {
        var n: Float64 = 0.0
        for ((k, v) in a) {
            if (b.get(k).isSome()) {
                n = n + 1.0
            }
        }
        return n
    }

    /// 交叉验证：命中返回 (policyNo, file, evidence)
    /// 注：`match` 是仓颉关键字，不能作函数名，故用 matchPolicy
    public static func matchPolicy(title: String, passage: String, kb: PolicyKb): (Bool, String, String, String) {
        if (!kb.ok) {
            return (false, "", "", "")
        }
        let n = PolicyKb.normalize(title)
        if (n.size == 0) {
            return (false, "", "", "")
        }
        let g = PolicyKb.bigrams(n)

        var bestJ: Float64 = 0.0
        var bestAt: Int64 = -1
        for (i in 0..kb.norms.size) {
            let other = kb.norms[i]
            if (other.size == 0) {
                continue
            }
            // 包含覆盖：较短者占较长者比例 ≥ 80%
            let shorter = if (n.size <= other.size) { n } else { other }
            let longer = if (n.size <= other.size) { other } else { n }
            if (longer.size > 0 && longer.contains(shorter) && Float64(shorter.size) / Float64(longer.size) >= 0.8) {
                return (true, kb.entries[i].policyNo, kb.entries[i].file, "title")
            }
            let j = PolicyKb.jaccard(g, kb.grams[i])
            if (j > bestJ) {
                bestJ = j
                bestAt = i
            }
        }
        if (bestJ >= 0.6 && bestAt >= 0) {
            return (true, kb.entries[bestAt].policyNo, kb.entries[bestAt].file, "title")
        }

        var bestOv: Float64 = 0.0
        var bestOvAt: Int64 = -1
        for (i in 0..kb.grams.size) {
            if (kb.grams[i].size < 8) {
                continue
            }
            let ov = PolicyKb.overlap(g, kb.grams[i])
            if (ov > bestOv) {
                bestOv = ov
                bestOvAt = i
            }
        }
        if (bestOv >= 0.75 && bestOvAt >= 0) {
            return (true, kb.entries[bestOvAt].policyNo, kb.entries[bestOvAt].file, "core")
        }

        let blob = PolicyKb.normalize(title + " " + passage)
        if (blob.size > 0) {
            for (i in 0..kb.norms.size) {
                if (kb.norms[i].size < 8) {
                    continue
                }
                if (blob.contains(kb.norms[i])) {
                    return (true, kb.entries[i].policyNo, kb.entries[i].file, "fulltext")
                }
            }
        }
        return (false, "", "", "")
    }

    private static func strOf(m: HashMap<String, JsonValue>, key: String): String {
        if (let Some(v) <- m.get(key)) {
            return v.asString().getOrDefault({ => "" })
        }
        return ""
    }

    private static func isSkippable(r: Rune): Bool {
        if (r == r' ' || r == r'\t' || r == r'\n' || r == r'\r') {
            return true
        }
        let punct = "()（）【】[]《》·,.，。、/\\:;；'\"“”‘’!！？?-_—|"
        return punct.contains(r.toString())
    }
}
