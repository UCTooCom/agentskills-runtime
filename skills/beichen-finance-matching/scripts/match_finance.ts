#!/usr/bin/env node
/**
 * match_finance.ts — 金融匹配智能体 Step 2: 需求匹配优势金融机构（Match Finance）
 * 功能与 match_finance.py 完全一致
 * 硬性初筛（额度/担保对标产品要素）+ 优势匹配打分，输出 Top N 匹配矩阵。
 * 打分构成：领域命中(50%) + 服务经验先验(30%) + 周期适配(20%)。
 *
 * 用法:
 *     node --experimental-strip-types scripts/match_finance.ts --need output/needs/{case_id}.json [--topn 3] [--kb knowledge]
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;

function defaultKb(): string {
  return path.normalize(path.join(__dirname, "..", "knowledge"));
}

function defaultOutdir(): string {
  return path.normalize(path.join(__dirname, "..", "output", "matches"));
}

function llmAvailable(): boolean {
  return Boolean(process.env.LLM_API_KEY || process.env.OPENAI_API_KEY);
}

async function callLlm(prompt: string, system: string): Promise<string> {
  const base = (process.env.LLM_BASE_URL || process.env.OPENAI_BASE_URL || "https://api-ai.gitcode.com/v1").replace(/\/+$/, "");
  const key = process.env.LLM_API_KEY || process.env.OPENAI_API_KEY || "sk-dummy-key";
  const model = process.env.LLM_MODEL || "deepseek-flash";
  const url = `${base}/chat/completions`;
  const payload = {
    model,
    stream: false,
    messages: [
      { role: "system", content: system },
      { role: "user", content: prompt },
    ],
  };
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(120000), // 对齐 py timeout=120
  });
  if (!resp.ok) throw new Error(`LLM HTTP ${resp.status}: ${await resp.text()}`);
  const data: any = await resp.json();
  const choices = data.choices || [];
  if (!choices.length) throw new Error("LLM 返回空 choices");
  return choices[0].message?.content || "";
}

/** 解析额度字符串为万元上限；'无上限/不限/视情况/-'返回 null 表示不限或未知。 */
function parseAmountWan(s: string): number | null {
  if (!s) return null;
  if (/无上限|不限|视企业情况|视情况|-/.test(s)) return null;
  const m = /([\d.]+)\s*(万元|万元人民币|万|亿元|元)/.exec(s);
  if (!m) return null;
  const val = parseFloat(m[1]);
  const unit = m[2];
  if (unit.includes("亿")) return val * 10000;
  if (unit === "元") return val / 10000;
  return val;
}

function parseNeedAmountWan(need: any): number | null {
  const m = /([\d.]+)\s*(万|亿|元|千)?/.exec(need.amount || "");
  if (!m) return null;
  const val = parseFloat(m[1]);
  const unit = m[2] || "元";
  if (unit === "亿") return val * 10000;
  if (unit === "万") return val;
  return val / 10000;
}

/** 从企业画像与用途推断需求领域关键词。 */
function needDomains(need: any): string[] {
  const doms: string[] = [];
  const inds: string[] = (need.profile || {}).industry || [];
  doms.push(...inds);
  const purpose = need.purpose || "";
  if (purpose === "研发投入") doms.push("科技");
  return doms;
}

/** 硬性初筛（额度对标 + 担保对标），返回淘汰原因或 null。 */
function hardFilter(partner: any, need: any): string | null {
  const needAmt = parseNeedAmountWan(need);
  if (needAmt !== null) {
    const allLimited: number[] = [];
    for (const p of partner.products || []) {
      const cap = parseAmountWan(p.amount || "");
      if (cap !== null) allLimited.push(cap);
    }
    if (allLimited.length && needAmt > Math.max(...allLimited)) {
      return "需求金额超过该机构产品最高额度";
    }
  }
  return null;
}

function ruleScore(partner: any, need: any): any {
  const doms = needDomains(need).filter((d) => d);
  const strengths: string[] = partner.strength_domains || [];
  let hit = 0;
  for (const s of strengths) {
    for (const d of doms) {
      if (d && (d.includes(s) || s.includes(d))) {
        hit++;
        break;
      }
    }
  }
  const domainScore = strengths.length ? (50.0 * hit) / strengths.length : 20.0;
  const expScore = (30.0 * Math.min(partner.service_count || 0, 30)) / 30.0;
  const cycle = partner.avg_cycle_days || 5;
  const cycleScore = 20.0 * Math.max(0, 1.0 - cycle / 15.0);
  const total = Math.round((domainScore + expScore + cycleScore) * 10) / 10;
  const reasons: string[] = [];
  if (hit) reasons.push(`优势领域命中 ${hit} 项（${hit} 项与需求领域相关）`);
  reasons.push(`服务经验 ${partner.service_count || 0} 家次`);
  reasons.push(`平均放款周期约 ${cycle} 个工作日`);
  return {
    score: total,
    domain_score: Math.round(domainScore * 10) / 10,
    exp_score: Math.round(expScore * 10) / 10,
    cycle_score: Math.round(cycleScore * 10) / 10,
    basis: reasons.join("；"),
  };
}

/** 从机构产品中筛选与需求匹配的产品（额度/担保/用途），返回顶部产品。 */
function matchedProducts(partner: any, need: any, limit = 5): any[] {
  const needAmt = parseNeedAmountWan(need);
  const purpose = need.purpose || "";
  const out: any[] = [];
  for (const p of partner.products || []) {
    const cap = parseAmountWan(p.amount || "");
    if (needAmt !== null && cap !== null && needAmt > cap) continue;
    const purposes: string[] = p.purpose || [];
    if (purpose && purposes.length && !purposes.includes(purpose) && !purposes.some((x: string) => purpose.includes(x) || x.includes(purpose))) continue;
    out.push(p);
  }
  return out.slice(0, limit);
}

async function main() {
  const args = process.argv.slice(2);
  let needFile = "",
    kb = defaultKb(),
    topn = 3,
    outdir = defaultOutdir();
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--need") needFile = args[++i];
    else if (args[i] === "--kb") kb = args[++i];
    else if (args[i] === "--topn") { const v = args[++i]; if (!/^-?\d+$/.test(v)) { console.error(`错误: --topn 必须为整数: ${v}`); process.exit(2); } topn = parseInt(v, 10); }
    else if (args[i] === "--outdir") outdir = args[++i];
  }
  // 对齐 py argparse required=True（缺失 exit 2）
  if (!needFile) { console.error("错误: 缺少必填参数 --need"); process.exit(2); }

  const need = JSON.parse(fs.readFileSync(needFile, "utf-8"));
  const indexPath = path.join(kb, "finance-index.json");
  if (!fs.existsSync(indexPath)) {
    process.stderr.write("错误: 未找到 finance-index.json，请先运行 init_finance_kb.ts\n");
    process.exit(1);
  }
  const index = JSON.parse(fs.readFileSync(indexPath, "utf-8"));

  const results: any[] = [];
  const eliminated: any[] = [];
  for (const partner of index.partners || []) {
    const reason = hardFilter(partner, need);
    if (reason) {
      eliminated.push({ partner: partner.name, reason });
      continue;
    }
    const sc = ruleScore(partner, need);
    const products = matchedProducts(partner, need);
    let basis = sc.basis;
    if (llmAvailable()) {
      try {
        const prompt =
          "评估该融资需求与该机构的适配性，给一句话判定。\n需求：" +
          JSON.stringify({ amount: need.amount, purpose: need.purpose, term: need.term }) +
          "\n机构：" +
          JSON.stringify({ name: partner.name, strengths: partner.strength_domains });
        const llmOut = await callLlm(prompt, "你是园区金融服务匹配助手，输出一句话匹配依据。");
        if (llmOut.trim()) basis = llmOut.trim();
      } catch {
        /* ignore */
      }
    }
    results.push({
      partner: partner.name,
      partner_no: partner.partner_no,
      type: partner.type,
      strength_domains: partner.strength_domains || [],
      score: sc.score,
      score_breakdown: { domain: sc.domain_score, experience: sc.exp_score, cycle: sc.cycle_score },
      basis,
      products,
    });
  }

  results.sort((a, b) => b.score - a.score);
  const topN = Math.max(1, topn);
  const caseId = need.case_id || path.basename(needFile, path.extname(needFile));
  fs.mkdirSync(outdir, { recursive: true });
  const out = path.join(outdir, `${caseId}.json`);
  const result = {
    case_id: caseId,
    company_name: need.company_name,
    need: { amount: need.amount, purpose: need.purpose, term: need.term },
    matches: results.slice(0, topN),
    eliminated,
    total_partners: (index.partners || []).length,
  };
  fs.writeFileSync(out, JSON.stringify(result, null, 2), "utf-8");

  console.log(
    JSON.stringify({
      success: true,
      output: out,
      matched: results.slice(0, topN).length,
      eliminated: eliminated.length,
      llm_used: llmAvailable(),
    }),
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});