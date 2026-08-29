# 产业政策技能（北辰产业政策智能体）技术设计文档

> **文档定位**：本文档为 shenicest 黑客松参赛作品核心开发件《产业政策技能》（`beichen-policy-assistant`）的技术设计文档（design.md），定义"怎么做"。
>
> **比赛**：shenicest 黑客松 · 北辰产业云社区命题 | **版本**：v1.0 | **日期**：2026-08-29

---

# 一、总体架构设计

## 1.1 架构图

```
┌───────────────────────────────────────────────────────────────────────┐
│            用户（园区运营人员 / 入驻企业 / 评审专家）                      │
│      输入企业名称 → 获取政策匹配报告 / 管理政策库更新 / 跟进申报           │
└──────────────────────────────┬────────────────────────────────────────┘
                               │ WebMCP 自然语言 / aibuilder / CLI
┌──────────────────────────────▼────────────────────────────────────────┐
│                  AgentSkills Runtime（仓颉 Runtime v0.0.27）           │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │      产业政策技能 Skill（beichen-policy-assistant）              │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │ │
│  │  │1.画像    │→│2.检索   │→│3.匹配   │→│4.报告   │→│5.落库   │  │ │
│  │  │ profile │ │ match   │ │ matrix  │ │ report  │ │persist  │  │ │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘  │ │
│  │       │           │           │           │           │       │ │
│  │  ┌────▼───────────▼───────────▼────┐ ┌────▼────────────▼────┐ │ │
│  │  │  三层知识库 knowledge/           │ │  company / tasks 表   │ │ │
│  │  │  政策原文库·官方解读库·实操洞察库 │ │  （画像+报告+申报任务） │ │ │
│  │  └────────────────▲────────────────┘ └──────────────────────┘ │ │
│  │  ┌───────────────┴────────────────┐                            │ │
│  │  │ 6.自动更新 update_policy_kb     │ ── 人工研判门禁（commit）    │ │
│  │  └────────────────────────────────┘                            │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│  内置工具: web_fetch/http_request/web_search/cli_execute              │
│  大模型: 昇腾 API（AtomGit，OpenAI 兼容）                              │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
        ┌──────────────────▼───────────────┐   ┌─────────────────────┐
        │ 政府公开网站（合规抓取）            │   │ aibuilder（web-admin)│
        │ 北京市政府/朝阳区政府/科委/中关村    │   │ 企业列表·报告·申报任务 │
        └──────────────────────────────────┘   └─────────────────────┘
```

## 1.2 技术选型

| 层级 | 选型 | 说明 |
|------|------|------|
| 技能运行时 | AgentSkills Runtime（仓颉）v0.0.27 | 技能执行环境、内置工具、插件系统 |
| 技能格式 | SKILL.md + scripts | 符合 AgentSkills 开放标准 |
| 知识库 | 文件型三层知识库（Markdown + JSON 索引） | 无外部向量库依赖，检索用本地脚本 + LLM 语义判定 |
| 脚本语言 | Python 3 | 画像采集/匹配/报告/落库轻量脚本（沿用智能投研助理模式） |
| 大模型 | 昇腾 API（AtomGit） | OpenAI 兼容接口，`.env` 配置 |
| 数据库 | PostgreSQL | company / tasks 表（复用现有） |
| 呈现 | aibuilder（web-admin）+ WebMCP | 企业列表 + 报告详情 + 自然语言交互 |
| 定时任务 | crontab_sched 能力 / cron | 政策库每日自动更新 |

---

# 二、Skill 目录结构设计

```
skills/beichen-policy-assistant/
├── SKILL.md                      # 技能定义（SOP 主文档）
├── COMPOSITION.yaml              # 组合步骤编排（画像→匹配→报告→落库）
├── README.md                     # 技能说明
├── knowledge/                    # 三层知识库（版本管理，随技能发布）
│   ├── policy-original/          # 政策原文库（74 条种子条目）
│   ├── policy-interpretation/    # 官方解读库
│   ├── policy-insight/           # 实操洞察库
│   └── policy-index.json         # 政策索引（编号/领域/层级/部门/状态）
├── scripts/
│   ├── init_policy_kb.py         # Step0 知识库初始化（74 条种子入库）
│   ├── build_enterprise_profile.py # Step1 全景企业画像
│   ├── match_policy.py           # Step2+3 多元政策匹配（双源检索+语义适配）
│   ├── update_policy_kb.py       # Step4 政策库自动更新（抓取→储备库；commit→正式库）
│   ├── generate_policy_report.py # Step5 适配研判报告（昇腾 API / 模板降级）
│   └── save_to_db.py             # Step6 结果落库（company upsert + tasks 插入）
└── output/                       # 运行产物（不入版本库）
    ├── profiles/                 # 企业画像 JSON+MD
    ├── matches/                  # 匹配矩阵 JSON
    ├── reports/                  # 适配报告 Markdown（{企业}-{date}.md）
    └── pending/                  # 政策储备库流水（{date}.json）
```

## 2.1 三层知识库条目格式

政策原文库条目（`knowledge/policy-original/{序号}-{政策名称}.md`）：

```markdown
---
policy_no: "56"                     # 命题附件序号（1-74）
domain: 高新技术产业                  # 所属领域
level: 区级                          # 政策层级（市级/区级）
department: 朝阳区科信局              # 发布部门
title: 北京市朝阳区支持高新技术企业创新发展若干政策
status: active                      # active / pending / expired
conditions:                         # 申报条件（结构化，供匹配用）
  region: 朝阳区注册
  qualification: 高新技术企业认定
  industry: []
support: "资金支持/研发费用补贴"
source: 命题附件《北辰产业云社区命题》政策目录
---
# 政策要点
（申报条件、支持方式、申报周期、材料清单……）
```

`policy-index.json` 汇总全部条目元数据，匹配脚本首先加载索引做硬性条件初筛，再读条目全文做语义匹配。

---

# 三、模块设计

## 3.1 init_policy_kb.py（知识库初始化）

**输入**：`--seed knowledge/policy-seed.json`（由命题附件 74 条政策目录预生成的种子文件）
**逻辑**：
1. 解析种子（编号/领域/层级/部门/政策名称）
2. 为每条政策生成 Markdown 条目骨架（front-matter 元数据 + 待补要点区）
3. 生成 `policy-index.json`
4. 幂等：已存在条目跳过

## 3.2 build_enterprise_profile.py（全景企业画像）

**输入**：`--company "企业名称"`、`--outdir`
**逻辑**：
1. 工商信息：公开工商查询接口（合规）获取注册资本、成立日期、经营范围、注册区域
2. 经营信息：web_search 检索企业官网/公开报道，提取行业、规模、产品、资质（如高新认定、专精特新）
3. 舆情信息：web_search 近期新闻，正负面分类
4. 智能处理：LLM 语义甄别、冗余过滤、要点萃取（无 LLM 时规则降级）
5. 输出 `output/profiles/{企业slug}.json` + `.md`（画像 Markdown）
**关键实现**：`fetch_biz_info()`、`search_and_extract()`、`summarize_profile()`

## 3.3 match_policy.py（多元政策匹配）

**输入**：企业画像 JSON + `--topn 10`
**逻辑**：
1. **硬性条件初筛**：画像 region/qualification/industry 对标 policy-index（注册区域不符、行业负面、已过期 → 淘汰）
2. **双源检索**：本地三层知识库条目全文 + web_search 实时公开资源（获取最新申报通知）
3. **语义适配研判**：LLM 判定画像与申报条件的多维匹配度（0-100 评分），输出匹配依据与缺口项；无 LLM 时按条件命中数规则打分
4. **幻觉治理**：每条匹配结论必须绑定政策原文库 policy_no；无法绑定 → 状态"待核实"，不进正式报告
5. 输出 `output/matches/{企业slug}-{date}.json`（匹配矩阵）

## 3.4 update_policy_kb.py（政策库自动更新）

**输入**：`--sources`（默认北京市政府/朝阳区政府/市科委/中关村管委会列表页）、`--commit`（研判确认模式）
**逻辑**：
1. **抓取模式**（默认，供每日 cron 触发）：抓取来源列表页 → 解析新增政策标题/链接/发布日期 → 与索引去重 → 写入 `output/pending/{date}.json`（状态 pending）
2. **commit 模式**（人工研判确认后）：读取 pending 流水中被确认的条目 → 生成/更新政策原文库条目（状态 active）→ 更新索引
3. 全程留痕：抓取时间、来源 URL、研判人（--reviewer 参数）

## 3.5 generate_policy_report.py（适配研判报告）

**输入**：匹配矩阵 JSON + 企业画像
**逻辑**：
1. 检测 LLM 配置（`LLM_API_KEY`/`OPENAI_API_KEY`）
2. 有配置：调用昇腾 API 生成结构化报告——匹配政策清单（按评分排序）、逐条申报条件对标表（企业现状 vs 条件：满足/部分满足/不满足）、缺口分析、申报建议与优先级
3. 无配置：模板降级生成（矩阵表格直出，保证可运行）
4. 固定附加合规声明
5. 输出 `output/reports/{企业slug}-{date}.md`

## 3.6 save_to_db.py（结果落库）

**输入**：画像 + 报告 + 匹配矩阵
**逻辑**：
1. company 表 upsert（按 company_name，org_type='beichen-enterprise'，画像摘要入 org_description）
2. tasks 表插入匹配报告（task_type='policy-match'，status='completed'）
3. Top N 匹配政策生成申报任务（task_type='policy-apply'，status='pending'，extra_data 含 policy_no、材料清单）
4. 支持 psycopg2 直连或仅生成 SQL 文件

---

# 四、大模型接入设计（昇腾算力底座）

## 4.1 配置方式

runtime `.env`（与智能投研助理共用配置）：

```env
MODEL_PROVIDER=atomgit
MODEL_NAME=deepseek-v4-flash
MODEL_CONFIG=atomgit:deepseek-v4-flash
ATOMGIT_API_KEY=<token>
ATOMGIT_BASE_URL=https://api-ai.gitcode.com/v1
```

## 4.2 脚本侧 LLM 调用

```env
LLM_BASE_URL=https://api-ai.gitcode.com/v1
LLM_API_KEY=<token>
LLM_MODEL=deepseek-v4-flash
```

> 注：脚本侧 LLM 为可选增强（画像萃取/语义匹配/报告生成三处使用）；无配置时全部有规则/模板降级路径，保证技能在任何环境可运行。

---

# 五、数据库落库设计

## 5.1 company 表 upsert

```sql
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified)
VALUES ('{企业名称}', '{注册区域}', '{画像摘要}', 'beichen-enterprise', false)
ON CONFLICT (company_name) DO UPDATE SET org_description = EXCLUDED.org_description;
```

## 5.2 tasks 表插入（匹配报告 / 申报任务）

```sql
-- 匹配报告
INSERT INTO public.tasks
  (id, title, description, task_type, task_status, priority, company_id, tags, extra_data)
SELECT '{uuid}', '政策适配报告 - {企业名称}', '{报告正文}', 'policy-match', 'completed', 'normal',
       c.id, '["beichen","policy-match"]'::jsonb,
       '{"profile_date":"{date}","matched_count":{n}}'::jsonb
FROM public.company c WHERE c.company_name = '{企业名称}';

-- 申报任务（每条 Top 匹配政策一个）
INSERT INTO public.tasks
  (id, title, description, task_type, task_status, priority, company_id, tags, extra_data)
SELECT '{uuid}', '政策申报 - {政策名称}', '{申报要点与材料清单}', 'policy-apply', 'pending', 'normal',
       c.id, '["beichen","policy-apply"]'::jsonb,
       '{"policy_no":"{编号}","deadline":"{申报截止}"}'::jsonb
FROM public.company c WHERE c.company_name = '{企业名称}';
```

---

# 六、合规与安全设计

1. **数据合规**：仅抓取政府公开网站与公开工商/舆情信息，记录来源与时间
2. **人工研判门禁**：储备库 → 正式库必须人工 commit（命题要求的"产业同事研判确认"机制）
3. **内容合规**：报告固定附加"仅供申报参考，不构成法律意见"声明
4. **权限安全**：脚本仅访问白名单数据源与本地数据库；commit 操作需 --reviewer 留痕
5. **审计留痕**：画像、匹配、更新、落库全流程产物持久化于 output/，可追溯
6. **信创合规**：仓颉 Runtime + 昇腾算力 + 国产数据库

---

# 七、风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 政府网站反爬/限流 | 自动更新失败 | 多源列表、失败重试、指数退避、人工补录路径 |
| 工商信息接口不可用 | 画像缺失 | web_search 降级采集 + 用户手动补充画像字段 |
| 无 LLM 配置 | 匹配与报告质量下降 | 规则打分 + 模板降级（保证可运行） |
| 政策条目要点不全（种子仅目录） | 匹配依据单薄 | 双源检索补全（web_search 实时公开资源）+ 官方解读库持续沉淀 |
| company 表无唯一约束 | upsert 冲突 | 先查后更兼容路径（沿用智能投研助理方案） |
| 语义匹配误判 | 错误申报建议 | 评分 + 依据 + 缺口项三要素输出，人工复核申报任务 |

---

# 八、验收检查清单

- [ ] SKILL.md 符合 AgentSkills 标准格式
- [ ] COMPOSITION.yaml 定义六步编排
- [ ] 6 个 Python 脚本齐全且语法正确
- [ ] knowledge/policy-original 74 条种子条目 + policy-index.json 生成
- [ ] 三层知识库目录结构与条目 front-matter 规范
- [ ] 匹配结论均可回溯 policy_no（幻觉治理）
- [ ] 落库逻辑复用 company / tasks 表结构
- [ ] 支持昇腾 API（AtomGit）配置 + 降级路径
- [ ] 报告含合规免责声明
- [ ] runtime 加载技能成功（人工验证）
- [ ] 端到端执行成功（人工验证）
- [ ] aibuilder 呈现画像/报告/申报任务（人工验证）
