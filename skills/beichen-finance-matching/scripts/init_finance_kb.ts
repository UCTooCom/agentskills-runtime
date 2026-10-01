#!/usr/bin/env node
/**
 * init_finance_kb.ts — 金融匹配智能体 Step 0: 金融工具数据库初始化
 * 功能与 init_finance_kb.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;
const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地时间 ISO（对齐 Python datetime.now().isoformat()）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}
const TYPE_CN: Record<string, string> = { bank: "银行", securities: "证券", fund: "基金", investor: "投资公司" };
const TYPE_FILE: Record<string, string> = { bank: "banks", securities: "securities", fund: "funds", investor: "investors" };

function sanitizeFilename(s: string): string {
  return (s || "").replace(/[\s\u3000]+/g, "").replace(/[\\/:*?"<>|()（）/]/g, "") || "product";
}

async function main() {
  const args = process.argv.slice(2);
  let seed = "", kb = path.normalize(path.join(__dirname, "..", "knowledge")), force = false;
  for (let i = 0; i < args.length; i++) { if (args[i] === "--seed") seed = args[++i]; else if (args[i] === "--kb") kb = args[++i]; else if (args[i] === "--force") force = true; }
  // 对齐 py argparse required=True（缺失 exit 2）
  if (!seed) { console.error("错误: 缺少必填参数 --seed"); process.exit(2); }
  const seedData = JSON.parse(fs.readFileSync(seed, "utf-8"));
  const partnersDir = path.join(kb, "finance-partners"), productsDir = path.join(kb, "finance-products"), experienceDir = path.join(kb, "finance-experience");
  for (const d of [partnersDir, productsDir, experienceDir]) fs.mkdirSync(d, { recursive: true });
  const partners = seedData.partners || [];
  const grouped: Record<string, any[]> = {};
  for (const p of partners) { const ftype = TYPE_FILE[p.type || "bank"] || "banks"; (grouped[ftype] ||= []).push(p); }
  for (const ftype of ["banks", "securities", "funds", "investors"]) {
    const items = grouped[ftype] || [];
    const fpath = path.join(partnersDir, `${ftype}.json`);
    if (items.length || !fs.existsSync(fpath) || force) fs.writeFileSync(fpath, JSON.stringify({ file: ftype, partners: items }, null, 2), "utf-8");
  }
  const index: any = { version: "1.0.0", generated_at: localIso(), partner_count: partners.length, partners: [] };
  let productTotal = 0;
  for (const p of partners) {
    const products = p.products || []; const productList: any[] = [];
    for (const prod of products) {
      const fname = `${sanitizeFilename(p.name)}-${sanitizeFilename(prod.name)}.md`;
      const fpath = path.join(productsDir, fname);
      if (!fs.existsSync(fpath) || force) {
        const lines = ["---", `partner: ${p.name}`, `partner_type: ${TYPE_CN[p.type] || p.type}`, `product: ${prod.name}`, `type: ${prod.type || ""}`, `amount: ${prod.amount || ""}`, `term: ${prod.term || ""}`, `guarantee: ${prod.guarantee || ""}`, `target: ${prod.target || ""!}`, `rate: ${prod.rate || ""}`, "---", "", `# ${prod.name}`, "", `- 机构：${p.name}`, `- 产品类型：${prod.type || ""}`, `- 额度：${prod.amount || ""}`, `- 期限：${prod.term || ""}`, `- 担保方式：${prod.guarantee || ""}`, `- 适用客群：${prod.target || ""}`, ""];
        fs.writeFileSync(fpath, lines.join("\n"), "utf-8");
      }
      productList.push({ name: prod.name, type: prod.type || "", amount: prod.amount || "", term: prod.term || "", guarantee: prod.guarantee || "", target: prod.target || "", purpose: prod.purpose || [], file: path.join("finance-products", fname) });
    }
    index.partners.push({ partner_no: p.partner_no, name: p.name, type: p.type, strength_domains: p.strength_domains || [], service_count: p.service_count || 0, avg_cycle_days: p.avg_cycle_days || 0, products: productList });
    productTotal += products.length;
  }
  index.product_count = productTotal;
  index.finance_policies = seedData.finance_policies || [];
  const indexPath = path.join(kb, "finance-index.json");
  fs.writeFileSync(indexPath, JSON.stringify(index, null, 2), "utf-8");
  console.log(JSON.stringify({ success: true, index: indexPath, partner_count: partners.length, product_count: productTotal, output: indexPath }));
}

main().catch((e) => { console.error(e); process.exit(1); });