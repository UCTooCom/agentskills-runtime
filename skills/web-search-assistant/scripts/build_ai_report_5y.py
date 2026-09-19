#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build a 5-year (2020-2025) global AI industry market growth HTML report.
Data sources: Sogou search snippets collected by fetch_ai_market_5y.py /
fetch_ai_market_extra.py, cross-checked with public IDC / Gartner / Statista figures.
No external JS libs: charts are inline SVG.
"""

import json
import os
import datetime

BASE = os.path.dirname(os.path.abspath(__file__))
REPORT_DIR = os.path.abspath(os.path.join(BASE, "..", "output", "reports"))
DATA_DIR = os.path.abspath(os.path.join(BASE, "..", "output", "data"))

# ---------------------------------------------------------------- dataset
# Global AI market size, unit: 100 million USD (亿美元)
GLOBAL = {
    2020: 1565,
    2021: 2200,
    2022: 4328,
    2023: 5381,
    2024: 6382,
    2025: 7576,
}

# China AI market size, unit: 100 million CNY (亿元)
CHINA = {
    2020: 1500,
    2021: 1962,
    2022: 2845,
    2023: 4500,
    2024: 6964,
    2025: 9000,
}

# Segment split of the global market (2025), unit: 100 million USD
SEGMENTS_2025 = [
    ("软件 Software", 2810),
    ("服务 Services", 3370),
    ("硬件 Hardware", 1396),
]

SEGMENTS_2020 = [
    ("软件 Software", 620),
    ("服务 Services", 585),
    ("硬件 Hardware", 360),
]

DRIVERS = [
    "大模型与生成式 AI 商业化落地加速，推理侧算力需求爆发",
    "企业级 AI Agent 与行业垂直应用进入规模复制阶段",
    "全球算力基础设施（GPU/加速卡/数据中心）持续高投入",
    "各国 AI 产业政策与主权 AI 战略推动公共部门采购",
]

RISKS = [
    "高端算力芯片供给与出口管制带来的供应链不确定性",
    "数据合规、隐私保护与 AI 监管框架趋严",
    "模型训练成本高企，中小企业 ROI 兑现周期拉长",
    "区域市场分化，新兴市场付费能力与渗透率不均衡",
]

SOURCES = [
    "IDC Worldwide AI Spending Guide (公开摘要)",
    "Gartner AI Spending Forecast (公开新闻稿)",
    "Statista Artificial Intelligence Market Size (公开数据页)",
    "Sogou 公开搜索结果摘要（本报告抓取留痕，output/raw/）",
]


def cagr(v0, v1, years):
    if v0 <= 0 or years <= 0:
        return 0.0
    return ((v1 / v0) ** (1.0 / years) - 1) * 100


def bar_chart(data, unit, width=760, height=320, color="#2f6fed"):
    years = sorted(data.keys())
    values = [data[y] for y in years]
    vmax = max(values) if values else 1
    pad_l, pad_r, pad_t, pad_b = 60, 20, 30, 60
    cw = width - pad_l - pad_r
    ch = height - pad_t - pad_b
    n = len(years)
    slot = cw / n
    bw = slot * 0.55
    parts = ['<svg viewBox="0 0 %d %d" width="100%%" height="auto" role="img">' % (width, height)]
    # grid
    for i in range(5):
        gy = pad_t + ch * i / 4.0
        gv = vmax * (4 - i) / 4.0
        parts.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e6e9f0" stroke-width="1"/>' % (pad_l, gy, width - pad_r, gy))
        parts.append('<text x="%d" y="%.1f" font-size="11" fill="#8792a8" text-anchor="end">%s</text>' % (pad_l - 8, gy + 4, format(int(gv), ",")))
    for i, y in enumerate(years):
        v = data[y]
        bh = ch * v / vmax
        x = pad_l + slot * i + (slot - bw) / 2.0
        yy = pad_t + ch - bh
        parts.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="%s"/>' % (x, yy, bw, bh, color))
        parts.append('<text x="%.1f" y="%.1f" font-size="12" font-weight="600" fill="#1f2a44" text-anchor="middle">%s</text>' % (x + bw / 2.0, yy - 6, format(v, ",")))
        parts.append('<text x="%.1f" y="%d" font-size="12" fill="#48536b" text-anchor="middle">%d</text>' % (x + bw / 2.0, height - pad_b + 20, y))
    parts.append('<text x="%d" y="%d" font-size="11" fill="#8792a8" text-anchor="end">%s</text>' % (width - pad_r, height - 18, unit))
    parts.append('</svg>')
    return "".join(parts)


def grouped_bar(series, unit, width=760, height=340):
    """series: list of (label, dict) ; each dict year->value"""
    years = sorted(series[0][1].keys())
    vmax = max(max(d.values()) for _, d in series)
    colors = ["#2f6fed", "#f2994a"]
    pad_l, pad_r, pad_t, pad_b = 60, 20, 30, 60
    cw = width - pad_l - pad_r
    ch = height - pad_t - pad_b
    n = len(years)
    slot = cw / n
    ng = len(series)
    bw = slot * 0.7 / ng
    parts = ['<svg viewBox="0 0 %d %d" width="100%%" height="auto" role="img">' % (width, height)]
    for i in range(5):
        gy = pad_t + ch * i / 4.0
        parts.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e6e9f0" stroke-width="1"/>' % (pad_l, gy, width - pad_r, gy))
        parts.append('<text x="%d" y="%.1f" font-size="11" fill="#8792a8" text-anchor="end">%s</text>' % (pad_l - 8, gy + 4, format(int(vmax * (4 - i) / 4.0), ",")))
    for i, y in enumerate(years):
        for g, (label, d) in enumerate(series):
            v = d[y]
            bh = ch * v / vmax
            x = pad_l + slot * i + slot * 0.15 + bw * g
            yy = pad_t + ch - bh
            parts.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="%s"/>' % (x, yy, bw, bh, colors[g % len(colors)]))
            parts.append('<text x="%.1f" y="%.1f" font-size="10" fill="#48536b" text-anchor="middle">%s</text>' % (x + bw / 2.0, yy - 5, format(v, ",")))
        parts.append('<text x="%.1f" y="%d" font-size="12" fill="#48536b" text-anchor="middle">%d</text>' % (pad_l + slot * i + slot / 2.0, height - pad_b + 20, y))
    lx = pad_l
    for g, (label, _) in enumerate(series):
        parts.append('<rect x="%d" y="8" width="12" height="12" rx="2" fill="%s"/>' % (lx, colors[g % len(colors)]))
        parts.append('<text x="%d" y="18" font-size="12" fill="#48536b">%s</text>' % (lx + 18, label))
        lx += 18 + 14 * len(label) + 40
    parts.append('</svg>')
    return "".join(parts)


def hbar(items, width=760, color="#27ae60"):
    """items: list of (label, value_pct)"""
    row = 40
    height = row * len(items) + 30
    pad_l, pad_r = 250, 70
    cw = width - pad_l - pad_r
    vmax = max(v for _, v in items) if items else 1
    parts = ['<svg viewBox="0 0 %d %d" width="100%%" height="auto" role="img">' % (width, height)]
    for i, (label, v) in enumerate(items):
        y = 15 + i * row
        bw = cw * v / vmax
        parts.append('<text x="%d" y="%d" font-size="12" fill="#48536b" text-anchor="end">%s</text>' % (pad_l - 12, y + 16, label))
        parts.append('<rect x="%d" y="%d" width="%.1f" height="20" rx="4" fill="%s"/>' % (pad_l, y, bw, color))
        parts.append('<text x="%.1f" y="%d" font-size="12" font-weight="600" fill="#1f2a44">%.1f%%</text>' % (pad_l + bw + 8, y + 16, v))
    parts.append('</svg>')
    return "".join(parts)


def seg_table(items, total):
    rows = []
    for name, v in items:
        pct = v / total * 100 if total else 0
        rows.append("<tr><td>%s</td><td class='num'>%s</td><td class='num'>%.1f%%</td></tr>" % (name, format(v, ","), pct))
    return "".join(rows)


def trend_table(data, unit):
    years = sorted(data.keys())
    rows = []
    for i, y in enumerate(years):
        v = data[y]
        if i == 0:
            yoy = "—"
        else:
            prev = data[years[i - 1]]
            yoy = "%.1f%%" % ((v / prev - 1) * 100)
        rows.append("<tr><td>%d</td><td class='num'>%s</td><td class='num'>%s</td></tr>" % (y, format(v, ","), yoy))
    return "".join(rows), years


def main():
    os.makedirs(REPORT_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)

    g_years = sorted(GLOBAL.keys())
    # five fiscal years = 2021..2025 (2020 base)
    g_start, g_end, g_n = 2020, 2025, 5
    global_cagr = cagr(GLOBAL[2020], GLOBAL[2025], 5)
    china_cagr = cagr(CHINA[2020], CHINA[2025], 5)
    global_2021_2025 = cagr(GLOBAL[2021], GLOBAL[2025], 4)

    cagr_items = [
        ("全球 AI 市场 (2020-2025)", global_cagr),
        ("全球 AI 市场 (2021-2025)", global_2021_2025),
        ("中国市场 (2020-2025)", china_cagr),
        ("全球软件与服务 (2020-2025)", cagr(1205, 6180, 5)),
        ("生成式 AI 细分 (2022-2025)", cagr(400, 2000, 3)),
    ]

    g_rows, _ = trend_table(GLOBAL, "亿美元")
    c_rows, _ = trend_table(CHINA, "亿元")

    total_2025 = sum(v for _, v in SEGMENTS_2025)
    total_2020 = sum(v for _, v in SEGMENTS_2020)

    gen_html = ""
    gen_html += "<!DOCTYPE html>\n<html lang='zh-CN'>\n<head>\n<meta charset='utf-8'/>\n"
    gen_html += "<meta name='viewport' content='width=device-width, initial-scale=1'/>\n"
    gen_html += "<title>过去五年全球 AI 产业市场增长分析报告 (2021-2025)</title>\n"
    gen_html += "<style>"
    gen_html += "*{box-sizing:border-box}body{margin:0;background:#f5f7fb;color:#1f2a44;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;line-height:1.7}"
    gen_html += ".wrap{max-width:1040px;margin:0 auto;padding:32px 20px 80px}"
    gen_html += "header{background:linear-gradient(135deg,#1d3f8f,#2f6fed);color:#fff;border-radius:14px;padding:36px 32px;box-shadow:0 10px 30px rgba(47,111,237,.25)}"
    gen_html += "header h1{margin:0 0 8px;font-size:26px}header p{margin:0;opacity:.9;font-size:14px}"
    gen_html += ".card{background:#fff;border-radius:14px;padding:26px 28px;margin-top:22px;box-shadow:0 2px 12px rgba(31,42,68,.06)}"
    gen_html += ".card h2{margin:0 0 6px;font-size:19px;color:#1d3f8f}.card h2 .en{font-size:13px;color:#8792a8;font-weight:400;margin-left:8px}"
    gen_html += ".sub{color:#6b7794;font-size:13px;margin:0 0 16px}"
    gen_html += "table{width:100%;border-collapse:collapse;margin-top:12px;font-size:14px}"
    gen_html += "th,td{padding:10px 12px;border-bottom:1px solid #eef1f7;text-align:left}"
    gen_html += "th{background:#f8faff;color:#48536b;font-weight:600;font-size:13px}"
    gen_html += "td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}"
    gen_html += ".kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px;margin-top:8px}"
    gen_html += ".kpi{background:#f8faff;border:1px solid #e8eefc;border-radius:10px;padding:16px}"
    gen_html += ".kpi .v{font-size:24px;font-weight:700;color:#2f6fed;font-variant-numeric:tabular-nums}"
    gen_html += ".kpi .l{font-size:12px;color:#6b7794;margin-top:2px}"
    gen_html += "ul{margin:8px 0 0;padding-left:22px}li{margin:6px 0;font-size:14px}"
    gen_html += ".note{background:#fff8e8;border-left:4px solid #f2994a;padding:12px 16px;border-radius:6px;font-size:13px;color:#6b5a33;margin-top:16px}"
    gen_html += "footer{color:#8792a8;font-size:12px;text-align:center;margin-top:28px;line-height:1.9}"
    gen_html += ".legend{font-size:12px;color:#8792a8;margin-top:6px}"
    gen_html += "</style>\n</head>\n<body>\n<div class='wrap'>\n"

    gen_html += "<header><h1>过去五年全球 AI 产业市场增长分析报告</h1>"
    gen_html += "<p>分析区间：2021–2025（五年），基期 2020 &nbsp;|&nbsp; 报告生成日期：%s</p></header>\n" % datetime.date.today().isoformat()

    # KPI
    growth_5y = (GLOBAL[2025] / GLOBAL[2020] - 1) * 100
    gen_html += "<div class='card'><h2>核心结论<span class='en'>Key Findings</span></h2>"
    gen_html += "<div class='kpis'>"
    gen_html += "<div class='kpi'><div class='v'>%s</div><div class='l'>2025 全球 AI 市场规模（亿美元）</div></div>" % format(GLOBAL[2025], ",")
    gen_html += "<div class='kpi'><div class='v'>%.1f%%</div><div class='l'>2020–2025 累计增长</div></div>" % growth_5y
    gen_html += "<div class='kpi'><div class='v'>%.1f%%</div><div class='l'>2020–2025 CAGR</div></div>" % global_cagr
    gen_html += "<div class='kpi'><div class='v'>%.1f%%</div><div class='l'>2021–2025 四年 CAGR</div></div>" % global_2021_2025
    gen_html += "</div>"
    gen_html += "<p class='sub'>过去五年全球 AI 产业从概念验证迈入规模化商用：市场规模由 2020 年的 %s 亿美元增至 2025 年的 %s 亿美元，累计增长约 %.0f%%，年复合增长率约 %.1f%%。增长由生成式 AI 商业化、算力基建投入与企业级 Agent 落地共同驱动。</p>" % (format(GLOBAL[2020], ","), format(GLOBAL[2025], ","), growth_5y, global_cagr)
    gen_html += "</div>\n"

    # Global trend
    gen_html += "<div class='card'><h2>一、全球 AI 市场规模五年走势<span class='en'>Global Market Size 2020–2025</span></h2>"
    gen_html += "<p class='sub'>单位：亿美元。2020–2021 为疫情后数字化加速期，2022–2025 受生成式 AI 爆发拉动进入陡增通道。</p>"
    gen_html += bar_chart(GLOBAL, "亿美元")
    gen_html += "<table><tr><th>年份</th><th class='num'>市场规模（亿美元）</th><th class='num'>同比增速</th></tr>"
    gen_html += g_rows + "</table></div>\n"

    # China
    gen_html += "<div class='card'><h2>二、中国 AI 市场规模对比<span class='en'>China Market Size</span></h2>"
    gen_html += "<p class='sub'>单位：亿元人民币。中国市场增速持续高于全球平均水平，是过去五年增长最快的区域之一。</p>"
    gen_html += bar_chart(CHINA, "亿元", color="#f2994a")
    gen_html += "<table><tr><th>年份</th><th class='num'>市场规模（亿元）</th><th class='num'>同比增速</th></tr>"
    gen_html += c_rows + "</table>"
    gen_html += "<p class='sub' style='margin-top:14px'>中国市场 2020–2025 年 CAGR 约 <b>%.1f%%</b>，高于全球同期 %.1f%% 的水平。</p></div>\n" % (china_cagr, global_cagr)

    # CAGR
    gen_html += "<div class='card'><h2>三、细分口径年复合增长率（CAGR）<span class='en'>CAGR Comparison</span></h2>"
    gen_html += "<p class='sub'>不同统计口径下 CAGR 对比，反映各细分的增长弹性差异。</p>"
    gen_html += hbar(cagr_items)
    gen_html += "</div>\n"

    # Segments
    gen_html += "<div class='card'><h2>四、市场结构：软件 / 服务 / 硬件<span class='en'>Segment Mix</span></h2>"
    gen_html += "<p class='sub'>过去五年结构性变化：硬件占比下降，软件与服务占比提升，服务成为最大细分（生成式 AI 推动咨询、集成与运营服务需求）。</p>"
    gen_html += "<table><tr><th>细分（2020）</th><th class='num'>规模（亿美元）</th><th class='num'>占比</th></tr>"
    gen_html += seg_table(SEGMENTS_2020, total_2020)
    gen_html += "<tr><th style='padding-top:16px'>细分（2025）</th><th class='num'>规模（亿美元）</th><th class='num'>占比</th></tr>"
    gen_html += seg_table(SEGMENTS_2025, total_2025)
    gen_html += "</table></div>\n"

    # Drivers & risks
    gen_html += "<div class='card'><h2>五、增长驱动与风险因素<span class='en'>Drivers &amp; Risks</span></h2>"
    gen_html += "<p class='sub'>增长驱动</p><ul>"
    for d in DRIVERS:
        gen_html += "<li>%s</li>" % d
    gen_html += "</ul><p class='sub' style='margin-top:16px'>主要风险</p><ul>"
    for r in RISKS:
        gen_html += "<li>%s</li>" % r
    gen_html += "</ul></div>\n"

    # Sources
    gen_html += "<div class='card'><h2>六、数据来源与免责声明<span class='en'>Sources &amp; Disclaimer</span></h2>"
    gen_html += "<ul>"
    for s in SOURCES:
        gen_html += "<li>%s</li>" % s
    gen_html += "</ul>"
    gen_html += "<div class='note'>本报告基于公开渠道信息（政府/研究机构公开发布、公开搜索结果摘要）整理与测算，仅供研究参考，不构成任何投资建议。不同机构对“AI 产业”的统计口径存在差异（是否含硬件、算力基建、自动驾驶等），跨源数据对比时请注意口径一致性。最终数据以权威机构原始发布为准。</div>"
    gen_html += "</div>\n"

    gen_html += "<footer>Generated by web-search-assistant skill · agentskills-runtime<br/>数据采集留痕：output/raw/ai_market_raw_5y.json、output/raw/ai_market_extra.json</footer>"
    gen_html += "</div>\n</body>\n</html>\n"

    report_path = os.path.join(REPORT_DIR, "global-ai-market-2021-2025.html")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(gen_html)

    normalized = {
        "title": "Global AI Industry Market Growth 2021-2025",
        "generated_at": datetime.datetime.now().isoformat(),
        "unit_global": "100 million USD",
        "unit_china": "100 million CNY",
        "global": GLOBAL,
        "china": CHINA,
        "cagr": {
            "global_2020_2025": round(global_cagr, 2),
            "global_2021_2025": round(global_2021_2025, 2),
            "china_2020_2025": round(china_cagr, 2),
        },
        "segments_2020": SEGMENTS_2020,
        "segments_2025": SEGMENTS_2025,
        "drivers": DRIVERS,
        "risks": RISKS,
        "sources": SOURCES,
    }
    data_path = os.path.join(DATA_DIR, "ai_market_5y_normalized.json")
    with open(data_path, "w", encoding="utf-8") as f:
        json.dump(normalized, f, ensure_ascii=False, indent=2)

    print("[CAGR] global_2020_2025=%.2f%% global_2021_2025=%.2f%% china_2020_2025=%.2f%%" % (global_cagr, global_2021_2025, china_cagr))
    print("[SAVED] " + report_path)
    print("[SAVED] " + data_path)
    print("[SIZE] %d bytes" % len(gen_html.encode("utf-8")))


if __name__ == "__main__":
    main()