# 金融匹配技能（北辰金融匹配智能体）技术设计文档

> **文档定位**：本文档为 shenicest 黑客松参赛作品核心开发件《金融匹配技能》（`beichen-finance-matching`）的技术设计文档（design.md），定义"怎么做"。
>
> **比赛**：shenicest 黑客松 · 北辰产业云社区命题 | **版本**：v1.0 | **日期**：2026-08-29

---

# 一、总体架构设计

## 1.1 架构图

```
┌────────────────────────────────────────────────────────────────────────┐
│          用户（园区运营 / 入驻企业 / 评审专家）                            │
│   提交融资需求 → 获取匹配方案与材料包 → 跟踪 SOP 六阶段进度                │
└──────────────────────────────┬─────────────────────────────────────────┘
                               │ WebMCP 自然语言 / aibuilder / CLI
┌──────────────────────────────▼─────────────────────────────────────────┐
│                  AgentSkills Runtime（仓颉 Runtime v0.0.27）            │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │      金融匹配技能 Skill（beichen-finance-matching）               │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │ │
│  │  │1.需求    │→│2.匹配   │→│3.方案   │→│4.材料包 │→│5.跟踪   │   │ │
│  │  │ intake  │ │ match   │ │ plan    │ │ dossier │ │ track   │   │ │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │ │
│  │       │           │           │           │           │        │ │
│  │  ┌────▼───────────▼───────────▼────┐ ┌────▼────────────▼────┐  │ │
│  │  │  金融工具数据库 knowledge/       │ │  company / tasks 表   │  │ │
│  │  │  90+伙伴(64银/12证/9基/6投)      │ │  （企业+方案+服务任务） │  │ │
│  │  │  产品要素·服务经验               │ │                       │  │ │
│  │  └─────────────────────────────────┘ └───────────────────────┘  │ │
│  │  SOP 时效引擎: 1d审核→1d方案→2d对接→3-5d落地→约定时限闭环          │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│  内置工具: web_fetch/http_request/web_search/cli_execute              │
│  大模型: 昇腾 API（AtomGit，OpenAI 兼容）                              │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
        ┌──────────────────────────▼──────────────┐  ┌──────────────────┐
        │ 公开金融产品资料（合规补充）                │  │ aibuilder(web-admin)│
        │ 机构官网·产品说明                          │  │ 企业·方案·进度呈现   │
        └────────────────────────────────────────┘  └──────────────────┘
```

## 1.2 技术选型

| 层级 | 选型 | 说明 |
|------|------|------|
| 技能运行时 | AgentSkills Runtime（仓颉）v0.0.27 | 技能执行环境、内置工具、插件系统 |
| 技能格式 | SKILL.md + scripts | 符合 AgentSkills 开放标准 |
| 知识库 | 文件型金融工具数据库（JSON + Markdown） | 机构/产品/经验三层数据，本地检索 |
| 脚本语言 | Python 3 | 建库/采集/匹配/方案/材料包/跟踪轻量脚本 |
| 大模型 | 昇腾 API（AtomGit） | OpenAI 兼容接口，`.env` 配置 |
| 数据库 | PostgreSQL | company / tasks 表（复用现有） |
| 呈现 | aibuilder（web-admin）+ WebMCP | 企业列表 + 方案/进度 + 自然语言交互 |

---

# 二、Skill 目录结构设计

```
skills/beichen-finance-matching/
├── SKILL.md                      # 技能定义（SOP 主文档）
├── COMPOSITION.yaml              # 组合步骤编排（需求→匹配→方案→材料包→跟踪→落库）
├── README.md                     # 技能说明
├── knowledge/                    # 金融工具数据库（版本管理，随技能发布）
│   ├── finance-partners/         # 金融伙伴库
│   │   ├── banks.json            # 64 家银行
│   │   ├── securities.json       # 12 家证券
│   │   ├── funds.json            # 9 家基金
│   │   └── investors.json        # 6 家投资公司
│   ├── finance-products/         # 产品要素库（{机构}-{产品}.md）
│   ├── finance-experience/       # 服务经验案例要点（脱敏）
│   └── finance-index.json        # 总索引
├── scripts/
│   ├── init_finance_kb.py        # Step0 金融工具数据库初始化（90+ 伙伴种子入库）
│   ├── collect_financing_need.py # Step1 需求采集与初步审核（SOP 阶段一）
│   ├── match_finance.py          # Step2 需求匹配优势金融机构
│   ├── generate_finance_plan.py  # Step3 定制金融方案（昇腾 API / 模板降级，SOP 阶段二）
│   ├── build_dossier.py          # Step4 对接材料包（SOP 阶段三）
│   ├── track_service.py          # Step5 SOP 六阶段跟踪（阶段推进/超期标记/回访任务）
│   └── save_to_db.py             # Step6 结果落库（company upsert + tasks 插入）
└── output/                       # 运行产物（不入版本库）
    ├── needs/                    # 融资需求档案 JSON
    ├── matches/                  # 匹配矩阵 JSON
    ├── plans/                    # 融资方案 Markdown（{企业}-{date}.md）
    ├── dossiers/                 # 对接材料包（{企业}-{机构}.md）
    └── tracking/                 # 服务跟踪流水（{企业}-{case_id}.json）
```

## 2.1 金融伙伴库数据格式

`knowledge/finance-partners/banks.json`（证券/基金/投资公司同构）：

```json
{
  "partner_type": "bank",
  "partners": [
    {
      "partner_no": "BK-001",
      "name": "XX银行北京分行",
      "strength_domains": ["科技金融", "中小企业信贷", "知识产权质押"],
      "products": ["科技型企业信用贷", "知识产权质押贷"],
      "service_count": 32,
      "avg_cycle_days": 5,
      "notes": "对AI/机器人企业有专项额度"
    }
  ]
}
```

> 注：种子数据以命题目录（64 银行 / 12 证券 / 9 基金 / 6 投资）为骨架，具体名称与产品要素由运营方持续补充；演示环境使用示例机构名，正式部署替换真实数据。

## 2.2 SOP 时效引擎配置

`scripts/track_service.py` 内建 SOP 阶段定义：

```python
SOP_STAGES = [
    {"stage": 1, "name": "资料提交与审核", "sla_days": 1},
    {"stage": 2, "name": "方案制定与洽谈", "sla_days": 1},
    {"stage": 3, "name": "金融机构对接",   "sla_days": 2},
    {"stage": 4, "name": "落地执行",       "sla_days": 5},   # 3-5 个工作日
    {"stage": 5, "name": "服务闭环",       "sla_days": None}, # 约定时限
    {"stage": 6, "name": "长期维护",       "sla_days": None}, # 回访周期任务
]
```

阶段截止时间按工作日计算（跳过周末），`track_service.py --check` 批量扫描超期任务并标记 `overdue`。

---

# 三、模块设计

## 3.1 init_finance_kb.py（金融工具数据库初始化）

**输入**：`--seed knowledge/finance-seed.json`（由命题目录预生成：类型与数量 64/12/9/6）
**逻辑**：
1. 解析种子生成四类伙伴库 JSON 骨架（partner_no/name/strength_domains/products 占位）
2. 加载产品要素库与经验库，生成 `finance-index.json`（机构总数、分类计数、优势领域分布）
3. 幂等：已存在条目跳过

## 3.2 collect_financing_need.py（需求采集与初步审核）

**输入**：`--company "企业名称"` `--amount 500万` `--term 2年` `--purpose 研发投入` `--guarantee 信用` `--revenue 3000万`，或 `--input needs.json` 批量
**逻辑**：
1. 结构化建档：企业信息（存在 output/profiles 画像则自动带入）、金额、期限、用途、担保、财务概况
2. 完整性校验：必填项缺失 → 输出补全提示，档案状态 `draft`
3. 可行性初判：金额/营收比例、用途合理性规则检查（规则可解释）
4. 通过 → 状态 `intaked`，生成 SOP case_id，进入阶段一（截止 = 1 个工作日）
**关键实现**：`validate_need()`、`feasibility_check()`、`create_case()`

## 3.3 match_finance.py（需求匹配优势金融机构）

**输入**：需求档案 JSON + `--topn 3`
**逻辑**：
1. **硬性初筛**：产品要素（额度范围/期限/担保方式）与需求对标，不满足淘汰
2. **优势匹配打分**：需求领域 × 机构 strength_domains 命中度（权重 50%）+ 服务经验 service_count 先验（权重 30%）+ 平均放款周期与需求急迫度（权重 20%）
3. **LLM 增强研判**（可选）：语义判断机构产品与需求场景适配性，输出匹配依据一句话
4. 输出 `output/matches/{case_id}.json`（Top N 机构、产品、评分构成、依据）

## 3.4 generate_finance_plan.py（定制金融方案）

**输入**：匹配矩阵 + 需求档案
**逻辑**：
1. 检测 LLM 配置（`LLM_API_KEY`/`OPENAI_API_KEY`）
2. 有配置：调用昇腾 API 生成方案——备选机构方案对比表（额度/利率区间/期限/担保/放款周期）、逐方案适配理由、组合融资建议（如"信贷+贴息"）、风险提示、对接路径
3. 无配置：模板降级（匹配矩阵直出对比表，保证可运行）
4. 固定附加合规声明
5. 输出 `output/plans/{case_id}.md`；SOP 推进至阶段二（截止 = 1 个工作日）

## 3.5 build_dossier.py（对接材料包）

**输入**：方案 + 目标机构（Top 1 或用户指定）
**逻辑**：
1. 按机构类型生成标准材料清单（银行信贷：营业执照/近两年财报/纳税记录/经营流水/用途说明；股权机构：BP/股权结构/尽调材料）
2. 预填需求档案与画像已有信息（企业名称、注册区域、规模、用途）
3. 标注缺失材料与获取路径（如"纳税记录：电子税务局打印"）
4. 输出 `output/dossiers/{case_id}-{机构}.md`；SOP 推进至阶段三（截止 = 2 个工作日）

## 3.6 track_service.py（SOP 跟踪）

**输入**：`--case {case_id} --advance/--check/--review`
**逻辑**：
1. `--advance`：阶段推进（记录推进时间、责任人 `--owner`），自动计算下一阶段截止（工作日）
2. `--check`：批量扫描全部进行中 case，超期标记 `overdue` 并输出超期报告
3. `--review`：服务闭环后创建周期性回访任务（默认每季度）
4. 全程留痕于 `output/tracking/{case_id}.json`

## 3.7 save_to_db.py（结果落库）

**输入**：需求档案 + 方案 + 跟踪流水
**逻辑**：
1. company 表 upsert（org_type='beichen-enterprise'，需求摘要入 org_description）
2. tasks 表插入融资方案（task_type='finance-plan'，status='completed'）
3. tasks 表插入阶段服务任务（task_type='finance-service'，extra_data 含 sop_stage/due_date/owner/case_id）
4. 支持 psycopg2 直连或仅生成 SQL 文件

---

# 四、大模型接入设计（昇腾算力底座）

## 4.1 配置方式

runtime `.env`（与智能投研助理、产业政策技能共用配置）：

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

> 注：脚本侧 LLM 为可选增强（匹配语义研判/方案生成两处使用）；无配置时规则打分 + 模板降级，保证技能在任何环境可运行。

---

# 五、数据库落库设计

## 5.1 company 表 upsert

```sql
INSERT INTO public.company (company_name, region, org_description, org_type, is_verified)
VALUES ('{企业名称}', '{注册区域}', '{企业+融资需求摘要}', 'beichen-enterprise', false)
ON CONFLICT (company_name) DO UPDATE SET org_description = EXCLUDED.org_description;
```

## 5.2 tasks 表插入（方案 / 阶段服务任务）

```sql
-- 融资方案
INSERT INTO public.tasks
  (id, title, description, task_type, task_status, priority, company_id, tags, extra_data)
SELECT '{uuid}', '融资方案 - {企业名称}', '{方案正文}', 'finance-plan', 'completed', 'normal',
       c.id, '["beichen","finance-plan"]'::jsonb,
       '{"case_id":"{case_id}","amount":"{金额}","partners":["{机构1}","{机构2}"]}'::jsonb
FROM public.company c WHERE c.company_name = '{企业名称}';

-- 阶段服务任务（SOP 各阶段）
INSERT INTO public.tasks
  (id, title, description, task_type, task_status, priority, company_id, tags, extra_data)
SELECT '{uuid}', '{阶段名} - {企业名称}', '{阶段任务说明}', 'finance-service', 'pending', 'normal',
       c.id, '["beichen","finance-service"]'::jsonb,
       '{"case_id":"{case_id}","sop_stage":{n},"due_date":"{截止日期}","owner":"{责任人}"}'::jsonb
FROM public.company c WHERE c.company_name = '{企业名称}';
```

---

# 六、合规与安全设计

1. **数据合规**：仅使用命题目录与公开产品资料；服务经验案例脱敏后入库
2. **内容合规**：方案固定附加"仅供融资决策参考，不构成投资建议，最终以金融机构审批为准"声明
3. **权限安全**：财务信息属敏感数据，脚本仅本地处理与白名单数据库；RBAC 控制呈现权限
4. **审计留痕**：需求、匹配、方案、材料包、跟踪全流程产物持久化于 output/
5. **信创合规**：仓颉 Runtime + 昇腾算力 + 国产数据库

---

# 七、风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 伙伴库具体机构名/产品要素不全（命题仅给数量） | 匹配依据单薄 | 骨架先行 + web_search 合规补充 + 运营方持续维护机制 |
| 无 LLM 配置 | 方案质量下降 | 规则打分 + 模板降级（保证可运行） |
| 金融机构实际产品与库内要素偏差 | 方案失准 | 方案标注数据来源与假设，"最终以机构审批为准"声明 |
| SOP 时效为承诺值而非系统强制 | 超期无感知 | 超期自动标记 + 超期报告（可度量、可追责） |
| company 表无唯一约束 | upsert 冲突 | 先查后更兼容路径（沿用智能投研助理方案） |
| 财务数据敏感 | 泄露风险 | 本地处理、脱敏输出、RBAC、审计日志 |

---

# 八、验收检查清单

- [ ] SKILL.md 符合 AgentSkills 标准格式
- [ ] COMPOSITION.yaml 定义六步编排
- [ ] 7 个 Python 脚本齐全且语法正确
- [ ] knowledge/finance-partners 四类库生成（64/12/9/6）+ finance-index.json
- [ ] SOP 时效引擎（工作日计算、超期标记）正确
- [ ] 落库逻辑复用 company / tasks 表结构
- [ ] 支持昇腾 API（AtomGit）配置 + 降级路径
- [ ] 方案含合规免责声明
- [ ] runtime 加载技能成功（人工验证）
- [ ] 端到端执行成功（需求→匹配→方案→材料包→跟踪，人工验证）
- [ ] aibuilder 呈现方案与进度（人工验证）
