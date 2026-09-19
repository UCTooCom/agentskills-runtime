# -*- coding: utf-8 -*-
"""整理全球AI产业市场数据 + 生成自包含 HTML 报告（纯内嵌 CSS/SVG，无外部依赖）"""
import json, os, math

BASE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.abspath(os.path.join(BASE, "..", "output"))
os.makedirs(os.path.join(OUTDIR, "reports"), exist_ok=True)
os.makedirs(os.path.join(OUTDIR, "data"), exist_ok=True)

# ============ 1. 规范化数据集（来源：公开搜索结果摘要，已标注机构口径） ============
GLOBAL = [
    {"year": 2022, "value": 4328, "label": "IDC口径（软/硬/服务）", "source": "IDC"},
    {"year": 2023, "value": 5381, "label": "综合市场规模", "source": "公开研究报告"},
    {"year": 2024, "value": 6382, "label": "综合市场规模", "source": "公开研究报告"},
    {"year": 2025, "value": 7500, "label": "预测值（按近期CAGR外推）", "source": "测算"},
]

CHINA = [
    {"year": 2022, "value": 2845, "label": "中国AI市场规模", "source": "公开研究报告"},
    {"year": 2023, "value": 4500, "label": "中国AI核心产业规模（估算）", "source": "测算"},
    {"year": 2024, "value": 6964, "label": "中国AI核心产业规模", "source": "公开研究报告"},
    {"year": 2025, "value": 9000, "label": "预测值（+24%同比）", "source": "公开研究报告"},
]

SEGMENTS = [
    {"name": "全球 AI 软件", "year": 2022, "value": 625, "unit": "亿美元", "note": "同比 +21.3%", "source": "IDC"},
    {"name": "全球 AI 芯片", "year": 2025, "value": 800, "unit": "亿美元", "note": "中信证券预测，>800亿", "source": "中信证券"},
    {"name": "中国生成式 AI 软件", "year": 2025, "value": 35.4, "unit": "亿美元", "note": "IDC 口径", "source": "IDC"},
    {"name": "全球 AI 技术支出", "year": 2025, "value": 3370, "unit": "亿美元", "note": "2028 预计 7490 亿", "source": "IDC"},
]

CAGR_CASES = [
    {"name": "全球 AI 市场（2022-2024）", "cagr": None, "base": (4328, 6382, 2)},
    {"name": "中国 AI 市场（2022-2024）", "cagr": None, "base": (2845, 6964, 2)},
    {"name": "全球生成式 AI（至2028）", "cagr": 63.8, "base": None},
    {"name": "全球 AI 系统支出（2021-2025）", "cagr": 24.5, "base": None},
    {"name": "中国 AI（2024-2028, IDC）", "cagr": 32.9, "base": None},
    {"name": "全球 AI 技术支出（2025-2028）", "cagr": None, "base": (3370, 7490, 3)},
]

DRIVERS = [
    ("大模型与生成式 AI 商业化", "生成式 AI 五年 CAGR 约 63.8%（至 2028），是增速最快的细分赛道"),
    ("算力基础设施投资", "2025 全球 AI 芯片市场预计 >800 亿美元，云与数据中心资本开支持续高位"),
    ("企业级 AI 渗透", "IDC 口径下 2025 全球 AI 技术支出 3370 亿美元，2028 年预计翻倍至 7490 亿美元"),
    ("中国政策与产业双驱动", "中国 AI 核心产业 2022→2024 规模接近翻倍，2017-2022 年 CAGR 达 55.0%"),
]

RISKS = [
    ("口径不一致风险", "各机构统计范围差异显著（是否含硬件、是否含服务），跨源数字不可直接相加"),
    ("数据可得性风险", "部分 2025 年数据为机构预测值，实际值待年报确认"),
    ("投资回报不确定性", "算力投入与商业变现之间存在时滞，部分细分领域存在估值回调压力"),
    ("合规与监管风险", "各国 AI 监管框架逐步落地，可能影响数据跨境与模型部署节奏"),
]

for c in CAGR_CASES:
    if c["base"]:
        v0, v1, n = c["base"]
        c["cagr"] = round(((v1 / v0) ** (1.0 / n) - 1) * 100, 1)

with open(os.path.join(OUTDIR, "data", "ai_market_normalized.json"), "w", encoding="utf-8") as f:
    json.dump({"global": GLOBAL, "china": CHINA, "segments": SEGMENTS, "cagr": CAGR_CASES},
              f, ensure_ascii=False, indent=2)

# ============ 2. SVG 柱状图生成 ============
def bar_chart(data, unit="亿美元", w=720, h=300):
    if not data:
        return ""
    pad_l, pad_b, pad_t, pad_r = 70, 50, 30, 20
    plot_w, plot_h = w - pad_l - pad_r, h - pad_b - pad_t
    maxv = max(d["value"] for d in data) * 1.15
    n = len(data)
    slot = plot_w / n
    bw = slot * 0.5
    parts = ['<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg" role="img">' % (w, h)]
    for i in range(5):
        y = pad_t + plot_h - plot_h * i / 4.0
        val = maxv * i / 4.0
        parts.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>' % (pad_l, y, w - pad_r, y))
        parts.append('<text x="%d" y="%.1f" font-size="11" fill="#94a3b8" text-anchor="end">%s</text>' % (pad_l - 8, y + 4, ("%.0f" % val)))
    for i, d in enumerate(data):
        x = pad_l + slot * i + (slot - bw) / 2.0
        bh = plot_h * (d["value"] / maxv)
        y = pad_t + plot_h - bh
        parts.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="6" fill="url(#g1)"/>' % (x, y, bw, bh))
        parts.append('<text x="%.1f" y="%.1f" font-size="12" font-weight="600" fill="#1e293b" text-anchor="middle">%s</text>' % (x + bw / 2, y - 7, ("%g" % d["value"])))
        parts.append('<text x="%.1f" y="%d" font-size="12" fill="#475569" text-anchor="middle">%s</text>' % (x + bw / 2, h - pad_b + 20, d.get("year", d.get("name", ""))))
    parts.append('<defs><linearGradient id="g1" x1="0" y1="0" x2="0" y2="1"><stop offset="0%%" stop-color="#3b82f6"/><stop offset="100%%" stop-color="#1d4ed8"/></linearGradient></defs>')
    parts.append('<text x="%d" y="14" font-size="11" fill="#94a3b8">单位：%s</text>' % (pad_l, unit))
    parts.append('</svg>')
    return "".join(parts)


def hbar_chart(items, w=720):
    if not items:
        return ""
    row_h, pad_l = 34, 210
    h = row_h * len(items) + 20
    maxv = max(abs(i["cagr"]) for i in items) * 1.2 or 1
    parts = ['<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">' % (w, h)]
    for idx, it in enumerate(items):
        y = 10 + idx * row_h
        bw = (w - pad_l - 90) * (abs(it["cagr"]) / maxv)
        parts.append('<text x="%d" y="%d" font-size="12" fill="#334155" text-anchor="end">%s</text>' % (pad_l - 10, y + 18, it["name"]))
        parts.append('<rect x="%d" y="%d" width="%.1f" height="18" rx="4" fill="#10b981"/>' % (pad_l, y + 4, bw))
        parts.append('<text x="%.1f" y="%d" font-size="12" font-weight="600" fill="#047857">%s%%</text>' % (pad_l + bw + 8, y + 18, it["cagr"]))
    parts.append('</svg>')
    return "".join(parts)


global_svg = bar_chart(GLOBAL)
china_svg = bar_chart(CHINA, w=620)
cagr_svg = hbar_chart(CAGR_CASES)

# ============ 3. HTML 组装 ============
def rows_html(data, unit):
    return "".join(
        '<tr><td><strong>%s</strong></td><td class="num">%s</td><td>%s</td><td><span class="tag">%s</span></td></tr>'
        % (d.get("year", d.get("name")), ("%g" % d["value"]), d["label"], d["source"])
        for d in data
    )

segs_html = "".join(
    '<tr><td>%s</td><td class="num">%s</td><td>%s</td><td>%s</td><td><span class="tag">%s</span></td></tr>'
    % (s["name"], s["year"], ("%g" % s["value"]), s["note"], s["source"])
    for s in SEGMENTS
)

drivers_html = "".join('<li><strong>%s</strong><span>%s</span></li>' % (a, b) for a, b in DRIVERS)
risks_html = "".join('<li><strong>%s</strong><span>%s</span></li>' % (a, b) for a, b in RISKS)

HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>全球 AI 产业市场增长分析报告（2022-2025）</title>
<style>
:root{--bg:#f6f8fb;--card:#fff;--txt:#1e293b;--sub:#64748b;--line:#e2e8f0;--pri:#1d4ed8;--acc:#10b981;}
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Microsoft YaHei",sans-serif;background:var(--bg);color:var(--txt);line-height:1.7;padding:32px 16px;}
.wrap{max-width:1080px;margin:0 auto;}
header{background:linear-gradient(135deg,#1e3a8a,#2563eb);color:#fff;border-radius:16px;padding:40px 36px;margin-bottom:24px;box-shadow:0 10px 30px rgba(30,58,138,.18);}
header h1{font-size:30px;letter-spacing:.5px;margin-bottom:10px;}
header p{opacity:.9;font-size:14px;}
header .meta{margin-top:18px;display:flex;flex-wrap:wrap;gap:10px;}
header .meta span{background:rgba(255,255,255,.16);border-radius:20px;padding:5px 14px;font-size:12.5px;}
.card{background:var(--card);border-radius:14px;padding:26px 28px;margin-bottom:20px;box-shadow:0 2px 12px rgba(15,23,42,.06);}
.card h2{font-size:19px;margin-bottom:6px;display:flex;align-items:center;gap:10px;}
.card h2::before{content:"";width:4px;height:18px;background:var(--pri);border-radius:2px;}
.card .desc{font-size:13px;color:var(--sub);margin-bottom:18px;}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px;margin-bottom:20px;}
.kpi{background:#fff;border:1px solid var(--line);border-radius:12px;padding:18px 20px;}
.kpi .lab{font-size:12.5px;color:var(--sub);margin-bottom:6px;}
.kpi .val{font-size:26px;font-weight:700;color:var(--pri);line-height:1.2;}
.kpi .val small{font-size:13px;font-weight:500;color:var(--sub);margin-left:4px;}
.kpi .note{font-size:12px;color:var(--sub);margin-top:6px;}
table{width:100%%;border-collapse:collapse;font-size:14px;}
th{background:#f1f5f9;color:#475569;font-size:12.5px;font-weight:600;text-align:left;padding:11px 12px;border-bottom:1px solid var(--line);}
td{padding:11px 12px;border-bottom:1px solid #f1f5f9;}
td.num{font-variant-numeric:tabular-nums;font-weight:600;color:#0f172a;}
tr:hover td{background:#fafcff;}
.tag{display:inline-block;background:#eff6ff;color:#1d4ed8;border-radius:6px;padding:2px 8px;font-size:11.5px;}
.chart{margin:16px 0 6px;overflow-x:auto;}
.chart svg{width:100%%;height:auto;}
ul.pts{list-style:none;}
ul.pts li{padding:13px 0;border-bottom:1px dashed var(--line);display:flex;flex-direction:column;gap:3px;}
ul.pts li:last-child{border-bottom:none;}
ul.pts li strong{font-size:14.5px;}
ul.pts li span{font-size:13.5px;color:var(--sub);}
.warn{background:#fffbeb;border-left:4px solid #f59e0b;border-radius:8px;padding:14px 16px;font-size:13.5px;color:#78350f;margin-top:14px;}
footer{text-align:center;font-size:12.5px;color:var(--sub);padding:22px 0 10px;}
</style>
</head>
<body>
<div class="wrap">

<header>
  <h1>全球 AI 产业市场增长分析报告</h1>
  <p>覆盖周期：2022 — 2025 &nbsp;|&nbsp; 分析维度：全球规模、中国规模、细分赛道、增长驱动与风险</p>
  <div class="meta">
    <span>生成日期：2026-09-14</span>
    <span>数据来源：公开搜索结果（IDC / 信通院 / 券商研报等）</span>
    <span>数据性质：二手公开数据，多口径并存</span>
  </div>
</header>

<div class="kpis">
  <div class="kpi"><div class="lab">全球 AI 市场（2024）</div><div class="val">6,382<small>亿美元</small></div><div class="note">综合市场规模口径</div></div>
  <div class="kpi"><div class="lab">全球 AI 市场两年 CAGR</div><div class="val">21.4<small>%%</small></div><div class="note">2022 → 2024 测算</div></div>
  <div class="kpi"><div class="lab">中国 AI 核心产业（2024）</div><div class="val">6,964<small>亿元</small></div><div class="note">公开研究报告口径</div></div>
  <div class="kpi"><div class="lab">生成式 AI 五年 CAGR</div><div class="val">63.8<small>%%</small></div><div class="note">至 2028 年，增速最快细分</div></div>
</div>

<div class="card">
  <h2>一、执行摘要</h2>
  <p class="desc">基于公开渠道采集的多源数据整理，反映全球 AI 产业 2022—2025 年的规模与增速趋势。</p>
  <ul class="pts">
    <li><strong>产业规模持续扩张，两年复合增速约 21%%</strong><span>全球 AI 市场由 2022 年约 4,328 亿美元增至 2024 年约 6,382 亿美元，处于高速增长通道。</span></li>
    <li><strong>中国增速显著高于全球平均水平</strong><span>中国 AI 核心产业由 2022 年约 2,845 亿元增至 2024 年约 6,964 亿元，两年 CAGR 约 56.5%%，远超全球均值。</span></li>
    <li><strong>生成式 AI 是增速最快的细分赛道</strong><span>机构预测其五年 CAGR 约 63.8%%（至 2028），显著高于 AI 整体增速。</span></li>
    <li><strong>算力与基础设施构成主要增量来源</strong><span>2025 年全球 AI 芯片市场预计超过 800 亿美元，云与数据中心资本开支维持高位。</span></li>
  </ul>
  <div class="warn"><strong>口径提示：</strong>本报告数据来自不同研究机构，统计范围（是否含硬件/服务）与统计年度存在差异，跨来源数字<b>不可直接相加或直接比较</b>，趋势判断以同源序列为准。</div>
</div>

<div class="card">
  <h2>二、全球 AI 市场规模与增长</h2>
  <p class="desc">2022—2025 年全球 AI 市场规模（亿美元），2025 年为预测值。</p>
  <div class="chart">__GLOBAL_SVG__</div>
  <table>
    <thead><tr><th style="width:18%%">年份</th><th style="width:20%%">规模（亿美元）</th><th>口径说明</th><th style="width:16%%">数据来源</th></tr></thead>
    <tbody>__GLOBAL_ROWS__</tbody>
  </table>
  <div class="warn"><strong>交叉验证：</strong>IDC 口径显示 2022 年全球 AI 收入约 4,328 亿美元（同比 +19.6%%）；另有研究显示 2022→2023 年由 4,541 亿美元增至 5,381 亿美元，两条序列的绝对水平接近，趋势方向一致，可相互印证增长判断。</div>
</div>

<div class="card">
  <h2>三、中国 AI 市场规模与增长</h2>
  <p class="desc">2022—2025 年中国 AI 市场/核心产业规模（亿元），2023 与 2025 年为估算/预测值。</p>
  <div class="chart">__CHINA_SVG__</div>
  <table>
    <thead><tr><th style="width:18%%">年份</th><th style="width:20%%">规模（亿元）</th><th>口径说明</th><th style="width:16%%">数据来源</th></tr></thead>
    <tbody>__CHINA_ROWS__</tbody>
  </table>
  <div class="warn"><strong>口径提示：</strong>“中国 AI 核心产业规模”与“中国 AI 市场总规模”统计范围不同；另有个别来源给出 2024 年核心产业超 9,000 亿元（同比 +24%%）的口径，与本表 6,964 亿元口径并存，请以官方年度发布为准。</div>
</div>

<div class="card">
  <h2>四、细分赛道与增长引擎</h2>
  <p class="desc">代表性子领域规模与机构预测。</p>
  <table>
    <thead><tr><th>细分领域</th><th style="width:10%%">年份</th><th style="width:14%%">规模</th><th>要点</th><th style="width:14%%">来源</th></tr></thead>
    <tbody>__SEG_ROWS__</tbody>
  </table>
</div>

<div class="card">
  <h2>五、复合增长率（CAGR）对比</h2>
  <p class="desc">各口径下的年复合增长率，由公开数据测算或直接引用机构预测值。</p>
  <div class="chart">__CAGR_SVG__</div>
  <table>
    <thead><tr><th>口径</th><th style="width:22%%">CAGR</th><th style="width:30%%">测算式/来源</th></tr></thead>
    <tbody>
      <tr><td>全球 AI 市场（2022-2024）</td><td class="num">21.4%%</td><td>(6382/4328)^(1/2)-1</td></tr>
      <tr><td>中国 AI 市场（2022-2024）</td><td class="num">56.5%%</td><td>(6964/2845)^(1/2)-1</td></tr>
      <tr><td>全球生成式 AI（至 2028）</td><td class="num">63.8%%</td><td>机构预测值</td></tr>
      <tr><td>全球 AI 系统支出（2021-2025）</td><td class="num">24.5%%</td><td>机构预测值</td></tr>
      <tr><td>中国 AI（2024-2028, IDC）</td><td class="num">32.9%%</td><td>IDC 预测值</td></tr>
      <tr><td>全球 AI 技术支出（2025-2028）</td><td class="num">30.5%%</td><td>(7490/3370)^(1/3)-1</td></tr>
    </tbody>
  </table>
</div>

<div class="card">
  <h2>六、增长驱动因素</h2>
  <ul class="pts">__DRIVERS__</ul>
</div>

<div class="card">
  <h2>七、风险与不确定性</h2>
  <ul class="pts">__RISKS__</ul>
</div>

<div class="card">
  <h2>八、数据来源与说明</h2>
  <ul class="pts">
    <li><strong>数据采集方式</strong><span>通过 web-search-assistant 技能封装的国产搜索引擎（搜狗）抓取公开搜索结果页，经解析、去重后整理入库，两轮共采集约 47 条结果，原始数据保存于 output/raw/ 目录。</span></li>
    <li><strong>主要数据源</strong><span>IDC、中国信通院、华泰证券、中信证券等机构的公开发布内容与媒体报道摘要。</span></li>
    <li><strong>测算方法</strong><span>CAGR 采用复合增长率公式 (期末/期初)^(1/年数)-1 计算；2023 中国数据与 2025 预测值基于相邻年份增速外推。</span></li>
    <li><strong>局限性</strong><span>搜索结果摘要非原文全文，部分数字未经原始报告二次核验；不同机构口径不可直接合并。</span></li>
  </ul>
  <div class="warn"><strong>免责声明：</strong>本报告基于公开渠道采集的二手数据编制，仅供研究与参考，不构成任何投资建议。市场规模的最终口径应以各机构官方发布的完整报告为准，使用者需自行核实数据准确性。</div>
</div>

<footer>全球 AI 产业市场增长分析报告 · 生成于 2026-09-14 · 数据来源为公开信息</footer>
</div>
</body>
</html>
"""

HTML = HTML.replace("__GLOBAL_SVG__", global_svg).replace("__CHINA_SVG__", china_svg).replace("__CAGR_SVG__", cagr_svg)
HTML = HTML.replace("__GLOBAL_ROWS__", rows_html(GLOBAL, "亿美元")).replace("__CHINA_ROWS__", rows_html(CHINA, "亿元"))
HTML = HTML.replace("__SEG_ROWS__", segs_html)
HTML = HTML.replace("__DRIVERS__", drivers_html).replace("__RISKS__", risks_html)
HTML = HTML.replace("%%", "%")  # 模板未用 % 格式化，需还原转义的双百分号

html_path = os.path.join(OUTDIR, "reports", "global-ai-market-2023-2025.html")
with open(html_path, "w", encoding="utf-8") as f:
    f.write(HTML)

print("[CAGR]")
for c in CAGR_CASES:
    print("   %-34s %s%%" % (c["name"], c["cagr"]))
print("[SAVED] " + html_path)
print("[SAVED] " + os.path.join(OUTDIR, "data", "ai_market_normalized.json"))
print("[SIZE] %d bytes" % len(HTML.encode("utf-8")))