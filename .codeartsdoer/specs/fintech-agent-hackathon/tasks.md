# 智能投研助理参赛作品编码任务清单

> **文档定位**：本文档为 2026 昇腾 x AtomGit「金融行业应用 Agent 黑客松」参赛作品《智能投研助理》的任务清单（tasks.md），定义"按什么顺序做什么"。
>
> **版本**：v1.0 | **日期**：2026-08-07 | **提交截止**：2026-08-08 晚 24 点

---

## 任务总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 0 | 需求分析与比赛要求对照 | ✅ 完成 |
| Phase 1 | 创建智能投研助理 Skill（SKILL.md + COMPOSITION.yaml） | ✅ 完成 |
| Phase 2 | 编写 scripts 脚本（抓取/清洗/提取/生成/落库） | ✅ 完成 |
| Phase 3 | 撰写参赛文档（spec/design/tasks） | ✅ 完成 |
| Phase 4 | 配置昇腾算力（.env → AtomGit） | ⬜ 待完成 |
| Phase 5 | 端到端验证 + 录屏 + README 提交件 | ⬜ 人工验证 |

---

## Phase 0：需求分析与比赛要求对照

- [x] TASK-0-01：阅读比赛文档 comp.md（金融行业应用 Agent 黑客松）
- [x] TASK-0-02：选择赛题"智能投研助理 —— 自动抓取、清洗、提取，输出每日投资简报"
- [x] TASK-0-03：对照 3 个硬性要求（金融场景 / 必须能跑 / 解决真问题）
- [x] TASK-0-04：对照昇腾算力要求（昇腾 NPU 或昇腾 API）
- [x] TASK-0-05：对照评审标准（技术创新 25 / 场景落地 30 / 作品完整 25 / 答辩 20）
- [x] TASK-0-06：对照交付件要求（可运行代码 + 录屏视频 + 技术文档）

## Phase 1：创建智能投研助理 Skill

- [x] TASK-1-01：创建 `skills/investment-research-assistant/SKILL.md`（SOP 主文档）
  - 定义六步 SOP：抓取 → 清洗 → 提取 → 生成 → 落库 → 简报
  - 定义输入参数（companies/date/data_sources/output_dir）
  - 定义输出与使用示例
  - 安全合规章节（数据合规/内容合规/权限安全/信创合规）
- [x] TASK-1-02：创建 `skills/investment-research-assistant/COMPOSITION.yaml`（六步编排）

## Phase 2：编写 scripts 脚本

- [x] TASK-2-01：`scripts/fetch_market_data.py` —— 自动抓取（Step 1）
  - 公司列表解析（代码/名称归一化）
  - 公开行情接口抓取（合规）
  - 输出 `output/raw/{date}.json`，记录数据来源与时间
- [x] TASK-2-02：`scripts/clean_market_data.py` —— 数据清洗（Step 2）
  - 数值归一化、标题去重、无效数据剔除
  - 输出 `output/clean/{date}.json`
- [x] TASK-2-03：`scripts/extract_factors.py` —— 要素提取（Step 3）
  - 行情指标 / 情绪 / 风险提示提取
  - 输出 `output/factors/{date}.json`
- [x] TASK-2-04：`scripts/generate_report.py` —— 研报生成（Step 4）
  - 昇腾 API（AtomGit OpenAI 兼容）调用
  - 无 LLM 配置时模板降级（保证可运行）
  - 输出 `output/brief/{date}.md`，含免责声明
- [x] TASK-2-05：`scripts/save_report_to_db.py` —— 结果落库（Step 5）
  - company 表 upsert（按 company_name）
  - tasks 表插入研报（task_type='research'，关联 company_id）
  - 支持 psycopg2 直连或生成 SQL 文件

## Phase 3：撰写参赛文档

- [x] TASK-3-01：`spec.md` —— 需求规格（组件定位/设计原则/领域术语/角色边界/核心能力/数据约束/参赛要求对照/验收标准）
- [x] TASK-3-02：`design.md` —— 技术设计（架构图/目录结构/模块设计/昇腾接入/落库设计/合规安全/风险缓解/验收清单）
- [x] TASK-3-03：`tasks.md` —— 本任务清单

## Phase 4：配置昇腾算力（.env → AtomGit）

- [ ] TASK-4-01：修改 `apps/agentskills-runtime/.env` 大模型提供商为 AtomGit（昇腾 API）
  ```env
  MODEL_PROVIDER=atomgit
  MODEL_NAME=deepseek-v4-flash
  MODEL_CONFIG=atomgit:deepseek-v4-flash
  ATOMGIT_API_KEY=<token>
  ATOMGIT_BASE_URL=https://api-ai.gitcode.com/v1
  ```
- [ ] TASK-4-02：核对 `.env.example` 确认配置项完整

## Phase 5：端到端验证与提交件（人工操作）

- [ ] TASK-5-01：启动 runtime，确认技能加载成功（`skills/investment-research-assistant`）
- [ ] TASK-5-02：执行技能：`skill run investment-research-assistant:generate-daily-brief companies="600519,000858"`
- [ ] TASK-5-03：验证 output/raw、clean、factors、brief 各阶段产物
- [ ] TASK-5-04：验证 company / tasks 表落库，aibuilder 呈现研报
- [ ] TASK-5-05：录制演示视频（展示核心能力），链接放入 README
- [ ] TASK-5-06：撰写 README（产品文档 + 架构图 + 核心模块截图 + 性能数据）
- [ ] TASK-5-07：提交到 AtomGit 官方赛事仓库（8.8 晚 24 点前）

---

## 提交物清单

| # | 交付件 | 形式 | 状态 |
|---|--------|------|------|
| 1 | 产品可运行 | Skill + scripts 代码 | ✅ 代码完成，待人工运行验证 |
| 2 | 项目源码 | AtomGit 仓库 | ⬜ 待提交 |
| 3 | 技术文档 | README + spec/design/tasks | ⬜ README 待撰写 |
| 4 | 录屏视频 | 视频链接放 README | ⬜ 待录制 |
