# 金融匹配智能体（beichen-finance-matching）

北辰产业云社区命题"金融服务体系化"课题的参赛技能，实现产业金融服务 SOP 全流程线上化。

## 能力

- 金融工具数据库：90+ 金融伙伴与产品结构化知识库
- 融资需求采集与初步审核：完整性校验 + 可行性初判（SOP 阶段一，1 工作日）
- 需求匹配优势机构：硬性初筛 + 优势匹配打分 + 服务经验先验
- 定制金融方案：备选机构方案对比 + 适配理由 + 风险提示（SOP 阶段二）
- 对接材料包：标准材料清单 + 预填信息 + 缺失项标注（SOP 阶段三）
- SOP 六阶段跟踪：时效内建 + 超期自动标记 + 回访提醒
- 结果落库：company 表企业 + tasks 表融资方案/服务任务（aibuilder 呈现）

## 目录结构

```
beichen-finance-matching/
├── SKILL.md              # 技能定义（SOP 主文档）
├── COMPOSITION.yaml      # 全流程编排
├── README.md
├── knowledge/            # 金融工具数据库
│   ├── finance-seed.json         # 金融伙伴种子
│   ├── finance-partners/         # 伙伴库（banks/securities/funds/investors）
│   ├── finance-products/         # 产品要素库
│   ├── finance-experience/       # 服务经验库（脱敏）
│   └── finance-index.json        # 总索引（init 生成）
├── scripts/
│   ├── init_finance_kb.py        # 工具库初始化
│   ├── collect_financing_need.py # 需求采集
│   ├── match_finance.py          # 机构匹配
│   ├── generate_finance_plan.py  # 方案生成
│   ├── build_dossier.py          # 对接材料包
│   ├── track_service.py          # SOP 跟踪
│   └── save_to_db.py             # 结果落库
└── output/               # 运行产物（不入库）
    ├── needs/  matches/  plans/  dossiers/  tracking/  sql/
```

## 依赖

```bash
pip install requests psycopg2-binary
```

## 端到端执行

```bash
# 0. 初始化金融工具数据库
python scripts/init_finance_kb.py --seed knowledge/finance-seed.json

# 1. 需求建档
python scripts/collect_financing_need.py --company "北京北辰实业有限公司" --amount "500万" --purpose "研发投入"

# 2. 机构匹配
python scripts/match_finance.py --need output/needs/{case_id}.json

# 3. 方案生成
python scripts/generate_finance_plan.py --need output/needs/{case_id}.json --matches output/matches/{case_id}.json

# 4. 对接材料包
python scripts/build_dossier.py --need output/needs/{case_id}.json --partner "光大银行"

# 5. SOP 跟踪
python scripts/track_service.py --case {case_id} --advance --owner "张工"

# 6. 落库
python scripts/save_to_db.py --need output/needs/{case_id}.json --plan output/plans/{case_id}.md --tracking output/tracking/{case_id}.json --sql-only
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `LLM_BASE_URL` / `OPENAI_BASE_URL` | LLM API 基址 | `https://api-ai.gitcode.com/v1`（AtomGit 昇腾 API） |
| `LLM_API_KEY` / `OPENAI_API_KEY` | API 密钥 | 未设置时降级为规则/模板 |
| `LLM_MODEL` | 模型名 | `deepseek-v4-flash` |
| `DATABASE_URL` | PostgreSQL 连接串（直连模式） | — |

## 合规声明

融资方案仅供融资决策参考，不构成投资建议，最终以金融机构审批为准。