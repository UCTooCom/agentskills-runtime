#!/usr/bin/env node
/**
 * update_policy_kb.ts — 产业政策智能体: 政策库自动更新
 * 功能与 update_policy_kb.py 完全一致
 *
 * 运行方式:
 *   抓取模式: node --experimental-strip-types update_policy_kb.ts --sources default
 *   演示模式: node --experimental-strip-types update_policy_kb.ts --demo
 *   commit 模式: node --experimental-strip-types update_policy_kb.ts --commit --date 2026-08-29 --reviewer 张工
 */
import * as path from "path";
import * as fs from "fs";

const __dirname = import.meta.dirname;
const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地时间 ISO（对齐 Python datetime.now().isoformat()）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}
// 等价 Python json.dumps(v, ensure_ascii=False)（默认分隔符 ": " / ", "，非 ASCII 不转义）
function pyDumps(v: any): string {
  if (v === null) return "null";
  const t = typeof v;
  if (t === "string") return JSON.stringify(v);
  if (t === "number" || t === "boolean") return String(v);
  if (Array.isArray(v)) return "[" + v.map(pyDumps).join(", ") + "]";
  if (t === "object") {
    const ks = Object.keys(v as object);
    return ks.length ? "{" + ks.map((k) => JSON.stringify(k) + ": " + pyDumps((v as any)[k])).join(", ") + "}" : "{}";
  }
  return "null";
}

const SOURCE_URLS: Record<string, string> = {
  "北京市人民政府": "https://www.beijing.gov.cn/",
  "朝阳区人民政府": "http://www.bjchy.gov.cn/",
  "北京市科委": "https://kw.beijing.gov.cn/",
  "中关村管委会": "https://zgcgw.beijing.gov.cn/",
};

function parseArgs(): Record<string, string | boolean> {
  const args: Record<string, string | boolean> = {};
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = process.argv[i + 1];
      if (next && !next.startsWith("--")) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  return args;
}

function defaultKb(): string {
  return path.normalize(path.join(__dirname, "..", "knowledge"));
}

function defaultPending(): string {
  return path.normalize(path.join(__dirname, "..", "output", "pending"));
}

function todayStr(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

function sanitizeFilename(s: string): string {
  let r = (s || "").replace(/[\s\u3000]+/g, "");
  r = r.replace(/[\\/:*?"<>|]/g, "");
  return r || "policy";
}

async function fetchSource(url: string): Promise<any[]> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    const resp = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0" },
      signal: controller.signal,
    });
    clearTimeout(timeout);
    const html = await resp.text();
    const items: any[] = [];
    const regex = /<a[^>]+href="([^"]+)"[^>]*>([^<]*)<\/a>/g;
    let m: RegExpExecArray | null;
    while ((m = regex.exec(html)) !== null) {
      const title = m[2].replace(/\s+/g, "");
      if (/政策|申报|通知|补贴|支持/.test(title) && title.length > 6) {
        let href = m[1];
        if (href.startsWith("/")) href = url.replace(/\/$/, "") + href;
        items.push({ title, url: href });
      }
      if (items.length >= 20) break;
    }
    return items;
  } catch (e: any) {
    return [{ error: String(e) }];
  }
}

function demoPending(date: string): any[] {
  return [
    { policy_no: null, title: "朝阳区关于支持数据要素产业高质量发展的若干措施（征求意见稿）", url: "https://example.gov.cn/notice/demo-1", department: "朝阳区数据局", level: "区级", domain: "数据要素", published_date: date, status: "pending" },
    { policy_no: null, title: "北京市关于进一步支持人工智能创新应用的通知", url: "https://example.gov.cn/notice/demo-2", department: "北京市经信局", level: "市级", domain: "人工智能", published_date: date, status: "confirmed", reviewer: "待填", reviewed_at: date },
  ];
}

async function fetchMode(args: Record<string, string | boolean>) {
  const demo = args.demo === true;
  const sources = typeof args.sources === "string" ? args.sources : "default";
  const date = typeof args.date === "string" ? args.date : todayStr();
  const pendingDir = typeof args.pending === "string" ? args.pending : defaultPending();

  const pending: any[] = [];
  if (demo) {
    pending.push(...demoPending(date));
  } else {
    const srcMap = sources === "default" ? SOURCE_URLS : Object.fromEntries(sources.split(",").map((u: string) => [u, u]));
    for (const [name, url] of Object.entries(srcMap)) {
      const items = await fetchSource(url);
      for (const it of items) {
        if (it.error) {
          pending.push({ source: name, url, error: it.error });
        } else {
          Object.assign(it, { source: name, department: name, published_date: date, status: "pending" });
          pending.push(it);
        }
      }
    }
  }
  fs.mkdirSync(pendingDir, { recursive: true });
  const out = path.join(pendingDir, `${date}.json`);
  const payload = { date, fetched_at: localIso(), count: pending.length, items: pending };
  fs.writeFileSync(out, JSON.stringify(payload, null, 2), "utf-8");
  console.log(JSON.stringify({ success: true, mode: "fetch", output: out, count: pending.length }));
}

function renderMarkdown(item: any, newNo: string): string {
  const cond = { region: item.region || "", qualification: item.qualification || "", industry: item.industry || [] };
  return [
    "---",
    `policy_no: "${newNo}"`,
    `domain: ${item.domain || ""}`,
    `level: ${item.level || ""}`,
    `department: ${item.department || ""}`,
    `title: ${item.title || ""}`,
    "status: active",
    "conditions:",
    `  region: ${cond.region}`,
    `  qualification: ${cond.qualification}`,
    `  industry: ${pyDumps(cond.industry)}`,
    `support: "${item.support || ""}"`,
    `source: ${item.url || ""}`,
    "---",
    "",
    `# ${item.title || ""}`,
    "",
    "## 政策要点",
    "",
    "（申报条件、支持方式、申报周期、材料清单——待运营方补全）",
    "",
  ].join("\n");
}

function commitMode(args: Record<string, string | boolean>) {
  const date = typeof args.date === "string" ? args.date : todayStr();
  const reviewer = typeof args.reviewer === "string" ? args.reviewer : "";
  const kb = typeof args.kb === "string" ? args.kb : defaultKb();
  const pendingDir = typeof args.pending === "string" ? args.pending : defaultPending();

  const pendingFile = path.join(pendingDir, `${date}.json`);
  if (!fs.existsSync(pendingFile)) {
    console.error("错误: 未找到当日储备流水，请先执行抓取模式");
    process.exit(1);
  }
  const payload = JSON.parse(fs.readFileSync(pendingFile, "utf-8"));
  const confirmed = (payload.items || []).filter((it: any) => it.status === "confirmed" && !it.policy_no);
  if (!confirmed.length) {
    console.log(JSON.stringify({ success: true, mode: "commit", committed: 0, note: "无已确认待入库条目" }));
    return;
  }

  const indexPath = path.join(kb, "policy-index.json");
  const index = JSON.parse(fs.readFileSync(indexPath, "utf-8"));
  const existingNos = new Set((index.policies || []).map((p: any) => String(p.policy_no)));
  let maxNo = Math.max(0, ...[...existingNos].filter(s => /^\d+$/.test(s)).map(Number));

  const origDir = path.join(kb, "policy-original");
  fs.mkdirSync(origDir, { recursive: true });
  let committed = 0;
  for (const item of confirmed) {
    maxNo++;
    const newNo = String(maxNo);
    const reviewTime = todayStr();
    const fname = `${newNo}-${sanitizeFilename(item.title || "")}.md`;
    fs.writeFileSync(path.join(origDir, fname), renderMarkdown(item, newNo), "utf-8");
    index.policies.push({
      policy_no: newNo, domain: item.domain || "", level: item.level || "",
      department: item.department || "", title: item.title || "",
      status: "active", conditions: {}, support: item.support || "",
      file: path.join("policy-original", fname),
    });
    item.policy_no = newNo;
    item.reviewer = reviewer;
    item.reviewed_at = reviewTime;
    committed++;
  }

  fs.writeFileSync(indexPath, JSON.stringify(index, null, 2), "utf-8");
  fs.writeFileSync(pendingFile, JSON.stringify(payload, null, 2), "utf-8");
  console.log(JSON.stringify({ success: true, mode: "commit", committed, reviewer, next_policy_no: String(maxNo) }));
}

async function main() {
  const args = parseArgs();
  const commit = args.commit === true;
  const reviewer = typeof args.reviewer === "string" ? args.reviewer : "";

  if (commit) {
    if (!reviewer) {
      console.error("错误: commit 模式必须指定 --reviewer（研判人留痕）");
      process.exit(1);
    }
    commitMode(args);
  } else {
    await fetchMode(args);
  }
}

main();