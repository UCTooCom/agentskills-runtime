#!/usr/bin/env node
/**
 * gen_policy_summary.ts — 生成政策汇总报告
 * 功能与 gen_policy_summary.py 完全一致
 *
 * 运行方式: node --experimental-strip-types gen_policy_summary.ts
 */
import * as path from "path";
import * as fs from "fs";

const __dirname = import.meta.dirname;
const BASE = path.normalize(path.join(__dirname, ".."));

function loadJson(p: string): any {
  let content = fs.readFileSync(p, "utf-8");
  if (content.charCodeAt(0) === 0xfeff) content = content.slice(1);
  return JSON.parse(content);
}

function findRecords(obj: any): [string | null, any[]] {
  if (Array.isArray(obj)) return ["items", obj];
  if (obj && typeof obj === "object") {
    for (const [k, v] of Object.entries(obj)) {
      if (Array.isArray(v) && v.length > 0 && typeof v[0] === "object") return [k, v];
    }
    for (const [k, v] of Object.entries(obj)) {
      if (Array.isArray(v)) return [k, v];
    }
  }
  return [null, []];
}

function g(d: any, keys: string[], def: any = ""): any {
  for (const k of keys) {
    if (d && typeof d === "object" && d[k]) return d[k];
  }
  return def;
}

function counterTable(counter: Record<string, number>, label: string): string {
  const lines = [`| ${label} | 政策数量 |`, "|------|------|"];
  const entries = Object.entries(counter).sort((a, b) => b[1] - a[1] || String(a[0]).localeCompare(String(b[0])));
  for (const [name, cnt] of entries) {
    lines.push(`| ${name} | ${cnt} |`);
  }
  return lines.join("\n");
}

function todayStr(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

function main() {
  const today = todayStr();
  const idxPath = path.join(BASE, "knowledge", "policy-index.json");
  const outDir = path.join(BASE, "output", "reports");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `policy-summary-${today}.md`);

  const idx = loadJson(idxPath);
  const [, policies] = findRecords(idx);

  const domains: Record<string, number> = {};
  const levels: Record<string, number> = {};
  const depts: Record<string, number> = {};
  const statuses: Record<string, number> = {};
  let noConditions = 0;
  const rows: [string, string, string, string, string, string, string][] = [];
  for (const p of policies) {
    const domain = String(g(p, ["domain"], "未分类"));
    const level = String(g(p, ["level"], "未标注"));
    const dept = String(g(p, ["department"], "未标注"));
    const title = String(g(p, ["title"], "(无标题)"));
    const no = String(g(p, ["policy_no"], ""));
    const st = String(g(p, ["status"], "active"));
    const f = String(g(p, ["file"], ""));
    domains[domain] = (domains[domain] || 0) + 1;
    levels[level] = (levels[level] || 0) + 1;
    depts[dept] = (depts[dept] || 0) + 1;
    statuses[st] = (statuses[st] || 0) + 1;
    const cond = p.conditions;
    if (!cond) noConditions++;
    rows.push([no, domain, level, dept, title, st, f]);
  }

  rows.sort((a, b) => {
    const aIsNum = /^\d+$/.test(a[0]);
    const bIsNum = /^\d+$/.test(b[0]);
    if (aIsNum && bIsNum) return parseInt(a[0], 10) - parseInt(b[0], 10);
    if (aIsNum) return -1;
    if (bIsNum) return 1;
    return String(a[0]).localeCompare(String(b[0]));
  });

  const pendingPath = path.join(BASE, "output", "pending", `${today}.json`);
  let pending: any = null;
  let pendingItems: any[] = [];
  let pendingMeta = "";
  if (fs.existsSync(pendingPath)) {
    pending = loadJson(pendingPath);
    [, pendingItems] = findRecords(pending);
    pendingMeta = String(g(pending, ["fetched_at"], ""));
  }

  const lines: string[] = [];
  lines.push("# 北京市产业政策汇总报告", "");
  lines.push(`**报告日期**：${today}  `);
  lines.push("**生成方式**：北辰产业政策智能体（beichen-policy-assistant）政策库聚合，三层知识库 + 全网实时检索  ");
  lines.push("**数据来源**：北辰命题附件政策目录（74 条）+ 北京市政府公开网站最新政策抓取  ");
  lines.push("**报告性质**：政策库汇总与动态通报，非单一企业适配研判", "");
  lines.push("---", "");
  lines.push("## 一、报告说明", "");
  lines.push("本报告对政策智能体的三层知识库（政策原文库 / 官方解读库 / 实操洞察库）进行全量聚合统计，");
  lines.push("并汇总最新一轮政府公开网站政策抓取结果，输出可溯源的政策全景与动态清单。");
  lines.push("所有条目均绑定 `policy_no` 编号，可回溯至 `knowledge/policy-original/` 原文文件。", "");
  lines.push("## 二、政策库总览", "");
  lines.push(`- 政策原文库条目数：**${policies.length}** 条`);
  lines.push(`- 政策索引版本：${String(g(idx, ["version"], "-"))}`);
  lines.push(`- 索引生成时间：${String(g(idx, ["generated_at"], "-"))}`);
  lines.push(`- 状态分布：${Object.entries(statuses).map(([k, v]) => `${k}=${v}`).join("，")}`);
  lines.push(`- 待补充结构化要素（条件/支持力度）条目数：${noConditions} 条（需人工或 LLM 抽取补充）`);
  lines.push("- 官方解读库文件数：3 份（编号 5 / 12 / 17）");
  lines.push("- 实操洞察库文件数：3 份（中小企业 / 人工智能 / 高新技术产业）", "");
  lines.push("## 三、政策领域分布", "");
  lines.push(counterTable(domains, "政策领域"), "");
  lines.push("## 四、政策层级与发布部门分布", "");
  lines.push(counterTable(levels, "政策层级"), "");
  lines.push(counterTable(depts, "发布部门"), "");
  lines.push("## 五、政策原文库清单（按编号）", "");
  lines.push("| 编号 | 政策名称 | 领域 | 层级 | 状态 | 原文文件 |");
  lines.push("|------|----------|------|------|------|----------|");
  for (const [no, domain, level, , title, st, f] of rows) {
    lines.push(`| ${no} | ${title} | ${domain} | ${level} | ${st} | \`${f}\` |`);
  }
  lines.push("");
  lines.push(`## 六、最新政策动态（${today} 抓取）`, "");
  if (pending === null) {
    lines.push("本轮未发现抓取流水文件。");
  } else {
    lines.push(`- 抓取时间：${pendingMeta || "-"}`);
    lines.push(`- 抓取条目数：**${pendingItems.length}** 条`);
    const okItems = pendingItems.filter((x) => String(g(x, ["status"], "")).toLowerCase() !== "error");
    const errItems = pendingItems.filter((x) => String(g(x, ["status"], "")).toLowerCase() === "error");
    lines.push(`- 待研判（pending）条目数：${okItems.length} 条 | 抓取失败条目数：${errItems.length} 条`);
    lines.push("- 入库门禁：储备库 → 正式库须经人工研判 commit（`--reviewer` 留痕）", "");
    lines.push("| 序号 | 标题 | 发布单位 | 发布日期 | 状态 | 链接 |");
    lines.push("|------|------|----------|----------|------|------|");
    let idx2 = 1;
    for (const it of pendingItems) {
      let title = String(g(it, ["title"], "(未解析)"));
      const dept = String(g(it, ["department", "source"], "(未解析)"));
      const pub = String(g(it, ["published_date"], "-"));
      const st = String(g(it, ["status"], "pending"));
      const url = String(g(it, ["url"], "-"));
      if (String(st).toLowerCase() === "error") {
        title = "(抓取失败) " + String(g(it, ["error"], ""));
      }
      lines.push(`| ${idx2} | ${title} | ${dept} | ${pub} | ${st} | ${url} |`);
      idx2++;
    }
  }
  lines.push("");
  lines.push("## 七、申报要点与建议", "");
  lines.push("1. **领域聚焦**：政策库覆盖人才创业、知识产权、金融支持、人工智能与机器人、数据要素、");
  lines.push("   数字医疗健康、互联网 3.0/元宇宙、科技创新与高新技术、商务文化消费、中小企业与外资、");
  lines.push("   国际消费中心城市建设等方向，可按企业主营领域快速定位。");
  lines.push("2. **层级联动**：市、区两级政策并存，建议按\"市级普惠 + 区级叠加\"组合申报，提高支持叠加度。");
  lines.push("3. **要素补全**：原文库中条件与支持力度字段尚未结构化，正式匹配前需完成要素抽取，");
  lines.push("   否则匹配结果应标记\"待核实\"，不得进入正式报告。");
  lines.push("4. **时效跟踪**：储备库条目须经人工研判后转入正式库；建议每日定时抓取并定期清理超期条目。");
  lines.push("5. **企业适配**：如需针对具体企业输出可申报清单与适配研判报告，请提供企业名称，");
  lines.push("   智能体将执行\"企业画像 → 政策匹配 → 适配报告 → 申报任务 → 落库\"全流程。", "");
  lines.push("## 八、合规声明", "");
  lines.push("- 本报告数据仅来源于公开工商信息、政府公开网站与公开政策目录，已记录来源与抓取时间。");
  lines.push("- 储备库条目须经人工研判门禁方可转入正式库，本报告不对未确认条目作确定性结论。");
  lines.push("- 本报告仅供申报参考，不构成法律意见；最终以主管部门发布的政策原文与审批结果为准。", "");

  const content = lines.join("\n");
  fs.writeFileSync(outPath, content, "utf-8");

  console.log(`OK report=${outPath}`);
  console.log(`bytes=${Buffer.byteLength(content, "utf-8")}`);
  console.log(`policies=${policies.length} domains=${Object.keys(domains).length} levels=${Object.keys(levels).length} depts=${Object.keys(depts).length} no_conditions=${noConditions}`);
  console.log(`pending_items=${pendingItems.length}`);
  console.log("domain_counts=" + Object.entries(domains).sort((a, b) => b[1] - a[1]).map(([, c]) => c).join(";"));
  console.log("level_counts=" + Object.entries(levels).map(([, c]) => c).join(";"));
}

main();