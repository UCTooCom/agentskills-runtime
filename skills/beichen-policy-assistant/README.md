# 产业政策智能体（beichen-policy-assistant）

北辰产业云社区命题"政策赋能精准化"课题的参赛技能，实现政策库—匹配库—申报库全流程服务。

## 能力

- 全景企业画像：输入企业名称，聚合工商/经营/舆情公开信息
- 三层知识库：政策原文库 / 官方解读库 / 实操洞察库，根除 AI 幻觉
- 多元政策匹配：本地知识库 + 全网实时资源双源检索，语义级匹配
- 政策库自动更新：每日抓取政府网站 → 储备库 → 人工研判 → 正式库
- 申报闭环：匹配政策生成申报任务，材料清单与进度跟踪
- 结果落库：company 表企业画像 + tasks 表匹配报告/申报任务（aibuilder 呈现）

## 目录结构

```
beichen-policy-assistant/
├── SKILL.md              # 技能定义（SOP 主文档）
├── COMPOSITION.yaml      # 主流程编排
├── README.md
├── knowledge/            # 三层知识库
│   ├── policy-seed.json          # 74 条政策目录种子
│   ├── policy-original/          # 政策原文库（init 生成）
│   ├── policy-interpretation/    # 官方解读库
│   ├── policy-insight/           # 实操洞察库
│   └── policy-index.json         # 政策索引（init 生成）
├── scripts/
│   ├── init_policy_kb.py         # 知识库初始化
│   ├── build_enterprise_profile.py # 企业画像
│   ├── match_policy.py           # 政策匹配
│   ├── update_policy_kb.py       # 政策库自动更新
│   ├── generate_policy_report.py # 适配报告
│   └── save_to_db.py             # 结果落库
└── output/               # 运行产物（不入库）
    ├── profiles/  matches/  reports/  pending/  sql/
```

## 依赖

```bash
pip install requests psycopg2-binary
```

- `requests`：HTTP 抓取（缺省自动降级 urllib）
- `psycopg2-binary`：直连 PostgreSQL 落库（`--sql-only` 模式不需要）

## 端到端执行

```bash
# 0. 初始化知识库（74 条种子）
python scripts/init_policy_kb.py --seed knowledge/policy-seed.json

# 1. 企业画像
python scripts/build_enterprise_profile.py --company "北京北辰实业有限公司"

# 2. 政策匹配
python scripts/match_policy.py --profile output/profiles/beijing_beichen_shiyeyouxiangongsi.json

# 3. 适配报告
python scripts/generate_policy_report.py \
  --profile output/profiles/beijing_beichen_shiyeyouxiangongsi.json \
  --matches output/matches/beijing_beichen_shiyeyouxiangongsi-$(date +%F).json

# 4. 落库（生成 SQL 文件）
python scripts/save_to_db.py \
  --profile output/profiles/beijing_beichen_shiyeyouxiangongsi.json \
  --report output/reports/beijing_beichen_shiyeyouxiangongsi-$(date +%F).md \
  --matches output/matches/beijing_beichen_shiyeyouxiangongsi-$(date +%F).json \
  --sql-only
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `LLM_BASE_URL` / `OPENAI_BASE_URL` | LLM API 基址 | `https://api-ai.gitcode.com/v1`（AtomGit 昇腾 API） |
| `LLM_API_KEY` / `OPENAI_API_KEY` | API 密钥 | 未设置时降级为规则/模板 |
| `LLM_MODEL` | 模型名 | `deepseek-flash` |
| `DATABASE_URL` | PostgreSQL 连接串（直连模式） | — |

## 合规声明

匹配报告内容仅供申报参考，不构成法律意见；政策更新须经人工研判确认后方可入库。