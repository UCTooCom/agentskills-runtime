# 金融匹配技能（北辰金融匹配智能体）编码任务清单

> **文档定位**：本文档为 shenicest 黑客松参赛作品核心开发件《金融匹配技能》（`beichen-finance-matching`）的任务清单（tasks.md），定义"按什么顺序做什么"。
>
> **版本**：v1.0 | **日期**：2026-08-29

---

## 任务总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 0 | 需求分析与命题要求对照 | ✅ 完成 |
| Phase 1 | 种子数据与金融工具数据库初始化 | ⬜ 待完成 |
| Phase 2 | 创建技能（SKILL.md + COMPOSITION.yaml + scripts） | ⬜ 待完成 |
| Phase 3 | 撰写需求文档（spec/design/tasks） | ✅ 完成 |
| Phase 4 | 配置昇腾算力（.env → AtomGit） | ⬜ 待完成 |
| Phase 5 | 端到端验证 + 演示素材 | ⬜ 人工验证 |

---

## Phase 0：需求分析与命题要求对照

- [x] TASK-0-01：研读《北辰产业云社区命题 PPT》金融服务体系化章节（90+ 伙伴：64 银行/12 证券/9 基金/6 投资公司，200+ 家次服务经验）
- [x] TASK-0-02：拆解北辰商管产业金融 SOP 六阶段与时效承诺（1d/1d/2d/3-5d/约定时限/长期）
- [x] TASK-0-03：确认三大痛点（融资难/对接繁/流程慢）与三大保障原则（精准高效对接/专属全程辅导/标准前置管控）
- [x] TASK-0-04：确定技能形态实现方案（技能与智能体可互转，asr 一切皆技能插件系统）
- [x] TASK-0-05：对照 shenicest 赛道要求（真实解决具体问题 / 必须能跑 / 注重稳定与数据安全）
- [x] TASK-0-06：确认复用清单（runtime 内置工具 / 昇腾 API / company+tasks 表 / aibuilder / WebMCP / 智能投研助理 SOP 范式 / 产业政策技能画像互认）

## Phase 1：种子数据与金融工具数据库初始化

- [ ] TASK-1-01：生成 `knowledge/finance-seed.json`（64 银行/12 证券/9 基金/6 投资公司骨架；演示环境示例机构名，正式部署替换真实数据）
- [ ] TASK-1-02：编写 `scripts/init_finance_kb.py`，生成四类伙伴库 JSON + `finance-index.json`
- [ ] TASK-1-03：创建产品要素库（`finance-products/`）——为银行信贷/知识产权质押/科技金融专项/股权投资/上市辅导等高频产品补充要素条目（额度/期限/担保/客群/优势领域）
- [ ] TASK-1-04：创建服务经验库（`finance-experience/`）——3-5 个脱敏案例要点（行业/规模/产品/周期/结果）

## Phase 2：创建技能与脚本

- [ ] TASK-2-01：创建 `skills/beichen-finance-matching/SKILL.md`（SOP 主文档）
  - 定义六步 SOP：需求建档 → 机构匹配 → 方案生成 → 材料包 → SOP 跟踪 → 落库呈现
  - 定义输入参数（company/amount/term/purpose/guarantee/revenue/case_id/owner/topn）
  - 安全合规章节（数据合规/财务信息敏感级/内容合规/信创合规）
- [ ] TASK-2-02：创建 `COMPOSITION.yaml`（六步编排）
- [ ] TASK-2-03：`scripts/collect_financing_need.py` —— 需求采集与初步审核（SOP 阶段一）
  - 结构化建档 + 完整性校验 + 可行性初判（规则可解释）
  - 自动带入产业政策技能画像（存在 output/profiles 时）
  - 生成 case_id，阶段一截止 = 1 个工作日
- [ ] TASK-2-04：`scripts/match_finance.py` —— 需求匹配优势金融机构
  - 硬性初筛（额度/期限/担保对标产品要素）
  - 优势匹配打分（领域命中 50% + 服务经验先验 30% + 周期适配 20%）
  - LLM 语义研判可选增强；输出 Top N 匹配矩阵
- [ ] TASK-2-05：`scripts/generate_finance_plan.py` —— 定制金融方案（SOP 阶段二）
  - 昇腾 API（AtomGit OpenAI 兼容）生成备选方案对比表 + 适配理由 + 组合建议 + 风险提示
  - 无 LLM 模板降级；固定合规声明
- [ ] TASK-2-06：`scripts/build_dossier.py` —— 对接材料包（SOP 阶段三）
  - 按机构类型标准材料清单 + 预填已有信息 + 缺失项与获取路径标注
- [ ] TASK-2-07：`scripts/track_service.py` —— SOP 六阶段跟踪
  - SOP_STAGES 时效引擎（工作日计算，1d/1d/2d/5d/约定/长期）
  - --advance 阶段推进（--owner 责任到人）/ --check 超期批量标记 / --review 回访任务
- [ ] TASK-2-08：`scripts/save_to_db.py` —— 结果落库
  - company upsert（org_type='beichen-enterprise'，与产业政策技能共用）
  - tasks 插入 finance-plan（completed）+ finance-service（含 sop_stage/due_date/owner）
  - psycopg2 直连或生成 SQL 文件

## Phase 3：撰写需求文档

- [x] TASK-3-01：`spec.md` —— 需求规格（组件定位/设计原则/领域术语/角色边界/核心能力/数据约束/命题对照/验收标准）
- [x] TASK-3-02：`design.md` —— 技术设计（架构图/目录结构/伙伴库格式/SOP 时效引擎/模块设计/昇腾接入/落库设计/合规安全/风险缓解/验收清单）
- [x] TASK-3-03：`tasks.md` —— 本任务清单

## Phase 4：配置昇腾算力（.env → AtomGit）

- [ ] TASK-4-01：确认 `apps/agentskills-runtime/.env` 大模型提供商为 AtomGit（昇腾 API）
  ```env
  MODEL_PROVIDER=atomgit
  MODEL_NAME=deepseek-v4-flash
  MODEL_CONFIG=atomgit:deepseek-v4-flash
  ATOMGIT_API_KEY=<token>
  ATOMGIT_BASE_URL=https://api-ai.gitcode.com/v1
  ```
- [ ] TASK-4-02：核对脚本侧 `LLM_BASE_URL/LLM_API_KEY/LLM_MODEL` 环境变量

## Phase 5：端到端验证与演示素材（人工操作）

- [ ] TASK-5-01：启动 runtime，确认技能加载成功（`skills/beichen-finance-matching`）
- [ ] TASK-5-02：执行需求建档：`skill run beichen-finance-matching:intake company="北京XX科技有限公司" amount="500万" purpose="研发投入"`
- [ ] TASK-5-03：执行匹配与方案生成，验证 output/needs、matches、plans 各阶段产物
- [ ] TASK-5-04：生成对接材料包（output/dossiers），核对清单完整性与预填信息
- [ ] TASK-5-05：SOP 跟踪演练（--advance 逐阶段推进 + --check 超期标记），验证时效引擎正确性
- [ ] TASK-5-06：验证 company / tasks 落库，aibuilder 呈现方案与进度任务
- [ ] TASK-5-07：双技能协同验证：产业政策技能画像 → 金融匹配技能建档自动带入
- [ ] TASK-5-08：录制演示片段（供作品演示视频剪辑：需求→匹配→方案→材料包→进度闭环）
- [ ] TASK-5-09：更新 shenicestHackathon 项目文档 4.4 节（金融匹配智能体→技能实现）引用本技能

---

## 提交物清单

| # | 交付件 | 形式 | 状态 |
|---|--------|------|------|
| 1 | 技能源码 | skills/beichen-finance-matching（SKILL.md + knowledge + scripts） | ⬜ 待开发 |
| 2 | 种子数据 | knowledge/finance-seed.json（64/12/9/6 伙伴骨架） | ⬜ 待生成 |
| 3 | 需求文档 | spec.md / design.md / tasks.md | ✅ 完成 |
| 4 | 端到端演示 | 演示视频片段 + aibuilder 截图 | ⬜ 待录制 |
