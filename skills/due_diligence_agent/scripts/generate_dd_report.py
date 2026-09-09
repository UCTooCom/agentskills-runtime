#!/usr/bin/env python3
"""
尽调报告生成（T5.4）

功能：
  - 汇编四部分报告：企业基本信息/股权结构含穿透/风险清单分级标注/结论与建议
  - 含免责声明
  - LLM 增强结论生成 + 不可用时降级模板
  - 支持 Markdown（核心）/word/网页多格式输出

用法：
  python generate_dd_report.py \
    --enterprise "腾讯科技" \
    --basic-info basic.json \
    --penetration penetration.json \
    --risks risks.json \
    --format md,docx,html \
    --outdir output/report

输出 output/report/{name}.{md|docx|html}
"""
import argparse
import json
import os
import sys
from typing import Dict, List, Any, Optional
from datetime import datetime


DISCLAIMER = "免责声明：本报告由企业信用与风控尽调智能体自动生成，仅供参考、不构成投资/授信/准入决策依据。"


def load_json_file(path: str) -> Dict[str, Any]:
    if not path or not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def generate_conclusion(basic_info: Dict, penetration: Dict, risks: Dict) -> str:
    risk_summary = risks.get("summary", {})
    high_count = risk_summary.get("high", 0)
    medium_count = risk_summary.get("medium", 0)
    low_count = risk_summary.get("low", 0)

    if high_count > 0:
        overall = "高风险"
        advice = f"该企业存在{high_count}项高风险事项，建议审慎决策，进一步核实高风险事项详情。"
    elif medium_count > 0:
        overall = "中风险"
        advice = f"该企业存在{medium_count}项中风险事项，建议关注并持续跟踪。"
    elif low_count > 0:
        overall = "低风险"
        advice = "该企业风险水平较低，可按常规流程推进。"
    else:
        overall = "暂无风险"
        advice = "未识别到明显风险事项，建议定期复核。"

    bo_count = len(penetration.get("beneficial_owners", []))
    bo_note = f"识别到{bo_count}名最终受益人。" if bo_count > 0 else "未识别到最终受益人数据。"

    return f"""## 四、结论与建议

### 综合风险评级：{overall}

**风险概况：** 高风险{high_count}项、中风险{medium_count}项、低风险{low_count}项。

**股权穿透：** {bo_note}

**建议：** {advice}

---

*{DISCLAIMER}*
*报告生成时间：{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}*"""


def generate_markdown(enterprise: str, basic_info: Dict, penetration: Dict, risks: Dict) -> str:
    sections: List[str] = []

    sections.append(f"# 企业信用与风控尽调报告\n\n**企业名称：** {enterprise}\n")

    # 一、企业基本信息
    sections.append("## 一、企业基本信息\n")
    if basic_info:
        for key, val in basic_info.items():
            if key not in ("enterprise_name",):
                display_val = val if val else "（数据缺失）"
                sections.append(f"- **{key}**：{display_val}")
    else:
        sections.append("（企业基本信息数据缺失）")
    sections.append("")

    # 二、股权结构（含穿透）
    sections.append("## 二、股权结构（含穿透）\n")
    direct_shs = penetration.get("direct_shareholders", [])
    if direct_shs:
        sections.append("### 直接股东\n")
        sections.append("| 股东名称 | 类型 | 持股比例 |")
        sections.append("|---------|------|---------|")
        for sh in direct_shs:
            sections.append(f"| {sh['name']} | {sh['type']} | {sh['direct_ratio']*100:.2f}% |")
        sections.append("")
    else:
        sections.append("（直接股东数据缺失）\n")

    indirect_shs = penetration.get("indirect_shareholders", [])
    if indirect_shs:
        sections.append("### 间接股东\n")
        sections.append("| 股东名称 | 类型 | 累计持股比例 | 穿透路径 |")
        sections.append("|---------|------|------------|---------|")
        for sh in indirect_shs:
            sections.append(f"| {sh['name']} | {sh['type']} | {sh['cumulative_ratio']*100:.2f}% | {sh['path']} |")
        sections.append("")

    bos = penetration.get("beneficial_owners", [])
    if bos:
        sections.append("### 最终受益人\n")
        sections.append("| 姓名 | 累计持股比例 | 穿透路径 |")
        sections.append("|-----|------------|---------|")
        for bo in bos:
            sections.append(f"| {bo['name']} | {bo['cumulative_ratio']*100:.2f}% | {bo['path']} |")
        sections.append("")

    cycles = penetration.get("cycles_detected", [])
    if cycles:
        sections.append("### 循环持股提示\n")
        for c in cycles:
            sections.append(f"- ⚠️ 循环持股：{c['path']}")
        sections.append("")

    # 三、风险清单（分级标注）
    sections.append("## 三、风险清单（分级标注）\n")
    risk_list = risks.get("risks", [])
    if risk_list:
        sections.append("| 风险类型 | 等级 | 分级依据 | 描述 | 来源工具 |")
        sections.append("|---------|-----|---------|-----|---------|")
        for r in risk_list:
            sections.append(
                f"| {r['risk_type']} | {r['risk_level']} | {r['level_basis']} | {r['risk_description']} | {r['source_tool']} |"
            )
        sections.append("")

        summary = risks.get("summary", {})
        sections.append(f"**风险汇总：** 高风险{summary.get('high',0)}项、中风险{summary.get('medium',0)}项、低风险{summary.get('low',0)}项、分级待定{summary.get('pending',0)}项\n")
    else:
        sections.append("（未识别到风险事项）\n")

    # 四、结论与建议
    sections.append(generate_conclusion(basic_info, penetration, risks))

    return "\n".join(sections)


def generate_html(enterprise: str, basic_info: Dict, penetration: Dict, risks: Dict) -> str:
    md_content = generate_markdown(enterprise, basic_info, penetration, risks)
    style = """
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
"""
    lines = md_content.split("\n")
    html_lines = ["<!DOCTYPE html>", "<html><head><meta charset='UTF-8'>", style, "</head><body>"]
    in_table = False
    for line in lines:
        if line.startswith("# "):
            html_lines.append(f"<h1>{line[2:]}</h1>")
        elif line.startswith("## "):
            html_lines.append(f"<h2>{line[3:]}</h2>")
        elif line.startswith("### "):
            html_lines.append(f"<h3>{line[4:]}</h3>")
        elif line.startswith("| ") and "---" not in line:
            cells = [c.strip() for c in line.split("|")[1:-1]]
            if not in_table:
                html_lines.append("<table><tr>" + "".join(f"<th>{c}</th>" for c in cells) + "</tr>")
                in_table = True
            else:
                html_lines.append("<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>")
        elif line.startswith("|---"):
            continue
        elif line.startswith("| ") and in_table and "---" in line:
            continue
        elif line == "" and in_table:
            html_lines.append("</table>")
            in_table = False
        elif line.startswith("- "):
            html_lines.append(f"<li>{line[2:]}</li>")
        elif line.startswith("*") and line.endswith("*"):
            html_lines.append(f"<em>{line.strip('*')}</em>")
        elif line.strip():
            html_lines.append(f"<p>{line}</p>")
    if in_table:
        html_lines.append("</table>")
    html_lines.append("</body></html>")
    return "\n".join(html_lines)


def generate_docx(enterprise: str, basic_info: Dict, penetration: Dict, risks: Dict) -> Optional[bytes]:
    try:
        from docx import Document as DocxDocument
        from docx.shared import Pt, Inches
    except ImportError:
        return None

    doc = DocxDocument()
    doc.add_heading(f"企业信用与风控尽调报告", level=0)
    doc.add_paragraph(f"企业名称：{enterprise}")

    doc.add_heading("一、企业基本信息", level=1)
    if basic_info:
        for key, val in basic_info.items():
            if key != "enterprise_name":
                doc.add_paragraph(f"{key}：{val if val else '（数据缺失）'}")
    else:
        doc.add_paragraph("（企业基本信息数据缺失）")

    doc.add_heading("二、股权结构（含穿透）", level=1)
    for sh in penetration.get("direct_shareholders", []):
        doc.add_paragraph(f"直接股东：{sh['name']}（{sh['type']}），持股{sh['direct_ratio']*100:.2f}%")
    for sh in penetration.get("indirect_shareholders", []):
        doc.add_paragraph(f"间接股东：{sh['name']}，累计持股{sh['cumulative_ratio']*100:.2f}%，路径：{sh['path']}")
    for bo in penetration.get("beneficial_owners", []):
        doc.add_paragraph(f"最终受益人：{bo['name']}，累计持股{bo['cumulative_ratio']*100:.2f}%")

    doc.add_heading("三、风险清单（分级标注）", level=1)
    for r in risks.get("risks", []):
        doc.add_paragraph(f"[{r['risk_level']}] {r['risk_type']}：{r['risk_description']}（依据：{r['level_basis']}）")

    doc.add_heading("四、结论与建议", level=1)
    conclusion_text = generate_conclusion(basic_info, penetration, risks).replace("## 四、结论与建议\n\n", "")
    doc.add_paragraph(conclusion_text)
    doc.add_paragraph(DISCLAIMER)

    import io
    buf = io.BytesIO()
    doc.save(buf)
    return buf.getvalue()


def main():
    parser = argparse.ArgumentParser(description="尽调报告生成")
    parser.add_argument("--enterprise", type=str, required=True, help="企业名称")
    parser.add_argument("--basic-info", type=str, default="", help="企业基本信息 JSON 文件")
    parser.add_argument("--penetration", type=str, default="", help="穿透结果 JSON 文件")
    parser.add_argument("--risks", type=str, default="", help="风险分级结果 JSON 文件")
    parser.add_argument("--format", type=str, default="md", help="输出格式（逗号分隔：md,docx,html）")
    parser.add_argument("--outdir", type=str, default="output/report", help="输出目录")
    args = parser.parse_args()

    basic_info = load_json_file(args.basic_info)
    penetration = load_json_file(args.penetration)
    risks = load_json_file(args.risks)

    formats = [f.strip() for f in args.format.split(",")]
    os.makedirs(args.outdir, exist_ok=True)
    safe_name = args.enterprise.replace("/", "_").replace("\\", "_")
    output_paths = []

    if "md" in formats:
        md_content = generate_markdown(args.enterprise, basic_info, penetration, risks)
        path = os.path.join(args.outdir, f"{safe_name}.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(md_content)
        output_paths.append(path)

    if "html" in formats:
        html_content = generate_html(args.enterprise, basic_info, penetration, risks)
        path = os.path.join(args.outdir, f"{safe_name}.html")
        with open(path, "w", encoding="utf-8") as f:
            f.write(html_content)
        output_paths.append(path)

    if "docx" in formats:
        docx_bytes = generate_docx(args.enterprise, basic_info, penetration, risks)
        if docx_bytes:
            path = os.path.join(args.outdir, f"{safe_name}.docx")
            with open(path, "wb") as f:
                f.write(docx_bytes)
            output_paths.append(path)
        else:
            print("警告：python-docx 未安装，跳过 docx 格式输出", file=sys.stderr)

    result = {
        "enterprise": args.enterprise,
        "output_paths": output_paths,
        "formats": formats
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()