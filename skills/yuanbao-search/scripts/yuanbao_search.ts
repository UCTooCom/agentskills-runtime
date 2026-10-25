#!/usr/bin/env node
/**
 * yuanbao_search.ts — 元宝搜索检索内核（SearchPro）+ 可信度四因子标注 + 政策原文库交叉验证
 * 功能与 yuanbao_search.py 完全一致
 *
 * 运行方式:
 *   node --experimental-strip-types yuanbao_search.ts --query "专精特新 中小企业 申报 条件" --industry gov --cnt 50 --freshness 1y
 *   node --experimental-strip-types yuanbao_search.ts --selftest
 *
 * 输出: stdout 单行 JSON（结构与 design §2.7.2 / spec §6.2 一致）；诊断与心跳一律 stderr。
 */
import * as fs from "node:fs";
import * as path from "node:path";
import { spawn } from "node:child_process";
import {
  CredentialError,
  WSA_ENDPOINT,
  buildSignedRequest,
  loadCredential,
} from "./sign.ts";
import {
  buildIndex,
  loadKb,
  matchPolicy,
  type KbIndex,
  type PolicyKb,
} from "./policy_kb.ts";

const __dirname = import.meta.dirname;

// ───────────────────────── 常量（实测约束，勿随意改） ─────────────────────────

const HTTP_CLIENT_PATH = path.resolve(
  __dirname,
  "../../http-client/scripts/http_client.ts"
);
const CNT_ENUM = [10, 20, 30, 40, 50];
const TIMEOUT_MS = 5000; // spec §4.1：单次检索 ≤5s
const MAX_RETRY = 2; // spec §4.2：退避重试至多 2 次
const QUERY_MAX = 200;

const GOV_HINTS = [".gov.cn", "gov.cn", ".gov.", "beijing.gov"];
const PORTAL_HINTS = [
  "xinhuanet.com",
  "people.com.cn",
  "cctv.com",
  "cctv.cn",
  "chinadaily.com.cn",
  "chinanews.com.cn",
  "news.cn",
  "workercn.cn",
  "gmw.cn",
  "people.com",
  "163.com",
  "sina.com.cn",
  "sohu.com",
  "qq.com",
  "baidu.com",
  "zhihu.com",
];

// ───────────────────────── 参数解析 ─────────────────────────

interface CliArgs {
  query: string;
  industry: string;
  freshness: string;
  site: string;
  exclude: string;
  cnt: number;
  deeplinks: boolean;
  selftest: boolean;
  pretty: boolean;
  envFile: string;
  kbPath: string;
  noKb: boolean;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = {
    query: "",
    industry: "gov",
    freshness: "",
    site: "",
    exclude: "",
    cnt: 50,
    deeplinks: false,
    selftest: false,
    pretty: false,
    envFile: "",
    kbPath: "",
    noKb: false,
  };
  const need = (i: number, name: string): string => {
    const v = argv[i + 1];
    if (v === undefined || v.startsWith("--")) {
      fail(`参数 ${name} 缺少取值`, 2);
    }
    return v;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--query":
        args.query = need(i, "--query");
        i++;
        break;
      case "--industry":
        args.industry = need(i, "--industry");
        i++;
        break;
      case "--freshness":
        args.freshness = need(i, "--freshness");
        i++;
        break;
      case "--site":
        args.site = need(i, "--site");
        i++;
        break;
      case "--exclude":
        args.exclude = need(i, "--exclude");
        i++;
        break;
      case "--cnt":
        args.cnt = Number(need(i, "--cnt"));
        i++;
        break;
      case "--env-file":
        args.envFile = need(i, "--env-file");
        i++;
        break;
      case "--kb":
        args.kbPath = need(i, "--kb");
        i++;
        break;
      case "--deeplinks":
        args.deeplinks = true;
        break;
      case "--selftest":
        args.selftest = true;
        break;
      case "--json":
        break; // 默认即单行 JSON
      case "--pretty":
        args.pretty = true;
        break;
      case "--no-kb":
        args.noKb = true;
        break;
      case "--help":
      case "-h":
        printUsage();
        process.exit(0);
      default:
        fail(`未知参数：${a}`, 2);
    }
  }
  return args;
}

function printUsage(): void {
  process.stderr.write(
    [
      "用法:",
      "  yuanbao_search.ts --query \"检索词\" [--industry gov|news|acad|finance]",
      "    [--freshness d7|m3|y1|1d|1w|1m|1y|YYYY-MM-DD|YYYY-MM-DD..YYYY-MM-DD]",
      "    [--site <域名>] [--exclude <d1|d2|...最多5个>] [--cnt 10|20|30|40|50]",
      "    [--deeplinks] [--selftest] [--pretty] [--no-kb] [--env-file <path>] [--kb <path>]",
      "",
    ].join("\n")
  );
}

function fail(msg: string, code: number): never {
  process.stderr.write(`[yuanbao-search] 错误：${msg}\n`);
  process.exit(code);
}

// ───────────────────────── M2 检索编排 ─────────────────────────

/** Cnt 收敛到枚举 {10,20,30,40,50}（取最接近档位） */
function clampCnt(cnt: number): number {
  if (!Number.isFinite(cnt) || cnt <= 0) return 50;
  let best = CNT_ENUM[0];
  let bestDiff = Math.abs(cnt - best);
  for (const c of CNT_ENUM) {
    const d = Math.abs(cnt - c);
    if (d < bestDiff) {
      best = c;
      bestDiff = d;
    }
  }
  return best;
}

/**
 * 时效窗归一化 → API 的 Freshness 形态：d[N](1-30) / m[N](1-12) / y[N](1-5) / YYYY-MM-DD / A,B
 * 友好写法 1d / 1w(=d7) / 1m / 1y 与 "A..B" 一并兼容；无法识别时返回空串（调用方降级为不传）。
 */
function normalizeFreshness(raw: string, warn: (s: string) => void): { value: string; days: number } {
  const s = (raw || "").trim();
  if (!s) return { value: "", days: 0 };
  const clamp = (n: number, lo: number, hi: number): number =>
    Math.min(hi, Math.max(lo, n));

  let m = s.match(/^(\d+)\s*(d|w|m|y)$/i);
  if (m) {
    const n = parseInt(m[1], 10);
    const unit = m[2].toLowerCase();
    if (unit === "d") return { value: `d${clamp(n, 1, 30)}`, days: clamp(n, 1, 30) };
    if (unit === "w") return { value: `d${clamp(n * 7, 1, 30)}`, days: clamp(n * 7, 1, 30) };
    if (unit === "m") return { value: `m${clamp(n, 1, 12)}`, days: clamp(n, 1, 12) * 30 };
    return { value: `y${clamp(n, 1, 5)}`, days: clamp(n, 1, 5) * 365 };
  }
  m = s.match(/^(d|m|y)(\d+)$/i);
  if (m) {
    const unit = m[1].toLowerCase();
    const n = parseInt(m[2], 10);
    if (unit === "d") return { value: `d${clamp(n, 1, 30)}`, days: clamp(n, 1, 30) };
    if (unit === "m") return { value: `m${clamp(n, 1, 12)}`, days: clamp(n, 1, 12) * 30 };
    return { value: `y${clamp(n, 1, 5)}`, days: clamp(n, 1, 5) * 365 };
  }
  m = s.match(/^(\d{4}-\d{2}-\d{2})(?:\.\.(\d{4}-\d{2}-\d{2}))?$/);
  if (m) {
    if (m[2]) return { value: `${m[1]},${m[2]}`, days: 0 };
    return { value: m[1], days: 0 };
  }
  warn(`--freshness 取值无法识别（${s}），本次不携带时效窗`);
  return { value: "", days: 0 };
}

interface BuiltPayload {
  payload: Record<string, unknown>;
  freshnessDays: number;
}

function buildPayload(args: CliArgs, warn: (s: string) => void): BuiltPayload {
  if (args.site && args.exclude) {
    fail("--site 与 --exclude 互斥，请只指定其中一个", 2);
  }
  if (args.exclude) {
    const parts = args.exclude
      .split("|")
      .map((x) => x.trim())
      .filter((x) => x.length > 0);
    if (parts.length > 5) fail("--exclude 最多支持 5 个域名（| 分隔）", 2);
  }
  const payload: Record<string, unknown> = { Query: args.query };
  if (args.industry) payload.Industry = args.industry;
  payload.Cnt = clampCnt(args.cnt);
  // Mode 默认不携带：实测 Mode=1 旗舰版仅召回 1 条且无 score（design R3 / G4）
  if (args.site) payload.Site = args.site.trim();
  else if (args.exclude) payload.Site = `exclude:${args.exclude.trim()}`;
  if (args.deeplinks) payload.Deeplinks = true;
  const fr = normalizeFreshness(args.freshness, warn);
  if (fr.value) payload.Freshness = fr.value;
  return { payload, freshnessDays: fr.days };
}

// ───────────────────────── 传输层（复用 http_client.ts，失败回退内置 fetch） ─────────────────────────

interface RawResponse {
  status: number | null;
  body: any;
  error: string | null;
  transport: string;
}

function viaHttpClient(url: string, body: string, headers: Record<string, string>, timeoutMs: number): Promise<RawResponse> {
  return new Promise((resolve) => {
    if (!fs.existsSync(HTTP_CLIENT_PATH)) {
      resolve({ status: null, body: null, error: "http_client.ts 不存在", transport: "none" });
      return;
    }
    const child = spawn(
      process.execPath,
      ["--experimental-strip-types", HTTP_CLIENT_PATH, "POST", url, body, JSON.stringify(headers)],
      { stdio: ["ignore", "pipe", "pipe"] }
    );
    let out = "";
    let err = "";
    let done = false;
    const timer = setTimeout(() => {
      if (!done) {
        done = true;
        try {
          child.kill();
        } catch {
          /* 忽略：超时后子进程可能已退出 */
        }
        resolve({ status: null, body: null, error: "timeout", transport: "http_client" });
      }
    }, timeoutMs);
    const finish = (r: RawResponse): void => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      resolve(r);
    };
    child.stdout.on("data", (d: Buffer) => {
      out += d.toString("utf8");
    });
    child.stderr.on("data", (d: Buffer) => {
      err += d.toString("utf8");
    });
    child.on("error", () =>
      finish({ status: null, body: null, error: "spawn failed", transport: "http_client" })
    );
    child.on("close", () => {
      try {
        const parsed = JSON.parse(out.trim());
        finish({
          status: typeof parsed.status === "number" ? parsed.status : null,
          body: parsed.body,
          error: parsed.error ?? (parsed.success ? null : "http_client 返回失败"),
          transport: "http_client",
        });
      } catch {
        finish({
          status: null,
          body: null,
          error: `http_client 输出无法解析${err ? "：" + err.slice(0, 120) : ""}`,
          transport: "http_client",
        });
      }
    });
  });
}

async function viaFetch(url: string, body: string, headers: Record<string, string>, timeoutMs: number): Promise<RawResponse> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { method: "POST", headers, body, signal: controller.signal });
    const text = await res.text();
    let parsed: any = text;
    try {
      parsed = JSON.parse(text);
    } catch {
      /* 非 JSON 时保留原文，交由上层按结构异常处理 */
    }
    return { status: res.status, body: parsed, error: null, transport: "fetch" };
  } catch (e: any) {
    const name = e && e.name ? String(e.name) : "";
    const msg = e && e.message ? String(e.message) : String(e);
    return { status: null, body: null, error: name === "AbortError" ? "timeout" : msg, transport: "fetch" };
  } finally {
    clearTimeout(timer);
  }
}

async function requestOnce(url: string, body: string, headers: Record<string, string>, warn: (s: string) => void): Promise<RawResponse> {
  const r = await viaHttpClient(url, body, headers, TIMEOUT_MS);
  if (r.error === null && r.status !== null) return r;
  warn(`http_client 通道不可用（${r.error}），回退内置 fetch`);
  return await viaFetch(url, body, headers, TIMEOUT_MS);
}

// ───────────────────────── 错误分类（spec §5.1.3） ─────────────────────────

type ErrorKind = "none" | "retryable" | "auth" | "notopen" | "struct";

function classifyError(code: string): { kind: ErrorKind; message: string } {
  switch (code) {
    case "RequestLimitExceeded":
      return { kind: "retryable", message: "调用配额超限" };
    case "AuthFailure":
    case "UnauthorizedOperation":
      // 不回显服务端原始消息中的敏感片段（G7）
      return { kind: "auth", message: "凭据无效或未授权" };
    case "ResourceUnavailable":
    case "ResourcesSoldOut":
      return { kind: "notopen", message: "资源不可用，请确认服务开通状态" };
    case "InternalError":
      return { kind: "retryable", message: "服务内部错误" };
    default:
      return { kind: "struct", message: code || "未知错误" };
  }
}

// ───────────────────────── M3 响应解析（存在性防御） ─────────────────────────

interface Doc {
  title: string;
  url: string;
  site: string;
  date: string;
  passage: string;
  content?: string;
  pics?: unknown;
  favicon?: string;
  score?: number;
  authorityLevel?: number;
  vr?: boolean;
  deeplinks?: unknown;
}

function str(v: unknown): string {
  return typeof v === "string" ? v : v === undefined || v === null ? "" : String(v);
}

function isAbsoluteUrl(u: string): boolean {
  try {
    const parsed = new URL(u);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

function safeParse(s: string): any | null {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

function parseDocs(respBody: any, warn: (s: string) => void): { docs: Doc[]; version: string; requestId: string; dropped: number } {
  const empty = { docs: [] as Doc[], version: "", requestId: "", dropped: 0 };
  if (!respBody || typeof respBody !== "object") {
    warn("响应结构异常：顶层不是对象，按空结果处理");
    return empty;
  }
  const r: any = (respBody as any).Response ?? respBody;
  if (r && r.Error) {
    return empty;
  }
  const rawPages = Array.isArray(r?.Pages) ? r.Pages : [];
  let dropped = 0;
  const docs: Doc[] = [];
  for (const p of rawPages) {
    // G6：Pages 每个元素是 JSON 字符串，必须二次 parse
    const obj = typeof p === "string" ? safeParse(p) : p;
    if (!obj || typeof obj !== "object") {
      dropped++;
      continue;
    }
    const url = str((obj as any).url);
    if (!isAbsoluteUrl(url)) {
      dropped++; // url 是溯源唯一依据，缺失即丢弃
      continue;
    }
    const scoreRaw = (obj as any).score;
    const authorityRaw = (obj as any).authority_level;
    const doc: Doc = {
      title: str((obj as any).title),
      url,
      site: str((obj as any).site),
      date: str((obj as any).date),
      passage: str((obj as any).passage),
    };
    if (typeof (obj as any).content === "string") doc.content = (obj as any).content;
    if ((obj as any).pics !== undefined) doc.pics = (obj as any).pics;
    if (typeof (obj as any).favicon === "string") doc.favicon = (obj as any).favicon;
    if (typeof scoreRaw === "number" && Number.isFinite(scoreRaw)) doc.score = scoreRaw;
    if (typeof authorityRaw === "number" && Number.isFinite(authorityRaw)) doc.authorityLevel = authorityRaw;
    if ((obj as any).vr !== undefined) doc.vr = Boolean((obj as any).vr);
    if ((obj as any).deeplinks !== undefined) doc.deeplinks = (obj as any).deeplinks;
    docs.push(doc);
  }
  if (dropped > 0) warn(`丢弃 ${dropped} 条无效结果（缺 url 或解析失败）`);
  return { docs, version: str(r?.Version), requestId: str(r?.RequestId), dropped };
}

function extractApiError(respBody: any): string {
  const r: any = respBody && typeof respBody === "object" ? respBody.Response ?? respBody : null;
  if (r && r.Error && typeof r.Error === "object") return str(r.Error.Code);
  if (r && r.Error && typeof r.Error === "string") return r.Error;
  return "";
}

// ───────────────────────── M4 归一化 ─────────────────────────

/** 批次内 min-max 归一化；vr 且无 score 的条目不参与（返回 undefined） */
function normalizeScores(docs: Doc[]): (number | undefined)[] {
  const vals = docs
    .filter((d) => typeof d.score === "number" && !(d.vr === true && typeof d.score !== "number"))
    .map((d) => d.score as number);
  const scored = docs.map((d) => (typeof d.score === "number" ? (d.score as number) : null));
  const nums = scored.filter((v): v is number => typeof v === "number");
  if (nums.length === 0) return docs.map(() => undefined);
  const max = Math.max(...nums);
  const min = Math.min(...nums);
  void vals;
  return scored.map((v) => {
    if (v === null) return undefined;
    if (max === min) return 0.5;
    return Number(((v - min) / (max - min)).toFixed(4));
  });
}

// ───────────────────────── M5 可信度四因子合成 ─────────────────────────

type Authority = "高" | "中" | "低" | "不可用";
type SourceTier = "最高" | "中间" | "最低";
type Freshness = "现行有效" | "已过期" | "未知";
type KbHit = "已命中" | "未命中" | "库不可用";

interface Credibility {
  authority: Authority;
  sourceTier: SourceTier;
  freshness: Freshness;
  kbHit: KbHit;
  policyNo: string;
  policyFile: string;
  status: "可采信" | "待核实";
  level: "高" | "中" | "低";
  reason: string;
}

function judgeAuthority(doc: Doc): { value: Authority; note: string } {
  const v = doc.authorityLevel;
  if (typeof v !== "number") return { value: "不可用", note: "本次服务档位未提供" };
  if (v >= 4) return { value: "高", note: `${v}(高)` };
  if (v === 3) return { value: "中", note: `${v}(中)` };
  return { value: "低", note: `${v}(低)` };
}

function judgeSource(doc: Doc): { value: SourceTier; note: string } {
  const haystack = `${doc.site} ${doc.url}`.toLowerCase();
  for (const h of GOV_HINTS) {
    if (haystack.includes(h)) return { value: "最高", note: `${doc.site || doc.url}（政府信源）` };
  }
  for (const h of PORTAL_HINTS) {
    if (haystack.includes(h)) return { value: "中间", note: `${doc.site || doc.url}（门户/机构）` };
  }
  return { value: "最低", note: doc.site ? `${doc.site}（未知站点）` : "site 为空（未知站点）" };
}

function judgeFreshness(doc: Doc, days: number): { value: Freshness; note: string } {
  if (!doc.date) return { value: "未知", note: "无发布时间" };
  const t = Date.parse(doc.date);
  if (Number.isNaN(t)) return { value: "未知", note: `日期无法解析(${doc.date})` };
  const windowDays = days > 0 ? days : 365; // 未指定时效窗时按 1 年兜底
  const diffDays = (Date.now() - t) / 86400000;
  if (diffDays < 0) return { value: "现行有效", note: `${doc.date}（晚于当前时间，按有效计）` };
  if (diffDays <= windowDays) return { value: "现行有效", note: `${doc.date} 在 ${windowDays} 天时效窗内` };
  return { value: "已过期", note: `${doc.date} 超出 ${windowDays} 天时效窗` };
}

function downgrade(level: "高" | "中" | "低"): "高" | "中" | "低" {
  if (level === "高") return "中";
  if (level === "中") return "低";
  return "低";
}

/**
 * 结论状态判定（2026-10-25 修订为「可核验出处」门禁）
 *
 * 语义：敢说不知道 = 拿不出可核验出处时说不知道，而不是"本地库里没有就说不知道"。
 * 官方发布页（.gov.cn 等）本身就是可核验出处，URL 点得开、看得见发布日期。
 *
 * 置「待核实」的三条硬门禁：
 *   1. 信源分级 = 最低（未知站点 / 自媒体，无法核验发布主体）；
 *   2. 时效 = 已过期（过期政策不能作为申报依据）；
 *   3. 原文库不可用 且 信源非政府（失去事实底座，又不是官方一手来源）。
 * 其余情况可采信；原文库命中为**加分项**（绑定 policy_no 与原文路径），
 * 未命中则标注「未在本地政策原文库备案」，仍可采信但提示人工复核。
 */
function judgeStatus(s: SourceTier, f: Freshness, kbHit: KbHit): { status: "可采信" | "待核实"; gate: string } {
  if (s === "最低") return { status: "待核实", gate: "信源不可核验（未知站点/自媒体）" };
  if (f === "已过期") return { status: "待核实", gate: "已超出时效窗（过期政策不作申报依据）" };
  if (kbHit === "库不可用" && s !== "最高") return { status: "待核实", gate: "原文库不可用且非政府信源" };
  return { status: "可采信", gate: "具备可核验出处" };
}

function synthesize(
  doc: Doc,
  freshnessDays: number,
  kbHit: KbHit,
  hit: { policyNo: string; file: string; score: number; evidence: string }
): Credibility {
  const a = judgeAuthority(doc);
  const s = judgeSource(doc);
  const f = judgeFreshness(doc, freshnessDays);

  let level: "高" | "中" | "低" = s.value === "最高" ? "高" : s.value === "中间" ? "中" : "低";
  if (f.value === "已过期" || f.value === "未知") level = downgrade(level);
  if (a.value === "低" || a.value === "不可用") level = downgrade(level);

  const { status, gate } = judgeStatus(s.value, f.value, kbHit);

  const kbNote =
    kbHit === "已命中"
      ? `已命中(policy_no=${hit.policyNo}, ${hit.evidence === "fulltext" ? "正文引用" : "标题相似度=" + hit.score.toFixed(2)})`
      : kbHit === "未命中"
      ? "未命中（未在本地政策原文库备案，需人工复核）"
      : "库不可用";

  const reason =
    `权威度=${a.note}；信源=${s.value}(${s.note})；时效=${f.value}(${f.note})；原文库=${kbNote}` +
    ` → 结论状态：${status}（门禁：${gate}）` +
    (status === "待核实" ? "，已排除出正式报告" : "");

  return {
    authority: a.value,
    sourceTier: s.value,
    freshness: f.value,
    kbHit,
    policyNo: kbHit === "已命中" ? hit.policyNo : "",
    policyFile: kbHit === "已命中" ? hit.file : "",
    status,
    level,
    reason,
  };
}

// ───────────────────────── 主流程 ─────────────────────────

interface OutputItem {
  title: string;
  url: string;
  site: string;
  date: string;
  passage: string;
  scoreNorm?: number;
  authorityLevel?: number;
  vr?: boolean;
  policyNo?: string;
  policyFile?: string;
  credibility: Credibility;
}

function emit(obj: unknown, pretty: boolean): void {
  process.stdout.write((pretty ? JSON.stringify(obj, null, 2) : JSON.stringify(obj)) + "\n");
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const warns: string[] = [];
  const warn = (s: string): void => {
    warns.push(s);
    process.stderr.write(`[yuanbao-search] 告警：${s}\n`);
  };

  if (!args.selftest) {
    if (!args.query || !args.query.trim()) fail("--query 为必填项", 2);
    if (args.query.length > QUERY_MAX) fail(`--query 长度超过 ${QUERY_MAX} 字符`, 2);
  }

  let cred;
  try {
    cred = loadCredential(args.envFile);
  } catch (e) {
    if (e instanceof CredentialError) fail(e.message, 3);
    throw e;
  }

  // 原文库索引（启动时构建一次）
  let index: KbIndex | null = null;
  let kb: PolicyKb = { ok: false, count: 0, indexPath: "", entries: [], error: "" };
  if (args.noKb) {
    kb = { ok: false, count: 0, indexPath: "", entries: [], error: "调用方指定 --no-kb" };
    warn("已跳过原文库交叉验证（--no-kb）：非政府信源的结论将置「待核实」");
  } else {
    kb = loadKb(args.kbPath);
    if (!kb.ok) warn(`政策原文库不可用（${kb.error}）：非政府信源的结论将置「待核实」`);
    else index = buildIndex(kb);
  }

  const selftestQuery = "政策 申报";
  const query = args.selftest ? selftestQuery : args.query.trim();
  const { payload, freshnessDays } = args.selftest
    ? { payload: { Query: selftestQuery, Cnt: 10 }, freshnessDays: 0 }
    : buildPayload({ ...args, query }, warn);

  const signed = buildSignedRequest(payload, cred);
  const t0 = Date.now();

  let raw: RawResponse | null = null;
  let apiError = "";
  let degraded = false;
  const transports: string[] = [];

  for (let attempt = 0; attempt <= MAX_RETRY; attempt++) {
    const resp = await requestOnce(signed.url, signed.body, signed.headers, warn);
    transports.push(resp.transport);
    if (resp.error === null && resp.status !== null) {
      const code = extractApiError(resp.body);
      if (!code) {
        raw = resp;
        break;
      }
      const c = classifyError(code);
      apiError = code;
      if (c.kind === "auth" || c.kind === "notopen") {
        warn(`API ${code}：${c.message}（不重试）`);
        raw = null;
        degraded = true;
        break;
      }
      if (c.kind === "struct") {
        warn(`API ${code}：${c.message}，按空结果处理`);
        raw = null;
        degraded = true;
        break;
      }
      if (attempt < MAX_RETRY) {
        const wait = 300 * Math.pow(3, attempt);
        warn(`API ${code}：${c.message}，${wait}ms 后重试（第 ${attempt + 1} 次）`);
        await new Promise((r) => setTimeout(r, wait));
        continue;
      }
      warn(`API ${code}：${c.message}，重试 ${MAX_RETRY} 次仍失败，降级`);
      degraded = true;
      raw = null;
      break;
    }
    if (attempt < MAX_RETRY) {
      const wait = 300 * Math.pow(3, attempt);
      warn(`请求失败（${resp.error}），${wait}ms 后重试（第 ${attempt + 1} 次）`);
      await new Promise((r) => setTimeout(r, wait));
      continue;
    }
    warn(`请求失败（${resp.error}），重试 ${MAX_RETRY} 次仍失败，降级为空结果`);
    degraded = true;
  }

  const elapsedMs = Date.now() - t0;

  if (!raw) {
    emit(
      {
        ok: false,
        requestId: "",
        version: "",
        elapsedMs,
        degraded: true,
        error: apiError ? `API ${apiError}` : "检索通道不可用",
        warnings: warns,
        items: [],
        excluded: [],
      },
      args.pretty
    );
    process.exit(0); // 降级不中断：空结果 + 告警，退出码仍为 0（G11）
  }

  const parsed = parseDocs(raw.body, warn);
  const norms = normalizeScores(parsed.docs);

  // 可信度标注（批量心跳：每 100 条一行）
  const items: OutputItem[] = [];
  const excluded: Array<OutputItem & { reason: string }> = [];
  let authorityMissing = 0;
  for (let i = 0; i < parsed.docs.length; i++) {
    if (i > 0 && i % 100 === 0) {
      process.stderr.write(`[yuanbao-search] 进度：已标注 ${i}/${parsed.docs.length} 条\n`);
    }
    const d = parsed.docs[i];
    if (typeof d.authorityLevel !== "number") authorityMissing++;
    const m = index
      ? matchPolicy(d.title, d.passage, index)
      : { hit: false, policyNo: "", file: "", score: 0, evidence: "" };
    const kbHit: KbHit = !args.noKb && kb.ok ? (m.hit ? "已命中" : "未命中") : "库不可用";
    const c = synthesize(d, freshnessDays, kbHit, {
      policyNo: m.policyNo,
      file: m.file,
      score: m.score,
      evidence: m.evidence,
    });
    const item: OutputItem = {
      title: d.title,
      url: d.url,
      site: d.site,
      date: d.date,
      passage: d.passage,
      credibility: c,
    };
    if (typeof norms[i] === "number") item.scoreNorm = norms[i];
    if (typeof d.authorityLevel === "number") item.authorityLevel = d.authorityLevel;
    if (d.vr !== undefined) item.vr = d.vr;
    if (c.policyNo) item.policyNo = c.policyNo;
    if (c.policyFile) item.policyFile = c.policyFile;
    if (c.status === "可采信") items.push(item);
    else excluded.push({ ...item, reason: c.reason });
  }

  // 排序：有归一化分数的按分数降序；vr 且无 score 的排最后（REQ-PD-017）
  items.sort((a, b) => {
    const av = typeof a.scoreNorm === "number" ? a.scoreNorm : -1;
    const bv = typeof b.scoreNorm === "number" ? b.scoreNorm : -1;
    return bv - av;
  });

  if (parsed.version === "standard") {
    warn("本次服务档位为 standard（旗舰版能力可能缺失），已记录降级事件");
  }
  if (parsed.docs.length > 0 && authorityMissing === parsed.docs.length) {
    warn(`authority_level 整批缺失（${authorityMissing}/${parsed.docs.length}），已按「不可用」降级判定`);
  }

  const out = {
    ok: true,
    requestId: parsed.requestId,
    version: parsed.version,
    elapsedMs,
    degraded,
    query,
    transport: transports[transports.length - 1] ?? "",
    kb: { ok: kb.ok, count: kb.count, path: kb.indexPath },
    stats: {
      returned: parsed.docs.length,
      credible: items.length,
      excluded: excluded.length,
      authorityMissing,
    },
    warnings: warns,
    items,
    excluded,
  };

  if (args.selftest) {
    process.stderr.write(
      [
        "── 自检结果 ──",
        `HTTP 状态：${raw.status}`,
        `服务档位：${parsed.version || "(空)"}`,
        `返回条数：${parsed.docs.length}`,
        `耗时：${elapsedMs} ms`,
        `传输通道：${out.transport}`,
        `authority_level：${parsed.docs.length - authorityMissing}/${parsed.docs.length} 条可用`,
        `score：${parsed.docs.filter((d) => typeof d.score === "number").length}/${parsed.docs.length} 条可用`,
        `deeplinks：${parsed.docs.filter((d) => d.deeplinks !== undefined).length}/${parsed.docs.length} 条可用`,
        `政策原文库：${kb.ok ? `可用（${kb.count} 条）` : `不可用（${kb.error}）`}`,
      ].join("\n") + "\n"
    );
  }

  emit(out, args.pretty);
}

main().catch((e: any) => {
  const msg = e && e.message ? String(e.message) : String(e);
  // 兜底：任何未预期异常也必须输出单行 JSON，禁止抛栈中断调用方（G11）
  process.stderr.write(`[yuanbao-search] 未预期错误：${msg}\n`);
  process.stdout.write(
    JSON.stringify({ ok: false, degraded: true, error: msg, items: [], excluded: [] }) + "\n"
  );
  process.exit(1);
});
