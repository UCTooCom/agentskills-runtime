# Investment Research Assistant - Scripts

智能投研助理技能的脚本集合，实现六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报。

## 依赖

```bash
# Windows
pip install requests psycopg2-binary

# Linux/Mac
pip3 install requests psycopg2-binary
```

- `requests`：HTTP 抓取（fetch/generate 脚本；缺失时自动降级为 urllib）
- `psycopg2-binary`：直连 PostgreSQL 落库（仅 save_report_to_db.py 方式一需要；`--sql-only` 模式不需要）

## 脚本清单

| 脚本 | 步骤 | 输入 | 输出 | 关键参数 |
|------|------|------|------|---------|
| `fetch_market_data.py` | Step1 抓取 | `--companies`（必填） | `output/raw/{date}.json` | `--date` `--outdir` |
| `clean_market_data.py` | Step2 清洗 | `--input`（必填） | `output/clean/{date}.json` | `--outdir` |
| `extract_factors.py` | Step3 提取 | `--input`（必填） | `output/factors/{date}.json` | `--outdir` |
| `generate_report.py` | Step4 生成 | `--factors`（必填） | `output/brief/{date}.md` | `--outdir` |
| `save_report_to_db.py` | Step5 落库 | `--report`（必填） | `output/sql/report_*.sql` 或直连 DB | `--factors` `--sql-only` `--db-url` |

## 端到端执行示例

```bash
# Windows 用 python，Linux/Mac 用 python3
python fetch_market_data.py --companies "600519,000858,300750" --date 2026-08-11
python clean_market_data.py --input output/raw/2026-08-11.json
python extract_factors.py --input output/clean/2026-08-11.json
python generate_report.py --factors output/factors/2026-08-11.json
python save_report_to_db.py --report output/brief/2026-08-11.md --factors output/factors/2026-08-11.json --sql-only
```

## 数据源

- **东方财富公开行情接口**（`push2.eastmoney.com/api/qt/stock/get`）：收盘价、涨跌幅、PE/PB、成交量、市值
- **东方财富搜索接口**（`searchapi.eastmoney.com/api/suggest/get`）：公司名称 → 6 位代码解析
- 所有数据源均为公开/合规接口，仅用于技术交流

## 环境变量（generate_report.py 调 LLM 时）

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `LLM_BASE_URL` / `OPENAI_BASE_URL` | LLM API 基址 | `https://api-ai.gitcode.com/v1`（AtomGit 昇腾 API） |
| `LLM_API_KEY` / `OPENAI_API_KEY` | API 密钥 | 未设置时降级为模板化简报 |
| `LLM_MODEL` | 模型名 | `deepseek-v4-flash` |

## 环境变量（save_report_to_db.py 直连 DB 时）

| 变量 | 说明 | 示例 |
|------|------|------|
| `DATABASE_URL` | PostgreSQL 连接串 | `postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo` |

## 注意事项

- 东财接口返回值已放大 100 倍，`clean_market_data.py` 会 `/100` 还原为真实值
- 名称输入（如"贵州茅台"）会自动调东财搜索 API 解析为代码，搜索失败时占位待后续处理
- 非交易日运行时东财接口返回上一交易日数据
- 简报内容仅供技术交流，不构成投资建议
