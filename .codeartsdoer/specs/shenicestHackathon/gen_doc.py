# -*- coding: utf-8 -*-
"""生成 shenicest 黑客松项目文档（北辰产业云社区命题）：
1) 解决方案架构图 PNG（1920x1080）
2) Word 项目文档 docx
"""
import os
from PIL import Image, ImageDraw, ImageFont

F = r"C:\Windows\Fonts\msyh.ttc"
FB = r"C:\Windows\Fonts\msyhbd.ttc"
OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\.codeartsdoer\specs\shenicestHackathon"

def font(sz, bold=False):
    return ImageFont.truetype(FB if bold else F, sz)

# ============ 1. 解决方案架构图 ============
W, H = 1920, 1080
img = Image.new("RGB", (W, H), "white")
d = ImageDraw.Draw(img)

d.text((W//2, 58), "北辰产业云社区 · AI 解决方案总体架构", font=font(44, True), fill="#1F3864", anchor="mm")
d.text((W//2, 112), "AgentSkills-runtime（仓颉编程语言）驱动的产业园区一站式线上服务与生态连接平台", font=font(23), fill="#555555", anchor="mm")

bands = [
    ("用户与服务对象", "#E8F1FB", "#2E5395", [
        "园区运营方\n（北辰商管）", "入驻企业与创业团队\n（四大园区）",
        "政府主管部门\n（市/区两级）", "金融机构\n（投资64·银行12·证券9·基金6）"]),
    ("产业云社区应用层", "#E6F4F1", "#1F7A6B", [
        "线上供需对接官网\n需求发布·能力展示·智能撮合", "产业政策智能体\n企业画像·政策匹配·申报库",
        "金融匹配智能体\n需求采集·机构匹配·融资SOP", "规划扩展\n数据超市·应用超市·算力聚合"]),
    ("智能体引擎层", "#FDF0E3", "#C77A2B", [
        "AgentTeams\n分层协作（Manager/Leader/Worker）", "DAG 任务编排\n条件·聚合·重试",
        "上下文验证\n与压缩", "循环执行\n增量结果推送", "审批与回滚\nCheckpoint"]),
    ("技能与插件层\n（一切皆技能）", "#F0EAF8", "#6B4FA0", [
        "AgentSkills 标准\nSKILL.md 加载校验", "智能插件系统 v0.0.27\nplugin.yaml·plugingen 生成",
        "WASM 安全沙箱\n能力隔离", "RAG 混合检索\n三层知识库（原文/解读/实操）", "内置工具 18+\n低/中/高敏感度 RBAC"]),
    ("运行时内核\n（纯仓颉实现）", "#FBEAEA", "#B04A4A", [
        "高性能 HTTP/HTTPS 服务器\nhttp_lib·Trie 路由", "WebSocket / SSE\n实时双向通信",
        "MCP / WebMCP（W3C 提案）\n智能体直接操作 Web 应用", "执行证据链审计\n副作用追踪·哈希链"]),
    ("基础设施层\n（国产自主可控）", "#EDF2E9", "#5B7A3A", [
        "仓颉编程语言\n（静态类型·内存安全）", "PostgreSQL\n（内嵌·私有化部署）",
        "国产大模型\n昇腾 API / AtomGit", "PC 桌面客户端\nElectron+Vue 三平台"]),
]

x0, x1 = 70, 1850
y = 152
band_gap = 22
band_h = 122

def draw_arrow(cx, y1, y2, color="#999999"):
    d.line([(cx, y1), (cx, y2-8)], fill=color, width=3)
    d.polygon([(cx-7, y2-10), (cx+7, y2-10), (cx, y2)], fill=color)

for bi, (label, fill, border, boxes) in enumerate(bands):
    d.rounded_rectangle([x0, y, x0+170, y+band_h], radius=10, fill=border)
    lines = label.split("\n")
    total_h = sum(font(21 if len(lines) == 1 else 19, True).getbbox(l)[3] for l in lines) + (len(lines)-1)*6
    ty = y + (band_h - total_h) // 2
    for l in lines:
        fnt = font(21 if len(lines) == 1 else 19, True)
        d.text((x0+85, ty), l, font=fnt, fill="white", anchor="ma")
        ty += fnt.getbbox(l)[3] + 6
    d.rounded_rectangle([x0+180, y, x1, y+band_h], radius=10, fill=fill, outline=border, width=2)
    n = len(boxes)
    bx0, bx1 = x0+196, x1-16
    gap = 12
    bw = (bx1 - bx0 - gap*(n-1)) // n
    for i, txt in enumerate(boxes):
        bx = bx0 + i*(bw+gap)
        by, bh = y+10, band_h-20
        d.rounded_rectangle([bx, by, bx+bw, by+bh], radius=8, fill="white", outline=border, width=2)
        lines = txt.split("\n")
        ty = by + 12
        for li, l in enumerate(lines):
            ff = font(19, True) if li == 0 and len(lines) > 1 else font(16)
            d.text((bx+bw/2, ty), l, font=ff, fill="#333333", anchor="ma")
            ty += ff.getbbox(l)[3] + 8
    y += band_h
    if bi < len(bands)-1:
        for cx in (400, 700, 1000, 1300, 1600):
            draw_arrow(cx, y, y+band_gap)

ARCH_PNG = os.path.join(OUT, "shenicest-解决方案架构图.png")
img.save(ARCH_PNG)
print("arch png saved")

# ============ 2. Word 项目文档 ============
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

doc = Document()

# 全局字体
style = doc.styles["Normal"]
style.font.name = "Times New Roman"
style.font.size = Pt(11)
style.element.rPr.rFonts.set(qn("w:eastAsia"), "宋体")
style.paragraph_format.line_spacing = 1.3

for hname, sz, color in (("Heading 1", 16, "1F3864"), ("Heading 2", 14, "2E5395"), ("Heading 3", 12, "2E5395")):
    hs = doc.styles[hname]
    hs.font.name = "Times New Roman"
    hs.font.size = Pt(sz)
    hs.font.bold = True
    hs.font.color.rgb = RGBColor.from_string(color)
    rpr = hs.element.get_or_add_rPr()
    rf = rpr.find(qn("w:rFonts"))
    if rf is None:
        rf = OxmlElement("w:rFonts")
        rpr.append(rf)
    rf.set(qn("w:eastAsia"), "微软雅黑")

def para(text, bold=False, size=11, align=None, color=None, font_name="宋体", space_after=6, first_indent=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(space_after)
    if align is not None:
        p.alignment = align
    if first_indent is not None:
        p.paragraph_format.first_line_indent = Pt(first_indent)
    r = p.add_run(text)
    r.font.name = "Times New Roman"
    r.font.size = Pt(size)
    r.font.bold = bold
    if color:
        r.font.color.rgb = RGBColor.from_string(color)
    r._element.rPr.rFonts.set(qn("w:eastAsia"), font_name)
    return p

def bullet(text, size=11):
    p = doc.add_paragraph(style="List Bullet")
    r = p.add_run(text)
    r.font.name = "Times New Roman"
    r.font.size = Pt(size)
    r._element.rPr.rFonts.set(qn("w:eastAsia"), "宋体")
    p.paragraph_format.space_after = Pt(4)
    return p

def make_table(headers, rows, widths=None):
    tb = doc.add_table(rows=1, cols=len(headers))
    tb.style = "Table Grid"
    tb.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, h in enumerate(headers):
        cell = tb.rows[0].cells[i]
        cell.text = ""
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(h)
        r.font.bold = True
        r.font.size = Pt(10.5)
        r.font.name = "Times New Roman"
        r._element.rPr.rFonts.set(qn("w:eastAsia"), "微软雅黑")
    for row in rows:
        cells = tb.add_row().cells
        for i, v in enumerate(row):
            cells[i].text = ""
            p = cells[i].paragraphs[0]
            r = p.add_run(str(v))
            r.font.size = Pt(10)
            r.font.name = "Times New Roman"
            r._element.rPr.rFonts.set(qn("w:eastAsia"), "宋体")
    if widths:
        for i, w in enumerate(widths):
            for row in tb.rows:
                row.cells[i].width = Inches(w)
    return tb

# ---------- 封面 ----------
for _ in range(4):
    doc.add_paragraph()
para("AgentSkills-runtime", bold=True, size=30, align=WD_ALIGN_PARAGRAPH.CENTER, color="1F3864", font_name="微软雅黑")
para("采用仓颉编程语言的国产 AI Agent", bold=True, size=20, align=WD_ALIGN_PARAGRAPH.CENTER, color="1F3864", font_name="微软雅黑")
para("北辰产业云社区解决方案", bold=True, size=20, align=WD_ALIGN_PARAGRAPH.CENTER, color="1F3864", font_name="微软雅黑")
doc.add_paragraph()
para("SheNicest 2026 北京夏季烈变千人黑客松 · 软件应用赛道", size=13, align=WD_ALIGN_PARAGRAPH.CENTER, color="555555")
para("命题单位：北辰商管 · 北辰产业云社区命题", size=13, align=WD_ALIGN_PARAGRAPH.CENTER, color="555555")
doc.add_paragraph()
para("作品 Slogan：以中国智慧，筑全球智联，共建 AI 时代新质生产力", bold=True, size=14, align=WD_ALIGN_PARAGRAPH.CENTER, color="C77A2B", font_name="微软雅黑")
doc.add_paragraph()
para("申报单位：深圳优创智投科技有限公司（OpenCangjie 开源社区）", size=12, align=WD_ALIGN_PARAGRAPH.CENTER)
para("2026 年 8 月", size=12, align=WD_ALIGN_PARAGRAPH.CENTER)
doc.add_page_break()

# ---------- 一、作品信息 ----------
doc.add_heading("一、作品信息", level=1)
make_table(["条目", "内容"], [
    ["参赛赛道", "软件应用赛道：滴水穿石"],
    ["选择命题", "北辰商管 · 北辰产业云社区命题"],
    ["作品名称", "AgentSkills-runtime 采用仓颉编程语言的国产 AI Agent"],
    ["作品 Slogan", "以中国智慧，筑全球智联，共建 AI 时代新质生产力"],
    ["核心交付物", "asr v0.0.27 一切皆技能插件系统；线上供需对接官网子系统；产业政策智能体；金融匹配智能体"],
    ["开源仓库", "https://atomgit.com/uctoo/agentskills-runtime（GitHub 镜像：https://github.com/UCTooCom/agentskills-runtime），仓库 Topic 已设置 #shenicest-fission"],
    ["在线体验", "https://demo.uctoo.com"],
    ["开源协议", "MIT"],
], widths=[1.4, 5.1])

# ---------- 二、项目背景 ----------
doc.add_heading("二、项目背景", level=1)

doc.add_heading("2.1 命题理解：北辰产业云社区要解决什么问题", level=2)
para("北辰产业云社区是面向创业团队的一站式线上服务与生态连接平台，依托朝阳数据要素产业园（2024.5）、人工智能会展产业园（2025.9）、智能机器人创新应用基地（2025.12）、北辰 AI 超维社区（2026.4）四大园区，形成数字经济、人工智能、智能装备、会展科技的完整产业生态。其服务体系可概括为五大方向：政策赋能精准化、金融服务体系化、场景开放多元化、活动运营品牌化、企业服务专业化。", first_indent=22)
para("命题方在《北辰产业云社区命题》中明确给出了两大核心课题与参考实现方向：", first_indent=22)
bullet("课题一：政策赋能精准化。深度对接市、区两级政策（覆盖人才、知识产权、融资、AI、机器人、数据要素、高新技术等 74 项重点政策），建立政策库—匹配库—申报库全流程服务。命题方已有的产业政策智能体实践依赖飞书 Aily 搭建，我们需提供更自主可控、可私有化部署、能消除大模型幻觉的政策智能体升级方案。")
bullet("课题二：金融服务体系化。北辰商管拥有超 90 家优质金融合作伙伴（64 家投资公司、12 家银行、9 家证券、6 家基金）、超 200 家次企业金融服务经验，形成了融资难、对接繁、流程慢痛点下的产业金融服务 SOP（需求采集与初步审核 1 个工作日、方案制定与洽谈 1 个工作日等），需要以智能体方式将 SOP 线上化、自动化。")
bullet("平台化需求：以线上供需对接为纽带，把园区运营方、入驻企业、政府、金融机构连接成一个数字化生态社区。")

doc.add_heading("2.2 行业痛点与技术机遇", level=2)
para("产业园区运营正处在从物业管理向产业服务运营转型的深水区，三大矛盾突出：", first_indent=22)
bullet("政策红利触达率低：市、区两级政策数量庞大、更新频繁，招商人员人工匹配效率低、易遗漏，企业往往拿不到本可享受的政策红利；通用大模型做政策问答存在知识滞后、理解肤浅、编造条款的幻觉问题。")
bullet("金融对接链条长：企业融资涉及需求采集、材料准备、机构匹配、洽谈落地多个环节，靠人工转接平均需要多日；园区沉淀的金融伙伴资源缺少统一的数字化入口。")
bullet("供需信息不对称：园区开放的海量场景（会展、酒店、园区、商业）与企业技术能力之间缺少高效的撮合通道。")
para("同时，智能体技术为这些问题提供了新的解法，但企业级落地面临工程化瓶颈：主流 Agent 框架构建在 Python/TypeScript 等国外技术栈之上，缺少全链路国产自主可控方案；动态语言运行时的安全性与确定性难以满足政企客户要求。这正是我们的技术切入点。", first_indent=22)

doc.add_heading("2.3 我们的答案：AI 驱动开发框架驱动的产业云社区", level=2)
para("我们采用全栈自研的 AgentSkills-runtime（简称 asr）新一代 AI 驱动开发框架，开发了北辰产业云社区完整解决方案。框架具备 dual-drive 双驱动特性：无 AI 环境下是传统高性能开发框架，接入大模型后每个功能环节被 AI 驱动而智能化。本次参赛完成的开发产物如下：", first_indent=22)
bullet("更新 asr v0.0.27 版本，发布了一切皆技能的插件系统，对标 deepseek-harness 的一切皆插件方案；asr 的插件系统更加智能，并且具有强安全、高性能、原生智能，以及更加适用于企业级客户的确定性设计理念。")
bullet("针对北辰产业云社区需求，开发了线上供需对接官网子系统。")
bullet("针对政策赋能精准化和金融服务体系化两个课题，开发了产业政策智能体和金融匹配智能体，实现入驻企业智能化对接产业需求和金融服务。")

# ---------- 三、目标用户 ----------
doc.add_heading("三、目标用户", level=1)
make_table(["用户角色", "核心诉求", "对应功能"], [
    ["园区运营方（北辰商管）", "提升招商与服务效率，盘活政策、金融、场景资源，形成可运营的数据资产", "供需对接官网管理端、智能体运营看板、政策/金融智能体的运营干预与审计"],
    ["入驻企业与创业团队", "快速找到适配政策与融资渠道，低成本展示技术能力、获取园区场景", "企业画像自动生成、政策精准匹配与申报提醒、融资需求一键提交与智能匹配、供需发布"],
    ["政府主管部门", "政策精准触达企业，产业运行情况可观测", "政策库管理、政策匹配数据统计（可对接政企数据报送）"],
    ["金融机构", "高效获取合格融资标的，降低尽调成本", "金融工具数据库、企业需求结构化推送、对接进度跟踪"],
    ["开发者与开源社区", "在国产技术栈上快速开发 Agent 应用与技能插件", "40+ 开源技能、plugingen 插件生成器、多语言 SDK、MIT 开源协议"],
], widths=[1.5, 2.5, 2.5])
para("典型使用场景：一家入驻智能机器人创新应用基地的初创企业，登录供需对接官网完成企业信息填报后，产业政策智能体自动聚合工商、经营、舆情等全域信息生成企业画像，从政策库中匹配出可申报的市区两级人才与机器人产业政策并给出申报要点；金融匹配智能体根据其融资阶段与需求，从 90 余家金融伙伴中筛出适配机构并按北辰产业金融服务 SOP 推进对接；全过程留痕可审计，园区运营方在管理端实时掌握服务进度。", first_indent=22)

# ---------- 四、解决方案总体设计 ----------
doc.add_heading("四、解决方案总体设计", level=1)
doc.add_heading("4.1 总体架构", level=2)
doc.add_picture(ARCH_PNG, width=Inches(6.5))
para("图 1  北辰产业云社区解决方案总体架构", size=10, align=WD_ALIGN_PARAGRAPH.CENTER, color="555555")
para("解决方案分为五层：用户与服务对象层（园区运营方、企业、政府、金融机构）、产业云社区应用层（供需对接官网 + 两个智能体）、智能体引擎层（AgentTeams 协作、DAG 编排、审批回滚）、技能与插件层（一切皆技能的插件系统、WASM 沙箱、RAG 三层知识库）、运行时内核与基础设施层（纯仓颉实现的高性能服务器 + 国产大模型 + PostgreSQL）。全链路国产自主可控。", first_indent=22)

doc.add_heading("4.2 线上供需对接官网子系统", level=2)
para("面向园区生态的一站式线上服务与生态连接门户，基于 asr 的 Web 管理平台（web-admin，AI Agent Dashboard）与 WebMCP 能力构建：", first_indent=22)
bullet("供需发布与撮合：企业发布技术能力供给与场景需求，园区发布开放场景（会展、酒店、园区、商业）与合作机会，系统按标签与语义进行智能撮合推荐。")
bullet("企业服务门户：集成政策匹配、金融对接、空间与工商财税等服务入口，形成企业全生命周期服务目录。")
bullet("自然语言操作：依托 WebMCP（W3C 标准提案），智能体可直接操作 Web 应用，用户用自然语言即可完成查询、填报、发布等操作，大幅降低使用门槛。")
bullet("运营管理端：园区运营方对供需信息、入驻企业、服务进度进行统一管理与数据统计，所有操作经 RBAC 权限管控并留痕。")

doc.add_heading("4.3 产业政策智能体：让政策精准触达每一家企业", level=2)
para("针对政策赋能精准化课题，产业政策智能体实现企业画像—政策匹配—申报辅导的全流程自动化：", first_indent=22)
bullet("全景企业画像：输入企业名称后，自动聚合工商、经营、舆情等公开全域信息，完成多渠道异构商业数据批量聚合、信息甄别、冗余过滤与要点萃取，替代人工检索。")
bullet("三层知识库消除幻觉：借鉴命题方渐进式架构并升级实现——政策原文库（市、区两级政策全文，确保信息源头真实完整）、官方解读库（权威问答与解读，锚定官方口径）、实操洞察库（政企沟通隐性规则与申报要点），RAG 混合检索（向量 + BM25 + RRF 融合 + 交叉编码重排）确保匹配结果精准可信、引用可溯源。")
bullet("多元政策匹配：语义级对标打破关键词局限，自动筛除无关政策，输出匹配政策清单、适配度分析与申报要点；覆盖人才、知识产权、融资、AI、机器人、数据要素、高新技术等重点领域。")
bullet("政策库自动更新：定时从北京市人民政府、朝阳区人民政府、市科委、中关村管委会等网站自动抓取最新产业政策，经产业同事研判确认后汇入正式政策库，确保知识库信息始终最新。")
bullet("申报库闭环：匹配结果进入申报库，按申报截止时间生成提醒与材料清单，形成政策库—匹配库—申报库全流程服务。")

doc.add_heading("4.4 金融匹配智能体：把产业金融服务 SOP 搬到线上", level=2)
para("针对金融服务体系化课题，金融匹配智能体把北辰商管沉淀的产业金融服务 SOP 数字化、自动化：", first_indent=22)
bullet("需求采集与初步审核（1 个工作日）：结构化采集企业融资需求（阶段、金额、用途、担保条件），智能体自动完成信息完整性核验与初步筛选。")
bullet("方案制定与机构匹配（1 个工作日）：基于开放金融工具数据库（90+ 金融合作伙伴画像：64 家投资公司、12 家银行、9 家证券、6 家基金），按需求智能匹配优势金融机构并生成对接方案。")
bullet("落地执行与服务闭环：协助企业提交资料、跟进洽谈进度、定期回访维护；任务按 DAG 编排推进，每个环节责任到人、进度可视，异常自动预警。")
bullet("风控与合规：所有对企业数据的访问经 RBAC 授权，敏感操作需审批并可回滚，执行证据链全程留痕，满足金融级合规要求。")

doc.add_heading("4.5 一切皆技能的插件系统（asr v0.0.27 底座升级）", level=2)
para("本次参赛同步发布的 asr v0.0.27 核心 upgrade，是上述两个智能体与官网子系统的共同底座。传统开发框架的插件只连接物理结构、缺少大模型控制的神经系统；asr 将插件变为大模型可理解、可编排、可进化的技能单元：", first_indent=22)
bullet("插件即技能：每个插件以 skills/{name}/ 目录交付，包含 SKILL.md（大模型可理解的技能文档）、plugin.yaml（静态元数据：入口、路由、依赖表）、scripts/（可执行脚本与仓颉插件包），技能与插件统一为一套体系。")
bullet("plugingen 确定性生成器：从数据库表结构一键生成五层 CRUD 插件（含菜单权限、多语言配置），新能力一律以插件形态交付，宿主代码零侵入；与 deepseek-harness 的 Cordis 一切皆插件方案对标，asr 方案在静态类型语言上实现时空可组合性，且插件经过 WASM 沙箱隔离与敏感度分级管控，更适合企业级客户。")
bullet("进程级隔离插件轨（规划推进中）：对标 deepseek-harness 的 Cordis 插件管理器，已集成 cordis-cj 插件系统，支持插件独立进程加载（Starting/Pending/Active/Unloading 状态机），故障隔离与热插拔。")
bullet("渐进式加载：SKILL.md 元数据先行加载，技能体按需加载，保障运行时性能与上下文效率。")

# ---------- 五、技术栈 ----------
doc.add_heading("五、技术栈", level=1)
make_table(["层次", "技术选型", "说明"], [
    ["开发语言", "仓颉编程语言（Cangjie）", "华为开源的国产静态类型语言，编译期类型检查、内存安全，runtime 内核与插件均以仓颉实现"],
    ["运行时内核", "http_lib（纯仓颉 HTTP/1.1/2）", "Trie 树路由、中间件链、连接生命周期管理，零 C FFI 依赖"],
    ["实时通信", "WebSocket / SSE", "智能体增量结果推送、长连接双向通信"],
    ["协议标准", "MCP、WebMCP（W3C 提案）、GB/Z 185-2026 智能体互联国标", "智能体直接操作 Web 应用；国标本地/互联双模实现（AIC 身份码、mTLS、MQ）"],
    ["智能体引擎", "AgentTeams、DAG 编排引擎", "ManagerGroup/Leader/Worker 分层协作，条件/聚合/重试，审批与回滚 Checkpoint"],
    ["技能体系", "AgentSkills 标准、WASM 沙箱、RAG", "SKILL.md 加载校验、渐进式加载；向量+BM25+RRF 混合检索；18+ 内置工具按敏感度分级纳入 RBAC"],
    ["数据库", "PostgreSQL（pgsql-driver）", "内嵌于 PC 客户端安装包，支持私有化部署"],
    ["前端与客户端", "Vue 3、Electron、web-admin", "Web 管理平台 + PC 桌面客户端（Windows/macOS/Linux 安装即用）"],
    ["大模型底座", "国产大模型（昇腾 API / AtomGit 等多渠道接入）", "OpenAI 兼容接口，.env 一键切换提供商"],
    ["工程方法论", "规范驱动开发（spec/design/tasks）、AI Coding 全流程", "40+ 工程技能沉淀为可复用 SOP"],
], widths=[1.1, 2.3, 3.1])

# ---------- 六、创新点 ----------
doc.add_heading("六、创新点", level=1)
doc.add_heading("6.1 AI 驱动开发框架范式（dual-drive 双驱动）", level=2)
para("继 prompt、context、harness 之后提出的新一代 Agent 范式：框架具备双驱动特性，无 AI 环境下是传统高性能开发框架（确定性运行），接入大模型后每个功能环节被 AI 驱动而智能化。本作品即最佳例证——供需对接官网在无 AI 时是标准的信息发布与管理平台，接入大模型后即获得自然语言操作、智能撮合、智能体服务能力。该方向已被 OpenAI 开源 Codex Harness、DeepMind Nature 论文《Agentic Profiles for Effective AI Governance》交叉印证，理念提出有公开可查证记录（2025 年 12 月起系列公众号文章与 2026 年 7 月 WAIC 演讲）。", first_indent=22)
doc.add_heading("6.2 一切皆技能的 AI 驱动插件机制", level=2)
para("对标 deepseek-harness 的一切皆插件方案，asr 的插件系统更加智能：插件即技能，大模型可理解、可编排、可进化；且具有强安全（WASM 沙箱 + 敏感度分级 + RBAC）、高性能（仓颉静态编译，无动态语言运行时开销）、原生智能（插件文档即模型上下文）、确定性设计（plugingen 表驱动生成、声明式 plugin.yaml）四大差异化优势，更加适用于企业级客户。", first_indent=22)
doc.add_heading("6.3 三层知识库 + RAG 混合检索根除政策幻觉", level=2)
para("通用大模型做政策问答存在知识滞后、理解肤浅、编造条款三大顽疾。产业政策智能体以政策原文库、官方解读库、实操洞察库三层高质量知识集，配合混合检索与重排，确保每一条政策匹配均可溯源到原文，输出精准可信的适配研判——这正回应了命题方对精准可信政策匹配的要求，且不依赖飞书等外部 SaaS，可完全私有化部署。", first_indent=22)
doc.add_heading("6.4 全链路国产自主可控", level=2)
para("仓颉编程语言 runtime + 国产大模型（昇腾 API）+ PostgreSQL + 国产化部署方案，从语言、运行时、模型到数据库的完整自主可控技术栈，为政务、央国企等强合规场景提供可复制的国产 AI 基础设施样本。", first_indent=22)
doc.add_heading("6.5 确定性优先的工程路线", level=2)
para("用仓颉静态类型语言的系统工程整体确定性消除大模型不确定性：确定性 SOP 承担流程执行（如金融对接六环节），大模型只承担理解与研判；关键操作审批可回滚，执行证据链全程留痕，让智能体服务经得起政企客户的生产环境检验。", first_indent=22)

# ---------- 七、提交方案优势 ----------
doc.add_heading("七、提交方案优势", level=1)
para("相较基于国外技术栈或通用 SaaS 搭建的园区智能体方案，本方案从工程形态到大模型底座都面向企业级客户的真实约束设计，形成以下五项综合优势：", first_indent=22)
doc.add_heading("7.1 全栈可私有化部署，支持友好的二次开发", level=2)
para("方案全部组件（运行时内核、技能插件、供需对接官网、两个智能体、数据库）均可整体私有化部署到客户自有服务器或专属云，数据不出域，满足企业级客户数据私有化与安全合规要求。同时，框架采用 MIT 开源协议与规范驱动的模块化设计，plugigen 可从既有数据库表结构一键生成 CRUD 插件，客户可深度集成已有数字资产（工商、经营、园区管理等业务系统数据），以极低成本完成二次开发与功能扩展，避免被封闭 SaaS 绑定。", first_indent=22)
doc.add_heading("7.2 多渠道大模型接入，成本与效果灵活组合", level=2)
para("agentskills-runtime 原生支持多渠道大模型 API（昇腾 API、AtomGit 等国产模型渠道，及 OpenAI 兼容接口的任意提供商），并支持接入私有化部署大模型。客户可根据任务复杂度在成本与效果之间灵活组合：简单分类、抽取任务使用轻量模型或本地小模型降低成本，政策研判、智能撮合等高价值任务调用旗舰模型保障效果；.env 一键切换提供商，模型升级换代会话零迁移。核心能力沉淀在技能与 SOP 层而非模型层，不与任何单一模型厂商绑定。", first_indent=22)
doc.add_heading("7.3 框架、技能、数据库自进化闭环", level=2)
para("agentskills-runtime 实现了框架程序、技能、数据库三者联动的自进化闭环：plugigen 从数据库表结构生成技能插件，技能运行产生的新数据回流数据库，数据结构演进又可再生成新插件；开发过程中的需求分析、架构设计、测试、文档等环节均沉淀为可复用技能（40+ 技能库），下一个项目直接复用。这显著提高数字系统开发效率——本参赛作品两个智能体即从智能投研助理技能的 SOP 模式快速派生——并降低系统长期维护与运营成本，让数字资产随业务持续增值而非持续折旧。", first_indent=22)
doc.add_heading("7.4 APP、Web、PC、小程序全渠道覆盖", level=2)
para("已实现 APP 端、Web 端、PC 端、小程序端全渠道覆盖：Web 管理平台（AI Agent Dashboard）承载园区运营与企业服务门户，PC 桌面客户端（Electron，Windows/macOS/Linux 安装即用、内嵌 PostgreSQL）面向重度办公场景，APP 与小程序端面向企业用户移动使用。同一套技能与智能体服务通过统一运行时内核向各端输出，为用户提供多端一致的使用体验，园区运营方无需为多端重复建设。", first_indent=22)
doc.add_heading("7.5 契合国家顶层规划与产业政策导向", level=2)
para("方案符合国产自主可控与鸿蒙/仓颉生态支持等国家顶层规划的指导要求：以华为开源的仓颉编程语言构建全链路技术底座（语言、运行时、模型、数据库均国产可控），具备向鸿蒙生态（OHOS 交叉编译已纳入构建体系）延伸的原生能力；对接昇腾算力与国产大模型，服务数据要素、人工智能等国家重点产业方向。对于政务、央国企及产业园区客户，本方案既是业务工具，更是国产 AI 基础设施的可复制落地样本，享受信创政策红利并具备长期演进保障。", first_indent=22)

# ---------- 八、团队分工 ----------
doc.add_heading("八、团队分工", level=1)
para("团队由 1 名核心成员与 AI 智能体协作矩阵构成——这正是 AI 驱动开发框架理念的自我实践（dogfooding）：用自己的框架开发自己的产品。", first_indent=22)
make_table(["角色", "承担者", "职责"], [
    ["项目负责人 / 全栈工程师", "王智鹏（深圳优创智投科技有限公司，OpenCangjie 开源社区）", "总体架构设计、仓颉 runtime 与插件系统开发、智能体技能开发、供需对接官网集成、项目文档与答辩"],
    ["AI 需求分析师", "asr · sdd-spec / sdd-flow 技能", "参赛需求分析、规范驱动开发的 spec 文档生成与评审"],
    ["AI 架构师 / 设计师", "asr · sdd-design / cangjie-coder 技能", "技术设计文档、仓颉代码生成（严格依据官方文档检索后编码）"],
    ["AI 测试工程师", "asr · test-generator / sdd-test 技能", "测试用例生成、单元测试、跨平台兼容性验证"],
    ["AI 文档工程师", "asr · doc-helper / uctoo-doc 技能", "README、API 文档、参赛文档撰写辅助"],
], widths=[1.5, 2.2, 2.8])

# ---------- 九、开发过程 ----------
doc.add_heading("九、开发过程", level=1)
doc.add_heading("9.1 项目历程", level=2)
make_table(["时间", "里程碑", "关键产出"], [
    ["2026.03", "asr v0.0.16 初始版本发布", "AgentSkills 标准实现、技能加载与执行、多语言 SDK"],
    ["2026.05-06", "企业级能力建设", "AgentTeams 协作、DAG 编排、WASM 沙箱、RAG 混合检索、GB/Z 185-2026 国标双模实现"],
    ["2026.07", "GOAI 世界人工智能开源大赛（新智基座赛道）", "AI Coding 全流程闭环 22 个工程任务：spec 驱动开发、crud-generator、40+ 技能沉淀"],
    ["2026.08.07", "asr v0.0.26 发布", "http_lib 纯仓颉 HTTP 库迁移（根治 10053）、pgsql-driver 迁移、PC 桌面客户端安装即用"],
    ["2026.08（本赛事）", "asr v0.0.27 + 北辰解决方案", "一切皆技能插件系统（plugingen、plugin.yaml）、线上供需对接官网子系统、产业政策智能体、金融匹配智能体"],
], widths=[1.1, 2.1, 3.3])
doc.add_heading("9.2 AI 驱动的开发流程", level=2)
para("本次参赛开发全程践行规范驱动开发（Spec-Driven Development）与 AI Coding 闭环：需求分析（spec.md）→ 技术设计（design.md）→ 任务分解（tasks.md）→ AI 生成代码（cangjie-coder 技能，强制先检索官方文档确定编码依据再生成）→ 测试验证（test-generator）→ 文档沉淀（doc-helper）。每个环节的产出均以技能形式沉淀，可在下一个项目中直接复用。两个智能体技能即以智能投研助理技能（2026 年金融 Agent 黑客松作品，实现抓取—清洗—提取—生成—落库—简报六步 SOP）验证过的 SOP 模式为模板快速派生，体现了技能复用体系的价值。", first_indent=22)
doc.add_heading("9.3 质量与稳定性保障", level=2)
bullet("金融投研场景已完成 17 轮真实业务迭代验证，从勉强可用演进到稳定产出，验证了底座的工程成熟度。")
bullet("RBAC 权限体系 + 敏感度分级 + 执行证据链审计 + 审批回滚四重防线，17 轮迭代零安全事故。")
bullet("开源社区检验：GitHub/AtomGit 50+ star、AtomGit G-Star 推荐、CCF 青年开源种子计划支持；WAIC 2026 演讲与多篇研究文章形成理论背书。")

# ---------- 十、后续计划 ----------
doc.add_heading("十、后续计划", level=1)
make_table(["阶段", "时间", "计划内容"], [
    ["短期（赛后 1 个月）", "2026.09", "导入市、区两级 74 项政策全量数据完成政策库初始化；对接北辰商管金融伙伴数据库；供需对接官网公测并邀请首批园区企业试用"],
    ["中期（3-6 个月）", "2026.10-2027.03", "asr v0.0.28：技能市场 Web UI、集群部署支持；进程级隔离插件轨（cordis-cj）正式发布；扩展数据超市、应用超市、算力聚合等园区智能体；与北辰商管开展试点合作，沉淀可量化的服务成效数据"],
    ["长期（6-12 个月）", "2027", "以智能体互联国标（GB/Z 185-2026）互联模式接入更广泛的园区生态与政务系统；面向园区运营方推出私有化部署 License 与 SaaS 订阅商业模式；将北辰模式复制到更多产业园区"],
], widths=[1.3, 1.0, 4.2])
para("我们期望与北辰商管持续共建：asr 提供自主可控的智能体基础设施，北辰产业云社区提供真实产业场景，共同打造 AI 时代的园区产业服务新范式。", first_indent=22)

# ---------- 十一、附录 ----------
doc.add_heading("十一、附录：作品与开源信息", level=1)
make_table(["条目", "地址/说明"], [
    ["主仓库（AtomGit）", "https://atomgit.com/uctoo/agentskills-runtime（Topic：#shenicest-fission）"],
    ["GitHub 镜像", "https://github.com/UCTooCom/agentskills-runtime"],
    ["AI Agent Dashboard（web-admin）", "https://atomgit.com/UCToo/web-admin"],
    ["PC 桌面客户端", "https://atomgit.com/UCToo/agentskills-runtime-pc"],
    ["在线体验", "https://demo.uctoo.com"],
    ["作品演示视频", "见提交材料（含供需对接官网操作、产业政策智能体匹配演示、金融匹配智能体 SOP 流程演示）"],
    ["开源协议", "MIT（可自由商用）"],
], widths=[1.8, 4.7])

OUT_DOCX = os.path.join(OUT, "shenicest项目文档-AgentSkills-runtime.docx")
doc.save(OUT_DOCX)
print("saved:", OUT_DOCX)
