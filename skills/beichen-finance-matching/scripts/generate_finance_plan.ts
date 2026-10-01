#!/usr/bin/env node
/**
 * generate_finance_plan.ts — 金融匹配智能体 Step 3: 定制金融方案（Generate Finance Plan）
 * 功能与 generate_finance_plan.py 完全一致
 * 默认调用昇腾 API / AtomGit 生成；未配置 LLM 时降级为模板（矩阵直出对比表）。
 *
 * 用法:
 *     node --experimental-strip-types scripts/generate_finance_plan.ts --need {需求json} --matches {匹配json} [--outdir output/plans]
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;

function defaultOutdir(): string {
  return path.normalize(path.join(__dirname, "..", "output", "plans"));
}

function llmAvailable(): boolean {
  return Boolean(process.env.LLM_API_KEY || process.env.OPENAI_API_KEY);
}

async function callLlm(prompt: string): Promise<string> {
  const base = (process.env.LLM_BASE_URL || process.env.OPENAI_BASE_URL || "https://api-ai.gitcode.com/v1").replace(/\/+$/, "");
  const key = process.env.LLM_API_KEY || process.env.OPENAI_API_KEY || "sk-dummy-key";
  const model = process.env.LLM_MODEL || "deepseek-flash";
  const url = `${base}/chat/completions`;
  const payload = {
    model,
    stream: false,
    messages: [
      { role: "system", content: "你是园区产业金融服务顾问，输出定制融资方案。方案仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。" },
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

function buildTemplatePlan(need: any, matches: any, policies: any[]): string {
  const lines: string[] = [
    `# 定制融资方案 - ${need.company_name || ""}`,
    "",
    "## 需求概览",
    "",
    `- 融资金额：${need.amount || ""}`,
    `- 融资期限：${need.term || ""}`,
    `- 融资用途：${need.purpose || ""}`,
    `- 担保方式：${need.guarantee || ""}`,
    `- 服务单号：${need.case_id || ""}`,
    "",
    "## 备选机构方案对比",
    "",
    "| 机构 | 推荐产品 | 产品类型 | 额度 | 期限 | 担保 | 匹配度 |",
    "|------|---------|---------|------|------|------|--------|",
  ];
  for (const m of matches.matches || []) {
    const partner = m.partner;
    const prods: any[] = m.products || [];
    if (prods.length) {
      for (const p of prods.slice(0, 2)) {
        lines.push(`| ${partner} | ${p.name} | ${p.type} | ${p.amount} | ${p.term} | ${p.guarantee} | ${m.score} |`);
      }
    } else {
      lines.push(`| ${partner} | — | — | — | — | — | ${m.score} |`);
    }
  }
  lines.push("", "## 各方案适配理由", "");
  for (const m of matches.matches || []) {
    lines.push(`### ${m.partner}（匹配度 ${m.score}）`);
    lines.push(`- 匹配依据：${m.basis}`);
    lines.push(`- 优势领域：${(m.strength_domains || []).join("、")}`);
    lines.push("");
  }
  lines.push("## 组合融资建议", "");
  if (policies.length) {
    lines.push("可叠加以下金融类政策降低综合成本：");
    for (const pol of policies.slice(0, 5)) {
      lines.push(`- ${pol.name}（${pol.provider}）：${pol.detail}`);
    }
  } else {
    lines.push('- 可考虑"信贷 + 贴息"组合，具体以机构审批与政策兑现为准。');
  }
  lines.push(
    "",
    "## 风险提示",
    "",
    "- 融资可行性、利率与放款以金融机构独立审批为准。",
    "- 产品额度/利率为公开资料区间，实际以合同条款为准。",
    "",
    "## 对接路径",
    "",
    "1. 企业与匹配机构联系人对接，提交对接材料包；",
    "2. 机构审核资料并出具初步方案；",
    "3. 双方洽谈细节并签约落地。",
    "",
    "## 合规声明",
    "",
    "> 本方案由金融匹配智能体自动生成，仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。",
    "",
  );
  return lines.join("\n");
}

async function main() {
  const args = process.argv.slice(2);
  let needFile = "",
    matchesFile = "",
    outdir = defaultOutdir();
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--need") needFile = args[++i];
    else if (args[i] === "--matches") matchesFile = args[++i];
    else if (args[i] === "--outdir") outdir = args[++i];
  }
  // 对齐 py argparse required=True（缺失 exit 2）
  if (!needFile) { console.error("错误: 缺少必填参数 --need"); process.exit(2); }
  if (!matchesFile) { console.error("错误: 缺少必填参数 --matches"); process.exit(2); }

  const need = JSON.parse(fs.readFileSync(needFile, "utf-8"));
  const matches = JSON.parse(fs.readFileSync(matchesFile, "utf-8"));
  const policies: any[] = matches.finance_policies || [];

  let llmUsed = false;
  let plan: string;
  if (llmAvailable()) {
    const prompt =
      "请基于以下融资需求与匹配结果，生成定制融资方案（Markdown：需求概览、备选方案对比表、逐方案适配理由、组合融资建议、风险提示、对接路径）。\n" +
      `需求：${JSON.stringify(need, null, 2)}\n` +
      `匹配：${JSON.stringify(matches, null, 2)}`;
    try {
      plan = await callLlm(prompt);
      if (plan.trim()) {
        llmUsed = true;
      } else {
        plan = buildTemplatePlan(need, matches, policies);
      }
    } catch (e: any) {
      process.stderr.write(`LLM 调用失败，降级模板生成: ${e.message || e}\n`);
      plan = buildTemplatePlan(need, matches, policies);
    }
  } else {
    plan = buildTemplatePlan(need, matches, policies);
  }

  if (!plan.includes("不构成投资建议")) {
    plan += "\n\n> 本方案仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。\n";
  }

  fs.mkdirSync(outdir, { recursive: true });
  const caseId = need.case_id || path.basename(needFile, path.extname(needFile));
  const out = path.join(outdir, `${caseId}.md`);
  fs.writeFileSync(out, plan, "utf-8");

  console.log(JSON.stringify({ success: true, output: out, llm_used: llmUsed }));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});