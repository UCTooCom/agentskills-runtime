#!/usr/bin/env node
/**
 * 尽调报告生成（T5.4） - TypeScript 版本
 * 功能与 generate_dd_report.py 完全一致
 * docx 格式因 Node.js 无内置 docx 库而降级跳过（与 Python 中 python-docx 未安装时行为一致）
 * 运行：node --experimental-strip-types scripts/generate_dd_report.ts [参数]
 */
import * as fs from 'node:fs';
import * as path from 'node:path';

type Dict = Record<string, any>;

const DISCLAIMER = '免责声明：本报告由企业信用与风控尽调智能体自动生成，仅供参考、不构成投资/授信/准入决策依据。';

function formatDateTime(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

function loadJsonFile(filePath: string): Dict {
  if (!filePath || !fs.existsSync(filePath)) return {};
  return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
}

function generateConclusion(basicInfo: Dict, penetration: Dict, risks: Dict): string {
  const riskSummary: Dict = risks.summary ?? {};
  const highCount: number = riskSummary.high ?? 0;
  const mediumCount: number = riskSummary.medium ?? 0;
  const lowCount: number = riskSummary.low ?? 0;

  let overall: string, advice: string;
  if (highCount > 0) {
    overall = '高风险';
    advice = `该企业存在${highCount}项高风险事项，建议审慎决策，进一步核实高风险事项详情。`;
  } else if (mediumCount > 0) {
    overall = '中风险';
    advice = `该企业存在${mediumCount}项中风险事项，建议关注并持续跟踪。`;
  } else if (lowCount > 0) {
    overall = '低风险';
    advice = '该企业风险水平较低，可按常规流程推进。';
  } else {
    overall = '暂无风险';
    advice = '未识别到明显风险事项，建议定期复核。';
  }

  const boCount = (penetration.beneficial_owners ?? []).length;
  const boNote = boCount > 0 ? `识别到${boCount}名最终受益人。` : '未识别到最终受益人数据。';

  return `## 四、结论与建议

### 综合风险评级：${overall}

**风险概况：** 高风险${highCount}项、中风险${mediumCount}项、低风险${lowCount}项。

**股权穿透：** ${boNote}

**建议：** ${advice}

---

*${DISCLAIMER}*
*报告生成时间：${formatDateTime(new Date())}*`;
}

function generateMarkdown(enterprise: string, basicInfo: Dict, penetration: Dict, risks: Dict): string {
  const sections: string[] = [];

  sections.push(`# 企业信用与风控尽调报告\n\n**企业名称：** ${enterprise}\n`);

  // 一、企业基本信息
  sections.push('## 一、企业基本信息\n');
  if (Object.keys(basicInfo).length > 0) {
    for (const [key, val] of Object.entries(basicInfo)) {
      if (key !== 'enterprise_name') {
        const displayVal = val || '（数据缺失）';
        sections.push(`- **${key}**：${displayVal}`);
      }
    }
  } else {
    sections.push('（企业基本信息数据缺失）');
  }
  sections.push('');

  // 二、股权结构（含穿透）
  sections.push('## 二、股权结构（含穿透）\n');
  const directShs: Dict[] = penetration.direct_shareholders ?? [];
  if (directShs.length > 0) {
    sections.push('### 直接股东\n');
    sections.push('| 股东名称 | 类型 | 持股比例 |');
    sections.push('|---------|------|---------|');
    for (const sh of directShs) {
      sections.push(`| ${sh.name} | ${sh.type} | ${(sh.direct_ratio * 100).toFixed(2)}% |`);
    }
    sections.push('');
  } else {
    sections.push('（直接股东数据缺失）\n');
  }

  const indirectShs: Dict[] = penetration.indirect_shareholders ?? [];
  if (indirectShs.length > 0) {
    sections.push('### 间接股东\n');
    sections.push('| 股东名称 | 类型 | 累计持股比例 | 穿透路径 |');
    sections.push('|---------|------|------------|---------|');
    for (const sh of indirectShs) {
      sections.push(`| ${sh.name} | ${sh.type} | ${(sh.cumulative_ratio * 100).toFixed(2)}% | ${sh.path} |`);
    }
    sections.push('');
  }

  const bos: Dict[] = penetration.beneficial_owners ?? [];
  if (bos.length > 0) {
    sections.push('### 最终受益人\n');
    sections.push('| 姓名 | 累计持股比例 | 穿透路径 |');
    sections.push('|-----|------------|---------|');
    for (const bo of bos) {
      sections.push(`| ${bo.name} | ${(bo.cumulative_ratio * 100).toFixed(2)}% | ${bo.path} |`);
    }
    sections.push('');
  }

  const cycles: Dict[] = penetration.cycles_detected ?? [];
  if (cycles.length > 0) {
    sections.push('### 循环持股提示\n');
    for (const c of cycles) {
      sections.push(`- ⚠️ 循环持股：${c.path}`);
    }
    sections.push('');
  }

  // 三、风险清单（分级标注）
  sections.push('## 三、风险清单（分级标注）\n');
  const riskList: Dict[] = risks.risks ?? [];
  if (riskList.length > 0) {
    sections.push('| 风险类型 | 等级 | 分级依据 | 描述 | 来源工具 |');
    sections.push('|---------|-----|---------|-----|---------|');
    for (const r of riskList) {
      sections.push(
        `| ${r.risk_type} | ${r.risk_level} | ${r.level_basis} | ${r.risk_description} | ${r.source_tool} |`
      );
    }
    sections.push('');

    const summary: Dict = risks.summary ?? {};
    sections.push(`**风险汇总：** 高风险${summary.high ?? 0}项、中风险${summary.medium ?? 0}项、低风险${summary.low ?? 0}项、分级待定${summary.pending ?? 0}项\n`);
  } else {
    sections.push('（未识别到风险事项）\n');
  }

  // 四、结论与建议
  sections.push(generateConclusion(basicInfo, penetration, risks));

  return sections.join('\n');
}

function generateHtml(enterprise: string, basicInfo: Dict, penetration: Dict, risks: Dict): string {
  const mdContent = generateMarkdown(enterprise, basicInfo, penetration, risks);
  const style = `
<style>
body { font-family: 'Microsoft YaHei', sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; }
h1 { color: #1a5276; border-bottom: 3px solid #1a5276; padding-bottom: 10px; }
h2 { color: #2874a6; margin-top: 30px; }
h3 { color: #3498db; }
table { border-collapse: collapse; width: 100%; margin: 10px 0; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #f2f2f2; }
em { color: #7f8c8d; font-size: 0.9em; }
</style>
`;
  const lines = mdContent.split('\n');
  const htmlLines: string[] = ['<!DOCTYPE html>', "<html><head><meta charset='UTF-8'>", style, '</head><body>'];
  let inTable = false;
  for (const line of lines) {
    if (line.startsWith('# ')) {
      htmlLines.push(`<h1>${line.slice(2)}</h1>`);
    } else if (line.startsWith('## ')) {
      htmlLines.push(`<h2>${line.slice(3)}</h2>`);
    } else if (line.startsWith('### ')) {
      htmlLines.push(`<h3>${line.slice(4)}</h3>`);
    } else if (line.startsWith('| ') && !line.includes('---')) {
      const cells = line.split('|').slice(1, -1).map(c => c.trim());
      if (!inTable) {
        htmlLines.push('<table><tr>' + cells.map(c => `<th>${c}</th>`).join('') + '</tr>');
        inTable = true;
      } else {
        htmlLines.push('<tr>' + cells.map(c => `<td>${c}</td>`).join('') + '</tr>');
      }
    } else if (line.startsWith('|---')) {
      continue;
    } else if (line.startsWith('| ') && inTable && line.includes('---')) {
      continue;
    } else if (line === '' && inTable) {
      htmlLines.push('</table>');
      inTable = false;
    } else if (line.startsWith('- ')) {
      htmlLines.push(`<li>${line.slice(2)}</li>`);
    } else if (line.startsWith('*') && line.endsWith('*')) {
      htmlLines.push(`<em>${line.replace(/^\*+/, '').replace(/\*+$/, '')}</em>`);
    } else if (line.trim()) {
      htmlLines.push(`<p>${line}</p>`);
    }
  }
  if (inTable) {
    htmlLines.push('</table>');
  }
  htmlLines.push('</body></html>');
  return htmlLines.join('\n');
}

function main(): void {
  const args = process.argv.slice(2);
  let enterprise = '', basicInfoFile = '', penetrationFile = '', risksFile = '';
  let format = 'md', outdir = 'output/report';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--enterprise' && i + 1 < args.length) enterprise = args[++i];
    else if (args[i] === '--basic-info' && i + 1 < args.length) basicInfoFile = args[++i];
    else if (args[i] === '--penetration' && i + 1 < args.length) penetrationFile = args[++i];
    else if (args[i] === '--risks' && i + 1 < args.length) risksFile = args[++i];
    else if (args[i] === '--format' && i + 1 < args.length) format = args[++i];
    else if (args[i] === '--outdir' && i + 1 < args.length) outdir = args[++i];
  }

  if (!enterprise) {
    console.error('错误：缺少必需参数 --enterprise');
    process.exit(2);
  }

  const basicInfo = loadJsonFile(basicInfoFile);
  const penetration = loadJsonFile(penetrationFile);
  const risks = loadJsonFile(risksFile);

  const formats = format.split(',').map(f => f.trim());
  fs.mkdirSync(outdir, { recursive: true });
  const safeName = enterprise.replace(/\//g, '_').replace(/\\/g, '_');
  const outputPaths: string[] = [];

  if (formats.includes('md')) {
    const mdContent = generateMarkdown(enterprise, basicInfo, penetration, risks);
    const filePath = path.join(outdir, `${safeName}.md`);
    fs.writeFileSync(filePath, mdContent, 'utf-8');
    outputPaths.push(filePath);
  }

  if (formats.includes('html')) {
    const htmlContent = generateHtml(enterprise, basicInfo, penetration, risks);
    const filePath = path.join(outdir, `${safeName}.html`);
    fs.writeFileSync(filePath, htmlContent, 'utf-8');
    outputPaths.push(filePath);
  }

  if (formats.includes('docx')) {
    // docx 为 Python-only 能力：Node 无内置 docx 库且不引入 npm 依赖，
    // 与 py 版 python-docx 未安装时的降级行为对齐，并显式指引切换到 Python 版本
    console.error('警告：TypeScript 版本不支持 docx 输出（Node 无内置 docx 库），跳过 docx 格式。如需 docx，请降级使用 Python 版本（需 pip install python-docx）：python scripts/generate_dd_report.py [相同参数]');
  }

  const result = {
    enterprise,
    output_paths: outputPaths,
    formats
  };
  console.log(JSON.stringify(result, null, 2));
}

main();