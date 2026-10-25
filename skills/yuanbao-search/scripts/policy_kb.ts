#!/usr/bin/env node
/**
 * policy_kb.ts — 政策原文库交叉验证器（design §2.5.6 / M6）
 *
 * 输入：检索条目标题；底座：beichen-policy-assistant 的 policy-index.json（74 条北京政策）。
 * 输出：是否命中 + 命中的 policy_no / 原文路径。
 *
 * 算法（确定性，不依赖 LLM）：
 *   1. 归一化：全角转半角 → 去空白 → 去标点；
 *   2. 2-gram 字符集 → Jaccard 相似度 J = |A∩B| / |A∪B|；
 *   3. 命中条件：J ≥ 0.6，或一方包含另一方且被包含长度 ≥ 80%。
 *
 * 强约束（design G14）：索引不可解析 → kbHit = 库不可用 → 调用方须将所有结论置「待核实」。
 */
import * as fs from "node:fs";
import * as path from "node:path";

const __dirname = import.meta.dirname;

export interface PolicyEntry {
  policy_no: string;
  domain: string;
  level: string;
  department: string;
  title: string;
  status: string;
  file: string;
}

export interface PolicyKb {
  /** 索引是否可用；false 时调用方必须把所有结论置「待核实」（G14） */
  ok: boolean;
  count: number;
  indexPath: string;
  entries: PolicyEntry[];
  error: string;
}

export interface KbMatch {
  hit: boolean;
  policyNo: string;
  policyTitle: string;
  file: string;
  /** Jaccard 相似度；库不可用时为 0 */
  score: number;
  /** 命中证据来源：title=标题相似 / fulltext=正文出现政策全名 / ""=未命中 */
  evidence: string;
}

/** 默认索引路径：../beichen-policy-assistant/knowledge/policy-index.json */
export function defaultKbPath(): string {
  return path.resolve(
    __dirname,
    "../../beichen-policy-assistant/knowledge/policy-index.json"
  );
}

const PUNCT = /[()（）【】[\]《》·,.，。、/\\:：;；'"“”‘’!？?\-_—|]/g;

/** 全角转半角 + 去空白 + 去标点 */
export function normalizeTitle(s: string): string {
  if (!s) return "";
  let out = "";
  for (const ch of String(s)) {
    const code = ch.charCodeAt(0);
    // 全角空格 → 半角；全角 ！～ → 半角
    if (code === 0x3000) {
      out += " ";
      continue;
    }
    if (code >= 0xff01 && code <= 0xff5e) {
      out += String.fromCharCode(code - 0xfee0);
      continue;
    }
    out += ch;
  }
  return out.replace(/\s+/g, "").replace(PUNCT, "").toLowerCase();
}

/** 2-gram 字符集（按字符而非字节，中文安全） */
export function bigrams(s: string): Set<string> {
  const arr = Array.from(s);
  const out = new Set<string>();
  if (arr.length === 0) return out;
  if (arr.length === 1) {
    out.add(arr[0]);
    return out;
  }
  for (let i = 0; i < arr.length - 1; i++) out.add(arr[i] + arr[i + 1]);
  return out;
}

/**
 * 重叠系数 |A∩B| / min(|A|,|B|)
 * 相比 Jaccard 对"一方是另一方的措辞扩展版"更鲁棒：
 * 长通知标题里嵌着短政策名时，Jaccard 被分母摊薄，重叠系数不会。
 */
export function overlap(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  const small = a.size <= b.size ? a : b;
  const big = a.size <= b.size ? b : a;
  let inter = 0;
  small.forEach((v) => {
    if (big.has(v)) inter++;
  });
  return inter / small.size;
}

export function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let inter = 0;
  const small = a.size <= b.size ? a : b;
  const big = a.size <= b.size ? b : a;
  small.forEach((v) => {
    if (big.has(v)) inter++;
  });
  const union = a.size + b.size - inter;
  return union === 0 ? 0 : inter / union;
}

/**
 * 加载政策索引。任何解析失败都返回 ok:false（不抛异常），由调用方降级。
 */
export function loadKb(kbPath?: string): PolicyKb {
  const target = kbPath && kbPath.length > 0 ? kbPath : defaultKbPath();
  const empty: PolicyKb = {
    ok: false,
    count: 0,
    indexPath: target,
    entries: [],
    error: "",
  };
  let raw = "";
  try {
    if (!fs.existsSync(target)) {
      empty.error = `政策索引不存在：${target}`;
      return empty;
    }
    raw = fs.readFileSync(target, "utf8");
  } catch (e: any) {
    empty.error = `政策索引读取失败：${e && e.message ? e.message : String(e)}`;
    return empty;
  }
  try {
    const parsed = JSON.parse(raw);
    const list = Array.isArray(parsed) ? parsed : parsed && parsed.policies;
    if (!Array.isArray(list)) {
      empty.error = "政策索引结构异常：未找到 policies 数组";
      return empty;
    }
    const entries: PolicyEntry[] = [];
    for (const it of list) {
      if (!it || typeof it !== "object") continue;
      entries.push({
        policy_no: String((it as any).policy_no ?? ""),
        domain: String((it as any).domain ?? ""),
        level: String((it as any).level ?? ""),
        department: String((it as any).department ?? ""),
        title: String((it as any).title ?? ""),
        status: String((it as any).status ?? ""),
        file: String((it as any).file ?? ""),
      });
    }
    if (entries.length === 0) {
      empty.error = "政策索引为空";
      return empty;
    }
    return { ok: true, count: entries.length, indexPath: target, entries, error: "" };
  } catch (e: any) {
    empty.error = `政策索引解析失败：${e && e.message ? e.message : String(e)}`;
    return empty;
  }
}

/** 构建归一化索引（启动时一次，74 条规模开销可忽略） */
export interface KbIndex {
  kb: PolicyKb;
  norms: string[];
  grams: Set<string>[];
}

export function buildIndex(kb: PolicyKb): KbIndex {
  const norms: string[] = [];
  const grams: Set<string>[] = [];
  for (const p of kb.entries) {
    const n = normalizeTitle(p.title);
    norms.push(n);
    grams.push(bigrams(n));
  }
  return { kb, norms, grams };
}

const J_THRESHOLD = 0.6;
const COVER_RATIO = 0.8;
/** 正文全名命中的最短政策名长度（太短的名字容易误命中） */
const FULLTEXT_MIN_LEN = 8;
/** 核心名重叠系数阈值 + 最短 gram 数（低于此规模的重叠不可靠） */
const OVERLAP_THRESHOLD = 0.75;
const OVERLAP_MIN_GRAMS = 8;

/**
 * 交叉验证：命中 → 绑定 policy_no 与原文路径。
 *
 * 两级证据（2026-10-25 修订，理由见 design §2.5.6 修订记录）：
 *   1. 标题级：2-gram Jaccard ≥ 0.6，或一方包含另一方且较短者占比 ≥ 80%；
 *   2. 正文级：政策全名（≥8 字）出现在「标题 + 摘要」归一化文本中 —— 申报通知常以
 *      "根据《XXX 若干措施》…" 的形式引用政策，标题比对天然低分，必须靠正文兜住。
 */
export function matchPolicy(title: string, passage: string, index: KbIndex): KbMatch {
  const miss: KbMatch = { hit: false, policyNo: "", policyTitle: "", file: "", score: 0, evidence: "" };
  if (!index.kb.ok) return miss;
  const n = normalizeTitle(title);
  if (!n) return miss;
  const g = bigrams(n);

  let best = 0;
  let bestAt = -1;
  for (let i = 0; i < index.grams.length; i++) {
    const other = index.norms[i];
    if (!other) continue;
    const shorter = n.length <= other.length ? n : other;
    const longer = n.length <= other.length ? other : n;
    if (longer.includes(shorter) && longer.length > 0 && shorter.length / longer.length >= COVER_RATIO) {
      return {
        hit: true,
        policyNo: index.kb.entries[i].policy_no,
        policyTitle: index.kb.entries[i].title,
        file: index.kb.entries[i].file,
        score: Math.max(jaccard(g, index.grams[i]), shorter.length / longer.length),
        evidence: "title",
      };
    }
    const j = jaccard(g, index.grams[i]);
    if (j > best) {
      best = j;
      bestAt = i;
    }
  }
  if (best >= J_THRESHOLD && bestAt >= 0) {
    return {
      hit: true,
      policyNo: index.kb.entries[bestAt].policy_no,
      policyTitle: index.kb.entries[bestAt].title,
      file: index.kb.entries[bestAt].file,
      score: best,
      evidence: "title",
    };
  }

  // 三级证据：核心名重叠系数（长标题里嵌着政策名时 Jaccard 会被摊薄）
  let bestOv = 0;
  let bestOvAt = -1;
  for (let i = 0; i < index.grams.length; i++) {
    const other = index.grams[i];
    if (other.size < OVERLAP_MIN_GRAMS) continue;
    const ov = overlap(g, other);
    if (ov > bestOv) {
      bestOv = ov;
      bestOvAt = i;
    }
  }
  if (bestOv >= OVERLAP_THRESHOLD && bestOvAt >= 0) {
    return {
      hit: true,
      policyNo: index.kb.entries[bestOvAt].policy_no,
      policyTitle: index.kb.entries[bestOvAt].title,
      file: index.kb.entries[bestOvAt].file,
      score: bestOv,
      evidence: "core",
    };
  }

  // 二级证据：正文（标题 + 摘要）中出现政策全名
  const blob = normalizeTitle(`${title} ${passage}`);
  if (blob.length > 0) {
    for (let i = 0; i < index.norms.length; i++) {
      const name = index.norms[i];
      if (name.length < FULLTEXT_MIN_LEN) continue;
      if (blob.includes(name)) {
        return {
          hit: true,
          policyNo: index.kb.entries[i].policy_no,
          policyTitle: index.kb.entries[i].title,
          file: index.kb.entries[i].file,
          score: 1,
          evidence: "fulltext",
        };
      }
    }
  }
  return { ...miss, score: best };
}
